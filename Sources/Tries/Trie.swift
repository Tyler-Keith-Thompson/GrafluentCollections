@_exported import CollectionErrors

/// A set of sequences kept in a trie: a tree whose edges carry symbols and whose root-to-vertex
/// paths spell the keys (Fredkin, 1960).
///
/// Keys are sequences of `Hashable` symbols, stored as `[Symbol]`: `Trie<Character>` holds words,
/// `Trie<Unicode.Scalar>` the same words scalar by scalar, `Trie<UInt8>` byte strings. Lookup,
/// insertion and removal follow the key down from the root, O(*m*·*σ*) for a key of *m* symbols
/// and at most *σ* children per vertex. A trie answers the queries a hash set cannot: every key
/// with a prefix, whether any key has one, and the longest key that is a prefix of a query.
///
/// ```swift
/// let words = Trie(["car", "cart", "cat", "dog"])
/// words.contains("cat")                                   // true
/// words.elements(withPrefix: "car").map { String($0) }    // ["car", "cart"]
/// words.longestPrefix(of: "carton").map { String($0) }    // "cart"
/// ```
///
/// Iteration visits each key before the keys it is a prefix of. When the symbols are
/// `Comparable`, each vertex keeps its children sorted, so the keys come in lexicographic order;
/// otherwise children come in the order they were first added.
///
/// The vertices live in flat arrays with `Int32` links, so the trie holds fewer than 2³¹ − 1
/// vertices, and copying it copies a few arrays only when one copy is mutated.
@frozen
public struct Trie<Symbol: Hashable> {
    @usableFromInline
    package var _core: _TrieCore<Symbol, Void>

    /// An empty trie.
    @inlinable
    public init() {
        _core = _TrieCore()
    }

    /// The trie holding the distinct keys of `keys`.
    ///
    /// - Parameter keys: The keys, in any order.
    /// - Complexity: O(*L*·*σ*) for *L* symbols in all.
    @inlinable
    public init<Keys: Sequence>(_ keys: Keys) where Keys.Element: Sequence, Keys.Element.Element == Symbol {
        self.init()
        for key in keys {
            _ = _core.insert(key, ())
        }
    }

    /// The number of keys. O(1).
    @inlinable
    public var count: Int { _core.count }

    /// Whether the trie holds no keys. O(1).
    @inlinable
    public var isEmpty: Bool { _core.count == 0 }

    /// Whether the trie holds `key`. O(*m*·*σ*) for a key of *m* symbols.
    @inlinable
    public func contains(_ key: some Sequence<Symbol>) -> Bool {
        _core.value(forKey: key) != nil
    }

    /// Whether some key starts with `prefix`; for the empty prefix, whether the trie holds any
    /// key. O(*m*·*σ*).
    @inlinable
    public func hasPrefix(_ prefix: some Sequence<Symbol>) -> Bool {
        let vertex = _core.vertex(for: prefix)
        return vertex >= 0 && _core.counts[Int(vertex)] > 0
    }

    /// The keys that start with `prefix`, `prefix` itself included when the trie holds it, in
    /// iteration order.
    ///
    /// - Parameter prefix: The prefix.
    /// - Returns: A view of those keys; its `count` is O(1).
    /// - Complexity: O(*m*·*σ*) to find the prefix.
    @inlinable
    public func elements(withPrefix prefix: some Sequence<Symbol>) -> PrefixView {
        PrefixView(_core, vertex: _core.vertex(for: prefix))
    }

    /// The longest key that is a prefix of `query`, `query` itself included, or nil when no key
    /// is. O(*m*·*σ*), plus the length of the key returned.
    @inlinable
    public func longestPrefix(of query: some Sequence<Symbol>) -> [Symbol]? {
        let vertex = _core.longestKeyVertex(along: query)
        return vertex < 0 ? nil : _core.key(of: vertex)
    }

    /// Inserts `key` unless the trie holds it.
    ///
    /// - Returns: Whether it was inserted, and the key, as the trie stores it.
    /// - Complexity: O(*m*·*σ*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func insert(_ key: some Sequence<Symbol>) -> (inserted: Bool, memberAfterInsert: [Symbol]) {
        let (inserted, vertex) = _core.insert(key, ())
        return (inserted, _core.key(of: vertex))
    }

    /// Removes `key`, and the vertices left with no key below them.
    ///
    /// - Returns: The key removed, or nil when the trie doesn't hold it.
    /// - Complexity: O(*m*·*σ*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: some Sequence<Symbol>) -> [Symbol]? {
        let symbols = Array(key)
        return _core.removeValue(forKey: symbols) == nil ? nil : symbols
    }
}

extension Trie {
    /// The keys of a trie that start with a prefix, read from the trie's storage; see
    /// ``Trie/elements(withPrefix:)``.
    @frozen
    public struct PrefixView: Sequence {
        @usableFromInline let _core: _TrieCore<Symbol, Void>
        @usableFromInline let _vertex: Int32

        @inlinable
        init(_ core: _TrieCore<Symbol, Void>, vertex: Int32) {
            _core = core
            _vertex = vertex
        }

        /// The number of keys with the prefix. O(1).
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

    /// An iterator over a trie's keys, each before the keys it is a prefix of: O(1) per vertex,
    /// plus a copy of each key.
    @frozen
    public struct Iterator: IteratorProtocol {
        @usableFromInline var _preorder: _TrieCore<Symbol, Void>.Preorder

        @inlinable
        init(_ core: _TrieCore<Symbol, Void>, from vertex: Int32) {
            _preorder = _TrieCore.Preorder(core, from: vertex)
        }

        @inlinable
        public mutating func next() -> [Symbol]? {
            _preorder.next()?.key
        }
    }
}

extension Trie: Sequence {
    @inlinable
    public var underestimatedCount: Int { _core.count }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_core, from: 0)
    }
}

extension Trie: SetAlgebra {
    /// Whether the trie holds `member`. O(*m*·*σ*).
    @inlinable
    public func contains(_ member: [Symbol]) -> Bool {
        _core.value(forKey: member) != nil
    }

    /// Inserts `newMember` unless the trie holds it.
    ///
    /// - Returns: Whether it was inserted, and the key equal to it afterwards.
    /// - Complexity: O(*m*·*σ*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func insert(_ newMember: [Symbol]) -> (inserted: Bool, memberAfterInsert: [Symbol]) {
        (_core.insert(newMember, ()).inserted, newMember)
    }

    /// Inserts `newMember`.
    ///
    /// - Returns: `newMember` when the trie already held it, nil when it was added.
    /// - Complexity: O(*m*·*σ*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func update(with newMember: [Symbol]) -> [Symbol]? {
        _core.insert(newMember, ()).inserted ? nil : newMember
    }

    /// Removes `member`, and the vertices left with no key below them.
    ///
    /// - Returns: The key removed, or nil when the trie doesn't hold it.
    /// - Complexity: O(*m*·*σ*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func remove(_ member: [Symbol]) -> [Symbol]? {
        _core.removeValue(forKey: member) == nil ? nil : member
    }

    /// The keys of either trie. O(*L*·*σ*) for *L* symbols in `other`'s keys.
    @inlinable
    public func union(_ other: Trie) -> Trie {
        var result = self
        result.formUnion(other)
        return result
    }

    /// The keys of both tries. O(*L*·*σ*) for *L* symbols in this trie's keys.
    @inlinable
    public func intersection(_ other: Trie) -> Trie {
        var result = Trie()
        for key in self where other.contains(key) {
            _ = result._core.insert(key, ())
        }
        return result
    }

    /// The keys of exactly one of the tries. O(*L*·*σ*) for *L* symbols in both tries' keys.
    @inlinable
    public func symmetricDifference(_ other: Trie) -> Trie {
        var result = Trie()
        for key in self where !other.contains(key) {
            _ = result._core.insert(key, ())
        }
        for key in other where !contains(key) {
            _ = result._core.insert(key, ())
        }
        return result
    }

    /// The keys of this trie that are not in `other`. O(*L*·*σ*) for *L* symbols in this trie's
    /// keys.
    @inlinable
    public func subtracting(_ other: Trie) -> Trie {
        var result = Trie()
        for key in self where !other.contains(key) {
            _ = result._core.insert(key, ())
        }
        return result
    }

    /// Adds the keys of `other`. O(*L*·*σ*) for *L* symbols in `other`'s keys.
    @inlinable
    public mutating func formUnion(_ other: Trie) {
        for key in other {
            _ = _core.insert(key, ())
        }
    }

    /// Keeps only the keys also in `other`. O(*L*·*σ*).
    @inlinable
    public mutating func formIntersection(_ other: Trie) {
        self = intersection(other)
    }

    /// Keeps the keys of exactly one of the tries. O(*L*·*σ*).
    @inlinable
    public mutating func formSymmetricDifference(_ other: Trie) {
        self = symmetricDifference(other)
    }

    /// Removes the keys also in `other`. O(*L*·*σ*).
    @inlinable
    public mutating func subtract(_ other: Trie) {
        for key in other {
            _ = _core.removeValue(forKey: key)
        }
    }
}

extension Trie: ExpressibleByArrayLiteral {
    /// The trie holding the literal's distinct keys. O(*L*·*σ*).
    @inlinable
    public init(arrayLiteral keys: [Symbol]...) {
        self.init(keys)
    }
}

extension Trie: Equatable {
    /// Whether two tries hold the same keys, whatever order their children were added in.
    /// O(*L*·*σ*).
    @inlinable
    public static func == (lhs: Trie, rhs: Trie) -> Bool {
        lhs.count == rhs.count && lhs.allSatisfy { rhs.contains($0) }
    }
}

extension Trie: Hashable {
    /// Hashes the count and the keys, independently of their order. O(*L*).
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        var combined = 0
        for key in self {
            var keyHasher = Hasher()
            keyHasher.combine(key)
            combined &+= keyHasher.finalize()
        }
        hasher.combine(combined)
    }
}

extension Trie: Encodable where Symbol: Encodable {
    /// Encodes the keys in iteration order as an unkeyed container of arrays. O(*L*).
    @inlinable
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for key in self {
            try container.encode(key)
        }
    }
}

extension Trie: Decodable where Symbol: Decodable {
    /// Decodes the keys from an unkeyed container of arrays, in any order. O(*L*·*σ*).
    @inlinable
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.init()
        while !container.isAtEnd {
            _ = _core.insert(try container.decode([Symbol].self), ())
        }
    }
}

extension Trie: Sendable where Symbol: Sendable {}
extension Trie.Iterator: Sendable where Symbol: Sendable {}
extension Trie.PrefixView: Sendable where Symbol: Sendable {}

extension Trie: CustomStringConvertible {
    /// The keys in iteration order, written as an array of arrays.
    public var description: String {
        Array(self).description
    }
}
