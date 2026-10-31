/// A sorted dictionary kept in a B-tree: unique keys in ascending order, each with a value.
///
/// Lookup, insertion and removal by key take O(log *n*), as in ``BTree``, whose nodes it shares
/// the layout of. The key–value pairs are a random-access collection in ascending key order. Its
/// ``Index`` is a pair's rank, so `dictionary[dictionary.startIndex]` is the pair with the
/// smallest key, and it is a type of its own, so subscripting by key and by index never clash.
/// Reading a pair by index costs O(log *n*), and a pass through the whole collection costs O(*n*).
///
/// ```swift
/// var stock: BTreeDictionary = ["pear": 4, "apple": 7]
/// stock["fig"] = 2
/// stock["apple", default: 0] += 1
/// stock.map(\.key)          // ["apple", "fig", "pear"]
/// stock["apple"]            // 8
/// ```
///
/// Copies share their nodes: mutating one copy copies only the nodes on the path it changes.
@frozen
public struct BTreeDictionary<Key: Comparable, Value> {
    @usableFromInline
    package var _core: _BTreeCore<Key, Value>

    @inlinable
    init(_core: _BTreeCore<Key, Value>) {
        self._core = _core
    }

    /// An empty dictionary.
    @inlinable
    public init() {
        _core = _BTreeCore()
    }

    /// The dictionary of `keysAndValues`, whose keys must be distinct.
    ///
    /// - Parameter keysAndValues: The pairs, in any order. Traps when two keys are equal; use
    ///   ``init(checkedUniqueKeysWithValues:)`` to throw instead.
    /// - Complexity: O(*n* log *n*).
    @inlinable
    public init(uniqueKeysWithValues keysAndValues: some Sequence<(Key, Value)>) {
        do throws(DuplicateKey) {
            _core = try Self._sortedCore(keysAndValues) { _, _ throws(DuplicateKey) in throw DuplicateKey() }
        } catch {
            preconditionFailure("Duplicate keys")
        }
    }

    /// The dictionary of `keysAndValues`, throwing instead of trapping when two keys are equal.
    ///
    /// - Parameter keysAndValues: The pairs, in any order.
    /// - Throws: `DuplicateKey` when two keys are equal.
    /// - Complexity: O(*n* log *n*).
    @inlinable
    public init(checkedUniqueKeysWithValues keysAndValues: some Sequence<(Key, Value)>) throws(DuplicateKey) {
        _core = try Self._sortedCore(keysAndValues) { _, _ throws(DuplicateKey) in throw DuplicateKey() }
    }

    /// The dictionary of `keysAndValues`, merging the values of equal keys with `combine`, in the
    /// order the pairs appear.
    ///
    /// - Parameters:
    ///   - keysAndValues: The pairs, in any order.
    ///   - combine: Given the value so far and the next value for the same key, the value kept.
    /// - Throws: Whatever `combine` throws.
    /// - Complexity: O(*n* log *n*).
    @inlinable
    public init<E: Error>(_ keysAndValues: some Sequence<(Key, Value)>, uniquingKeysWith combine: (Value, Value) throws(E) -> Value) throws(E) {
        _core = try Self._sortedCore(keysAndValues, combine: combine)
    }

    /// Sorts the pairs by key, the position breaking ties, and merges equal keys with `combine`.
    @inlinable
    static func _sortedCore<E: Error>(
        _ keysAndValues: some Sequence<(Key, Value)>,
        combine: (Value, Value) throws(E) -> Value
    ) throws(E) -> _BTreeCore<Key, Value> {
        var pairs = ContiguousArray(keysAndValues)
        var isStrictlyAscending = true
        var k = 1
        while k < pairs.count {
            if !(pairs[k &- 1].0 < pairs[k].0) {
                isStrictlyAscending = false
                break
            }
            k &+= 1
        }
        var keys = ContiguousArray<Key>()
        var values = ContiguousArray<Value>()
        keys.reserveCapacity(pairs.count)
        values.reserveCapacity(pairs.count)
        if isStrictlyAscending {
            for (key, value) in pairs {
                keys.append(key)
                values.append(value)
            }
        } else {
            var order = Array(pairs.indices)
            order.sort { a, b in pairs[a].0 < pairs[b].0 || (!(pairs[b].0 < pairs[a].0) && a < b) }
            for position in order {
                let (key, value) = pairs[position]
                if let last = keys.last, !(last < key) {
                    values[values.count &- 1] = try combine(values[values.count &- 1], value)
                } else {
                    keys.append(key)
                    values.append(value)
                }
            }
            pairs.removeAll()
        }
        return _BTreeCore(sortedUniqueKeys: keys, values: values)
    }

    /// The number of nodes on every path from the root down to a leaf: 0 when empty, 1 while the
    /// root is the only node. O(log *n*).
    @inlinable
    public var height: Int { _core.height }

    /// The value for `key`, or nil when absent; setting nil removes the pair.
    ///
    /// - Complexity: O(log *n*), plus O(log *n*) node copies for a set when the storage is
    ///   shared.
    @inlinable
    public subscript(key: Key) -> Value? {
        get {
            _core.element(forKey: key)?.value
        }
        set {
            if let newValue {
                updateValue(newValue, forKey: key)
            } else {
                removeValue(forKey: key)
            }
        }
    }

    /// The value for `key`, or `defaultValue` when absent; setting stores the value for `key`.
    ///
    /// - Complexity: O(log *n*), plus O(log *n*) node copies for a set when the storage is
    ///   shared.
    @inlinable
    public subscript(key: Key, default defaultValue: @autoclosure () -> Value) -> Value {
        get {
            _core.element(forKey: key)?.value ?? defaultValue()
        }
        set {
            updateValue(newValue, forKey: key)
        }
    }

    /// Stores `value` for `key`.
    ///
    /// - Returns: The value replaced, or nil when `key` was absent.
    /// - Complexity: O(log *n*), plus O(log *n*) node copies when the storage is shared with
    ///   another copy.
    @inlinable
    @discardableResult
    public mutating func updateValue(_ value: Value, forKey key: Key) -> Value? {
        _core.insert(key, value, existing: .replaceValue)?.value
    }

    /// Removes the pair for `key`.
    ///
    /// - Returns: The value removed, or nil when `key` was absent.
    /// - Complexity: O(log *n*), plus O(log *n*) node copies when the storage is shared with
    ///   another copy.
    @inlinable
    @discardableResult
    public mutating func removeValue(forKey key: Key) -> Value? {
        _core.remove(key)?.value
    }

    /// The index of the pair for `key`, or nil when absent. O(log *n*).
    @inlinable
    public func index(forKey key: Key) -> Index? {
        guard let rank = _core.rank(of: key) else { return nil }
        return Index(_rank: rank)
    }

    /// The index of the first pair whose key is not less than `key`, or `endIndex` when every key
    /// is less. O(log *n*).
    @inlinable
    public func lowerBound(_ key: Key) -> Index {
        Index(_rank: _core.countBelow(key, orEqual: false))
    }

    /// The index of the first pair whose key is greater than `key`, or `endIndex` when none is.
    /// O(log *n*).
    @inlinable
    public func upperBound(_ key: Key) -> Index {
        Index(_rank: _core.countBelow(key, orEqual: true))
    }

    /// The pairs whose keys lie in `range`, in ascending key order. O(log *n*).
    @inlinable
    public func elements(in range: Range<Key>) -> Slice<BTreeDictionary> {
        self[lowerBound(range.lowerBound) ..< lowerBound(range.upperBound)]
    }

    /// The pairs whose keys lie in `range`, in ascending key order. O(log *n*).
    @inlinable
    public func elements(in range: ClosedRange<Key>) -> Slice<BTreeDictionary> {
        self[lowerBound(range.lowerBound) ..< upperBound(range.upperBound)]
    }

    /// Removes and returns the pair at `index`.
    ///
    /// - Parameter index: The index of the pair. Traps unless it is a valid index; use
    ///   ``remove(checkedAt:)`` to throw instead.
    /// - Complexity: O(log *n*), plus O(log *n*) node copies when the storage is shared with
    ///   another copy.
    @inlinable
    @discardableResult
    public mutating func remove(at index: Index) -> Element {
        precondition(index._rank >= 0 && index._rank < _core.count, "Index out of range")
        let removed = _core.remove(atRank: index._rank)
        return (removed.key, removed.value)
    }

    /// Removes and returns the pair at `index`, throwing instead of trapping on an invalid index.
    ///
    /// - Parameter index: The index of the pair.
    /// - Throws: `IndexOutOfRange` unless `index` is a valid index; the dictionary is unchanged.
    /// - Complexity: O(log *n*), plus O(log *n*) node copies when the storage is shared with
    ///   another copy.
    @inlinable
    @discardableResult
    public mutating func remove(checkedAt index: Index) throws(IndexOutOfRange) -> Element {
        guard index._rank >= 0 && index._rank < _core.count else { throw IndexOutOfRange() }
        let removed = _core.remove(atRank: index._rank)
        return (removed.key, removed.value)
    }

    /// The pair at `position`, throwing instead of trapping on an invalid index.
    ///
    /// - Parameter position: The index of the pair.
    /// - Throws: `IndexOutOfRange` unless `position` is a valid index.
    /// - Complexity: O(log *n*).
    @inlinable
    public subscript(checked position: Index) -> Element {
        get throws(IndexOutOfRange) {
            guard position._rank >= 0 && position._rank < _core.count else { throw IndexOutOfRange() }
            let element = _core.element(atRank: position._rank)
            return (element.key, element.value)
        }
    }
}

extension BTreeDictionary {
    /// The two dictionaries a split produces: the pairs whose keys are below the split point, and
    /// the rest.
    @frozen
    public struct Split {
        /// The pairs whose keys are below the split point.
        public var lower: BTreeDictionary

        /// The pairs whose keys are not below the split point.
        public var upper: BTreeDictionary

        /// The parts of a split.
        ///
        /// - Parameters:
        ///   - lower: The pairs whose keys are below the split point.
        ///   - upper: The pairs whose keys are not below the split point.
        @inlinable
        public init(lower: BTreeDictionary, upper: BTreeDictionary) {
            self.lower = lower
            self.upper = upper
        }
    }

    /// Splits the dictionary into the pairs whose keys are below `key` and the rest.
    ///
    /// - Parameter key: The split point. Its pair goes to the upper part when present.
    /// - Returns: The lower part, whose keys are all less than `key`, and the upper part.
    /// - Complexity: O(*n*): both parts are built anew.
    @inlinable
    public func split(at key: Key) -> Split {
        let boundary = lowerBound(key)._rank
        var lowerKeys = ContiguousArray<Key>()
        var lowerValues = ContiguousArray<Value>()
        var upperKeys = ContiguousArray<Key>()
        var upperValues = ContiguousArray<Value>()
        lowerKeys.reserveCapacity(boundary)
        lowerValues.reserveCapacity(boundary)
        upperKeys.reserveCapacity(count &- boundary)
        upperValues.reserveCapacity(count &- boundary)
        for (rank, pair) in enumerated() {
            if rank < boundary {
                lowerKeys.append(pair.key)
                lowerValues.append(pair.value)
            } else {
                upperKeys.append(pair.key)
                upperValues.append(pair.value)
            }
        }
        return Split(
            lower: BTreeDictionary(_core: _BTreeCore(sortedUniqueKeys: lowerKeys, values: lowerValues)),
            upper: BTreeDictionary(_core: _BTreeCore(sortedUniqueKeys: upperKeys, values: upperValues))
        )
    }
}

extension BTreeDictionary: RandomAccessCollection {
    public typealias Element = (key: Key, value: Value)
    public typealias Indices = Range<Index>
    public typealias SubSequence = Slice<BTreeDictionary>

    /// A position in the dictionary: the rank of a pair by key. Mutating the dictionary shifts
    /// the ranks after the change, as an array's indices shift.
    @frozen
    public struct Index: Comparable, Hashable, Strideable, Sendable {
        @usableFromInline
        var _rank: Int

        @inlinable
        init(_rank: Int) {
            self._rank = _rank
        }

        @inlinable
        public static func < (lhs: Index, rhs: Index) -> Bool { lhs._rank < rhs._rank }

        @inlinable
        public func distance(to other: Index) -> Int { other._rank &- _rank }

        @inlinable
        public func advanced(by n: Int) -> Index { Index(_rank: _rank &+ n) }
    }

    @inlinable public var startIndex: Index { Index(_rank: 0) }
    @inlinable public var endIndex: Index { Index(_rank: _core.count) }
    @inlinable public var count: Int { _core.count }
    @inlinable public var isEmpty: Bool { _core.count == 0 }

    /// The pair at `position`, the one with the `position`-th smallest key.
    ///
    /// - Parameter position: The index of the pair. Traps unless it is a valid index; use
    ///   ``subscript(checked:)`` to throw instead.
    /// - Complexity: O(log *n*).
    @inlinable
    public subscript(position: Index) -> Element {
        precondition(position._rank >= 0 && position._rank < _core.count, "Index out of range")
        let element = _core.element(atRank: position._rank)
        return (element.key, element.value)
    }

    /// An iterator over the pairs in ascending key order: O(*n*) for the whole pass, O(log *n*)
    /// extra space.
    @frozen
    public struct Iterator: IteratorProtocol {
        @usableFromInline var _elements: _BTreeCore<Key, Value>.Elements

        @inlinable
        init(_ core: _BTreeCore<Key, Value>) {
            _elements = _BTreeCore.Elements(core)
        }

        @inlinable
        public mutating func next() -> Element? {
            guard let element = _elements.next() else { return nil }
            return (element.key, element.value)
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_core)
    }
}

extension BTreeDictionary: ExpressibleByDictionaryLiteral {
    /// The dictionary of the literal's pairs. Traps when two keys are equal. O(*n* log *n*).
    @inlinable
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(uniqueKeysWithValues: elements)
    }
}

extension BTreeDictionary: Equatable where Value: Equatable {
    /// Whether two dictionaries hold equal keys with equal values, whatever their shapes. O(*n*).
    @inlinable
    public static func == (lhs: BTreeDictionary, rhs: BTreeDictionary) -> Bool {
        lhs._core.count == rhs._core.count && lhs.elementsEqual(rhs) { $0.key == $1.key && $0.value == $1.value }
    }
}

extension BTreeDictionary: Hashable where Key: Hashable, Value: Hashable {
    /// Hashes the count and the pairs in ascending key order. O(*n*).
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_core.count)
        for (key, value) in self {
            hasher.combine(key)
            hasher.combine(value)
        }
    }
}

extension BTreeDictionary: Encodable where Key: Encodable, Value: Encodable {
    /// Encodes the pairs in ascending key order as an unkeyed container of alternating keys and
    /// values. O(*n*).
    @inlinable
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for (key, value) in self {
            try container.encode(key)
            try container.encode(value)
        }
    }
}

extension BTreeDictionary: Decodable where Key: Decodable, Value: Decodable {
    /// Decodes alternating keys and values from an unkeyed container, in any key order.
    ///
    /// - Throws: `DecodingError.dataCorrupted` when two keys are equal or a key has no value.
    /// - Complexity: O(*n* log *n*).
    @inlinable
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var pairs: [(Key, Value)] = []
        while !container.isAtEnd {
            let key = try container.decode(Key.self)
            guard !container.isAtEnd else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "A key has no value")
            }
            pairs.append((key, try container.decode(Value.self)))
        }
        do throws(DuplicateKey) {
            self.init(_core: try Self._sortedCore(pairs) { _, _ throws(DuplicateKey) in throw DuplicateKey() })
        } catch {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Duplicate keys")
        }
    }
}

extension BTreeDictionary: Sendable where Key: Sendable, Value: Sendable {}
extension BTreeDictionary.Iterator: Sendable where Key: Sendable, Value: Sendable {}

extension BTreeDictionary: CustomStringConvertible {
    /// The pairs in ascending key order, written as a dictionary literal.
    public var description: String {
        guard !isEmpty else { return "[:]" }
        var text = "["
        var first = true
        for (key, value) in self {
            if !first { text += ", " }
            first = false
            debugPrint(key, terminator: "", to: &text)
            text += ": "
            debugPrint(value, terminator: "", to: &text)
        }
        return text + "]"
    }
}
