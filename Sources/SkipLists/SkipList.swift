@_exported import CollectionErrors

/// A sorted set kept in a skip list: sorted linked lists stacked in levels, each level a random
/// sample of the one below, searched from the top level down (Pugh, 1990).
///
/// Each element stands in a tower of levels, one more with probability 1/4, so a search skips
/// ahead on the upper levels and finishes on the bottom one. Lookup, insertion and removal take
/// O(log *n*) expected time, with no rebalancing. Every link also records how many elements it
/// passes, so the elements are a random-access collection in ascending order, indexed by rank
/// like an array: `list[0]` is the smallest element. Reading an element by index costs O(log *n*)
/// expected, and a pass through the whole collection costs O(*n*).
///
/// ```swift
/// var numbers: SkipList = [8, 3, 5, 1, 9]
/// numbers.insert(4)
/// Array(numbers)                // [1, 3, 4, 5, 8, 9]
/// numbers.lowerBound(5)         // 3, the index of 5
/// numbers[1]                    // 3
/// ```
///
/// The tower heights come from a random number generator given at creation,
/// `SystemRandomNumberGenerator` by default; a seeded generator makes every shape reproducible.
/// The list draws one seed from it and keeps its own generator state, so a copy draws the same
/// heights as its original.
///
/// The elements and their towers live in flat arrays with `Int32` links, so the list holds fewer
/// than 2³¹ − 1 elements, and copying it copies a few arrays only when one copy is mutated.
@frozen
public struct SkipList<Element: Comparable> {
    @usableFromInline
    package var _core: _SkipListCore<Element>

    @inlinable
    init(_core: _SkipListCore<Element>) {
        self._core = _core
    }

    /// An empty skip list whose heights come from `SystemRandomNumberGenerator`.
    @inlinable
    public init() {
        var generator = SystemRandomNumberGenerator()
        self.init(using: &generator)
    }

    /// An empty skip list whose heights come from `generator`.
    ///
    /// - Parameter generator: The generator the list draws its seed from.
    @inlinable
    public init(using generator: inout some RandomNumberGenerator) {
        _core = _SkipListCore(heights: _SkipListHeights(using: &generator))
    }

    /// The skip list holding the distinct elements of `elements`, with heights from
    /// `SystemRandomNumberGenerator`; of equal elements, the first is kept.
    ///
    /// - Parameter elements: The elements, in any order.
    /// - Complexity: O(*n* log *n*) to sort them, then O(*n*) to build the list.
    @inlinable
    public init(_ elements: some Sequence<Element>) {
        var generator = SystemRandomNumberGenerator()
        self.init(elements, using: &generator)
    }

    /// The skip list holding the distinct elements of `elements`, with heights from `generator`;
    /// of equal elements, the first is kept.
    ///
    /// - Parameters:
    ///   - elements: The elements, in any order.
    ///   - generator: The generator the list draws its seed from.
    /// - Complexity: O(*n* log *n*) to sort them, then O(*n*) to build the list.
    @inlinable
    public init(_ elements: some Sequence<Element>, using generator: inout some RandomNumberGenerator) {
        _core = _SkipListCore(
            sortedUniqueElements: Self._sortedUnique(ContiguousArray(elements)),
            heights: _SkipListHeights(using: &generator)
        )
    }

    /// `elements` in ascending order with repeats dropped, the first of equal ones kept.
    @inlinable
    static func _sortedUnique(_ elements: ContiguousArray<Element>) -> ContiguousArray<Element> {
        var k = 1
        while k < elements.count {
            if !(elements[k &- 1] < elements[k]) { break }
            k &+= 1
        }
        guard k < elements.count else { return elements }
        // Sorted with each element's position as the tie-break, so the first of equal ones leads.
        var ordered = ContiguousArray(zip(elements, 0 ..< elements.count))
        ordered.sort { a, b in a.0 < b.0 || (!(b.0 < a.0) && a.1 < b.1) }
        var sorted = ContiguousArray<Element>()
        sorted.reserveCapacity(ordered.count)
        for (element, _) in ordered where sorted.isEmpty || sorted[sorted.count &- 1] < element {
            sorted.append(element)
        }
        return sorted
    }

    /// The level of the list (Pugh, 1990): the number of levels in use, the height of its
    /// tallest tower, and 1 when empty. It is O(log *n*) expected; reading it is O(1).
    @inlinable
    public var level: Int { _core.level }

    /// Whether the list holds an element equal to `element`. O(log *n*) expected.
    @inlinable
    public func contains(_ element: Element) -> Bool {
        _core.slot(of: element) >= 0
    }

    /// The index of the first element not less than `element`, or `endIndex` when every element
    /// is less. O(log *n*) expected.
    @inlinable
    public func lowerBound(_ element: Element) -> Int {
        _core.countBelow(element, orEqual: false)
    }

    /// The index of the first element greater than `element`, or `endIndex` when none is.
    /// O(log *n*) expected.
    @inlinable
    public func upperBound(_ element: Element) -> Int {
        _core.countBelow(element, orEqual: true)
    }

    /// The elements in `range`, in ascending order. O(log *n*) expected.
    @inlinable
    public func elements(in range: Range<Element>) -> Slice<SkipList> {
        self[lowerBound(range.lowerBound) ..< lowerBound(range.upperBound)]
    }

    /// The elements in `range`, in ascending order. O(log *n*) expected.
    @inlinable
    public func elements(in range: ClosedRange<Element>) -> Slice<SkipList> {
        self[lowerBound(range.lowerBound) ..< upperBound(range.upperBound)]
    }

    /// The smallest element, or nil when empty. O(1).
    @inlinable
    public func min() -> Element? {
        let slot = _core.firstSlot
        return slot < 0 ? nil : _core.elements[Int(slot)]
    }

    /// The largest element, or nil when empty. O(log *n*) expected.
    @inlinable
    public func max() -> Element? {
        let slot = _core.lastSlot
        return slot < 0 ? nil : _core.elements[Int(slot)]
    }

    /// Removes and returns the element at `index`.
    ///
    /// - Parameter index: The index of the element. Traps unless it is a valid index; use
    ///   ``remove(checkedAt:)`` to throw instead.
    /// - Complexity: O(log *n*) expected, plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func remove(at index: Int) -> Element {
        precondition(index >= 0 && index < _core.count, "Index out of range")
        return _core.remove(atRank: index)
    }

    /// Removes and returns the element at `index`, throwing instead of trapping on an invalid
    /// index.
    ///
    /// - Parameter index: The index of the element.
    /// - Throws: `IndexOutOfRange` unless `index` is a valid index; the list is unchanged.
    /// - Complexity: O(log *n*) expected, plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func remove(checkedAt index: Int) throws(IndexOutOfRange) -> Element {
        guard index >= 0 && index < _core.count else { throw IndexOutOfRange() }
        return _core.remove(atRank: index)
    }

    /// The element at `position`, throwing instead of trapping on an invalid index.
    ///
    /// - Parameter position: The index of the element.
    /// - Throws: `IndexOutOfRange` unless `position` is a valid index.
    /// - Complexity: O(log *n*) expected.
    @inlinable
    public subscript(checked position: Int) -> Element {
        get throws(IndexOutOfRange) {
            guard position >= 0 && position < _core.count else { throw IndexOutOfRange() }
            return _core.elements[Int(_core.slot(atRank: position))]
        }
    }
}

extension SkipList: RandomAccessCollection {
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public typealias SubSequence = Slice<SkipList>

    @inlinable public var startIndex: Int { 0 }
    @inlinable public var endIndex: Int { _core.count }
    @inlinable public var count: Int { _core.count }
    @inlinable public var isEmpty: Bool { _core.count == 0 }

    /// The element at `position`, the `position`-th smallest.
    ///
    /// - Parameter position: The index of the element. Traps unless it is a valid index; use
    ///   ``subscript(checked:)`` to throw instead.
    /// - Complexity: O(log *n*) expected.
    @inlinable
    public subscript(position: Int) -> Element {
        precondition(position >= 0 && position < _core.count, "Index out of range")
        return _core.elements[Int(_core.slot(atRank: position))]
    }

    /// An iterator over the elements in ascending order, along the bottom level: O(1) per
    /// element.
    @frozen
    public struct Iterator: IteratorProtocol {
        @usableFromInline let _core: _SkipListCore<Element>
        /// The next element's slot, −1 after the last, and the tower whose bottom link leads on.
        @usableFromInline var _slot: Int32
        @usableFromInline var _tower: Int32

        @inlinable
        init(_ core: _SkipListCore<Element>) {
            _core = core
            _slot = core.links[0].next
            _tower = core.links[0].tower
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _slot >= 0 else { return nil }
            let element = _core.elements[Int(_slot)]
            let link = _core.links[Int(_tower)]
            _slot = link.next
            _tower = link.tower
            return element
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

    /// Finds `element` by searching the list, so `firstIndex(of:)` costs O(log *n*) expected.
    @inlinable
    public func _customIndexOfEquatableElement(_ element: Element) -> Int?? {
        .some(_core.rank(of: element))
    }

    /// Finds `element` by searching the list, so `lastIndex(of:)` costs O(log *n*) expected.
    @inlinable
    public func _customLastIndexOfEquatableElement(_ element: Element) -> Int?? {
        .some(_core.rank(of: element))
    }
}

extension SkipList: SetAlgebra {
    /// Inserts `newMember` unless an equal element is present.
    ///
    /// - Returns: Whether it was inserted, and the member equal to `newMember` afterwards.
    /// - Complexity: O(log *n*) expected, plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func insert(_ newMember: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        let (inserted, slot) = _core.insert(newMember)
        return (inserted, inserted ? newMember : _core.elements[Int(slot)])
    }

    /// Inserts `newMember`, replacing an equal element if present.
    ///
    /// - Returns: The element replaced, or nil when none was equal.
    /// - Complexity: O(log *n*) expected, plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func update(with newMember: Element) -> Element? {
        let (inserted, slot) = _core.insert(newMember)
        guard !inserted else { return nil }
        let old = _core.elements[Int(slot)]
        _core.elements[Int(slot)] = newMember
        return old
    }

    /// Removes the element equal to `member`.
    ///
    /// - Returns: The element removed, or nil when none was equal.
    /// - Complexity: O(log *n*) expected, plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func remove(_ member: Element) -> Element? {
        _core.remove(member)
    }

    /// The elements of either list; of equal elements, this list's. O(*n* + *m*).
    @inlinable
    public func union(_ other: SkipList) -> SkipList {
        _merge(other, keepOnlyLeft: true, keepOnlyRight: true, keepBoth: true)
    }

    /// The elements of both lists, as this list holds them. O(*n* + *m*).
    @inlinable
    public func intersection(_ other: SkipList) -> SkipList {
        _merge(other, keepOnlyLeft: false, keepOnlyRight: false, keepBoth: true)
    }

    /// The elements of exactly one of the lists. O(*n* + *m*).
    @inlinable
    public func symmetricDifference(_ other: SkipList) -> SkipList {
        _merge(other, keepOnlyLeft: true, keepOnlyRight: true, keepBoth: false)
    }

    /// The elements of this list that are not in `other`. O(*n* + *m*).
    @inlinable
    public func subtracting(_ other: SkipList) -> SkipList {
        _merge(other, keepOnlyLeft: true, keepOnlyRight: false, keepBoth: false)
    }

    /// Adds the elements of `other`, keeping this list's of equal ones. O(*n* + *m*).
    @inlinable
    public mutating func formUnion(_ other: SkipList) {
        self = union(other)
    }

    /// Keeps only the elements also in `other`. O(*n* + *m*).
    @inlinable
    public mutating func formIntersection(_ other: SkipList) {
        self = intersection(other)
    }

    /// Keeps the elements of exactly one of the lists. O(*n* + *m*).
    @inlinable
    public mutating func formSymmetricDifference(_ other: SkipList) {
        self = symmetricDifference(other)
    }

    /// Removes the elements also in `other`. O(*n* + *m*).
    @inlinable
    public mutating func subtract(_ other: SkipList) {
        self = subtracting(other)
    }

    /// Merges both lists' elements in order and builds a list of those kept, with heights drawn
    /// from this list's generator.
    @inlinable
    func _merge(_ other: SkipList, keepOnlyLeft: Bool, keepOnlyRight: Bool, keepBoth: Bool) -> SkipList {
        var elements = ContiguousArray<Element>()
        elements.reserveCapacity(_core.count &+ other._core.count)
        var left = makeIterator()
        var right = other.makeIterator()
        var a = left.next()
        var b = right.next()
        while let x = a, let y = b {
            if x < y {
                if keepOnlyLeft { elements.append(x) }
                a = left.next()
            } else if y < x {
                if keepOnlyRight { elements.append(y) }
                b = right.next()
            } else {
                if keepBoth { elements.append(x) }
                a = left.next()
                b = right.next()
            }
        }
        if keepOnlyLeft {
            while let x = a {
                elements.append(x)
                a = left.next()
            }
        }
        if keepOnlyRight {
            while let y = b {
                elements.append(y)
                b = right.next()
            }
        }
        return SkipList(_core: _SkipListCore(sortedUniqueElements: elements, heights: _core.randomHeights))
    }
}

extension SkipList: ExpressibleByArrayLiteral {
    /// The skip list holding the literal's distinct elements. O(*n* log *n*).
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension SkipList: Equatable {
    /// Whether two skip lists hold equal elements, whatever their towers. O(*n*).
    @inlinable
    public static func == (lhs: SkipList, rhs: SkipList) -> Bool {
        lhs._core.count == rhs._core.count && lhs.elementsEqual(rhs)
    }
}

extension SkipList: Hashable where Element: Hashable {
    /// Hashes the count and the elements in ascending order. O(*n*).
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_core.count)
        for element in self {
            hasher.combine(element)
        }
    }
}

extension SkipList: Encodable where Element: Encodable {
    /// Encodes the elements in ascending order as an unkeyed container. O(*n*).
    @inlinable
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for element in self {
            try container.encode(element)
        }
    }
}

extension SkipList: Decodable where Element: Decodable {
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

extension SkipList: Sendable where Element: Sendable {}
extension SkipList.Iterator: Sendable where Element: Sendable {}

extension SkipList: CustomStringConvertible {
    /// The elements in ascending order, written as an array literal.
    public var description: String {
        Array(self).description
    }
}
