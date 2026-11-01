import BinarySearchTrees

/// An interval tree: a sorted collection of half-open intervals with a value each, which finds the
/// intervals overlapping a range, containing a point, or lying within a range in
/// O((*k* + 1) log *n*) for *k* results.
///
/// The intervals are kept in an AVL tree ordered by lower bound, then upper bound, then the order
/// they were inserted in, and each vertex also records the largest upper bound in its subtree, so
/// a search skips every subtree that ends before the query begins (Cormen, Leiserson, Rivest and
/// Stein, *Introduction to Algorithms*, §14.3). The same interval may be stored more than once,
/// with different values.
///
/// ```swift
/// var meetings = IntervalTree<Int, String>()
/// meetings.insert(9 ..< 10, value: "stand-up")
/// meetings.insert(10 ..< 12, value: "design review")
/// meetings.insert(11 ..< 13, value: "lunch")
/// meetings.containing(11).map(\.value)          // ["design review", "lunch"]
/// meetings.overlapping(9 ..< 11).map(\.value)   // ["stand-up", "design review"]
/// meetings.contained(in: 9 ..< 12).map(\.range) // [9 ..< 10, 10 ..< 12]
/// ```
///
/// Intervals are half-open, so `9 ..< 10` and `10 ..< 12` touch without overlapping. As a
/// collection, the tree's elements are its entries in that order, read by in-order position.
@frozen
public struct IntervalTree<Bound: Comparable, Value> {
    /// An interval and its value.
    @frozen
    public struct Entry {
        /// The interval, never empty.
        public var range: Range<Bound>
        /// The value stored with it.
        public var value: Value

        /// An entry of `range` and `value`. ``IntervalTree/init(_:)`` traps on an entry whose range is
        /// empty, and ``IntervalTree/init(checked:)`` throws ``EmptyRange``.
        @inlinable
        public init(range: Range<Bound>, value: Value) {
            self.range = range
            self.value = value
        }
    }

    @usableFromInline
    typealias _Core = _TreeCore<_IntervalKey<Bound>, Value, _AugmentedAVLBalancing<_LargestUpperBound<Bound>>>

    @usableFromInline
    var _core: _Core

    /// The serial number the next inserted interval takes, which orders equal intervals.
    @usableFromInline
    var _nextSerial: Int

    /// An empty tree.
    @inlinable
    public init() {
        _core = _Core()
        _nextSerial = 0
    }

    /// The tree holding `entries`; equal intervals keep their order.
    ///
    /// - Parameter entries: The entries. Traps unless every interval is non-empty; use
    ///   ``init(checked:)`` to throw instead.
    /// - Complexity: O(*n* log *n*).
    @inlinable
    public init(_ entries: some Sequence<Entry>) {
        let entries = ContiguousArray(entries)
        precondition(entries.allSatisfy { !$0.range.isEmpty }, "An interval tree holds only non-empty intervals")
        self.init(_sorted: entries)
    }

    /// The tree holding `entries`, throwing instead of trapping on an empty interval.
    ///
    /// - Parameter entries: The entries.
    /// - Throws: ``EmptyRange`` if any interval is empty.
    /// - Complexity: O(*n* log *n*).
    @inlinable
    public init(checked entries: some Sequence<Entry>) throws(EmptyRange) {
        let entries = ContiguousArray(entries)
        guard entries.allSatisfy({ !$0.range.isEmpty }) else { throw EmptyRange() }
        self.init(_sorted: entries)
    }

    /// Sorts the entries, builds the balanced tree in one pass, and records the largest upper
    /// bounds from the leaves up.
    @inlinable
    init(_sorted entries: ContiguousArray<Entry>) {
        var keys = ContiguousArray<_IntervalKey<Bound>>()
        keys.reserveCapacity(entries.count)
        for (serial, entry) in entries.enumerated() {
            keys.append(_IntervalKey(entry.range, serial: serial))
        }
        // A key's serial is its entry's position, so the values follow the sorted keys by it.
        keys.sort()
        var values = ContiguousArray<Value>()
        values.reserveCapacity(keys.count)
        for key in keys {
            values.append(entries[key.serial].value)
        }
        _core = _Core(sortedUniqueKeys: keys, values: values)
        _nextSerial = entries.count
        let root = _core.root
        _core.nodes.withUnsafeMutableBufferPointer { nodes in
            Self._recordLargestUpperBounds(nodes, root)
        }
    }

    @inlinable
    static func _recordLargestUpperBounds(_ nodes: UnsafeMutableBufferPointer<_TreeNode<_IntervalKey<Bound>>>, _ x: Int32) {
        guard x >= 0 else { return }
        _recordLargestUpperBounds(nodes, nodes[Int(x)].left)
        _recordLargestUpperBounds(nodes, nodes[Int(x)].right)
        _LargestUpperBound<Bound>.update(nodes, x)
    }

    /// Inserts `range` with `value`, after any equal intervals already present.
    ///
    /// - Parameters:
    ///   - range: The interval. Traps if it is empty; use ``insert(checked:value:)`` to throw
    ///     instead.
    ///   - value: Its value.
    /// - Complexity: O(log *n*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    public mutating func insert(_ range: Range<Bound>, value: Value) {
        precondition(!range.isEmpty, "An interval tree holds only non-empty intervals")
        _insert(range, value: value)
    }

    /// Inserts `range` with `value`, throwing instead of trapping on an empty interval.
    ///
    /// - Throws: ``EmptyRange`` if `range` is empty; the tree is unchanged.
    /// - Complexity: O(log *n*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    public mutating func insert(checked range: Range<Bound>, value: Value) throws(EmptyRange) {
        guard !range.isEmpty else { throw EmptyRange() }
        _insert(range, value: value)
    }

    @inlinable
    mutating func _insert(_ range: Range<Bound>, value: Value) {
        _ = _core.insert(_IntervalKey(range, serial: _nextSerial), value)
        _nextSerial &+= 1
    }

    /// Removes the earliest inserted entry whose interval is `range`, and returns its value, or
    /// nil when no entry has that interval.
    ///
    /// - Parameter range: The interval.
    /// - Complexity: O(log *n*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func remove(_ range: Range<Bound>) -> Value? {
        let slot = _firstSlot(of: range)
        guard slot >= 0 else { return nil }
        return _core.remove(_core.nodes[Int(slot)].key)?.value
    }

    /// The slot of the first entry, in order, whose interval is `range`, or −1.
    @inlinable
    func _firstSlot(of range: Range<Bound>) -> Int32 {
        _core.nodes.withUnsafeBufferPointer { nodes in
            var x = _core.root
            var candidate: Int32 = -1
            while x >= 0 {
                let key = nodes[Int(x)].key
                if key.lower < range.lowerBound || (key.lower == range.lowerBound && key.upper < range.upperBound) {
                    x = nodes[Int(x)].right
                } else {
                    candidate = x
                    x = nodes[Int(x)].left
                }
            }
            guard candidate >= 0 else { return -1 }
            let key = nodes[Int(candidate)].key
            return key.lower == range.lowerBound && key.upper == range.upperBound ? candidate : -1
        }
    }

    /// The entries whose intervals overlap `range`, in order: those that share at least one
    /// point with it. An empty `range` overlaps nothing.
    ///
    /// - Complexity: O(1); iterating costs O(min(*n*, (*k* + 1) log *n*)) for *k* entries.
    @inlinable
    public func overlapping(_ range: Range<Bound>) -> SearchView {
        SearchView(_core, after: range.lowerBound, before: range.upperBound, beforeIsInclusive: false, isContainment: false, isEmpty: range.isEmpty)
    }

    /// The entries whose intervals contain `point`, in order.
    ///
    /// - Complexity: O(1); iterating costs O(min(*n*, (*k* + 1) log *n*)) for *k* entries.
    @inlinable
    public func containing(_ point: Bound) -> SearchView {
        SearchView(_core, after: point, before: point, beforeIsInclusive: true, isContainment: false, isEmpty: false)
    }

    /// The entries whose intervals lie within `range`, in order.
    ///
    /// - Complexity: O(1); iterating costs O(log *n* + *m*) for the *m* entries whose lower
    ///   bounds lie in `range`.
    @inlinable
    public func contained(in range: Range<Bound>) -> SearchView {
        SearchView(_core, after: range.lowerBound, before: range.upperBound, beforeIsInclusive: false, isContainment: true, isEmpty: range.isEmpty)
    }

    /// The entry at in-order position `position`, throwing instead of trapping on an invalid
    /// position.
    ///
    /// - Throws: ``IndexOutOfRange`` unless `position` is a valid index.
    /// - Complexity: O(log *n*).
    @inlinable
    public subscript(checked position: Int) -> Entry {
        get throws(IndexOutOfRange) {
            guard position >= 0 && position < _core.count else { throw IndexOutOfRange() }
            return _entry(at: _core.slot(atRank: position))
        }
    }

    @inlinable
    func _entry(at slot: Int32) -> Entry {
        let key = _core.nodes[Int(slot)].key
        return Entry(range: key.lower ..< key.upper, value: _core.values[Int(slot)])
    }

    /// The entries of a search, read lazily from the tree; see ``IntervalTree/overlapping(_:)``,
    /// ``IntervalTree/containing(_:)`` and ``IntervalTree/contained(in:)``.
    @frozen
    public struct SearchView: Sequence {
        @usableFromInline let _core: _Core
        /// An entry's upper bound must be above this.
        @usableFromInline let _after: Bound
        /// An entry's lower bound must be below this, or with `_beforeIsInclusive`, at most this.
        @usableFromInline let _before: Bound
        @usableFromInline let _beforeIsInclusive: Bool
        /// Whether an entry must also lie within `_after ..< _before`.
        @usableFromInline let _isContainment: Bool
        @usableFromInline let _isEmpty: Bool

        @inlinable
        init(_ core: _Core, after: Bound, before: Bound, beforeIsInclusive: Bool, isContainment: Bool, isEmpty: Bool) {
            _core = core
            _after = after
            _before = before
            _beforeIsInclusive = beforeIsInclusive
            _isContainment = isContainment
            _isEmpty = isEmpty
        }

        /// An in-order walk with an explicit stack that skips every subtree whose largest upper
        /// bound is not above `after`, the right subtree of a vertex whose lower bound is past
        /// `before`, and, for containment, the left subtree of a vertex whose lower bound is below
        /// `after`.
        @frozen
        public struct Iterator: IteratorProtocol {
            @usableFromInline let _nodes: ContiguousArray<_TreeNode<_IntervalKey<Bound>>>
            @usableFromInline let _values: ContiguousArray<Value>
            @usableFromInline let _after: Bound
            @usableFromInline let _before: Bound
            @usableFromInline let _beforeIsInclusive: Bool
            @usableFromInline let _isContainment: Bool
            @usableFromInline var _stack: ContiguousArray<Int32>

            @inlinable
            init(_ view: SearchView) {
                _nodes = view._core.nodes
                _values = view._core.values
                _after = view._after
                _before = view._before
                _beforeIsInclusive = view._beforeIsInclusive
                _isContainment = view._isContainment
                _stack = []
                if !view._isEmpty && view._core.root >= 0 {
                    _stack.reserveCapacity(2 &* (Int.bitWidth &- view._core.count.leadingZeroBitCount))
                    _pushLeft(view._core.root)
                }
            }

            @inlinable
            mutating func _pushLeft(_ start: Int32) {
                var x = start
                while x >= 0 {
                    let key = _nodes[Int(x)].key
                    guard _after < key.maximumUpper else { return }
                    _stack.append(x)
                    if _isContainment && key.lower < _after { return }
                    x = _nodes[Int(x)].left
                }
            }

            @inlinable
            public mutating func next() -> Entry? {
                while let x = _stack.popLast() {
                    let node = _nodes[Int(x)]
                    let key = node.key
                    guard _beforeIsInclusive ? key.lower <= _before : key.lower < _before else { continue }
                    _pushLeft(node.right)
                    guard _after < key.upper else { continue }
                    if _isContainment && (key.lower < _after || _before < key.upper) { continue }
                    return Entry(range: key.lower ..< key.upper, value: _values[Int(x)])
                }
                return nil
            }
        }

        @inlinable
        public func makeIterator() -> Iterator {
            Iterator(self)
        }
    }

    /// The entries in order, by an in-order walk.
    @frozen
    public struct Iterator: IteratorProtocol {
        @usableFromInline let _core: _Core
        @usableFromInline var _slots: _Core.InorderSlots

        @inlinable
        init(_ core: _Core) {
            _core = core
            _slots = _Core.InorderSlots(core)
        }

        @inlinable
        public mutating func next() -> Entry? {
            guard let slot = _slots.next() else { return nil }
            let key = _core.nodes[Int(slot)].key
            return Entry(range: key.lower ..< key.upper, value: _core.values[Int(slot)])
        }
    }
}

extension IntervalTree: RandomAccessCollection {
    public typealias Element = Entry
    public typealias Index = Int
    public typealias Indices = Range<Int>

    @inlinable public var startIndex: Int { 0 }
    @inlinable public var endIndex: Int { _core.count }
    @inlinable public var count: Int { _core.count }
    @inlinable public var isEmpty: Bool { _core.count == 0 }

    /// The entry at in-order position `position`.
    ///
    /// - Parameter position: Traps unless it is a valid index; use ``subscript(checked:)`` to
    ///   throw instead.
    /// - Complexity: O(log *n*).
    @inlinable
    public subscript(position: Int) -> Entry {
        precondition(position >= 0 && position < _core.count, "Index out of range")
        return _entry(at: _core.slot(atRank: position))
    }

    /// Iterates in order in O(1) amortized per entry.
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_core)
    }
}

extension IntervalTree.Entry: Equatable where Value: Equatable {}
extension IntervalTree.Entry: Hashable where Bound: Hashable, Value: Hashable {}
extension IntervalTree.Entry: Sendable where Bound: Sendable, Value: Sendable {}

extension IntervalTree: Equatable where Value: Equatable {
    /// Whether two trees hold the same entries in the same order. O(*n*).
    @inlinable
    public static func == (lhs: IntervalTree, rhs: IntervalTree) -> Bool {
        lhs.count == rhs.count && lhs.elementsEqual(rhs)
    }
}

extension IntervalTree: Sendable where Bound: Sendable, Value: Sendable {}

extension IntervalTree: CustomStringConvertible {
    /// The entries, in order, as `range: value` pairs.
    public var description: String {
        "[" + map { "\($0.range): \($0.value)" }.joined(separator: ", ") + "]"
    }
}

/// An interval tree's key: the interval, its serial number among equal intervals, and the largest
/// upper bound in the subtree below it, which ordering ignores.
@frozen
@usableFromInline
package struct _IntervalKey<Bound: Comparable>: Comparable {
    @usableFromInline var lower: Bound
    @usableFromInline var upper: Bound
    @usableFromInline var serial: Int
    @usableFromInline var maximumUpper: Bound

    @inlinable
    init(_ range: Range<Bound>, serial: Int) {
        lower = range.lowerBound
        upper = range.upperBound
        self.serial = serial
        maximumUpper = range.upperBound
    }

    @inlinable
    package static func < (lhs: _IntervalKey, rhs: _IntervalKey) -> Bool {
        if lhs.lower != rhs.lower { return lhs.lower < rhs.lower }
        if lhs.upper != rhs.upper { return lhs.upper < rhs.upper }
        return lhs.serial < rhs.serial
    }

    @inlinable
    package static func == (lhs: _IntervalKey, rhs: _IntervalKey) -> Bool {
        lhs.lower == rhs.lower && lhs.upper == rhs.upper && lhs.serial == rhs.serial
    }
}

extension _IntervalKey: Sendable where Bound: Sendable {}

/// Keeps each interval-tree vertex's largest upper bound in its subtree.
@usableFromInline
package enum _LargestUpperBound<Bound: Comparable>: _TreeAugmentation {
    @inlinable @inline(__always)
    package static func update<Key>(_ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>, _ x: Int32) {
        precondition(Key.self == _IntervalKey<Bound>.self, "The largest-upper-bound summary is kept only by interval trees")
        let base = UnsafeMutableRawPointer(nodes.baseAddress!).assumingMemoryBound(to: _TreeNode<_IntervalKey<Bound>>.self)
        update(UnsafeMutableBufferPointer(start: base, count: nodes.count), x)
    }

    @inlinable @inline(__always)
    static func update(_ nodes: UnsafeMutableBufferPointer<_TreeNode<_IntervalKey<Bound>>>, _ x: Int32) {
        var largest = nodes[Int(x)].key.upper
        let left = nodes[Int(x)].left
        let right = nodes[Int(x)].right
        if left >= 0 && largest < nodes[Int(left)].key.maximumUpper {
            largest = nodes[Int(left)].key.maximumUpper
        }
        if right >= 0 && largest < nodes[Int(right)].key.maximumUpper {
            largest = nodes[Int(right)].key.maximumUpper
        }
        nodes[Int(x)].key.maximumUpper = largest
    }
}
