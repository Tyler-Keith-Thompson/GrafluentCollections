@_exported import CollectionErrors

/// A rope: a sequence stored as a balanced tree of chunks, so inserting, removing or replacing
/// elements anywhere costs O(log *n*) plus the elements moved within one chunk, rather than the
/// O(*n*) an array spends shifting everything after the edit.
///
/// The chunks, each up to a few kilobytes of elements, are the vertices of an AVL tree in flat
/// arrays, in sequence order, and each vertex records how many elements its subtree holds, so an
/// offset is found from the root in O(log *n*) (Boehm, Atkinson and Plass, "Ropes: an Alternative
/// to Strings", 1995). Each chunk is its own copy-on-write buffer: a copy of a rope shares every
/// chunk with the original until one of them edits it, and appending one rope to another shares
/// the appended rope's chunks.
///
/// ```swift
/// var text = Rope("Hello, world!")
/// text.insert(contentsOf: "brave new ", at: 7)
/// String(text)                       // "Hello, brave new world!"
/// text.removeSubrange(5 ..< 16)
/// String(text)                       // "Hello world!"
/// text[6]                            // "w"
/// ```
///
/// Indices are offsets from the start, `0 ..< count`. Reading an element costs O(log *n*), and
/// O(1) amortized over a pass through the rope.
@frozen
public struct Rope<Element> {
    /// The chunks and their links; slots in `_free` are unused.
    @usableFromInline package var _nodes: ContiguousArray<_RopeNode<Element>>
    @usableFromInline var _root: Int32
    @usableFromInline var _free: ContiguousArray<Int32>

    /// An empty rope.
    @inlinable
    public init() {
        _nodes = []
        _root = -1
        _free = []
    }

    /// The most elements a chunk holds: about 2 KB of them, and at least 16.
    @inlinable
    static var _maximumChunk: Int {
        Swift.max(16, 2_048 / Swift.max(1, MemoryLayout<Element>.stride))
    }

    @inlinable
    public var count: Int { _size(_root) }

    // MARK: - Editing

    /// Inserts `newElements` at `offset`.
    ///
    /// - Parameters:
    ///   - newElements: The elements to insert.
    ///   - offset: Where they go. Traps unless it is in `0 ... count`.
    /// - Complexity: O(log *n* + *c*) for a few elements and a chunk of *c*; O((*k* / *c* + 1)
    ///   log *n* + *k*) for *k* elements.
    @inlinable
    public mutating func insert(contentsOf newElements: some Collection<Element>, at offset: Int) {
        precondition(offset >= 0 && offset <= count, "Offset out of range")
        let new = ContiguousArray(newElements)
        guard !new.isEmpty else { return }
        let maximum = Self._maximumChunk
        guard _root >= 0 else {
            _insertChunks(of: new, at: 0)
            return
        }
        let (slot, within) = _locate(offset, endInclusive: true)
        let chunkCount = _nodes[Int(slot)].chunk.count
        if chunkCount &+ new.count <= maximum {
            _root = _editChunk(_root, at: offset, endInclusive: true) { chunk, index in
                chunk.insert(contentsOf: new, at: index)
            }
            return
        }
        if within == chunkCount && new.count < maximum {
            // At the end of a full chunk: start the next one, so appends fill chunks.
            _insertNode(chunk: new, at: offset)
            return
        }
        if new.count < maximum / 2 {
            // Insert into the chunk, then split the overfull chunk in half.
            var tail = ContiguousArray<Element>()
            let start = offset &- within
            _root = _editChunk(_root, at: offset, endInclusive: true) { chunk, index in
                chunk.insert(contentsOf: new, at: index)
                let half = chunk.count / 2
                tail = ContiguousArray(chunk[half...])
                chunk.removeSubrange(half...)
            }
            let half = (chunkCount &+ new.count) / 2
            _insertNode(chunk: tail, at: start &+ half)
            return
        }
        // Split the chunk at the offset and put the new elements between, in chunks of their own.
        if within > 0 && within < chunkCount {
            var tail = ContiguousArray<Element>()
            _root = _editChunk(_root, at: offset, endInclusive: true) { chunk, index in
                tail = ContiguousArray(chunk[index...])
                chunk.removeSubrange(index...)
            }
            _insertNode(chunk: tail, at: offset)
        }
        _insertChunks(of: new, at: offset)
    }

    /// Inserts `newElement` at `offset`.
    ///
    /// - Parameter offset: Traps unless it is in `0 ... count`.
    /// - Complexity: O(log *n* + *c*) for chunks of *c* elements.
    @inlinable
    public mutating func insert(_ newElement: Element, at offset: Int) {
        insert(contentsOf: CollectionOfOne(newElement), at: offset)
    }

    /// Removes the elements at `offsets`.
    ///
    /// - Parameter offsets: Traps unless it lies in `0 ... count`.
    /// - Complexity: O((*k* / *c* + 1) log *n* + *c*) for *k* elements and chunks of *c*.
    @inlinable
    public mutating func removeSubrange(_ offsets: Range<Int>) {
        precondition(offsets.lowerBound >= 0 && offsets.upperBound <= count, "Range out of bounds")
        var remaining = offsets.count
        let start = offsets.lowerBound
        while remaining > 0 {
            let (slot, within) = _locate(start, endInclusive: false)
            let chunkCount = _nodes[Int(slot)].chunk.count
            if within == 0 && remaining >= chunkCount {
                _root = _removeNode(at: start, from: _root)
                remaining &-= chunkCount
            } else {
                let removed = Swift.min(remaining, chunkCount &- within)
                _root = _editChunk(_root, at: start, endInclusive: false) { chunk, index in
                    chunk.removeSubrange(index ..< index &+ removed)
                }
                remaining &-= removed
            }
        }
    }

    /// Appends the elements of `other`, sharing its chunks rather than copying their elements.
    ///
    /// - Complexity: O(*m* log(*n* + *m*)) for the *m* chunks of `other`.
    @inlinable
    public mutating func append(contentsOf other: Rope) {
        var offset = count
        other._forEachChunk { chunk in
            _insertNode(chunk: chunk, at: offset)
            offset &+= chunk.count
        }
    }

    /// The rope of the elements at `offsets`, sharing the chunks that lie wholly inside them.
    ///
    /// - Parameter offsets: Traps unless it lies in `0 ... count`.
    /// - Complexity: O((*k* / *c* + 1) log *n* + *c*) for *k* elements and chunks of *c*.
    @inlinable
    public func extracting(_ offsets: Range<Int>) -> Rope {
        precondition(offsets.lowerBound >= 0 && offsets.upperBound <= count, "Range out of bounds")
        var result = Rope()
        var offset = offsets.lowerBound
        while offset < offsets.upperBound {
            let (slot, within) = _locate(offset, endInclusive: false)
            let chunk = _nodes[Int(slot)].chunk
            let taken = Swift.min(chunk.count &- within, offsets.upperBound &- offset)
            if within == 0 && taken == chunk.count {
                result._insertNode(chunk: chunk, at: result.count)
            } else {
                result._insertNode(chunk: ContiguousArray(chunk[within ..< within &+ taken]), at: result.count)
            }
            offset &+= taken
        }
        return result
    }

    /// The elements of `lhs` followed by those of `rhs`, sharing the chunks of both.
    ///
    /// - Complexity: O(*m* log(*n* + *m*)) for the *m* chunks of `rhs`.
    @inlinable
    public static func + (lhs: Rope, rhs: Rope) -> Rope {
        var result = lhs
        result.append(contentsOf: rhs)
        return result
    }

    /// The element at `offset`, throwing instead of trapping on an invalid offset.
    ///
    /// - Throws: ``IndexOutOfRange`` unless `offset` is in `0 ..< count`.
    /// - Complexity: O(log *n*).
    @inlinable
    public subscript(checked offset: Int) -> Element {
        get throws(IndexOutOfRange) {
            guard offset >= 0 && offset < count else { throw IndexOutOfRange() }
            let (slot, within) = _locate(offset, endInclusive: false)
            return _nodes[Int(slot)].chunk[within]
        }
    }

    // MARK: - Internals

    @inlinable @inline(__always)
    func _size(_ x: Int32) -> Int { x < 0 ? 0 : _nodes[Int(x)].size }

    @inlinable @inline(__always)
    func _height(_ x: Int32) -> Int32 { x < 0 ? 0 : _nodes[Int(x)].height }

    /// The chunk holding `offset` and the offset within it. With `endInclusive`, an offset at the
    /// end of a chunk may be answered with that chunk, as an insertion there may use it.
    @inlinable
    func _locate(_ offset: Int, endInclusive: Bool) -> (slot: Int32, within: Int) {
        var x = _root
        var offset = offset
        while true {
            let left = _nodes[Int(x)].left
            let leftSize = _size(left)
            let chunkCount = _nodes[Int(x)].chunk.count
            if offset < leftSize {
                x = left
            } else if offset < leftSize &+ chunkCount || (endInclusive && offset == leftSize &+ chunkCount) {
                return (x, offset &- leftSize)
            } else {
                offset &-= leftSize &+ chunkCount
                x = _nodes[Int(x)].right
            }
        }
    }

    /// Edits the chunk `_locate(offset, endInclusive:)` finds with `body`, given the chunk and the
    /// offset within it, and updates the sizes on the path; returns the subtree's root.
    @inlinable
    mutating func _editChunk(_ x: Int32, at offset: Int, endInclusive: Bool, _ body: (inout ContiguousArray<Element>, Int) -> Void) -> Int32 {
        let left = _nodes[Int(x)].left
        let leftSize = _size(left)
        let chunkCount = _nodes[Int(x)].chunk.count
        if offset < leftSize {
            _nodes[Int(x)].left = _editChunk(left, at: offset, endInclusive: endInclusive, body)
        } else if offset < leftSize &+ chunkCount || (endInclusive && offset == leftSize &+ chunkCount) {
            body(&_nodes[Int(x)].chunk, offset &- leftSize)
        } else {
            let right = _nodes[Int(x)].right
            _nodes[Int(x)].right = _editChunk(right, at: offset &- leftSize &- chunkCount, endInclusive: endInclusive, body)
        }
        _update(x)
        return x
    }

    /// Inserts the elements as chunks of their own starting at the chunk boundary `offset`.
    @inlinable
    mutating func _insertChunks(of elements: ContiguousArray<Element>, at offset: Int) {
        let maximum = Self._maximumChunk
        var start = 0
        while start < elements.count {
            let end = Swift.min(start &+ maximum, elements.count)
            _insertNode(chunk: ContiguousArray(elements[start ..< end]), at: offset &+ start)
            start = end
        }
    }

    /// Inserts a vertex holding `chunk` at the chunk boundary `offset`.
    @inlinable
    mutating func _insertNode(chunk: ContiguousArray<Element>, at offset: Int) {
        guard !chunk.isEmpty else { return }
        let node = _RopeNode(chunk: chunk)
        let slot: Int32
        if let free = _free.popLast() {
            slot = free
            _nodes[Int(free)] = node
        } else {
            precondition(_nodes.count < Int(Int32.max), "A rope holds fewer than 2³¹ chunks")
            slot = Int32(truncatingIfNeeded: _nodes.count)
            _nodes.append(node)
        }
        _root = _insertNode(slot, at: offset, into: _root)
    }

    @inlinable
    mutating func _insertNode(_ slot: Int32, at offset: Int, into x: Int32) -> Int32 {
        guard x >= 0 else { return slot }
        let left = _nodes[Int(x)].left
        let leftSize = _size(left)
        if offset <= leftSize {
            _nodes[Int(x)].left = _insertNode(slot, at: offset, into: left)
        } else {
            let right = _nodes[Int(x)].right
            _nodes[Int(x)].right = _insertNode(slot, at: offset &- leftSize &- _nodes[Int(x)].chunk.count, into: right)
        }
        return _rebalance(x)
    }

    /// Removes the vertex whose chunk starts at `offset`; returns the subtree's new root.
    @inlinable
    mutating func _removeNode(at offset: Int, from x: Int32) -> Int32 {
        let left = _nodes[Int(x)].left
        let right = _nodes[Int(x)].right
        let leftSize = _size(left)
        if offset < leftSize {
            _nodes[Int(x)].left = _removeNode(at: offset, from: left)
            return _rebalance(x)
        }
        if offset > leftSize {
            _nodes[Int(x)].right = _removeNode(at: offset &- leftSize &- _nodes[Int(x)].chunk.count, from: right)
            return _rebalance(x)
        }
        _nodes[Int(x)].chunk = []
        _free.append(x)
        if left < 0 { return right }
        if right < 0 { return left }
        let (rest, successor) = _removeFirst(right)
        _nodes[Int(successor)].left = left
        _nodes[Int(successor)].right = rest
        return _rebalance(successor)
    }

    /// Unlinks the first vertex of the subtree; returns the subtree's new root and that vertex.
    @inlinable
    mutating func _removeFirst(_ x: Int32) -> (root: Int32, first: Int32) {
        let left = _nodes[Int(x)].left
        if left < 0 { return (_nodes[Int(x)].right, x) }
        let (rest, first) = _removeFirst(left)
        _nodes[Int(x)].left = rest
        return (_rebalance(x), first)
    }

    @inlinable
    mutating func _update(_ x: Int32) {
        let left = _nodes[Int(x)].left
        let right = _nodes[Int(x)].right
        _nodes[Int(x)].height = Swift.max(_height(left), _height(right)) &+ 1
        _nodes[Int(x)].size = _size(left) &+ _size(right) &+ _nodes[Int(x)].chunk.count
    }

    @inlinable
    mutating func _rotateRight(_ x: Int32) -> Int32 {
        let left = _nodes[Int(x)].left
        _nodes[Int(x)].left = _nodes[Int(left)].right
        _nodes[Int(left)].right = x
        _update(x)
        _update(left)
        return left
    }

    @inlinable
    mutating func _rotateLeft(_ x: Int32) -> Int32 {
        let right = _nodes[Int(x)].right
        _nodes[Int(x)].right = _nodes[Int(right)].left
        _nodes[Int(right)].left = x
        _update(x)
        _update(right)
        return right
    }

    @inlinable
    mutating func _rebalance(_ x: Int32) -> Int32 {
        _update(x)
        let left = _nodes[Int(x)].left
        let right = _nodes[Int(x)].right
        let balance = _height(left) &- _height(right)
        if balance > 1 {
            if _height(_nodes[Int(left)].left) < _height(_nodes[Int(left)].right) {
                _nodes[Int(x)].left = _rotateLeft(left)
            }
            return _rotateRight(x)
        }
        if balance < -1 {
            if _height(_nodes[Int(right)].right) < _height(_nodes[Int(right)].left) {
                _nodes[Int(x)].right = _rotateRight(right)
            }
            return _rotateLeft(x)
        }
        return x
    }

    /// Calls `body` with each chunk in order.
    @inlinable
    func _forEachChunk(_ body: (ContiguousArray<Element>) -> Void) {
        var slots = _ChunkSlots(_nodes, root: _root)
        while let slot = slots.next() {
            body(_nodes[Int(slot)].chunk)
        }
    }

    /// The vertices' slots in order, by an explicit stack of the left spine.
    @usableFromInline
    struct _ChunkSlots {
        @usableFromInline let nodes: ContiguousArray<_RopeNode<Element>>
        @usableFromInline var stack: ContiguousArray<Int32>

        @inlinable
        init(_ nodes: ContiguousArray<_RopeNode<Element>>, root: Int32) {
            self.nodes = nodes
            stack = []
            var x = root
            while x >= 0 {
                stack.append(x)
                x = nodes[Int(x)].left
            }
        }

        @inlinable
        mutating func next() -> Int32? {
            guard let x = stack.popLast() else { return nil }
            var y = nodes[Int(x)].right
            while y >= 0 {
                stack.append(y)
                y = nodes[Int(y)].left
            }
            return x
        }
    }
}

/// One vertex of a rope: a chunk of its elements, its children's slots (−1 for none), its height
/// in vertices, and the number of elements in its subtree.
@frozen
@usableFromInline
package struct _RopeNode<Element> {
    @usableFromInline package var chunk: ContiguousArray<Element>
    @usableFromInline var left: Int32
    @usableFromInline var right: Int32
    @usableFromInline var height: Int32
    @usableFromInline var size: Int

    @inlinable
    init(chunk: ContiguousArray<Element>) {
        self.chunk = chunk
        left = -1
        right = -1
        height = 1
        size = chunk.count
    }
}

extension Rope: RandomAccessCollection, MutableCollection {
    public typealias Index = Int
    public typealias Indices = Range<Int>

    @inlinable public var startIndex: Int { 0 }
    @inlinable public var endIndex: Int { count }
    @inlinable public var isEmpty: Bool { _root < 0 }

    /// The element at `offset`.
    ///
    /// - Parameter offset: Traps unless it is in `0 ..< count`; use ``subscript(checked:)`` to
    ///   throw instead when reading.
    /// - Complexity: O(log *n*), plus O(*c*) to copy a chunk shared with another rope when
    ///   writing.
    @inlinable
    public subscript(offset: Int) -> Element {
        get {
            precondition(offset >= 0 && offset < count, "Offset out of range")
            let (slot, within) = _locate(offset, endInclusive: false)
            return _nodes[Int(slot)].chunk[within]
        }
        set {
            precondition(offset >= 0 && offset < count, "Offset out of range")
            let (slot, within) = _locate(offset, endInclusive: false)
            _nodes[Int(slot)].chunk[within] = newValue
        }
    }

    /// Iterates chunk by chunk, in O(1) amortized per element.
    @frozen
    public struct Iterator: IteratorProtocol {
        @usableFromInline var _slots: _ChunkSlots
        @usableFromInline var _chunk: ContiguousArray<Element>
        @usableFromInline var _position: Int
        @usableFromInline var _end: Int

        @inlinable
        init(_ rope: Rope) {
            _slots = _ChunkSlots(rope._nodes, root: rope._root)
            _chunk = []
            _position = 0
            _end = 0
        }

        @inlinable
        public mutating func next() -> Element? {
            let position = _position
            if position < _end {
                _position = position &+ 1
                // In bounds: `_end` is the chunk's count.
                return _chunk.withUnsafeBufferPointer { $0[position] }
            }
            return _nextChunk()
        }

        @inlinable @inline(never)
        mutating func _nextChunk() -> Element? {
            while true {
                guard let slot = _slots.next() else { return nil }
                _chunk = _slots.nodes[Int(slot)].chunk
                _end = _chunk.count
                if _end > 0 {
                    _position = 1
                    return _chunk[0]
                }
            }
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(self)
    }
}

extension Rope: RangeReplaceableCollection {
    /// Replaces the elements at `offsets` with `newElements`.
    ///
    /// - Complexity: O((*k* / *c* + 1) log *n* + *c*) for *k* elements removed and inserted and
    ///   chunks of *c*.
    @inlinable
    public mutating func replaceSubrange(_ offsets: Range<Int>, with newElements: some Collection<Element>) {
        precondition(offsets.lowerBound >= 0 && offsets.upperBound <= count, "Range out of bounds")
        removeSubrange(offsets)
        insert(contentsOf: newElements, at: offsets.lowerBound)
    }

    /// The rope of `elements`, in order. O(*n*).
    @inlinable
    public init(_ elements: some Sequence<Element>) {
        self.init()
        _insertChunks(of: ContiguousArray(elements), at: 0)
    }

    @inlinable
    public mutating func append(_ newElement: Element) {
        insert(contentsOf: CollectionOfOne(newElement), at: count)
    }

    @inlinable
    public mutating func append(contentsOf newElements: some Sequence<Element>) {
        insert(contentsOf: ContiguousArray(newElements), at: count)
    }
}

extension Rope: ExpressibleByArrayLiteral {
    /// The rope of the literal's elements. O(*n*).
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension Rope: Equatable where Element: Equatable {
    /// Whether two ropes hold the same elements in the same order, however they are chunked. O(*n*).
    @inlinable
    public static func == (lhs: Rope, rhs: Rope) -> Bool {
        lhs.count == rhs.count && lhs.elementsEqual(rhs)
    }
}

extension Rope: Hashable where Element: Hashable {
    /// Hashes the count and the elements, in order, however they are chunked. O(*n*).
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for element in self {
            hasher.combine(element)
        }
    }
}

extension Rope: Sendable where Element: Sendable {}
extension _RopeNode: Sendable where Element: Sendable {}
extension Rope._ChunkSlots: Sendable where Element: Sendable {}

extension Rope: CustomStringConvertible {
    /// The elements, in order, written as an array literal.
    public var description: String {
        Array(self).description
    }
}

extension Rope {
    /// The rope's chunks in sequence order, each a run of consecutive elements stored together.
    ///
    /// The *i*th chunk is vertex *i* of `BinaryTree(rope)`. Concatenating the chunks gives the
    /// rope's elements; no chunk is empty.
    ///
    /// - Complexity: O(log *m*) to start for *m* chunks, then O(1) amortized per chunk.
    @inlinable
    public var chunksView: ChunksView { ChunksView(self) }

    /// A rope's chunks in sequence order.
    @frozen
    public struct ChunksView: Sequence {
        @usableFromInline let _nodes: ContiguousArray<_RopeNode<Element>>
        @usableFromInline let _root: Int32

        @inlinable
        init(_ rope: Rope) {
            _nodes = rope._nodes
            _root = rope._root
        }

        /// Walks the chunks in sequence order.
        @frozen
        public struct Iterator: IteratorProtocol {
            @usableFromInline var _slots: _ChunkSlots

            @inlinable
            init(_ slots: _ChunkSlots) {
                _slots = slots
            }

            /// The next chunk, or nil after the last.
            @inlinable
            public mutating func next() -> ContiguousArray<Element>? {
                guard let slot = _slots.next() else { return nil }
                return _slots.nodes[Int(slot)].chunk
            }
        }

        /// An iterator over the chunks.
        @inlinable
        public func makeIterator() -> Iterator {
            Iterator(_ChunkSlots(_nodes, root: _root))
        }
    }
}

extension Rope.ChunksView: Sendable where Element: Sendable {}
extension Rope.ChunksView.Iterator: Sendable where Element: Sendable {}
