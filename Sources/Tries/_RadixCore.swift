/// A radix tree's storage (Morrison, 1968): a trie in which every chain of vertices with one child
/// and no key is merged into one edge labelled with its symbols. Vertex 0 is the root, the empty
/// prefix; every other vertex `v` extends its parent's prefix by its label, the symbols
/// `labels[labelStarts[v] ..< labelStarts[v] + labelLengths[v]]`. No vertex but the root has one
/// child and no key, and every leaf ends a key. A vertex's children start with distinct symbols
/// and form a chain through `nextSiblings`, starting at `firstChildren[v]`: sorted by their first
/// symbol when the symbols are `Comparable`, in the order they were added otherwise. `values[v]`
/// is the value of the key ending at `v`, nil when none does, and `counts[v]` the number of keys at
/// or below `v`.
///
/// Labels are slices of one buffer. A split cuts a label in two where it is, and a merge joins two
/// labels in place when they lie side by side, appending a copy otherwise; the buffer is compacted
/// when its unused symbols outnumber the labels'. A removal fills a deleted vertex's slot with the
/// last vertex, redirecting the links to it.
@frozen
@usableFromInline
package struct _RadixCore<Symbol: Hashable, Value> {
    @usableFromInline package var labels: ContiguousArray<Symbol>
    @usableFromInline package var labelStarts: ContiguousArray<Int32>
    @usableFromInline package var labelLengths: ContiguousArray<Int32>
    @usableFromInline package var parents: ContiguousArray<Int32>
    @usableFromInline package var firstChildren: ContiguousArray<Int32>
    @usableFromInline package var nextSiblings: ContiguousArray<Int32>
    @usableFromInline package var counts: ContiguousArray<Int32>
    @usableFromInline package var values: ContiguousArray<Value?>
    /// The symbols the labels use: `labels.count` less the unused ones.
    @usableFromInline package var liveSymbols: Int

    /// The tree holding no keys: the root alone.
    @inlinable
    init() {
        labels = []
        labelStarts = [0]
        labelLengths = [0]
        parents = [-1]
        firstChildren = [-1]
        nextSiblings = [-1]
        counts = [0]
        values = [nil]
        liveSymbols = 0
    }

    /// The number of keys.
    @inlinable
    package var count: Int { Int(counts[0]) }

    /// The number of vertices, the root included.
    @inlinable
    package var vertexCount: Int { parents.count }

    /// The first symbol of `vertex`'s label, which must not be the root's.
    @inlinable
    func firstSymbol(of vertex: Int32) -> Symbol {
        labels[Int(labelStarts[Int(vertex)])]
    }

    /// The child of `vertex` whose label starts with `symbol`, or −1, and the child before it.
    @inlinable
    func child(of vertex: Int32, startingWith symbol: Symbol) -> (child: Int32, previous: Int32) {
        var previous: Int32 = -1
        var child = firstChildren[Int(vertex)]
        while child >= 0 && firstSymbol(of: child) != symbol {
            previous = child
            child = nextSiblings[Int(child)]
        }
        return (child, previous)
    }

    // MARK: Reads

    /// Where a search for a sequence of symbols stops.
    @frozen
    @usableFromInline
    struct _Stop {
        /// The last vertex whose whole prefix the search matched.
        @usableFromInline var vertex: Int32
        /// The child of `vertex` the search went on into, or −1, and how many symbols of its label
        /// matched.
        @usableFromInline var child: Int32
        @usableFromInline var matched: Int32
        /// Whether the sequence ran out: at `vertex` when `child` is −1, inside `child`'s label
        /// otherwise.
        @usableFromInline var isExhausted: Bool

        @inlinable
        init(vertex: Int32, child: Int32, matched: Int32, isExhausted: Bool) {
            self.vertex = vertex
            self.child = child
            self.matched = matched
            self.isExhausted = isExhausted
        }
    }

    /// Follows `key` from the root as far as the labels match it.
    @inlinable
    func _search(_ key: some Sequence<Symbol>) -> _Stop {
        labels.withUnsafeBufferPointer { labels in
            labelStarts.withUnsafeBufferPointer { labelStarts in
                labelLengths.withUnsafeBufferPointer { labelLengths in
                    firstChildren.withUnsafeBufferPointer { firstChildren in
                        nextSiblings.withUnsafeBufferPointer { nextSiblings in
                            var symbols = key.makeIterator()
                            var vertex: Int32 = 0
                            while let symbol = symbols.next() {
                                var child = firstChildren[Int(vertex)]
                                while child >= 0 && labels[Int(labelStarts[Int(child)])] != symbol {
                                    child = nextSiblings[Int(child)]
                                }
                                guard child >= 0 else {
                                    return _Stop(vertex: vertex, child: -1, matched: 0, isExhausted: false)
                                }
                                let start = Int(labelStarts[Int(child)])
                                let length = Int(labelLengths[Int(child)])
                                var matched = 1
                                while matched < length {
                                    guard let next = symbols.next() else {
                                        return _Stop(
                                            vertex: vertex,
                                            child: child,
                                            matched: Int32(truncatingIfNeeded: matched),
                                            isExhausted: true
                                        )
                                    }
                                    guard next == labels[start &+ matched] else {
                                        return _Stop(
                                            vertex: vertex,
                                            child: child,
                                            matched: Int32(truncatingIfNeeded: matched),
                                            isExhausted: false
                                        )
                                    }
                                    matched &+= 1
                                }
                                vertex = child
                            }
                            return _Stop(vertex: vertex, child: -1, matched: 0, isExhausted: true)
                        }
                    }
                }
            }
        }
    }

    /// The topmost vertex whose prefix starts with `prefix`, or −1 when no key starts with it:
    /// the vertex of `prefix` itself, or the vertex whose label `prefix` ends inside.
    @inlinable
    package func vertex(for prefix: some Sequence<Symbol>) -> Int32 {
        let stop = _search(prefix)
        guard stop.isExhausted else { return -1 }
        return stop.child >= 0 ? stop.child : stop.vertex
    }

    /// The value of `key`, or nil when the tree doesn't hold it.
    @inlinable
    package func value(forKey key: some Sequence<Symbol>) -> Value? {
        let stop = _search(key)
        guard stop.isExhausted && stop.child < 0 else { return nil }
        return values[Int(stop.vertex)]
    }

    /// The deepest vertex along `query` at which a key ends, or −1 when none does.
    @inlinable
    package func longestKeyVertex(along query: some Sequence<Symbol>) -> Int32 {
        var symbols = query.makeIterator()
        var vertex: Int32 = 0
        var found: Int32 = values[0] == nil ? -1 : 0
        while let symbol = symbols.next() {
            let child = child(of: vertex, startingWith: symbol).child
            guard child >= 0 else { break }
            let start = Int(labelStarts[Int(child)])
            let length = Int(labelLengths[Int(child)])
            var matched = 1
            while matched < length, let next = symbols.next(), next == labels[start &+ matched] {
                matched &+= 1
            }
            guard matched == length else { break }
            vertex = child
            if values[Int(vertex)] != nil { found = vertex }
        }
        return found
    }

    /// The prefix that `vertex` stands for. O(depth + length).
    @inlinable
    package func key(of vertex: Int32) -> [Symbol] {
        var length = 0
        var v = vertex
        while v > 0 {
            length &+= Int(labelLengths[Int(v)])
            v = parents[Int(v)]
        }
        return [Symbol](unsafeUninitializedCapacity: length) { buffer, initialized in
            var end = length
            var v = vertex
            while v > 0 {
                let start = Int(labelStarts[Int(v)])
                let count = Int(labelLengths[Int(v)])
                end &-= count
                var k = 0
                while k < count {
                    (buffer.baseAddress! + (end &+ k)).initialize(to: labels[start &+ k])
                    k &+= 1
                }
                v = parents[Int(v)]
            }
            initialized = length
        }
    }

    // MARK: Mutations

    /// Sets the value of `key`, adding the key when absent.
    ///
    /// - Returns: The value it replaced, or nil when the key was added.
    @inlinable
    package mutating func updateValue(_ value: Value, forKey key: some Sequence<Symbol>) -> Value? {
        let vertex = _makeVertex(for: key)
        let old = values[Int(vertex)]
        values[Int(vertex)] = value
        if old == nil { _addToCounts(from: vertex, 1) }
        return old
    }

    /// Adds `key` with `value` unless the tree holds it.
    ///
    /// - Returns: Whether it was added, and the vertex where the key ends.
    @inlinable
    package mutating func insert(_ key: some Sequence<Symbol>, _ value: Value) -> (inserted: Bool, vertex: Int32) {
        let vertex = _makeVertex(for: key)
        guard values[Int(vertex)] == nil else { return (false, vertex) }
        values[Int(vertex)] = value
        _addToCounts(from: vertex, 1)
        return (true, vertex)
    }

    /// The vertex for `key`, splitting a label where `key` ends or leaves it, and adding a leaf
    /// for the symbols past the last match.
    @inlinable
    mutating func _makeVertex(for key: some Sequence<Symbol>) -> Int32 {
        var symbols = key.makeIterator()
        var vertex: Int32 = 0
        while let symbol = symbols.next() {
            let (child, _) = child(of: vertex, startingWith: symbol)
            guard child >= 0 else {
                return _addLeaf(under: vertex, first: symbol, rest: &symbols)
            }
            let start = Int(labelStarts[Int(child)])
            let length = Int32(labelLengths[Int(child)])
            var matched: Int32 = 1
            while matched < length {
                guard let next = symbols.next() else {
                    return _split(child, at: matched)
                }
                guard next == labels[start &+ Int(matched)] else {
                    let middle = _split(child, at: matched)
                    return _addLeaf(under: middle, first: next, rest: &symbols)
                }
                matched &+= 1
            }
            vertex = child
        }
        return vertex
    }

    /// Cuts `vertex`'s label after `offset` symbols: a new vertex takes the first part and the
    /// vertex's place among its siblings, and `vertex` keeps the rest as its only child.
    ///
    /// - Returns: The new vertex.
    @inlinable
    mutating func _split(_ vertex: Int32, at offset: Int32) -> Int32 {
        precondition(parents.count < Int(Int32.max), "A radix tree holds fewer than 2³¹ − 1 vertices")
        let middle = Int32(truncatingIfNeeded: parents.count)
        let v = Int(vertex)
        let parent = parents[v]
        let start = labelStarts[v]
        labelStarts.append(start)
        labelLengths.append(offset)
        parents.append(parent)
        firstChildren.append(vertex)
        nextSiblings.append(nextSiblings[v])
        counts.append(counts[v])
        values.append(nil)
        _replaceInChain(of: parent, vertex, with: middle)
        parents[v] = middle
        nextSiblings[v] = -1
        labelStarts[v] = start &+ offset
        labelLengths[v] &-= offset
        return middle
    }

    /// A new leaf under `parent` whose label is `first` and then the rest of `symbols`, in its
    /// place in the parent's chain.
    @inlinable
    mutating func _addLeaf(
        under parent: Int32,
        first: Symbol,
        rest symbols: inout some IteratorProtocol<Symbol>
    ) -> Int32 {
        precondition(parents.count < Int(Int32.max), "A radix tree holds fewer than 2³¹ − 1 vertices")
        let leaf = Int32(truncatingIfNeeded: parents.count)
        let start = labels.count
        labels.append(first)
        while let symbol = symbols.next() {
            labels.append(symbol)
        }
        precondition(labels.count < Int(Int32.max), "A radix tree's labels hold fewer than 2³¹ − 1 symbols")
        let length = labels.count &- start
        liveSymbols &+= length
        var previous: Int32 = -1
        var next: Int32 = -1
        if let order = Symbol.self as? any Comparable.Type {
            (previous, next) = _insertionPoint(of: first, under: parent, order)
        } else {
            var child = firstChildren[Int(parent)]
            while child >= 0 {
                previous = child
                child = nextSiblings[Int(child)]
            }
        }
        labelStarts.append(Int32(truncatingIfNeeded: start))
        labelLengths.append(Int32(truncatingIfNeeded: length))
        parents.append(parent)
        firstChildren.append(-1)
        nextSiblings.append(next)
        counts.append(0)
        values.append(nil)
        if previous < 0 {
            firstChildren[Int(parent)] = leaf
        } else {
            nextSiblings[Int(previous)] = leaf
        }
        return leaf
    }

    /// Where a child starting with `symbol` goes in the sorted chain of `parent`'s children:
    /// between `previous` and `next`, −1 for the chain's ends. `Order` is `Symbol`, found to be
    /// `Comparable` at run time.
    @inlinable
    func _insertionPoint<Order: Comparable>(
        of symbol: Symbol,
        under parent: Int32,
        _: Order.Type
    ) -> (previous: Int32, next: Int32) {
        let ordered = unsafeBitCast(symbol, to: Order.self)
        var previous: Int32 = -1
        var child = firstChildren[Int(parent)]
        while child >= 0 && unsafeBitCast(firstSymbol(of: child), to: Order.self) < ordered {
            previous = child
            child = nextSiblings[Int(child)]
        }
        return (previous, child)
    }

    /// Removes `key`, then deletes a leaf it leaves without a key and merges a vertex it leaves
    /// with one child and no key into that child.
    ///
    /// - Returns: The key's value, or nil when the tree doesn't hold it.
    @inlinable
    package mutating func removeValue(forKey key: some Sequence<Symbol>) -> Value? {
        let stop = _search(key)
        guard stop.isExhausted && stop.child < 0, let old = values[Int(stop.vertex)] else { return nil }
        var vertex = stop.vertex
        values[Int(vertex)] = nil
        _addToCounts(from: vertex, -1)
        guard vertex > 0 else { return old }
        if firstChildren[Int(vertex)] < 0 {
            var parent = parents[Int(vertex)]
            _unlink(vertex, from: parent)
            liveSymbols &-= Int(labelLengths[Int(vertex)])
            if _delete(vertex) == parent {
                parent = vertex
            }
            vertex = parent
        }
        _mergeIfOnlyChild(vertex)
        _compactLabelsIfSparse()
        return old
    }

    /// Merges `vertex` into its child when it is not the root, has no key and has one child.
    @inlinable
    mutating func _mergeIfOnlyChild(_ vertex: Int32) {
        let v = Int(vertex)
        let child = firstChildren[v]
        guard vertex > 0, values[v] == nil, child >= 0, nextSiblings[Int(child)] < 0 else { return }
        let c = Int(child)
        let start = labelStarts[v]
        let length = labelLengths[v]
        if labelStarts[c] == start &+ length {
            labelStarts[c] = start
        } else {
            let newStart = labels.count
            let childStart = Int(labelStarts[c])
            let childLength = Int(labelLengths[c])
            labels.reserveCapacity(newStart &+ Int(length) &+ childLength)
            var k = 0
            while k < Int(length) {
                labels.append(labels[Int(start) &+ k])
                k &+= 1
            }
            k = 0
            while k < childLength {
                labels.append(labels[childStart &+ k])
                k &+= 1
            }
            precondition(labels.count < Int(Int32.max), "A radix tree's labels hold fewer than 2³¹ − 1 symbols")
            labelStarts[c] = Int32(truncatingIfNeeded: newStart)
        }
        labelLengths[c] &+= length
        let parent = parents[v]
        nextSiblings[c] = nextSiblings[v]
        parents[c] = parent
        _replaceInChain(of: parent, vertex, with: child)
        firstChildren[v] = -1
        _delete(vertex)
    }

    /// Rebuilds the label buffer from the labels in use when more than half of it is unused.
    @inlinable
    mutating func _compactLabelsIfSparse() {
        guard labels.count > 64 && labels.count > 2 &* liveSymbols else { return }
        var compacted = ContiguousArray<Symbol>()
        compacted.reserveCapacity(liveSymbols)
        var v = 1
        while v < parents.count {
            let start = Int(labelStarts[v])
            let length = Int(labelLengths[v])
            labelStarts[v] = Int32(truncatingIfNeeded: compacted.count)
            compacted.append(contentsOf: labels[start ..< start &+ length])
            v &+= 1
        }
        labels = compacted
    }

    /// Adds `delta` to the counts of `vertex` and every vertex above it.
    @inlinable
    mutating func _addToCounts(from vertex: Int32, _ delta: Int32) {
        var v = vertex
        while v >= 0 {
            counts[Int(v)] &+= delta
            v = parents[Int(v)]
        }
    }

    /// Puts `replacement` where `vertex` is in `parent`'s chain of children; `replacement` must
    /// already link to `vertex`'s next sibling.
    @inlinable
    mutating func _replaceInChain(of parent: Int32, _ vertex: Int32, with replacement: Int32) {
        if firstChildren[Int(parent)] == vertex {
            firstChildren[Int(parent)] = replacement
            return
        }
        var sibling = firstChildren[Int(parent)]
        while nextSiblings[Int(sibling)] != vertex {
            sibling = nextSiblings[Int(sibling)]
        }
        nextSiblings[Int(sibling)] = replacement
    }

    /// Takes `vertex` out of its parent's chain of children.
    @inlinable
    mutating func _unlink(_ vertex: Int32, from parent: Int32) {
        let next = nextSiblings[Int(vertex)]
        if firstChildren[Int(parent)] == vertex {
            firstChildren[Int(parent)] = next
            return
        }
        var sibling = firstChildren[Int(parent)]
        while nextSiblings[Int(sibling)] != vertex {
            sibling = nextSiblings[Int(sibling)]
        }
        nextSiblings[Int(sibling)] = next
    }

    /// Deletes `vertex`, already out of its parent's chain and with no children of its own, by
    /// moving the last vertex into its slot.
    ///
    /// - Returns: The vertex that moved into the slot, or −1 when `vertex` was the last.
    @inlinable
    @discardableResult
    mutating func _delete(_ vertex: Int32) -> Int32 {
        let last = Int32(truncatingIfNeeded: parents.count &- 1)
        let v = Int(vertex)
        if vertex != last {
            let l = Int(last)
            labelStarts[v] = labelStarts[l]
            labelLengths[v] = labelLengths[l]
            parents[v] = parents[l]
            firstChildren[v] = firstChildren[l]
            nextSiblings[v] = nextSiblings[l]
            counts[v] = counts[l]
            values.swapAt(v, l)
            _replaceInChain(of: parents[v], last, with: vertex)
            var child = firstChildren[v]
            while child >= 0 {
                parents[Int(child)] = vertex
                child = nextSiblings[Int(child)]
            }
        }
        labelStarts.removeLast()
        labelLengths.removeLast()
        parents.removeLast()
        firstChildren.removeLast()
        nextSiblings.removeLast()
        counts.removeLast()
        values.removeLast()
        return vertex == last ? -1 : last
    }

    // MARK: Traversal

    /// The keys at or below a vertex with their values, in preorder: a key before the keys it is
    /// a prefix of, and children in chain order. O(1) per vertex, plus its label and a copy of
    /// each key.
    @frozen
    @usableFromInline
    package struct Preorder {
        @usableFromInline let core: _RadixCore
        @usableFromInline let start: Int32
        /// The vertex to visit next, −1 when done, and the prefix it stands for.
        @usableFromInline var vertex: Int32
        @usableFromInline var key: [Symbol]

        @inlinable
        init(_ core: _RadixCore, from start: Int32) {
            self.core = core
            self.start = start
            vertex = start
            key = start > 0 ? core.key(of: start) : []
        }

        @inlinable
        package mutating func next() -> (key: [Symbol], value: Value)? {
            while vertex >= 0 {
                let value = core.values[Int(vertex)]
                let found = value == nil ? nil : key
                _advance()
                if let value, let found {
                    return (found, value)
                }
            }
            return nil
        }

        /// Appends `vertex`'s label to `key`.
        @inlinable
        mutating func _appendLabel(of vertex: Int32) {
            let start = Int(core.labelStarts[Int(vertex)])
            key.append(contentsOf: core.labels[start ..< start &+ Int(core.labelLengths[Int(vertex)])])
        }

        /// Moves to the next vertex in preorder within the start's subtree.
        @inlinable
        mutating func _advance() {
            let child = core.firstChildren[Int(vertex)]
            if child >= 0 {
                vertex = child
                _appendLabel(of: child)
                return
            }
            while vertex != start && core.nextSiblings[Int(vertex)] < 0 {
                key.removeLast(Int(core.labelLengths[Int(vertex)]))
                vertex = core.parents[Int(vertex)]
            }
            if vertex == start {
                vertex = -1
                return
            }
            key.removeLast(Int(core.labelLengths[Int(vertex)]))
            vertex = core.nextSiblings[Int(vertex)]
            _appendLabel(of: vertex)
        }
    }
}

extension _RadixCore: Sendable where Symbol: Sendable, Value: Sendable {}
extension _RadixCore.Preorder: Sendable where Symbol: Sendable, Value: Sendable {}
