@_exported import CollectionErrors

/// A dictionary keyed by sequences, kept in a trie: a tree whose edges carry symbols and whose
/// root-to-vertex paths spell the keys, each key's vertex holding its value (Fredkin, 1960).
///
/// Keys are sequences of `Hashable` symbols, stored as `[Symbol]`. Lookup, insertion and removal
/// follow the key down from the root, O(*m*·*σ*) for a key of *m* symbols and at most *σ*
/// children per vertex. Like ``Trie``, it answers prefix queries: every entry whose key has a
/// prefix, whether any key has one, and the entry whose key is the longest prefix of a query.
///
/// ```swift
/// var routes: TrieDictionary<Character, String> = [:]
/// routes["/"] = "home"
/// routes["/users"] = "user list"
/// routes.longestPrefix(of: "/users/42")?.value   // "user list"
/// routes.elements(withPrefix: "/u").count         // 1
/// ```
///
/// Iteration visits each entry before the entries whose keys extend its key: in lexicographic
/// order of the keys when the symbols are `Comparable`, children in the order they were first
/// added otherwise.
///
/// The vertices live in flat arrays with `Int32` links, so the dictionary holds fewer than
/// 2³¹ − 1 vertices, and copying it copies a few arrays only when one copy is mutated.
@frozen
public struct TrieDictionary<Symbol: Hashable, Value> {
    @usableFromInline
    package var _core: _TrieCore<Symbol, Value>

    /// An empty dictionary.
    @inlinable
    public init() {
        _core = _TrieCore()
    }

    /// The dictionary of `keysAndValues`, whose keys must be distinct.
    ///
    /// - Parameter keysAndValues: The entries, in any order. Traps on a repeated key; use
    ///   ``init(checkedUniqueKeysWithValues:)`` to throw instead.
    /// - Complexity: O(*L*·*σ*) for *L* symbols in all.
    @inlinable
    public init<Entries: Sequence, Key: Sequence>(uniqueKeysWithValues keysAndValues: Entries)
    where Entries.Element == (Key, Value), Key.Element == Symbol {
        self.init()
        for (key, value) in keysAndValues {
            precondition(_core.insert(key, value).inserted, "Duplicate key")
        }
    }

    /// The dictionary of `keysAndValues`, throwing instead of trapping on a repeated key.
    ///
    /// - Parameter keysAndValues: The entries, in any order.
    /// - Throws: `DuplicateKey` when two entries have equal keys.
    /// - Complexity: O(*L*·*σ*) for *L* symbols in all.
    @inlinable
    public init<Entries: Sequence, Key: Sequence>(checkedUniqueKeysWithValues keysAndValues: Entries) throws(DuplicateKey)
    where Entries.Element == (Key, Value), Key.Element == Symbol {
        self.init()
        for (key, value) in keysAndValues {
            guard _core.insert(key, value).inserted else { throw DuplicateKey() }
        }
    }

    /// The dictionary of `keysAndValues`, combining the values of equal keys with `combine`.
    ///
    /// - Parameters:
    ///   - keysAndValues: The entries, in any order.
    ///   - combine: Called with the value so far and the next value of a repeated key; returns
    ///     the value to keep.
    /// - Throws: What `combine` throws.
    /// - Complexity: O(*L*·*σ*) for *L* symbols in all.
    @inlinable
    public init<Entries: Sequence, Key: Sequence, E: Error>(
        _ keysAndValues: Entries,
        uniquingKeysWith combine: (Value, Value) throws(E) -> Value
    ) throws(E) where Entries.Element == (Key, Value), Key.Element == Symbol {
        self.init()
        for (key, value) in keysAndValues {
            let (inserted, vertex) = _core.insert(key, value)
            if !inserted, let existing = _core.values[Int(vertex)] {
                _core.values[Int(vertex)] = try combine(existing, value)
            }
        }
    }

    /// The number of entries. O(1).
    @inlinable
    public var count: Int { _core.count }

    /// Whether the dictionary holds no entries. O(1).
    @inlinable
    public var isEmpty: Bool { _core.count == 0 }

    /// The value of `key`, or nil when absent; setting nil removes the entry.
    ///
    /// - Complexity: O(*m*·*σ*) for a key of *m* symbols, plus O(*n*) for a write when the
    ///   storage is shared with another copy.
    @inlinable
    public subscript<Key: Sequence>(key: Key) -> Value? where Key.Element == Symbol {
        get { _core.value(forKey: key) }
        set {
            if let newValue {
                _ = _core.updateValue(newValue, forKey: key)
            } else {
                _ = _core.removeValue(forKey: key)
            }
        }
    }

    /// The value of `key`, or `defaultValue` when absent; setting stores the value.
    ///
    /// - Complexity: O(*m*·*σ*), plus O(*n*) for a write when the storage is shared.
    @inlinable
    public subscript<Key: Sequence>(key: Key, default defaultValue: @autoclosure () -> Value) -> Value where Key.Element == Symbol {
        get { _core.value(forKey: key) ?? defaultValue() }
        set { _ = _core.updateValue(newValue, forKey: key) }
    }

    /// Stores `value` for `key`.
    ///
    /// - Returns: The value replaced, or nil when the key was added.
    /// - Complexity: O(*m*·*σ*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func updateValue(_ value: Value, forKey key: some Sequence<Symbol>) -> Value? {
        _core.updateValue(value, forKey: key)
    }

    /// Removes the entry for `key`, and the vertices left with no key below them.
    ///
    /// - Returns: The value removed, or nil when the key was absent.
    /// - Complexity: O(*m*·*σ*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func removeValue(forKey key: some Sequence<Symbol>) -> Value? {
        _core.removeValue(forKey: key)
    }

    /// Whether some key starts with `prefix`; for the empty prefix, whether the dictionary holds
    /// any entry. O(*m*·*σ*).
    @inlinable
    public func hasPrefix(_ prefix: some Sequence<Symbol>) -> Bool {
        let vertex = _core.vertex(for: prefix)
        return vertex >= 0 && _core.counts[Int(vertex)] > 0
    }

    /// The entries whose keys start with `prefix`, `prefix`'s own entry included, in iteration
    /// order.
    ///
    /// - Parameter prefix: The prefix.
    /// - Returns: A view of those entries; its `count` is O(1).
    /// - Complexity: O(*m*·*σ*) to find the prefix.
    @inlinable
    public func elements(withPrefix prefix: some Sequence<Symbol>) -> PrefixView {
        PrefixView(_core, vertex: _core.vertex(for: prefix))
    }

    /// The entry whose key is the longest prefix of `query`, `query` itself included, or nil
    /// when no key is. O(*m*·*σ*), plus the length of the key returned.
    @inlinable
    public func longestPrefix(of query: some Sequence<Symbol>) -> Element? {
        let vertex = _core.longestKeyVertex(along: query)
        guard vertex >= 0, let value = _core.values[Int(vertex)] else { return nil }
        return (_core.key(of: vertex), value)
    }
}

extension TrieDictionary {
    /// The entries of a dictionary whose keys start with a prefix, read from the dictionary's
    /// storage; see ``TrieDictionary/elements(withPrefix:)``.
    @frozen
    public struct PrefixView: Sequence {
        @usableFromInline let _core: _TrieCore<Symbol, Value>
        @usableFromInline let _vertex: Int32

        @inlinable
        init(_ core: _TrieCore<Symbol, Value>, vertex: Int32) {
            _core = core
            _vertex = vertex
        }

        /// The number of entries with the prefix. O(1).
        @inlinable
        public var count: Int { _vertex < 0 ? 0 : Int(_core.counts[Int(_vertex)]) }

        /// Whether no key has the prefix. O(1).
        @inlinable
        public var isEmpty: Bool { count == 0 }

        @inlinable
        public var underestimatedCount: Int { count }

        @inlinable
        public func makeIterator() -> Iterator {
            Iterator(_core, from: _vertex)
        }
    }

    /// An iterator over a dictionary's entries, each before the entries whose keys extend its
    /// key: O(1) per vertex, plus a copy of each key.
    @frozen
    public struct Iterator: IteratorProtocol {
        @usableFromInline var _preorder: _TrieCore<Symbol, Value>.Preorder

        @inlinable
        init(_ core: _TrieCore<Symbol, Value>, from vertex: Int32) {
            _preorder = _TrieCore.Preorder(core, from: vertex)
        }

        @inlinable
        public mutating func next() -> Element? {
            _preorder.next()
        }
    }
}

extension TrieDictionary: Sequence {
    public typealias Element = (key: [Symbol], value: Value)

    @inlinable
    public var underestimatedCount: Int { _core.count }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_core, from: 0)
    }
}

extension TrieDictionary: ExpressibleByDictionaryLiteral {
    /// The dictionary of the literal's entries, whose keys must be distinct. O(*L*·*σ*).
    @inlinable
    public init(dictionaryLiteral elements: ([Symbol], Value)...) {
        self.init(uniqueKeysWithValues: elements)
    }
}

extension TrieDictionary: Equatable where Value: Equatable {
    /// Whether two dictionaries hold the same entries, whatever order their children were added
    /// in. O(*L*·*σ*).
    @inlinable
    public static func == (lhs: TrieDictionary, rhs: TrieDictionary) -> Bool {
        lhs.count == rhs.count && lhs.allSatisfy { rhs._core.value(forKey: $0.key) == $0.value }
    }
}

extension TrieDictionary: Hashable where Value: Hashable {
    /// Hashes the count and the entries, independently of their order. O(*L*).
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        var combined = 0
        for (key, value) in self {
            var entryHasher = Hasher()
            entryHasher.combine(key)
            entryHasher.combine(value)
            combined &+= entryHasher.finalize()
        }
        hasher.combine(combined)
    }
}

extension TrieDictionary: Encodable where Symbol: Encodable, Value: Encodable {
    /// Encodes the entries in iteration order as an unkeyed container of keys and values,
    /// alternating, as `Dictionary` encodes a key that is not a string. O(*L*).
    @inlinable
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for (key, value) in self {
            try container.encode(key)
            try container.encode(value)
        }
    }
}

extension TrieDictionary: Decodable where Symbol: Decodable, Value: Decodable {
    /// Decodes alternating keys and values from an unkeyed container.
    ///
    /// - Throws: `DecodingError.dataCorrupted` on a repeated key or a key without a value.
    /// - Complexity: O(*L*·*σ*).
    @inlinable
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.init()
        while !container.isAtEnd {
            let key = try container.decode([Symbol].self)
            guard !container.isAtEnd else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "A key without a value")
            }
            let value = try container.decode(Value.self)
            guard _core.insert(key, value).inserted else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "A repeated key")
            }
        }
    }
}

extension TrieDictionary: Sendable where Symbol: Sendable, Value: Sendable {}
extension TrieDictionary.Iterator: Sendable where Symbol: Sendable, Value: Sendable {}
extension TrieDictionary.PrefixView: Sendable where Symbol: Sendable, Value: Sendable {}

extension TrieDictionary: CustomStringConvertible {
    /// The entries in iteration order, written as an array of key–value pairs.
    public var description: String {
        Array(self).description
    }
}
