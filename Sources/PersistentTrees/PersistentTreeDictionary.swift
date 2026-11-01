/// A persistent sorted dictionary: unique keys in ascending order, each with a value, where every
/// version stays usable and versions share all but the vertices their edits touched.
///
/// The pairs live in the weight-balanced tree of immutable vertices that ``PersistentTreeSet``
/// uses: an edit makes O(log *n*) new vertices along the path to the change and shares the rest,
/// and ``merging(_:uniquingKeysWith:)`` joins trees in O(*m* log(*n* / *m* + 1)) for *m* ≤ *n*
/// pairs.
///
/// ```swift
/// let prices: PersistentTreeDictionary = ["pear": 4, "apple": 7]
/// let sale = prices.updatingValue(5, forKey: "apple")
/// prices["apple"]                    // 7
/// sale["apple"]                      // 5
/// sale.map(\.key)                    // ["apple", "pear"]
/// ```
///
/// The pairs are a random-access collection in ascending key order. Its ``Index`` is a pair's
/// rank, a type of its own so subscripting by key and by index never clash. Reading a pair by
/// index costs O(log *n*), and a pass through the whole dictionary O(*n*).
@frozen
public struct PersistentTreeDictionary<Key: Comparable, Value> {
    @usableFromInline
    package var _root: _PersistentNode<Key, Value>?

    @inlinable
    init(_root: _PersistentNode<Key, Value>?) {
        self._root = _root
    }

    /// An empty dictionary.
    @inlinable
    public init() {
        _root = nil
    }

    /// The dictionary of `keysAndValues`, whose keys must be distinct.
    ///
    /// - Parameter keysAndValues: The pairs, in any order. Traps when two keys are equal; use
    ///   ``init(checkedUniqueKeysWithValues:)`` to throw instead.
    /// - Complexity: O(*n* log *n*).
    @inlinable
    public init(uniqueKeysWithValues keysAndValues: some Sequence<(Key, Value)>) {
        do throws(DuplicateKey) {
            _root = try Self._sortedRoot(keysAndValues) { _, _ throws(DuplicateKey) in throw DuplicateKey() }
        } catch {
            preconditionFailure("Duplicate keys")
        }
    }

    /// The dictionary of `keysAndValues`, throwing instead of trapping when two keys are equal.
    ///
    /// - Throws: `DuplicateKey` when two keys are equal.
    /// - Complexity: O(*n* log *n*).
    @inlinable
    public init(checkedUniqueKeysWithValues keysAndValues: some Sequence<(Key, Value)>) throws(DuplicateKey) {
        _root = try Self._sortedRoot(keysAndValues) { _, _ throws(DuplicateKey) in throw DuplicateKey() }
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
        _root = try Self._sortedRoot(keysAndValues, combine: combine)
    }

    /// Sorts the pairs by key, the position breaking ties, merges equal keys with `combine`, and
    /// builds a balanced tree.
    @inlinable
    static func _sortedRoot<E: Error>(
        _ keysAndValues: some Sequence<(Key, Value)>,
        combine: (Value, Value) throws(E) -> Value
    ) throws(E) -> _PersistentNode<Key, Value>? {
        let pairs = ContiguousArray(keysAndValues)
        var order = Array(pairs.indices)
        order.sort { a, b in pairs[a].0 < pairs[b].0 || (!(pairs[b].0 < pairs[a].0) && a < b) }
        var keys = ContiguousArray<Key>()
        var values = ContiguousArray<Value>()
        keys.reserveCapacity(pairs.count)
        values.reserveCapacity(pairs.count)
        for position in order {
            let (key, value) = pairs[position]
            if let last = keys.last, !(last < key) {
                values[values.count &- 1] = try combine(values[values.count &- 1], value)
            } else {
                keys.append(key)
                values.append(value)
            }
        }
        return _PersistentNode.build(keys, values, 0 ..< keys.count)
    }

    /// The value for `key`, or nil when absent; setting nil removes the pair.
    ///
    /// - Complexity: O(log *n*), and O(log *n*) new vertices for a set.
    @inlinable
    public subscript(key: Key) -> Value? {
        get {
            _PersistentNode.find(key, in: _root)?.value
        }
        set {
            if let newValue {
                updateValue(newValue, forKey: key)
            } else {
                removeValue(forKey: key)
            }
        }
    }

    /// The value for `key`, or `defaultValue` when absent; a set stores the value for `key`.
    ///
    /// - Complexity: O(log *n*), and O(log *n*) new vertices for a set.
    @inlinable
    public subscript(key: Key, default defaultValue: @autoclosure () -> Value) -> Value {
        get {
            _PersistentNode.find(key, in: _root)?.value ?? defaultValue()
        }
        set {
            updateValue(newValue, forKey: key)
        }
    }

    /// Stores `value` for `key` and returns the value it replaced, or nil when `key` was absent.
    ///
    /// - Complexity: O(log *n*).
    @inlinable
    @discardableResult
    public mutating func updateValue(_ value: Value, forKey key: Key) -> Value? {
        var existing: _PersistentNode<Key, Value>?
        _root = _PersistentNode.inserting(key, value, into: _root, replacing: true, existing: &existing)
        return existing?.value
    }

    /// Removes the pair for `key` and returns its value, or nil when `key` was absent.
    ///
    /// - Complexity: O(log *n*).
    @inlinable
    @discardableResult
    public mutating func removeValue(forKey key: Key) -> Value? {
        var removed: _PersistentNode<Key, Value>?
        _root = _PersistentNode.removing(key, from: _root, removed: &removed)
        return removed?.value
    }

    /// The dictionary with `value` stored for `key`.
    ///
    /// - Complexity: O(log *n*) time, and O(log *n*) new vertices.
    @inlinable
    public func updatingValue(_ value: Value, forKey key: Key) -> PersistentTreeDictionary {
        var existing: _PersistentNode<Key, Value>?
        return PersistentTreeDictionary(_root: _PersistentNode.inserting(key, value, into: _root, replacing: true, existing: &existing))
    }

    /// The dictionary without the pair for `key`; this dictionary when `key` is absent.
    ///
    /// - Complexity: O(log *n*) time, and O(log *n*) new vertices.
    @inlinable
    public func removingValue(forKey key: Key) -> PersistentTreeDictionary {
        var removed: _PersistentNode<Key, Value>?
        return PersistentTreeDictionary(_root: _PersistentNode.removing(key, from: _root, removed: &removed))
    }

    /// The pairs of both dictionaries, with `combine` of this dictionary's value and `other`'s for
    /// a key in both.
    ///
    /// - Throws: Whatever `combine` throws.
    /// - Complexity: O(*m* log(*n* / *m* + 1)) for dictionaries of *m* ≤ *n* pairs.
    @inlinable
    public func merging<E: Error>(_ other: PersistentTreeDictionary, uniquingKeysWith combine: (Value, Value) throws(E) -> Value) throws(E) -> PersistentTreeDictionary {
        PersistentTreeDictionary(_root: try _PersistentNode.union(_root, other._root, combine: combine))
    }

    /// The index of the pair for `key`, or nil when absent. O(log *n*).
    @inlinable
    public func index(forKey key: Key) -> Index? {
        let rank = _PersistentNode.rank(of: key, in: _root, orEqual: false)
        guard rank < count, let root = _root, !(key < _PersistentNode.node(atRank: rank, in: root).key) else { return nil }
        return Index(_rank: rank)
    }

    /// The index of the first pair whose key is not less than `key`. O(log *n*).
    @inlinable
    public func lowerBound(_ key: Key) -> Index {
        Index(_rank: _PersistentNode.rank(of: key, in: _root, orEqual: false))
    }

    /// The index of the first pair whose key is greater than `key`. O(log *n*).
    @inlinable
    public func upperBound(_ key: Key) -> Index {
        Index(_rank: _PersistentNode.rank(of: key, in: _root, orEqual: true))
    }

    /// The pairs whose keys are in `range`, in ascending key order. O(log *n*).
    @inlinable
    public func elements(in range: Range<Key>) -> Slice<PersistentTreeDictionary> {
        self[lowerBound(range.lowerBound) ..< lowerBound(range.upperBound)]
    }

    /// The pairs whose keys are in `range`, in ascending key order. O(log *n*).
    @inlinable
    public func elements(in range: ClosedRange<Key>) -> Slice<PersistentTreeDictionary> {
        self[lowerBound(range.lowerBound) ..< upperBound(range.upperBound)]
    }

    /// Removes and returns the pair at `index`.
    ///
    /// - Parameter index: Traps unless it is a valid index; use ``remove(checkedAt:)`` to throw
    ///   instead.
    /// - Complexity: O(log *n*).
    @inlinable
    @discardableResult
    public mutating func remove(at index: Index) -> Element {
        let element = self[index]
        removeValue(forKey: element.key)
        return element
    }

    /// Removes and returns the pair at `index`, throwing instead of trapping on an invalid index.
    ///
    /// - Throws: ``IndexOutOfRange`` unless `index` is a valid index; the dictionary is unchanged.
    /// - Complexity: O(log *n*).
    @inlinable
    @discardableResult
    public mutating func remove(checkedAt index: Index) throws(IndexOutOfRange) -> Element {
        guard index._rank >= 0 && index._rank < count else { throw IndexOutOfRange() }
        return remove(at: index)
    }

    /// The pair at `position`, throwing instead of trapping on an invalid index.
    ///
    /// - Throws: ``IndexOutOfRange`` unless `position` is a valid index.
    /// - Complexity: O(log *n*).
    @inlinable
    public subscript(checked position: Index) -> Element {
        get throws(IndexOutOfRange) {
            guard position._rank >= 0 && position._rank < count, let root = _root else { throw IndexOutOfRange() }
            let node = _PersistentNode.node(atRank: position._rank, in: root)
            return (node.key, node.value)
        }
    }
}

extension PersistentTreeDictionary: RandomAccessCollection {
    public typealias Element = (key: Key, value: Value)
    public typealias Indices = Range<Index>
    public typealias SubSequence = Slice<PersistentTreeDictionary>

    /// A position in the dictionary: the rank of a pair by key. A version's indices stay valid
    /// for that version; another version's ranks shift after its edits.
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
    @inlinable public var endIndex: Index { Index(_rank: count) }
    @inlinable public var count: Int { _root?.size ?? 0 }
    @inlinable public var isEmpty: Bool { _root == nil }

    /// The pair at `position`, the one with the `position`-th smallest key.
    ///
    /// - Parameter position: Traps unless it is a valid index; use ``subscript(checked:)`` to
    ///   throw instead.
    /// - Complexity: O(log *n*).
    @inlinable
    public subscript(position: Index) -> Element {
        guard position._rank >= 0 && position._rank < count, let root = _root else {
            preconditionFailure("Index out of range")
        }
        let node = _PersistentNode.node(atRank: position._rank, in: root)
        return (node.key, node.value)
    }

    /// An iterator over the pairs in ascending key order: O(*n*) for the whole pass, O(log *n*)
    /// extra space.
    @frozen
    public struct Iterator: IteratorProtocol {
        @usableFromInline var _nodes: _PersistentNode<Key, Value>.InorderNodes

        @inlinable
        init(_ root: _PersistentNode<Key, Value>?) {
            _nodes = _PersistentNode.InorderNodes(root)
        }

        @inlinable
        public mutating func next() -> Element? {
            _nodes.next()?._withUnsafeGuaranteedRef { ($0.key, $0.value) }
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_root)
    }
}

extension PersistentTreeDictionary: ExpressibleByDictionaryLiteral {
    /// The dictionary of the literal's pairs. Traps when two keys are equal. O(*n* log *n*).
    @inlinable
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(uniqueKeysWithValues: elements)
    }
}

extension PersistentTreeDictionary: Equatable where Value: Equatable {
    /// Whether two dictionaries hold equal keys with equal values, whatever their shapes; O(1)
    /// for versions that share their root, O(*n*) otherwise.
    @inlinable
    public static func == (lhs: PersistentTreeDictionary, rhs: PersistentTreeDictionary) -> Bool {
        if lhs._root === rhs._root { return true }
        return lhs.count == rhs.count && lhs.elementsEqual(rhs) { $0.key == $1.key && $0.value == $1.value }
    }
}

extension PersistentTreeDictionary: Hashable where Key: Hashable, Value: Hashable {
    /// Hashes the count and the pairs in ascending key order. O(*n*).
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for (key, value) in self {
            hasher.combine(key)
            hasher.combine(value)
        }
    }
}

extension PersistentTreeDictionary: Encodable where Key: Encodable, Value: Encodable {
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

extension PersistentTreeDictionary: Decodable where Key: Decodable, Value: Decodable {
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
            self.init(_root: try Self._sortedRoot(pairs) { _, _ throws(DuplicateKey) in throw DuplicateKey() })
        } catch {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Duplicate keys")
        }
    }
}

extension PersistentTreeDictionary: Sendable where Key: Sendable, Value: Sendable {}
extension PersistentTreeDictionary.Iterator: Sendable where Key: Sendable, Value: Sendable {}

extension PersistentTreeDictionary: CustomStringConvertible {
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
