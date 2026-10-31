@_exported import CollectionErrors

/// A sorted set kept in a splay tree: a binary search tree that rotates each element it
/// accesses, inserts or removes up to the root (Sleator and Tarjan, 1985).
///
/// A splay tree keeps no balance information. Any sequence of *m* insertions, removals and
/// accesses on *n* elements costs O((*m* + *n*) log *n*) in all, so each takes O(log *n*)
/// amortized, and recently or frequently accessed elements stay near the root: accessing the
/// elements in ascending order costs O(*n*) in all. Reads (`contains(_:)`, the bounds, the
/// subscripts and iteration) leave the tree as it is, so they keep the value semantics and the
/// API of the other sorted sets, and take time proportional to the element's depth, which a run
/// of ascending insertions can make *n*. Use ``access(_:)`` to look an element up and splay it.
///
/// ```swift
/// var recent: SplayTree = [10, 20, 30, 40, 50]
/// recent.access(40)             // 40, now at the root
/// recent.contains(25)           // false, and the tree is unchanged
/// let parts = recent.split(at: 30)
/// Array(parts.lower)            // [10, 20]
/// Array(parts.upper)            // [30, 40, 50]
/// ```
///
/// The elements are a random-access collection in ascending order, indexed by rank like an
/// array: `tree[0]` is the smallest element. The vertices live in flat arrays with `Int32`
/// links, so the tree holds fewer than 2³¹ − 1 elements, and copying it copies a few arrays only
/// when one copy is mutated.
@frozen
public struct SplayTree<Element: Comparable> {
    @usableFromInline
    package var _core: _TreeCore<Element, Void, _SplayBalancing>

    @inlinable
    init(_core: _TreeCore<Element, Void, _SplayBalancing>) {
        self._core = _core
    }

    /// An empty tree.
    @inlinable
    public init() {
        _core = _TreeCore()
    }

    /// The tree holding the distinct elements of `elements`; of equal elements, the first is
    /// kept.
    ///
    /// - Parameter elements: The elements, in any order.
    /// - Complexity: O(*n* log *n*) to sort them, then O(*n*) to build a balanced tree.
    @inlinable
    public init(_ elements: some Sequence<Element>) {
        var keys = ContiguousArray(elements)
        var isStrictlyAscending = true
        var k = 1
        while k < keys.count {
            if !(keys[k &- 1] < keys[k]) {
                isStrictlyAscending = false
                break
            }
            k &+= 1
        }
        if !isStrictlyAscending {
            // Sorted with each element's position as the tie-break, so the first of equal ones leads.
            var ordered = ContiguousArray(zip(keys, 0 ..< keys.count))
            ordered.sort { a, b in a.0 < b.0 || (!(b.0 < a.0) && a.1 < b.1) }
            keys.removeAll(keepingCapacity: true)
            for (element, _) in ordered where keys.isEmpty || keys[keys.count &- 1] < element {
                keys.append(element)
            }
        }
        _core = _TreeCore(sortedUniqueKeys: keys, values: ContiguousArray(repeating: (), count: keys.count))
    }

    /// The number of elements on the longest path from the root down: 0 when empty, 1 for one
    /// element, and at most *n*. The tree does not record it, so reading it walks every vertex.
    /// O(*n*).
    @inlinable
    public var height: Int { _core.measuredHeight() }

    /// Looks up `element` and splays: the element equal to it, or else the last one its search
    /// passed, moves to the root.
    ///
    /// - Parameter element: The element to look up.
    /// - Returns: The element equal to `element`, or nil when none is.
    /// - Complexity: O(log *n*) amortized, plus O(*n*) when the storage is shared with another
    ///   copy.
    @inlinable
    @discardableResult
    public mutating func access(_ element: Element) -> Element? {
        let slot = _core.access(element)
        return slot < 0 ? nil : _core.key(at: slot)
    }

    /// Whether the tree holds an element equal to `element`. O(depth).
    @inlinable
    public func contains(_ element: Element) -> Bool {
        _core.slot(of: element) >= 0
    }

    /// The index of the first element not less than `element`, or `endIndex` when every element
    /// is less. O(depth).
    @inlinable
    public func lowerBound(_ element: Element) -> Int {
        _core.countBelow(element, orEqual: false)
    }

    /// The index of the first element greater than `element`, or `endIndex` when none is.
    /// O(depth).
    @inlinable
    public func upperBound(_ element: Element) -> Int {
        _core.countBelow(element, orEqual: true)
    }

    /// The elements in `range`, in ascending order. O(depth).
    @inlinable
    public func elements(in range: Range<Element>) -> Slice<SplayTree> {
        self[lowerBound(range.lowerBound) ..< lowerBound(range.upperBound)]
    }

    /// The elements in `range`, in ascending order. O(depth).
    @inlinable
    public func elements(in range: ClosedRange<Element>) -> Slice<SplayTree> {
        self[lowerBound(range.lowerBound) ..< upperBound(range.upperBound)]
    }

    /// The smallest element, or nil when empty. O(depth).
    @inlinable
    public func min() -> Element? {
        let slot = _core.extremeSlot(last: false)
        return slot < 0 ? nil : _core.key(at: slot)
    }

    /// The largest element, or nil when empty. O(depth).
    @inlinable
    public func max() -> Element? {
        let slot = _core.extremeSlot(last: true)
        return slot < 0 ? nil : _core.key(at: slot)
    }

    /// Removes and returns the element at `index`.
    ///
    /// - Parameter index: The index of the element. Traps unless it is a valid index; use
    ///   ``remove(checkedAt:)`` to throw instead.
    /// - Complexity: O(log *n*) amortized, plus O(*n*) when the storage is shared with another
    ///   copy.
    @inlinable
    @discardableResult
    public mutating func remove(at index: Int) -> Element {
        precondition(index >= 0 && index < _core.count, "Index out of range")
        return _core.remove(atRank: index).key
    }

    /// Removes and returns the element at `index`, throwing instead of trapping on an invalid
    /// index.
    ///
    /// - Parameter index: The index of the element.
    /// - Throws: `IndexOutOfRange` unless `index` is a valid index; the tree is unchanged.
    /// - Complexity: O(log *n*) amortized, plus O(*n*) when the storage is shared with another
    ///   copy.
    @inlinable
    @discardableResult
    public mutating func remove(checkedAt index: Int) throws(IndexOutOfRange) -> Element {
        guard index >= 0 && index < _core.count else { throw IndexOutOfRange() }
        return _core.remove(atRank: index).key
    }

    /// The element at `position`, throwing instead of trapping on an invalid index.
    ///
    /// - Parameter position: The index of the element.
    /// - Throws: `IndexOutOfRange` unless `position` is a valid index.
    /// - Complexity: O(depth).
    @inlinable
    public subscript(checked position: Int) -> Element {
        get throws(IndexOutOfRange) {
            guard position >= 0 && position < _core.count else { throw IndexOutOfRange() }
            return _core.key(at: _core.slot(atRank: position))
        }
    }
}

extension SplayTree {
    /// The two trees a split produces: the elements below the split point, and the rest.
    @frozen
    public struct Split {
        /// The elements below the split point.
        public var lower: SplayTree

        /// The elements not below the split point.
        public var upper: SplayTree

        /// The parts of a split.
        ///
        /// - Parameters:
        ///   - lower: The elements below the split point.
        ///   - upper: The elements not below the split point.
        @inlinable
        public init(lower: SplayTree, upper: SplayTree) {
            self.lower = lower
            self.upper = upper
        }
    }

    /// Splits the tree into the elements below `element` and the rest.
    ///
    /// Splays at `element` first, then copies the smaller part out.
    ///
    /// - Parameter element: The split point. It goes to the upper part when the tree holds it.
    /// - Returns: The lower part, whose elements are all less than `element`, and the upper part.
    /// - Complexity: O(*k* log *n*) amortized, where *k* is the smaller part's count, plus O(*n*)
    ///   when the storage is shared with another copy.
    @inlinable
    public consuming func split(at element: Element) -> Split {
        // Moved out, so the split mutates storage this tree no longer shares.
        let core = _core
        _core = _TreeCore()
        let parts = core.split(at: element)
        return Split(
            lower: SplayTree(_core: parts.lower),
            upper: SplayTree(_core: parts.upper)
        )
    }

    /// Adds the elements of `other`, all of which lie above this tree's elements or all below
    /// them.
    ///
    /// - Parameter other: The tree joined in.
    /// - Throws: `OverlappingKeys` when neither tree's elements all lie below the other's; the
    ///   tree is unchanged.
    /// - Complexity: O(*m* + log *n*) amortized, where *m* is `other.count`, plus O(*n*) when the
    ///   storage is shared with another copy.
    @inlinable
    public mutating func join(_ other: SplayTree) throws(OverlappingKeys) {
        guard let otherMin = other.min(), let otherMax = other.max() else { return }
        guard let selfMin = min(), let selfMax = max() else {
            _core = other._core
            return
        }
        if selfMax < otherMin {
            _core.join(other._core, otherIsUpper: true)
        } else if otherMax < selfMin {
            _core.join(other._core, otherIsUpper: false)
        } else {
            throw OverlappingKeys()
        }
    }
}


extension SplayTree: RandomAccessCollection {
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public typealias SubSequence = Slice<SplayTree>

    @inlinable public var startIndex: Int { 0 }
    @inlinable public var endIndex: Int { _core.count }
    @inlinable public var count: Int { _core.count }
    @inlinable public var isEmpty: Bool { _core.count == 0 }

    /// The element at `position`, the `position`-th smallest.
    ///
    /// - Parameter position: The index of the element. Traps unless it is a valid index; use
    ///   ``subscript(checked:)`` to throw instead.
    /// - Complexity: O(depth).
    @inlinable
    public subscript(position: Int) -> Element {
        precondition(position >= 0 && position < _core.count, "Index out of range")
        return _core.key(at: _core.slot(atRank: position))
    }

    /// An iterator over the elements in ascending order: O(*n*) for the whole pass, O(depth)
    /// extra space.
    @frozen
    public struct Iterator: IteratorProtocol {
        @usableFromInline var _slots: _TreeCore<Element, Void, _SplayBalancing>.InorderSlots

        @inlinable
        init(_ core: _TreeCore<Element, Void, _SplayBalancing>) {
            _slots = _TreeCore.InorderSlots(core)
        }

        @inlinable
        public mutating func next() -> Element? {
            guard let slot = _slots.next() else { return nil }
            return _slots.nodes[Int(slot)].key
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_core)
    }

    @inlinable
    public func _customContainsEquatableElement(_ element: Element) -> Bool? {
        contains(element)
    }

    /// Finds `element` by descending the tree, so `firstIndex(of:)` costs O(depth).
    @inlinable
    public func _customIndexOfEquatableElement(_ element: Element) -> Int?? {
        .some(_core.rank(of: element))
    }

    /// Finds `element` by descending the tree, so `lastIndex(of:)` costs O(depth).
    @inlinable
    public func _customLastIndexOfEquatableElement(_ element: Element) -> Int?? {
        .some(_core.rank(of: element))
    }
}

extension SplayTree: SetAlgebra {
    /// Inserts `newMember` unless an equal element is present.
    ///
    /// - Returns: Whether it was inserted, and the member equal to `newMember` afterwards.
    /// - Complexity: O(log *n*) amortized, plus O(*n*) when the storage is shared with another
    ///   copy.
    @inlinable
    @discardableResult
    public mutating func insert(_ newMember: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        let (inserted, slot) = _core.insert(newMember, ())
        return (inserted, inserted ? newMember : _core.key(at: slot))
    }

    /// Inserts `newMember`, replacing an equal element if present.
    ///
    /// - Returns: The element replaced, or nil when none was equal.
    /// - Complexity: O(log *n*) amortized, plus O(*n*) when the storage is shared with another
    ///   copy.
    @inlinable
    @discardableResult
    public mutating func update(with newMember: Element) -> Element? {
        let (inserted, slot) = _core.insert(newMember, ())
        guard !inserted else { return nil }
        let old = _core.key(at: slot)
        _core.nodes[Int(slot)].key = newMember
        return old
    }

    /// Removes the element equal to `member`.
    ///
    /// - Returns: The element removed, or nil when none was equal.
    /// - Complexity: O(log *n*) amortized, plus O(*n*) when the storage is shared with another
    ///   copy.
    @inlinable
    @discardableResult
    public mutating func remove(_ member: Element) -> Element? {
        _core.remove(member)?.key
    }

    /// The elements of either tree; of equal elements, this tree's. O(*n* + *m*).
    @inlinable
    public func union(_ other: SplayTree) -> SplayTree {
        _merge(other, keepOnlyLeft: true, keepOnlyRight: true, keepBoth: true)
    }

    /// The elements of both trees, as this tree holds them. O(*n* + *m*).
    @inlinable
    public func intersection(_ other: SplayTree) -> SplayTree {
        _merge(other, keepOnlyLeft: false, keepOnlyRight: false, keepBoth: true)
    }

    /// The elements of exactly one of the trees. O(*n* + *m*).
    @inlinable
    public func symmetricDifference(_ other: SplayTree) -> SplayTree {
        _merge(other, keepOnlyLeft: true, keepOnlyRight: true, keepBoth: false)
    }

    /// The elements of this tree that are not in `other`. O(*n* + *m*).
    @inlinable
    public func subtracting(_ other: SplayTree) -> SplayTree {
        _merge(other, keepOnlyLeft: true, keepOnlyRight: false, keepBoth: false)
    }

    /// Adds the elements of `other`, keeping this tree's of equal ones. O(*n* + *m*).
    @inlinable
    public mutating func formUnion(_ other: SplayTree) {
        self = union(other)
    }

    /// Keeps only the elements also in `other`. O(*n* + *m*).
    @inlinable
    public mutating func formIntersection(_ other: SplayTree) {
        self = intersection(other)
    }

    /// Keeps the elements of exactly one of the trees. O(*n* + *m*).
    @inlinable
    public mutating func formSymmetricDifference(_ other: SplayTree) {
        self = symmetricDifference(other)
    }

    /// Removes the elements also in `other`. O(*n* + *m*).
    @inlinable
    public mutating func subtract(_ other: SplayTree) {
        self = subtracting(other)
    }

    /// Merges both trees' elements in order and builds a balanced tree of those kept.
    @inlinable
    func _merge(_ other: SplayTree, keepOnlyLeft: Bool, keepOnlyRight: Bool, keepBoth: Bool) -> SplayTree {
        var keys = ContiguousArray<Element>()
        keys.reserveCapacity(_core.count &+ other._core.count)
        var left = makeIterator()
        var right = other.makeIterator()
        var a = left.next()
        var b = right.next()
        while let x = a, let y = b {
            if x < y {
                if keepOnlyLeft { keys.append(x) }
                a = left.next()
            } else if y < x {
                if keepOnlyRight { keys.append(y) }
                b = right.next()
            } else {
                if keepBoth { keys.append(x) }
                a = left.next()
                b = right.next()
            }
        }
        if keepOnlyLeft {
            while let x = a {
                keys.append(x)
                a = left.next()
            }
        }
        if keepOnlyRight {
            while let y = b {
                keys.append(y)
                b = right.next()
            }
        }
        return SplayTree(_core: _TreeCore(sortedUniqueKeys: keys, values: ContiguousArray(repeating: (), count: keys.count)))
    }
}

extension SplayTree: ExpressibleByArrayLiteral {
    /// The tree holding the literal's distinct elements. O(*n* log *n*).
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension SplayTree: Equatable {
    /// Whether two trees hold equal elements, whatever their shapes. O(*n*).
    @inlinable
    public static func == (lhs: SplayTree, rhs: SplayTree) -> Bool {
        lhs._core.count == rhs._core.count && lhs.elementsEqual(rhs)
    }
}

extension SplayTree: Hashable where Element: Hashable {
    /// Hashes the count and the elements in ascending order. O(*n*).
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_core.count)
        for element in self {
            hasher.combine(element)
        }
    }
}

extension SplayTree: Encodable where Element: Encodable {
    /// Encodes the elements in ascending order as an unkeyed container. O(*n*).
    @inlinable
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for element in self {
            try container.encode(element)
        }
    }
}

extension SplayTree: Decodable where Element: Decodable {
    /// Decodes the elements from an unkeyed container, in any order; of equal elements, the first
    /// is kept. O(*n* log *n*).
    @inlinable
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        if let count = container.count {
            elements.reserveCapacity(count)
        }
        while !container.isAtEnd {
            elements.append(try container.decode(Element.self))
        }
        self.init(elements)
    }
}

extension SplayTree: Sendable where Element: Sendable {}
extension SplayTree.Iterator: Sendable where Element: Sendable {}

extension SplayTree: CustomStringConvertible {
    /// The elements in ascending order, written as an array literal.
    public var description: String {
        Array(self).description
    }
}
