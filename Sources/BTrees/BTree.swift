@_exported import CollectionErrors

/// A sorted set kept in a B-tree: a search tree whose nodes each hold many elements in
/// ascending order, every leaf at the same depth (Bayer and McCreight, 1972).
///
/// A node holds tens of elements side by side in one allocation, so a lookup reads a few nodes
/// and few cache lines: lookup, insertion and removal take O(log *n*), with a node-sized constant.
/// The elements are a random-access collection in ascending order, indexed by rank like an
/// array: `tree[0]` is the smallest element. Reading an element by index costs O(log *n*), and a
/// pass through the whole collection costs O(*n*).
///
/// ```swift
/// var primes: BTree = [7, 2, 11, 3, 5]
/// primes.insert(13)
/// primes.contains(4)        // false
/// Array(primes)             // [2, 3, 5, 7, 11, 13]
/// primes.lowerBound(6)      // 3, the index of 7
/// ```
///
/// Copies share their nodes: mutating one copy copies only the nodes on the path it changes,
/// O(log *n*) of them, and leaves the rest shared.
@frozen
public struct BTree<Element: Comparable> {
    @usableFromInline
    package var _core: _BTreeCore<Element, Void>

    @inlinable
    init(_core: _BTreeCore<Element, Void>) {
        self._core = _core
    }

    /// An empty tree.
    @inlinable
    public init() {
        _core = _BTreeCore()
    }

    /// The tree holding the distinct elements of `elements`; of equal elements, the first is
    /// kept.
    ///
    /// - Parameter elements: The elements, in any order.
    /// - Complexity: O(*n* log *n*) to sort them, then O(*n*) to build the tree.
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
        _core = _BTreeCore(sortedUniqueKeys: keys, values: ContiguousArray(repeating: (), count: keys.count))
    }

    /// The number of nodes on every path from the root down to a leaf: 0 when empty, 1 while the
    /// root is the only node. O(log *n*).
    @inlinable
    public var height: Int { _core.height }

    /// Whether the tree holds an element equal to `element`. O(log *n*).
    @inlinable
    public func contains(_ element: Element) -> Bool {
        _core.element(forKey: element) != nil
    }

    /// The index of the first element not less than `element`, or `endIndex` when every element
    /// is less. O(log *n*).
    @inlinable
    public func lowerBound(_ element: Element) -> Int {
        _core.countBelow(element, orEqual: false)
    }

    /// The index of the first element greater than `element`, or `endIndex` when none is.
    /// O(log *n*).
    @inlinable
    public func upperBound(_ element: Element) -> Int {
        _core.countBelow(element, orEqual: true)
    }

    /// The elements in `range`, in ascending order. O(log *n*).
    @inlinable
    public func elements(in range: Range<Element>) -> Slice<BTree> {
        self[lowerBound(range.lowerBound) ..< lowerBound(range.upperBound)]
    }

    /// The elements in `range`, in ascending order. O(log *n*).
    @inlinable
    public func elements(in range: ClosedRange<Element>) -> Slice<BTree> {
        self[lowerBound(range.lowerBound) ..< upperBound(range.upperBound)]
    }

    /// The smallest element, or nil when empty. O(log *n*).
    @inlinable
    public func min() -> Element? {
        _core.extreme(last: false)?.key
    }

    /// The largest element, or nil when empty. O(log *n*).
    @inlinable
    public func max() -> Element? {
        _core.extreme(last: true)?.key
    }

    /// Removes and returns the element at `index`.
    ///
    /// - Parameter index: The index of the element. Traps unless it is a valid index; use
    ///   ``remove(checkedAt:)`` to throw instead.
    /// - Complexity: O(log *n*), plus O(log *n*) node copies when the storage is shared with
    ///   another copy.
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
    /// - Complexity: O(log *n*), plus O(log *n*) node copies when the storage is shared with
    ///   another copy.
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
    /// - Complexity: O(log *n*).
    @inlinable
    public subscript(checked position: Int) -> Element {
        get throws(IndexOutOfRange) {
            guard position >= 0 && position < _core.count else { throw IndexOutOfRange() }
            return _core.element(atRank: position).key
        }
    }
}

extension BTree {
    /// Removes and returns the smallest element, or nil when empty.
    ///
    /// - Complexity: O(log *n*), plus O(log *n*) node copies when the storage is shared with
    ///   another copy.
    @inlinable
    public mutating func popFirst() -> Element? {
        isEmpty ? nil : _core.remove(atRank: 0).key
    }

    /// Removes and returns the largest element, or nil when empty.
    ///
    /// - Complexity: O(log *n*), plus O(log *n*) node copies when the storage is shared with
    ///   another copy.
    @inlinable
    public mutating func popLast() -> Element? {
        isEmpty ? nil : _core.remove(atRank: _core.count &- 1).key
    }

    /// The two trees a split produces: the elements below the split point, and the rest.
    @frozen
    public struct Split {
        /// The elements below the split point.
        public var lower: BTree

        /// The elements not below the split point.
        public var upper: BTree

        /// The parts of a split.
        ///
        /// - Parameters:
        ///   - lower: The elements below the split point.
        ///   - upper: The elements not below the split point.
        @inlinable
        public init(lower: BTree, upper: BTree) {
            self.lower = lower
            self.upper = upper
        }
    }

    /// Splits the tree into the elements below `element` and the rest.
    ///
    /// - Parameter element: The split point. It goes to the upper part when the tree holds it.
    /// - Returns: The lower part, whose elements are all less than `element`, and the upper part.
    /// - Complexity: O(*n*): both parts are built anew.
    @inlinable
    public func split(at element: Element) -> Split {
        let boundary = lowerBound(element)
        var lower = ContiguousArray<Element>()
        var upper = ContiguousArray<Element>()
        lower.reserveCapacity(boundary)
        upper.reserveCapacity(count &- boundary)
        for (rank, member) in enumerated() {
            if rank < boundary {
                lower.append(member)
            } else {
                upper.append(member)
            }
        }
        return Split(
            lower: BTree(_core: _BTreeCore(sortedUniqueKeys: lower, values: ContiguousArray(repeating: (), count: lower.count))),
            upper: BTree(_core: _BTreeCore(sortedUniqueKeys: upper, values: ContiguousArray(repeating: (), count: upper.count)))
        )
    }
}

extension BTree: RandomAccessCollection {
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public typealias SubSequence = Slice<BTree>

    @inlinable public var startIndex: Int { 0 }
    @inlinable public var endIndex: Int { _core.count }
    @inlinable public var count: Int { _core.count }
    @inlinable public var isEmpty: Bool { _core.count == 0 }

    /// The element at `position`, the `position`-th smallest.
    ///
    /// - Parameter position: The index of the element. Traps unless it is a valid index; use
    ///   ``subscript(checked:)`` to throw instead.
    /// - Complexity: O(log *n*).
    @inlinable
    public subscript(position: Int) -> Element {
        precondition(position >= 0 && position < _core.count, "Index out of range")
        return _core.element(atRank: position).key
    }

    /// An iterator over the elements in ascending order: O(*n*) for the whole pass, O(log *n*)
    /// extra space.
    @frozen
    public struct Iterator: IteratorProtocol {
        @usableFromInline var _elements: _BTreeCore<Element, Void>.Elements

        @inlinable
        init(_ core: _BTreeCore<Element, Void>) {
            _elements = _BTreeCore.Elements(core)
        }

        @inlinable
        public mutating func next() -> Element? {
            _elements.next()?.key
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

    /// Finds `element` by descending the tree, so `firstIndex(of:)` costs O(log *n*).
    @inlinable
    public func _customIndexOfEquatableElement(_ element: Element) -> Int?? {
        .some(_core.rank(of: element))
    }

    /// Finds `element` by descending the tree, so `lastIndex(of:)` costs O(log *n*).
    @inlinable
    public func _customLastIndexOfEquatableElement(_ element: Element) -> Int?? {
        .some(_core.rank(of: element))
    }
}

extension BTree: SetAlgebra {
    /// Inserts `newMember` unless an equal element is present.
    ///
    /// - Returns: Whether it was inserted, and the member equal to `newMember` afterwards.
    /// - Complexity: O(log *n*), plus O(log *n*) node copies when the storage is shared with
    ///   another copy.
    @inlinable
    @discardableResult
    public mutating func insert(_ newMember: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        guard let existing = _core.insert(newMember, (), existing: .keep) else { return (true, newMember) }
        return (false, existing.key)
    }

    /// Inserts `newMember`, replacing an equal element if present.
    ///
    /// - Returns: The element replaced, or nil when none was equal.
    /// - Complexity: O(log *n*), plus O(log *n*) node copies when the storage is shared with
    ///   another copy.
    @inlinable
    @discardableResult
    public mutating func update(with newMember: Element) -> Element? {
        _core.insert(newMember, (), existing: .replaceElement)?.key
    }

    /// Removes the element equal to `member`.
    ///
    /// - Returns: The element removed, or nil when none was equal.
    /// - Complexity: O(log *n*), plus O(log *n*) node copies when the storage is shared with
    ///   another copy.
    @inlinable
    @discardableResult
    public mutating func remove(_ member: Element) -> Element? {
        _core.remove(member)?.key
    }

    /// The elements of either tree; of equal elements, this tree's. O(*n* + *m*).
    @inlinable
    public func union(_ other: BTree) -> BTree {
        _merge(other, keepOnlyLeft: true, keepOnlyRight: true, keepBoth: true)
    }

    /// The elements of both trees, as this tree holds them. O(*n* + *m*).
    @inlinable
    public func intersection(_ other: BTree) -> BTree {
        _merge(other, keepOnlyLeft: false, keepOnlyRight: false, keepBoth: true)
    }

    /// The elements of exactly one of the trees. O(*n* + *m*).
    @inlinable
    public func symmetricDifference(_ other: BTree) -> BTree {
        _merge(other, keepOnlyLeft: true, keepOnlyRight: true, keepBoth: false)
    }

    /// The elements of this tree that are not in `other`. O(*n* + *m*).
    @inlinable
    public func subtracting(_ other: BTree) -> BTree {
        _merge(other, keepOnlyLeft: true, keepOnlyRight: false, keepBoth: false)
    }

    /// Adds the elements of `other`, keeping this tree's of equal ones. O(*n* + *m*).
    @inlinable
    public mutating func formUnion(_ other: BTree) {
        self = union(other)
    }

    /// Keeps only the elements also in `other`. O(*n* + *m*).
    @inlinable
    public mutating func formIntersection(_ other: BTree) {
        self = intersection(other)
    }

    /// Keeps the elements of exactly one of the trees. O(*n* + *m*).
    @inlinable
    public mutating func formSymmetricDifference(_ other: BTree) {
        self = symmetricDifference(other)
    }

    /// Removes the elements also in `other`. O(*n* + *m*).
    @inlinable
    public mutating func subtract(_ other: BTree) {
        self = subtracting(other)
    }

    /// Merges both trees' elements in order and builds a tree of those kept.
    @inlinable
    func _merge(_ other: BTree, keepOnlyLeft: Bool, keepOnlyRight: Bool, keepBoth: Bool) -> BTree {
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
        return BTree(_core: _BTreeCore(sortedUniqueKeys: keys, values: ContiguousArray(repeating: (), count: keys.count)))
    }
}

extension BTree: ExpressibleByArrayLiteral {
    /// The tree holding the literal's distinct elements. O(*n* log *n*).
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension BTree: Equatable {
    /// Whether two trees hold equal elements, whatever their shapes. O(*n*).
    @inlinable
    public static func == (lhs: BTree, rhs: BTree) -> Bool {
        lhs._core.count == rhs._core.count && lhs.elementsEqual(rhs)
    }
}

extension BTree: Hashable where Element: Hashable {
    /// Hashes the count and the elements in ascending order. O(*n*).
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_core.count)
        for element in self {
            hasher.combine(element)
        }
    }
}

extension BTree: Encodable where Element: Encodable {
    /// Encodes the elements in ascending order as an unkeyed container. O(*n*).
    @inlinable
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for element in self {
            try container.encode(element)
        }
    }
}

extension BTree: Decodable where Element: Decodable {
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

extension BTree: Sendable where Element: Sendable {}
extension BTree.Iterator: Sendable where Element: Sendable {}

extension BTree: CustomStringConvertible {
    /// The elements in ascending order, written as an array literal.
    public var description: String {
        Array(self).description
    }
}
