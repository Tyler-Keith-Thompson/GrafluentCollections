/// A segment tree with lazy propagation: a sequence of values that combines any range of them
/// under a monoid and applies an update to every value in a range, each in O(log *n*).
///
/// The layout is ``SegmentTree``'s: a perfect binary tree over the values padded to a power of
/// two, in one flat array of cells. Beside each internal cell sits a pending update, applied to
/// that cell's value but not yet to the cells below it. A range update applies itself to the
/// O(log *n*) cells that cover the range and leaves it pending there, pushing older pending
/// updates down one level on the way so that updates reach each cell in the order they were made.
/// A query reads without changing the tree, composing the pending updates of the cells it
/// passes through.
///
/// The ``MonoidAction`` names the monoid and the updates:
///
/// ```swift
/// enum AddToSum: MonoidAction {
///     typealias Values = Sum<Int>
///     static var identity: Int { 0 }
///     static func compose(_ outer: Int, _ inner: Int) -> Int { outer + inner }
///     static func apply(_ update: Int, to sum: Int, count: Int) -> Int { sum + update * count }
/// }
///
/// var tree = LazySegmentTree<AddToSum>([1, 2, 3, 4, 5])
/// tree.apply(10, in: 1 ..< 4)
/// tree.combined(in: 0 ..< 5)   // 45
/// tree[2]                      // 13
/// ```
///
/// As a collection, a lazy segment tree's elements are the values, in order, with every update
/// applied.
@frozen
public struct LazySegmentTree<Action: MonoidAction> {
    public typealias Element = Action.Values.Element
    /// The updates the tree applies to ranges of values, as its action names them.
    public typealias Update = Action.Update

    /// The cells; cell 0 is unused, and the leaves start at half the count.
    @usableFromInline
    var _cells: ContiguousArray<Element>

    /// The update pending at each internal cell, for the cells below it; entry 0 is unused.
    @usableFromInline
    var _pending: ContiguousArray<Update>

    /// The number of values.
    @usableFromInline
    var _count: Int

    /// An empty tree.
    @inlinable
    public init() {
        self.init(EmptyCollection())
    }

    /// The tree holding `values`, in order, with no update pending.
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
        var cells = ContiguousArray(repeating: Action.Values.identity, count: 2 &* size)
        cells.withUnsafeMutableBufferPointer { cells in
            for k in 0 ..< count {
                cells[size &+ k] = values[k]
            }
            var k = size &- 1
            while k > 0 {
                cells[k] = Action.Values.combine(cells[2 &* k], cells[2 &* k &+ 1])
                k &-= 1
            }
        }
        _cells = cells
        _pending = ContiguousArray(repeating: Action.identity, count: size)
        _count = count
    }

    /// The number of leaves, a power of two.
    @inlinable
    var _size: Int { _pending.count }

    /// The values whose indices lie in `range`, combined in index order.
    ///
    /// - Parameter range: The indices combined. Traps unless every index in it is valid (an empty
    ///   range may sit at `endIndex`); use ``combined(checkedIn:)`` to throw instead.
    /// - Returns: The combination, or the identity for an empty range.
    /// - Complexity: O(log *n*).
    @inlinable
    public func combined(in range: Range<Int>) -> Element {
        precondition(range.lowerBound >= 0 && range.upperBound <= _count, "Range out of bounds")
        guard !range.isEmpty else { return Action.Values.identity }
        return _combined(range)
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
        return combined(in: range)
    }

    /// Applies `update` to every value whose index lies in `range`.
    ///
    /// - Parameters:
    ///   - update: The update.
    ///   - range: The indices updated. Traps unless every index in it is valid (an empty range
    ///     may sit at `endIndex`); use ``apply(_:checkedIn:)`` to throw instead.
    /// - Complexity: O(log *n*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    public mutating func apply(_ update: Update, in range: Range<Int>) {
        precondition(range.lowerBound >= 0 && range.upperBound <= _count, "Range out of bounds")
        guard !range.isEmpty else { return }
        _apply(update, cell: 1, lower: 0, upper: _size, range)
    }

    /// Applies `update` to every value whose index lies in `range`, throwing instead of trapping
    /// on an invalid range.
    ///
    /// - Throws: ``IndexOutOfRange`` unless every index in `range` is valid (an empty range may
    ///   sit at `endIndex`); the tree is unchanged.
    /// - Complexity: O(log *n*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    public mutating func apply(_ update: Update, checkedIn range: Range<Int>) throws(IndexOutOfRange) {
        guard range.lowerBound >= 0 && range.upperBound <= _count else { throw IndexOutOfRange() }
        apply(update, in: range)
    }

    /// Replaces the value at `index` with `value`, discarding the updates applied to it so far.
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
    /// - Throws: ``IndexOutOfRange`` unless `index` is a valid index; the tree is unchanged.
    /// - Complexity: O(log *n*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    public mutating func update(checkedAt index: Int, to value: Element) throws(IndexOutOfRange) {
        guard index >= 0 && index < _count else { throw IndexOutOfRange() }
        _update(at: index, to: value)
    }

    /// The value at `position`, with every update applied, throwing instead of trapping on an
    /// invalid index.
    ///
    /// - Parameter position: The index of the value.
    /// - Throws: ``IndexOutOfRange`` unless `position` is a valid index.
    /// - Complexity: O(log *n*).
    @inlinable
    public subscript(checked position: Int) -> Element {
        get throws(IndexOutOfRange) {
            guard position >= 0 && position < _count else { throw IndexOutOfRange() }
            return _value(at: position)
        }
    }

    // MARK: - Internals

    /// The values in `range`, combined in index order, with the updates pending above each cell
    /// applied. It walks down from the root to the cell where the range splits, then down each
    /// side to the range's two ends, gathering the cells the range covers.
    @inlinable
    func _combined(_ range: Range<Int>) -> Element {
        _cells.withUnsafeBufferPointer { cells in
            _pending.withUnsafeBufferPointer { pending in
                let lowerBound = range.lowerBound, upperBound = range.upperBound
                var cell = 1, lower = 0, upper = pending.count
                var above = Action.identity
                var middle: Int
                while true {
                    if lowerBound <= lower && upper <= upperBound {
                        return Action.apply(above, to: cells[cell], count: upper &- lower)
                    }
                    middle = (lower &+ upper) &>> 1
                    above = Action.compose(above, pending[cell])
                    if upperBound <= middle {
                        cell = 2 &* cell
                        upper = middle
                    } else if middle <= lowerBound {
                        cell = 2 &* cell &+ 1
                        lower = middle
                    } else {
                        break
                    }
                }
                // The left side, lowerBound ..< middle: each cell right of the path is covered.
                var left = Action.Values.identity
                var side = 2 &* cell, sideLower = lower, sideUpper = middle, sidePending = above
                while lowerBound > sideLower {
                    let half = (sideLower &+ sideUpper) &>> 1
                    let below = Action.compose(sidePending, pending[side])
                    if lowerBound < half {
                        let covered = Action.apply(below, to: cells[2 &* side &+ 1], count: sideUpper &- half)
                        left = Action.Values.combine(covered, left)
                        side = 2 &* side
                        sideUpper = half
                    } else {
                        side = 2 &* side &+ 1
                        sideLower = half
                    }
                    sidePending = below
                }
                left = Action.Values.combine(
                    Action.apply(sidePending, to: cells[side], count: sideUpper &- sideLower), left)
                // The right side, middle ..< upperBound: each cell left of the path is covered.
                var right = Action.Values.identity
                side = 2 &* cell &+ 1
                sideLower = middle
                sideUpper = upper
                sidePending = above
                while upperBound < sideUpper {
                    let half = (sideLower &+ sideUpper) &>> 1
                    let below = Action.compose(sidePending, pending[side])
                    if half < upperBound {
                        let covered = Action.apply(below, to: cells[2 &* side], count: half &- sideLower)
                        right = Action.Values.combine(right, covered)
                        side = 2 &* side &+ 1
                        sideLower = half
                    } else {
                        side = 2 &* side
                        sideUpper = half
                    }
                    sidePending = below
                }
                right = Action.Values.combine(
                    right, Action.apply(sidePending, to: cells[side], count: sideUpper &- sideLower))
                return Action.Values.combine(left, right)
            }
        }
    }

    /// The cells and pending updates, written through once the storage is unique.
    @usableFromInline
    struct _Buffers {
        @usableFromInline let cells: UnsafeMutableBufferPointer<Element>
        @usableFromInline let pending: UnsafeMutableBufferPointer<Update>
        @usableFromInline let count: Int

        @inlinable
        init(cells: UnsafeMutableBufferPointer<Element>, pending: UnsafeMutableBufferPointer<Update>, count: Int) {
            self.cells = cells
            self.pending = pending
            self.count = count
        }

        /// The number of values, not padding, among the leaves `lower ..< upper`.
        @inlinable
        func realCount(_ lower: Int, _ upper: Int) -> Int {
            Swift.max(0, Swift.min(upper, count) &- lower)
        }

        /// Applies `update` to `cell`, whose leaves hold `count` values, and leaves it pending
        /// for the cells below.
        @inlinable
        func applyToCell(_ update: Update, _ cell: Int, count: Int) {
            cells[cell] = Action.apply(update, to: cells[cell], count: count)
            if cell < pending.count {
                pending[cell] = Action.compose(update, pending[cell])
            }
        }

        /// Moves the update pending at `cell`, which covers `lower ..< upper`, to its children.
        @inlinable
        func push(_ cell: Int, lower: Int, upper: Int) {
            let update = pending[cell]
            let middle = (lower &+ upper) / 2
            applyToCell(update, 2 &* cell, count: realCount(lower, middle))
            applyToCell(update, 2 &* cell &+ 1, count: realCount(middle, upper))
            pending[cell] = Action.identity
        }

        @inlinable
        func apply(_ update: Update, cell: Int, lower: Int, upper: Int, _ range: Range<Int>) {
            if range.lowerBound <= lower && upper <= range.upperBound {
                applyToCell(update, cell, count: upper &- lower)
                return
            }
            push(cell, lower: lower, upper: upper)
            let middle = (lower &+ upper) / 2
            if range.lowerBound < middle {
                apply(update, cell: 2 &* cell, lower: lower, upper: middle, range)
            }
            if middle < range.upperBound {
                apply(update, cell: 2 &* cell &+ 1, lower: middle, upper: upper, range)
            }
            cells[cell] = Action.Values.combine(cells[2 &* cell], cells[2 &* cell &+ 1])
        }

        @inlinable
        func update(at index: Int, to value: Element) {
            let size = pending.count
            var cell = 1, lower = 0, upper = size
            while cell < size {
                push(cell, lower: lower, upper: upper)
                let middle = (lower &+ upper) / 2
                if index < middle {
                    cell = 2 &* cell
                    upper = middle
                } else {
                    cell = 2 &* cell &+ 1
                    lower = middle
                }
            }
            cells[cell] = value
            cell &>>= 1
            while cell > 0 {
                cells[cell] = Action.Values.combine(cells[2 &* cell], cells[2 &* cell &+ 1])
                cell &>>= 1
            }
        }
    }

    /// Runs `body` over the storage, made unique first.
    @inlinable
    mutating func _withBuffers(_ body: (_Buffers) -> Void) {
        let count = _count
        _cells.withUnsafeMutableBufferPointer { cells in
            _pending.withUnsafeMutableBufferPointer { pending in
                body(_Buffers(cells: cells, pending: pending, count: count))
            }
        }
    }

    @inlinable
    mutating func _apply(_ update: Update, cell: Int, lower: Int, upper: Int, _ range: Range<Int>) {
        _withBuffers { $0.apply(update, cell: cell, lower: lower, upper: upper, range) }
    }

    @inlinable
    mutating func _update(at index: Int, to value: Element) {
        _withBuffers { $0.update(at: index, to: value) }
    }

    /// The leaf with the updates pending above it applied, from the root down.
    @inlinable
    func _value(at position: Int) -> Element {
        let leaf = _size &+ position
        var pending = Action.identity
        var shift = _size.trailingZeroBitCount
        while shift > 0 {
            pending = Action.compose(pending, _pending[leaf >> shift])
            shift &-= 1
        }
        return Action.apply(pending, to: _cells[leaf], count: 1)
    }
}

extension LazySegmentTree: RandomAccessCollection {
    public typealias Index = Int
    public typealias Indices = Range<Int>

    @inlinable public var startIndex: Int { 0 }
    @inlinable public var endIndex: Int { _count }
    @inlinable public var count: Int { _count }
    @inlinable public var isEmpty: Bool { _count == 0 }

    /// The value at `position`, with every update applied.
    ///
    /// - Parameter position: The index of the value. Traps unless it is a valid index; use
    ///   ``subscript(checked:)`` to throw instead.
    /// - Complexity: O(log *n*).
    @inlinable
    public subscript(position: Int) -> Element {
        precondition(position >= 0 && position < _count, "Index out of range")
        return _value(at: position)
    }
}

extension LazySegmentTree: ExpressibleByArrayLiteral {
    /// The tree holding the literal's values, in order. O(*n*).
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

extension LazySegmentTree: Equatable where Element: Equatable {
    /// Whether two trees hold the same values, with their updates applied, in the same order.
    /// O(*n* log *n*).
    @inlinable
    public static func == (lhs: LazySegmentTree, rhs: LazySegmentTree) -> Bool {
        lhs._count == rhs._count && lhs.elementsEqual(rhs)
    }
}

extension LazySegmentTree: Hashable where Element: Hashable {
    /// Hashes the count and the values, in order. O(*n* log *n*).
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_count)
        for value in self {
            hasher.combine(value)
        }
    }
}

extension LazySegmentTree: Sendable where Element: Sendable, Update: Sendable {}

extension LazySegmentTree: CustomStringConvertible {
    /// The values, with their updates applied, in order, written as an array literal.
    public var description: String {
        Array(self).description
    }
}
