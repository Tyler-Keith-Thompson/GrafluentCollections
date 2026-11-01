/// A segment tree: a sequence of values that combines any range of them under a monoid and takes
/// point updates in O(log *n*) each.
///
/// The tree is a perfect binary tree over the values padded with the identity to a power of two,
/// *s*, stored in one flat array of 2*s* cells: cell 1 is the root, cell *k*'s children are 2*k*
/// and 2*k* + 1, and the values are the leaves at *s* through *s* + *n* − 1. Each cell holds the
/// combination of the leaves below it (Bentley, 1977). A range query combines the O(log *n*)
/// cells that cover it, from both ends upward, keeping the left and right parts apart, so the
/// operation need not be commutative.
///
/// ```swift
/// var tree = SegmentTree<Minimum<Int>>([5, 3, 8, 6, 1, 9])
/// tree.combined(in: 0 ..< 4)                           // 3
/// tree.update(at: 2, to: 0)
/// tree.combined(in: 0 ..< 4)                           // 0
/// tree.maxRight(from: 0) { $0 >= 3 }                   // 2: the minimum of 0 ..< 3 is 0
/// ```
///
/// As a collection, a segment tree's elements are the values themselves, in order.
@frozen
public struct SegmentTree<Operation: Monoid> {
    public typealias Element = Operation.Element

    /// The cells; cell 0 is unused, and the leaves start at half the count.
    @usableFromInline
    var _cells: ContiguousArray<Element>

    /// The number of values.
    @usableFromInline
    var _count: Int

    /// An empty tree.
    @inlinable
    public init() {
        self.init(EmptyCollection())
    }

    /// The tree holding `values`, in order.
    ///
    /// Combines each cell from its children once, from the bottom up.
    ///
    /// - Parameter values: The values, in order.
    /// - Complexity: O(*n*), where *n* is the number of values.
    @inlinable
    public init(_ values: some Sequence<Element>) {
        let values = ContiguousArray(values)
        let count = values.count
        var size = 1
        while size < count {
            size &<<= 1
        }
        var cells = ContiguousArray(repeating: Operation.identity, count: 2 &* size)
        cells.withUnsafeMutableBufferPointer { cells in
            for k in 0 ..< count {
                cells[size &+ k] = values[k]
            }
            var k = size &- 1
            while k > 0 {
                cells[k] = Operation.combine(cells[2 &* k], cells[2 &* k &+ 1])
                k &-= 1
            }
        }
        _cells = cells
        _count = count
    }

    /// The number of leaves, a power of two.
    @inlinable
    var _size: Int { _cells.count / 2 }

    /// The values whose indices lie in `range`, combined in index order.
    ///
    /// - Parameter range: The indices combined. Traps unless every index in it is valid (an empty
    ///   range may sit at `endIndex`); use ``combined(checkedIn:)`` to throw instead.
    /// - Returns: The combination, or the identity for an empty range.
    /// - Complexity: O(log *n*).
    @inlinable
    public func combined(in range: Range<Int>) -> Element {
        precondition(range.lowerBound >= 0 && range.upperBound <= _count, "Range out of bounds")
        return _combined(in: range)
    }

    /// The values whose indices lie in `range`, combined in index order, throwing instead of
    /// trapping on an invalid range.
    ///
    /// - Parameter range: The indices combined.
    /// - Returns: The combination, or the identity for an empty range.
    /// - Throws: ``IndexOutOfRange`` unless every index in `range` is valid (an empty range may
    ///   sit at `endIndex`).
    /// - Complexity: O(log *n*).
    @inlinable
    public func combined(checkedIn range: Range<Int>) throws(IndexOutOfRange) -> Element {
        guard range.lowerBound >= 0 && range.upperBound <= _count else { throw IndexOutOfRange() }
        return _combined(in: range)
    }

    /// Replaces the value at `index` with `value`.
    ///
    /// - Parameters:
    ///   - index: The index of the value replaced. Traps unless it is a valid index; use
    ///     ``update(checkedAt:to:)`` to throw instead.
    ///   - value: The new value.
    /// - Complexity: O(log *n*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    public mutating func update(at index: Int, to value: Element) {
        precondition(index >= 0 && index < _count, "Index out of range")
        _update(at: index, to: value)
    }

    /// Replaces the value at `index` with `value`, throwing instead of trapping on an invalid
    /// index.
    ///
    /// - Parameters:
    ///   - index: The index of the value replaced.
    ///   - value: The new value.
    /// - Throws: ``IndexOutOfRange`` unless `index` is a valid index; the tree is unchanged.
    /// - Complexity: O(log *n*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    public mutating func update(checkedAt index: Int, to value: Element) throws(IndexOutOfRange) {
        guard index >= 0 && index < _count else { throw IndexOutOfRange() }
        _update(at: index, to: value)
    }

    /// The largest `end` for which `predicate` holds for the values in `start ..< end` combined.
    ///
    /// `predicate` must hold for the identity, and once it fails for a range it must fail for
    /// every longer range from `start`, as a bound on a sum of non-negative values does.
    ///
    /// - Parameters:
    ///   - start: The first index combined. Traps unless it is in `0 ... count`; use
    ///     ``maxRight(checkedFrom:where:)`` to throw instead.
    ///   - predicate: The condition on a combined range. Traps unless it holds for the identity.
    /// - Returns: An index in `start ... count`.
    /// - Complexity: O(log *n*) calls to `predicate` and to the operation.
    @inlinable
    public func maxRight(from start: Int, where predicate: (Element) -> Bool) -> Int {
        precondition(start >= 0 && start <= _count, "Index out of range")
        return _maxRight(from: start, where: predicate)
    }

    /// The largest `end` for which `predicate` holds for the values in `start ..< end` combined,
    /// throwing instead of trapping on a start out of range.
    ///
    /// - Throws: ``IndexOutOfRange`` unless `start` is in `0 ... count`.
    /// - Complexity: O(log *n*) calls to `predicate` and to the operation.
    @inlinable
    public func maxRight(checkedFrom start: Int, where predicate: (Element) -> Bool) throws(IndexOutOfRange) -> Int {
        guard start >= 0 && start <= _count else { throw IndexOutOfRange() }
        return _maxRight(from: start, where: predicate)
    }

    /// The smallest `start` for which `predicate` holds for the values in `start ..< end`
    /// combined.
    ///
    /// `predicate` must hold for the identity, and once it fails for a range it must fail for
    /// every longer range ending at `end`.
    ///
    /// - Parameters:
    ///   - end: The index past the last combined. Traps unless it is in `0 ... count`; use
    ///     ``minLeft(checkedUpTo:where:)`` to throw instead.
    ///   - predicate: The condition on a combined range. Traps unless it holds for the identity.
    /// - Returns: An index in `0 ... end`.
    /// - Complexity: O(log *n*) calls to `predicate` and to the operation.
    @inlinable
    public func minLeft(upTo end: Int, where predicate: (Element) -> Bool) -> Int {
        precondition(end >= 0 && end <= _count, "Index out of range")
        return _minLeft(upTo: end, where: predicate)
    }

    /// The smallest `start` for which `predicate` holds for the values in `start ..< end`
    /// combined, throwing instead of trapping on an end out of range.
    ///
    /// - Throws: ``IndexOutOfRange`` unless `end` is in `0 ... count`.
    /// - Complexity: O(log *n*) calls to `predicate` and to the operation.
    @inlinable
    public func minLeft(checkedUpTo end: Int, where predicate: (Element) -> Bool) throws(IndexOutOfRange) -> Int {
        guard end >= 0 && end <= _count else { throw IndexOutOfRange() }
        return _minLeft(upTo: end, where: predicate)
    }

    /// The value at `position`, throwing instead of trapping on an invalid index.
    ///
    /// - Parameter position: The index of the value.
    /// - Throws: ``IndexOutOfRange`` unless `position` is a valid index.
    /// - Complexity: O(1).
    @inlinable
    public subscript(checked position: Int) -> Element {
        get throws(IndexOutOfRange) {
            guard position >= 0 && position < _count else { throw IndexOutOfRange() }
            return _cells[_size &+ position]
        }
    }

    // MARK: - Internals

    @inlinable
    func _combined(in bounds: Range<Int>) -> Element {
        _cells.withUnsafeBufferPointer { cells in
            let size = cells.count / 2
            var left = Operation.identity
            var right = Operation.identity
            var lower = bounds.lowerBound &+ size
            var upper = bounds.upperBound &+ size
            while lower < upper {
                if lower & 1 == 1 {
                    left = Operation.combine(left, cells[lower])
                    lower &+= 1
                }
                if upper & 1 == 1 {
                    upper &-= 1
                    right = Operation.combine(cells[upper], right)
                }
                lower &>>= 1
                upper &>>= 1
            }
            return Operation.combine(left, right)
        }
    }

    @inlinable
    mutating func _update(at index: Int, to value: Element) {
        _cells.withUnsafeMutableBufferPointer { cells in
            var k = cells.count / 2 &+ index
            cells[k] = value
            k &>>= 1
            while k > 0 {
                cells[k] = Operation.combine(cells[2 &* k], cells[2 &* k &+ 1])
                k &>>= 1
            }
        }
    }

    /// Climbs from the start's leaf while whole cells pass, then descends into the first cell
    /// that fails to find where.
    @inlinable
    func _maxRight(from start: Int, where predicate: (Element) -> Bool) -> Int {
        precondition(predicate(Operation.identity), "The predicate must hold for the identity")
        if start == _count { return _count }
        return _cells.withUnsafeBufferPointer { cells in
            let size = cells.count / 2
            var k = start &+ size
            var combined = Operation.identity
            repeat {
                while k & 1 == 0 {
                    k &>>= 1
                }
                let next = Operation.combine(combined, cells[k])
                if !predicate(next) {
                    while k < size {
                        k &*= 2
                        let left = Operation.combine(combined, cells[k])
                        if predicate(left) {
                            combined = left
                            k &+= 1
                        }
                    }
                    return k &- size
                }
                combined = next
                k &+= 1
            } while k & (0 &- k) != k
            return _count
        }
    }

    /// Climbs from the end's leaf while whole cells pass, then descends into the first cell that
    /// fails to find where.
    @inlinable
    func _minLeft(upTo end: Int, where predicate: (Element) -> Bool) -> Int {
        precondition(predicate(Operation.identity), "The predicate must hold for the identity")
        if end == 0 { return 0 }
        return _cells.withUnsafeBufferPointer { cells in
            let size = cells.count / 2
            var k = end &+ size
            var combined = Operation.identity
            repeat {
                k &-= 1
                while k > 1 && k & 1 == 1 {
                    k &>>= 1
                }
                let next = Operation.combine(cells[k], combined)
                if !predicate(next) {
                    while k < size {
                        k = 2 &* k &+ 1
                        let right = Operation.combine(cells[k], combined)
                        if predicate(right) {
                            combined = right
                            k &-= 1
                        }
                    }
                    return k &+ 1 &- size
                }
                combined = next
            } while k & (0 &- k) != k
            return 0
        }
    }
}

extension SegmentTree: RandomAccessCollection {
    public typealias Index = Int
    public typealias Indices = Range<Int>

    @inlinable public var startIndex: Int { 0 }
    @inlinable public var endIndex: Int { _count }
    @inlinable public var count: Int { _count }
    @inlinable public var isEmpty: Bool { _count == 0 }

    /// The value at `position`.
    ///
    /// - Parameter position: The index of the value. Traps unless it is a valid index; use
    ///   ``subscript(checked:)`` to throw instead.
    /// - Complexity: O(1).
    @inlinable
    public subscript(position: Int) -> Element {
        precondition(position >= 0 && position < _count, "Index out of range")
        return _cells[_size &+ position]
    }
}

extension SegmentTree: ExpressibleByArrayLiteral {
    /// The tree holding the literal's values, in order. O(*n*).
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension SegmentTree: Equatable where Element: Equatable {
    /// Whether two trees hold the same values in the same order. O(*n*).
    @inlinable
    public static func == (lhs: SegmentTree, rhs: SegmentTree) -> Bool {
        lhs._count == rhs._count && lhs.elementsEqual(rhs)
    }
}

extension SegmentTree: Hashable where Element: Hashable {
    /// Hashes the count and the values, in order. O(*n*).
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_count)
        for value in self {
            hasher.combine(value)
        }
    }
}

extension SegmentTree: Encodable where Element: Encodable {
    /// Encodes the values, in order, as an unkeyed container. O(*n*).
    @inlinable
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for value in self {
            try container.encode(value)
        }
    }
}

extension SegmentTree: Decodable where Element: Decodable {
    /// Decodes the values, in order, from an unkeyed container. O(*n*).
    @inlinable
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var values: [Element] = []
        while !container.isAtEnd {
            values.append(try container.decode(Element.self))
        }
        self.init(values)
    }
}

extension SegmentTree: Sendable where Element: Sendable {}

extension SegmentTree: CustomStringConvertible {
    /// The values, in order, written as an array literal.
    public var description: String {
        Array(self).description
    }
}
