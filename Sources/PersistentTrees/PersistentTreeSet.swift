@_exported import CollectionErrors

/// A persistent sorted set: unique elements in ascending order, where every version stays usable
/// and versions share all but the vertices their edits touched.
///
/// The elements live in a weight-balanced search tree of immutable vertices (Adams, 1993). An
/// insertion or removal makes new vertices only along the path to the change, O(log *n*) of them,
/// and shares the rest with the version it started from, so keeping every version of a history
/// of *n* edits costs O(*n* log *n*) space rather than the O(*n*²) of copying a whole tree for each.
/// ``union(_:)``, ``intersection(_:)``, ``subtracting(_:)`` and ``symmetricDifference(_:)`` split
/// and join trees (Blelloch, Ferizovic and Sun, 2016) in O(*m* log(*n* / *m* + 1)) for sets of
/// *m* ≤ *n* elements, and a subtree both sets share is kept whole without being visited.
///
/// ```swift
/// let empty = PersistentTreeSet<Int>()
/// let one = empty.inserting(5)
/// let two = one.inserting(3)
/// let three = two.removing(5)
/// Array(one)                         // [5]
/// Array(two)                         // [3, 5]
/// Array(three)                       // [3]
/// ```
///
/// The elements are a random-access collection in ascending order whose indices are ranks;
/// reading one by index costs O(log *n*), and a pass through the whole set O(*n*).
@frozen
public struct PersistentTreeSet<Element: Comparable> {
    @usableFromInline
    package var _root: _PersistentNode<Element, Void>?

    @inlinable
    init(_root: _PersistentNode<Element, Void>?) {
        self._root = _root
    }

    /// An empty set.
    @inlinable
    public init() {
        _root = nil
    }

    /// The set of `elements`, keeping the first of equal ones.
    ///
    /// - Complexity: O(*n*) when `elements` is strictly ascending, O(*n* log *n*) otherwise.
    @inlinable
    public init(_ elements: some Sequence<Element>) {
        var sorted = ContiguousArray(elements)
        var isStrictlyAscending = true
        var k = 1
        while k < sorted.count {
            if !(sorted[k &- 1] < sorted[k]) {
                isStrictlyAscending = false
                break
            }
            k &+= 1
        }
        if !isStrictlyAscending {
            var order = Array(sorted.indices)
            order.sort { a, b in sorted[a] < sorted[b] || (!(sorted[b] < sorted[a]) && a < b) }
            var unique = ContiguousArray<Element>()
            unique.reserveCapacity(sorted.count)
            for position in order {
                let element = sorted[position]
                if let last = unique.last, !(last < element) { continue }
                unique.append(element)
            }
            sorted = unique
        }
        let values = ContiguousArray(repeating: (), count: sorted.count)
        _root = _PersistentNode.build(sorted, values, 0 ..< sorted.count)
    }

    /// Whether `element` is in the set. O(log *n*).
    @inlinable
    public func contains(_ element: Element) -> Bool {
        _PersistentNode.find(element, in: _root) != nil
    }

    /// The set with `element` added; this set when it is already a member.
    ///
    /// - Complexity: O(log *n*) time, and O(log *n*) new vertices.
    @inlinable
    public func inserting(_ element: Element) -> PersistentTreeSet {
        var existing: _PersistentNode<Element, Void>?
        return PersistentTreeSet(_root: _PersistentNode.inserting(element, (), into: _root, replacing: false, existing: &existing))
    }

    /// The set without `element`; this set when it is not a member.
    ///
    /// - Complexity: O(log *n*) time, and O(log *n*) new vertices.
    @inlinable
    public func removing(_ element: Element) -> PersistentTreeSet {
        var removed: _PersistentNode<Element, Void>?
        return PersistentTreeSet(_root: _PersistentNode.removing(element, from: _root, removed: &removed))
    }

    /// The number of elements less than `element`: the index where it is or would be. O(log *n*).
    @inlinable
    public func lowerBound(_ element: Element) -> Int {
        _PersistentNode.rank(of: element, in: _root, orEqual: false)
    }

    /// The number of elements at most `element`: the index after it. O(log *n*).
    @inlinable
    public func upperBound(_ element: Element) -> Int {
        _PersistentNode.rank(of: element, in: _root, orEqual: true)
    }

    /// The elements in `range`, in ascending order. O(log *n*).
    @inlinable
    public func elements(in range: Range<Element>) -> Slice<PersistentTreeSet> {
        self[lowerBound(range.lowerBound) ..< lowerBound(range.upperBound)]
    }

    /// The elements in `range`, in ascending order. O(log *n*).
    @inlinable
    public func elements(in range: ClosedRange<Element>) -> Slice<PersistentTreeSet> {
        self[lowerBound(range.lowerBound) ..< upperBound(range.upperBound)]
    }

    /// The smallest element, or nil when the set is empty. O(log *n*).
    @inlinable
    public func min() -> Element? {
        var tree = _root
        while let left = tree?.left { tree = left }
        return tree?.key
    }

    /// The largest element, or nil when the set is empty. O(log *n*).
    @inlinable
    public func max() -> Element? {
        var tree = _root
        while let right = tree?.right { tree = right }
        return tree?.key
    }

    /// Removes and returns the element at `index`.
    ///
    /// - Parameter index: Traps unless it is in `0 ..< count`; use ``remove(checkedAt:)`` to throw
    ///   instead.
    /// - Complexity: O(log *n*).
    @inlinable
    @discardableResult
    public mutating func remove(at index: Int) -> Element {
        precondition(index >= 0 && index < count, "Index out of range")
        let element = self[index]
        self = removing(element)
        return element
    }

    /// Removes and returns the element at `index`, throwing instead of trapping on an invalid
    /// index.
    ///
    /// - Throws: ``IndexOutOfRange`` unless `index` is in `0 ..< count`; the set is unchanged.
    /// - Complexity: O(log *n*).
    @inlinable
    @discardableResult
    public mutating func remove(checkedAt index: Int) throws(IndexOutOfRange) -> Element {
        guard index >= 0 && index < count else { throw IndexOutOfRange() }
        return remove(at: index)
    }

    /// The element at `position`, throwing instead of trapping on an invalid index.
    ///
    /// - Throws: ``IndexOutOfRange`` unless `position` is in `0 ..< count`.
    /// - Complexity: O(log *n*).
    @inlinable
    public subscript(checked position: Int) -> Element {
        get throws(IndexOutOfRange) {
            guard position >= 0 && position < count, let root = _root else { throw IndexOutOfRange() }
            return _PersistentNode.node(atRank: position, in: root).key
        }
    }
}

extension PersistentTreeSet: RandomAccessCollection {
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public typealias SubSequence = Slice<PersistentTreeSet>

    @inlinable public var startIndex: Int { 0 }
    @inlinable public var endIndex: Int { _root?.size ?? 0 }
    @inlinable public var count: Int { _root?.size ?? 0 }
    @inlinable public var isEmpty: Bool { _root == nil }

    /// The element at `position`, the `position`-th smallest.
    ///
    /// - Parameter position: Traps unless it is in `0 ..< count`; use ``subscript(checked:)`` to
    ///   throw instead.
    /// - Complexity: O(log *n*).
    @inlinable
    public subscript(position: Int) -> Element {
        guard position >= 0 && position < count, let root = _root else {
            preconditionFailure("Index out of range")
        }
        return _PersistentNode.node(atRank: position, in: root).key
    }

    /// An iterator over the elements in ascending order: O(*n*) for the whole pass, O(log *n*)
    /// extra space.
    @frozen
    public struct Iterator: IteratorProtocol {
        @usableFromInline var _nodes: _PersistentNode<Element, Void>.InorderNodes

        @inlinable
        init(_ root: _PersistentNode<Element, Void>?) {
            _nodes = _PersistentNode.InorderNodes(root)
        }

        @inlinable
        public mutating func next() -> Element? {
            _nodes.next()?._withUnsafeGuaranteedRef { $0.key }
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_root)
    }

    @inlinable
    public func _customContainsEquatableElement(_ element: Element) -> Bool? {
        contains(element)
    }

    @inlinable
    public func _customIndexOfEquatableElement(_ element: Element) -> Int?? {
        let rank = lowerBound(element)
        return .some(rank < count && self[rank] == element ? rank : nil)
    }

    @inlinable
    public func _customLastIndexOfEquatableElement(_ element: Element) -> Int?? {
        _customIndexOfEquatableElement(element)
    }
}

extension PersistentTreeSet: SetAlgebra {
    /// Inserts `newMember` unless an equal element is present.
    ///
    /// - Returns: Whether it was inserted, and the member equal to it afterwards.
    /// - Complexity: O(log *n*).
    @inlinable
    @discardableResult
    public mutating func insert(_ newMember: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        var existing: _PersistentNode<Element, Void>?
        _root = _PersistentNode.inserting(newMember, (), into: _root, replacing: false, existing: &existing)
        if let existing { return (false, existing.key) }
        return (true, newMember)
    }

    /// Inserts `newMember`, replacing an equal element, and returns the element it replaced.
    ///
    /// - Complexity: O(log *n*).
    @inlinable
    @discardableResult
    public mutating func update(with newMember: Element) -> Element? {
        var existing: _PersistentNode<Element, Void>?
        _root = _PersistentNode.inserting(newMember, (), into: _root, replacing: true, existing: &existing)
        return existing?.key
    }

    /// Removes the element equal to `member` and returns it, or nil when there is none.
    ///
    /// - Complexity: O(log *n*).
    @inlinable
    @discardableResult
    public mutating func remove(_ member: Element) -> Element? {
        var removed: _PersistentNode<Element, Void>?
        _root = _PersistentNode.removing(member, from: _root, removed: &removed)
        return removed?.key
    }

    /// The elements of both sets, this set's when both hold equal ones.
    ///
    /// - Complexity: O(*m* log(*n* / *m* + 1)) for sets of *m* ≤ *n* elements.
    @inlinable
    public func union(_ other: PersistentTreeSet) -> PersistentTreeSet {
        PersistentTreeSet(_root: _PersistentNode.union(_root, other._root))
    }

    /// The elements in both sets, this set's ones.
    ///
    /// - Complexity: O(*m* log(*n* / *m* + 1)) for sets of *m* ≤ *n* elements.
    @inlinable
    public func intersection(_ other: PersistentTreeSet) -> PersistentTreeSet {
        PersistentTreeSet(_root: _PersistentNode.intersection(_root, other._root))
    }

    /// The elements in exactly one of the sets.
    ///
    /// - Complexity: O(*m* log(*n* / *m* + 1)) for sets of *m* ≤ *n* elements.
    @inlinable
    public func symmetricDifference(_ other: PersistentTreeSet) -> PersistentTreeSet {
        PersistentTreeSet(_root: _PersistentNode.symmetricDifference(_root, other._root))
    }

    /// The elements of this set not in `other`.
    ///
    /// - Complexity: O(*m* log(*n* / *m* + 1)) for sets of *m* ≤ *n* elements.
    @inlinable
    public func subtracting(_ other: PersistentTreeSet) -> PersistentTreeSet {
        PersistentTreeSet(_root: _PersistentNode.subtracting(other._root, from: _root))
    }

    @inlinable
    public mutating func formUnion(_ other: PersistentTreeSet) {
        self = union(other)
    }

    @inlinable
    public mutating func formIntersection(_ other: PersistentTreeSet) {
        self = intersection(other)
    }

    @inlinable
    public mutating func formSymmetricDifference(_ other: PersistentTreeSet) {
        self = symmetricDifference(other)
    }

    @inlinable
    public mutating func subtract(_ other: PersistentTreeSet) {
        self = subtracting(other)
    }

    /// Whether every element of this set is in `other`.
    ///
    /// - Complexity: O(*m* log(*n* / *m* + 1)) for sets of *m* ≤ *n* elements.
    @inlinable
    public func isSubset(of other: PersistentTreeSet) -> Bool {
        _PersistentNode.isSubset(_root, of: other._root)
    }

    /// Whether every element of `other` is in this set.
    ///
    /// - Complexity: O(*m* log(*n* / *m* + 1)) for sets of *m* ≤ *n* elements.
    @inlinable
    public func isSuperset(of other: PersistentTreeSet) -> Bool {
        _PersistentNode.isSubset(other._root, of: _root)
    }
}

extension PersistentTreeSet: ExpressibleByArrayLiteral {
    /// The set of the literal's elements, keeping the first of equal ones. O(*n* log *n*).
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension PersistentTreeSet: Equatable {
    /// Whether two sets hold equal elements, whatever their shapes; O(1) for versions that share
    /// their root, O(*n*) otherwise.
    @inlinable
    public static func == (lhs: PersistentTreeSet, rhs: PersistentTreeSet) -> Bool {
        if lhs._root === rhs._root { return true }
        return lhs.count == rhs.count && lhs.elementsEqual(rhs)
    }
}

extension PersistentTreeSet: Hashable where Element: Hashable {
    /// Hashes the count and the elements in ascending order. O(*n*).
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for element in self {
            hasher.combine(element)
        }
    }
}

extension PersistentTreeSet: Encodable where Element: Encodable {
    /// Encodes the elements in ascending order as an unkeyed container. O(*n*).
    @inlinable
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for element in self {
            try container.encode(element)
        }
    }
}

extension PersistentTreeSet: Decodable where Element: Decodable {
    /// Decodes the elements from an unkeyed container, in any order, keeping the first of equal
    /// ones. O(*n* log *n*).
    @inlinable
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        while !container.isAtEnd {
            elements.append(try container.decode(Element.self))
        }
        self.init(elements)
    }
}

extension PersistentTreeSet: Sendable where Element: Sendable {}
extension PersistentTreeSet.Iterator: Sendable where Element: Sendable {}

extension PersistentTreeSet: CustomStringConvertible {
    /// The elements in ascending order, written as an array literal.
    public var description: String {
        Array(self).description
    }
}
