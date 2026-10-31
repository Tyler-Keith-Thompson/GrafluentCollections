@_exported import CollectionErrors

/// A Fenwick tree (binary indexed tree): a sequence of values that answers prefix sums and takes
/// point updates in O(log *n*) each.
///
/// The tree stores *n* partial sums in one flat array. Cell `k` holds the sum of the values at
/// `k & (k + 1)` through `k`, so a prefix sum adds the cells on the path that clears the low
/// set bits of the index one at a time, and an update adds to the cells on the path that sets
/// the low clear bits (Fenwick, "A New Data Structure for Cumulative Frequency Tables", 1994).
///
/// ```swift
/// var tree: FenwickTree = [1, 2, 3, 4, 5, 6, 7, 8]
/// tree.prefixSum(through: 3)       // 10
/// tree.sum(in: 2 ..< 5)            // 12
/// tree.add(10, at: 2)
/// tree.prefixSum(through: 3)       // 20
/// tree.lowerBound(ofPrefixSum: 20) // 3
/// ```
///
/// As a collection, a Fenwick tree's elements are the values themselves, in order. Reading one
/// value costs O(log *n*) in the worst case and O(1) amortized over a pass through the
/// collection.
@frozen
public struct FenwickTree<Element: AdditiveArithmetic> {
    /// The partial sums: cell `k` holds the values at `k & (k + 1)` through `k`.
    @usableFromInline
    var _cells: ContiguousArray<Element>

    /// An empty tree.
    @inlinable
    public init() {
        _cells = []
    }

    /// The tree holding `values`, in order.
    ///
    /// Builds the cells in place, adding each cell to the one above it once, rather than
    /// inserting the values one at a time.
    ///
    /// - Parameter values: The values, in order.
    /// - Complexity: O(*n*), where *n* is the number of values.
    @inlinable
    public init(_ values: some Sequence<Element>) {
        var cells = ContiguousArray(values)
        cells.withUnsafeMutableBufferPointer { cells in
            let count = cells.count
            var k = 0
            while k < count {
                let above = k | (k &+ 1)
                if above < count {
                    cells[above] += cells[k]
                }
                k &+= 1
            }
        }
        _cells = cells
    }

    /// The sum of the values at `0` through `index`.
    ///
    /// - Parameter index: The last index summed. Traps unless it is a valid index; use
    ///   ``prefixSum(checkedThrough:)`` to throw instead.
    /// - Returns: The sum of the first `index + 1` values.
    /// - Complexity: O(log *n*).
    @inlinable
    public func prefixSum(through index: Int) -> Element {
        precondition(index >= 0 && index < _cells.count, "Index out of range")
        return _prefixSum(through: index)
    }

    /// The sum of the values at `0` through `index`, throwing instead of trapping on an invalid
    /// index.
    ///
    /// - Parameter index: The last index summed.
    /// - Returns: The sum of the first `index + 1` values.
    /// - Throws: ``IndexOutOfRange`` unless `index` is a valid index.
    /// - Complexity: O(log *n*).
    @inlinable
    public func prefixSum(checkedThrough index: Int) throws(IndexOutOfRange) -> Element {
        guard index >= 0 && index < _cells.count else { throw IndexOutOfRange() }
        return _prefixSum(through: index)
    }

    /// The sum of the values whose indices lie in `range`.
    ///
    /// - Parameter range: The indices summed. Traps unless every index in it is valid (an empty
    ///   range may sit at `endIndex`); use ``sum(checkedIn:)`` to throw instead.
    /// - Returns: The sum, or zero for an empty range.
    /// - Complexity: O(log *n*).
    @inlinable
    public func sum(in range: Range<Int>) -> Element {
        precondition(range.lowerBound >= 0 && range.upperBound <= _cells.count, "Range out of bounds")
        return _sum(in: range)
    }

    /// The sum of the values whose indices lie in `range`, throwing instead of trapping on an
    /// invalid range.
    ///
    /// - Parameter range: The indices summed.
    /// - Returns: The sum, or zero for an empty range.
    /// - Throws: ``IndexOutOfRange`` unless every index in `range` is valid (an empty range may
    ///   sit at `endIndex`).
    /// - Complexity: O(log *n*).
    @inlinable
    public func sum(checkedIn range: Range<Int>) throws(IndexOutOfRange) -> Element {
        guard range.lowerBound >= 0 && range.upperBound <= _cells.count else { throw IndexOutOfRange() }
        return _sum(in: range)
    }

    /// Adds `value` to the value at `index`.
    ///
    /// - Parameters:
    ///   - value: The amount added.
    ///   - index: The index of the value changed. Traps unless it is a valid index; use
    ///     ``add(_:checkedAt:)`` to throw instead.
    /// - Complexity: O(log *n*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    public mutating func add(_ value: Element, at index: Int) {
        precondition(index >= 0 && index < _cells.count, "Index out of range")
        _add(value, at: index)
    }

    /// Adds `value` to the value at `index`, throwing instead of trapping on an invalid index.
    ///
    /// - Parameters:
    ///   - value: The amount added.
    ///   - index: The index of the value changed.
    /// - Throws: ``IndexOutOfRange`` unless `index` is a valid index; the tree is unchanged.
    /// - Complexity: O(log *n*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    public mutating func add(_ value: Element, checkedAt index: Int) throws(IndexOutOfRange) {
        guard index >= 0 && index < _cells.count else { throw IndexOutOfRange() }
        _add(value, at: index)
    }

    /// The value at `position`, throwing instead of trapping on an invalid index.
    ///
    /// - Parameter position: The index of the value.
    /// - Throws: ``IndexOutOfRange`` unless `position` is a valid index.
    /// - Complexity: O(log *n*).
    @inlinable
    public subscript(checked position: Int) -> Element {
        get throws(IndexOutOfRange) {
            guard position >= 0 && position < _cells.count else { throw IndexOutOfRange() }
            return _value(at: position)
        }
    }

    @inlinable
    func _prefixSum(through index: Int) -> Element {
        _cells.withUnsafeBufferPointer { cells in
            var sum = Element.zero
            var k = index
            while k >= 0 {
                sum += cells[k]
                k = (k & (k &+ 1)) &- 1
            }
            return sum
        }
    }

    /// Walks both ends down the query tree (each cell's parent is the cell below its range) until
    /// they meet, so the cells the two prefixes share are never read.
    @inlinable
    func _sum(in bounds: Range<Int>) -> Element {
        _cells.withUnsafeBufferPointer { cells in
            var sum = Element.zero
            var upper = bounds.upperBound &- 1
            var lower = bounds.lowerBound &- 1
            while upper != lower {
                if upper > lower {
                    sum += cells[upper]
                    upper = (upper & (upper &+ 1)) &- 1
                } else {
                    sum -= cells[lower]
                    lower = (lower & (lower &+ 1)) &- 1
                }
            }
            return sum
        }
    }

    @inlinable
    mutating func _add(_ value: Element, at index: Int) {
        _cells.withUnsafeMutableBufferPointer { cells in
            let count = cells.count
            var k = index
            while k < count {
                cells[k] += value
                k |= k &+ 1
            }
        }
    }

    /// The cell at `position` less the cells directly below it in the update tree, which cover
    /// the rest of its range.
    @inlinable
    func _value(at position: Int) -> Element {
        _cells.withUnsafeBufferPointer { cells in
            var value = cells[position]
            let stop = (position & (position &+ 1)) &- 1
            var k = position &- 1
            while k > stop {
                value -= cells[k]
                k = (k & (k &+ 1)) &- 1
            }
            return value
        }
    }
}

extension FenwickTree where Element: Comparable {
    /// The first index whose prefix sum reaches `value`: the smallest `i` with
    /// `prefixSum(through: i) >= value`, or `endIndex` when the total is below `value`.
    ///
    /// Descends the tree by binary lifting, so it reads one cell per bit of the count. The answer
    /// is meaningful only when every value is non-negative, so that the prefix sums never
    /// decrease; that is not checked.
    ///
    /// - Parameter value: The prefix sum sought.
    /// - Returns: The first index whose prefix sum is at least `value`; `0` when `value` is at most
    ///   zero and the tree is not empty; `endIndex` when no prefix sum reaches it.
    /// - Complexity: O(log *n*).
    @inlinable
    public func lowerBound(ofPrefixSum value: Element) -> Int {
        _cells.withUnsafeBufferPointer { cells in
            let count = cells.count
            guard count > 0 else { return 0 }
            var step = 1
            while step <= count / 2 {
                step &<<= 1
            }
            var position = 0
            var remaining = value
            while step > 0 {
                let next = position &+ step
                if next <= count && cells[next &- 1] < remaining {
                    position = next
                    remaining -= cells[next &- 1]
                }
                step &>>= 1
            }
            return position
        }
    }
}

extension FenwickTree: RandomAccessCollection {
    public typealias Index = Int
    public typealias Indices = Range<Int>

    @inlinable public var startIndex: Int { 0 }
    @inlinable public var endIndex: Int { _cells.count }
    @inlinable public var count: Int { _cells.count }
    @inlinable public var isEmpty: Bool { _cells.isEmpty }

    /// The value at `position`.
    ///
    /// - Parameter position: The index of the value. Traps unless it is a valid index; use
    ///   ``subscript(checked:)`` to throw instead.
    /// - Complexity: O(log *n*), and O(1) amortized over a pass through the collection.
    @inlinable
    public subscript(position: Int) -> Element {
        precondition(position >= 0 && position < _cells.count, "Index out of range")
        return _value(at: position)
    }
}

extension FenwickTree: ExpressibleByArrayLiteral {
    /// The tree holding the literal's values, in order. O(*n*).
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension FenwickTree: Equatable where Element: Equatable {
    /// Whether two trees hold the same values in the same order. O(*n*).
    @inlinable
    public static func == (lhs: FenwickTree, rhs: FenwickTree) -> Bool {
        guard lhs._cells.count == rhs._cells.count else { return false }
        return lhs._cells == rhs._cells || lhs.elementsEqual(rhs)
    }
}

extension FenwickTree: Hashable where Element: Hashable {
    /// Hashes the count and the values, in order. O(*n*).
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_cells.count)
        for value in self {
            hasher.combine(value)
        }
    }
}

extension FenwickTree: Encodable where Element: Encodable {
    /// Encodes the values, in order, as an unkeyed container. O(*n*).
    @inlinable
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for value in self {
            try container.encode(value)
        }
    }
}

extension FenwickTree: Decodable where Element: Decodable {
    /// Decodes the values, in order, from an unkeyed container. O(*n*).
    @inlinable
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var values: [Element] = []
        if let count = container.count {
            values.reserveCapacity(count)
        }
        while !container.isAtEnd {
            values.append(try container.decode(Element.self))
        }
        self.init(values)
    }
}

extension FenwickTree: Sendable where Element: Sendable {}

extension FenwickTree: CustomStringConvertible {
    /// The values, in order, written as an array literal.
    public var description: String {
        Array(self).description
    }
}
