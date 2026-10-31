/// A sorted dictionary kept in an AVL tree: unique keys in ascending order, each with a value.
///
/// Lookup, insertion and removal by key take O(log *n*), as in ``AVLTree``, whose balancing and
/// height bound it shares. The key–value pairs are a random-access collection in ascending key
/// order. Its ``Index`` is a pair's rank, so `dictionary[dictionary.startIndex]` is the pair with
/// the smallest key, and it is a type of its own, so subscripting by key and by index never
/// clash. Reading a pair by index costs O(log *n*), and a pass through the whole collection costs
/// O(*n*).
///
/// ```swift
/// var stock: AVLDictionary = ["pear": 4, "apple": 7]
/// stock["fig"] = 2
/// stock["apple", default: 0] += 1
/// stock.map(\.key)          // ["apple", "fig", "pear"]
/// stock["apple"]            // 8
/// ```
@frozen
public struct AVLDictionary<Key: Comparable, Value> {
    @usableFromInline
    package var _core: _TreeCore<Key, Value, _AVLBalancing>

    @inlinable
    init(_core: _TreeCore<Key, Value, _AVLBalancing>) {
        self._core = _core
    }

    /// An empty dictionary.
    @inlinable
    public init() {
        _core = _TreeCore()
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
    ) throws(E) -> _TreeCore<Key, Value, _AVLBalancing> {
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
        return _TreeCore(sortedUniqueKeys: keys, values: values)
    }

    /// The number of pairs on the longest path from the root down: 0 when empty, 1 for one pair,
    /// and below 1.4405 log₂(*n* + 2) − 0.3277 always. O(1).
    @inlinable
    public var height: Int { _AVLBalancing.height(_core.nodes, root: _core.root) }

    /// The value for `key`, or nil when absent; setting nil removes the pair.
    ///
    /// - Complexity: O(log *n*), plus O(*n*) for a set when the storage is shared.
    @inlinable
    public subscript(key: Key) -> Value? {
        get {
            let slot = _core.slot(of: key)
            return slot < 0 ? nil : _core.values[Int(slot)]
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
    /// - Complexity: O(log *n*), plus O(*n*) for a set when the storage is shared.
    @inlinable
    public subscript(key: Key, default defaultValue: @autoclosure () -> Value) -> Value {
        get {
            let slot = _core.slot(of: key)
            return slot < 0 ? defaultValue() : _core.values[Int(slot)]
        }
        set {
            updateValue(newValue, forKey: key)
        }
    }

    /// Stores `value` for `key`.
    ///
    /// - Returns: The value replaced, or nil when `key` was absent.
    /// - Complexity: O(log *n*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func updateValue(_ value: Value, forKey key: Key) -> Value? {
        let (inserted, slot) = _core.insert(key, value)
        guard !inserted else { return nil }
        let old = _core.values[Int(slot)]
        _core.values[Int(slot)] = value
        return old
    }

    /// Removes the pair for `key`.
    ///
    /// - Returns: The value removed, or nil when `key` was absent.
    /// - Complexity: O(log *n*), plus O(*n*) when the storage is shared with another copy.
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
    public func elements(in range: Range<Key>) -> Slice<AVLDictionary> {
        self[lowerBound(range.lowerBound) ..< lowerBound(range.upperBound)]
    }

    /// The pairs whose keys lie in `range`, in ascending key order. O(log *n*).
    @inlinable
    public func elements(in range: ClosedRange<Key>) -> Slice<AVLDictionary> {
        self[lowerBound(range.lowerBound) ..< upperBound(range.upperBound)]
    }

    /// Removes and returns the pair at `index`.
    ///
    /// - Parameter index: The index of the pair. Traps unless it is a valid index; use
    ///   ``remove(checkedAt:)`` to throw instead.
    /// - Complexity: O(log *n*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func remove(at index: Index) -> Element {
        precondition(index._rank >= 0 && index._rank < _core.count, "Index out of range")
        let (key, value) = _core.remove(atRank: index._rank)
        return (key, value)
    }

    /// Removes and returns the pair at `index`, throwing instead of trapping on an invalid index.
    ///
    /// - Parameter index: The index of the pair.
    /// - Throws: `IndexOutOfRange` unless `index` is a valid index; the dictionary is unchanged.
    /// - Complexity: O(log *n*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func remove(checkedAt index: Index) throws(IndexOutOfRange) -> Element {
        guard index._rank >= 0 && index._rank < _core.count else { throw IndexOutOfRange() }
        let (key, value) = _core.remove(atRank: index._rank)
        return (key, value)
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
            let slot = Int(_core.slot(atRank: position._rank))
            return (_core.nodes[slot].key, _core.values[slot])
        }
    }
}

extension AVLDictionary: RandomAccessCollection {
    public typealias Element = (key: Key, value: Value)
    public typealias Indices = Range<Index>
    public typealias SubSequence = Slice<AVLDictionary>

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
        let slot = Int(_core.slot(atRank: position._rank))
        return (_core.nodes[slot].key, _core.values[slot])
    }

    /// An iterator over the pairs in ascending key order: O(*n*) for the whole pass, O(log *n*)
    /// extra space.
    @frozen
    public struct Iterator: IteratorProtocol {
        @usableFromInline let _values: ContiguousArray<Value>
        @usableFromInline var _slots: _TreeCore<Key, Value, _AVLBalancing>.InorderSlots

        @inlinable
        init(_ core: _TreeCore<Key, Value, _AVLBalancing>) {
            _values = core.values
            _slots = _TreeCore.InorderSlots(core)
        }

        @inlinable
        public mutating func next() -> Element? {
            guard let slot = _slots.next() else { return nil }
            return (_slots.nodes[Int(slot)].key, _values[Int(slot)])
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_core)
    }
}

extension AVLDictionary: ExpressibleByDictionaryLiteral {
    /// The dictionary of the literal's pairs. Traps when two keys are equal. O(*n* log *n*).
    @inlinable
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(uniqueKeysWithValues: elements)
    }
}

extension AVLDictionary: Equatable where Value: Equatable {
    /// Whether two dictionaries hold equal keys with equal values, whatever their shapes. O(*n*).
    @inlinable
    public static func == (lhs: AVLDictionary, rhs: AVLDictionary) -> Bool {
        lhs._core.count == rhs._core.count && lhs.elementsEqual(rhs) { $0.key == $1.key && $0.value == $1.value }
    }
}

extension AVLDictionary: Hashable where Key: Hashable, Value: Hashable {
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

extension AVLDictionary: Encodable where Key: Encodable, Value: Encodable {
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

extension AVLDictionary: Decodable where Key: Decodable, Value: Decodable {
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

extension AVLDictionary: Sendable where Key: Sendable, Value: Sendable {}
extension AVLDictionary.Iterator: Sendable where Key: Sendable, Value: Sendable {}

extension AVLDictionary: CustomStringConvertible {
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
