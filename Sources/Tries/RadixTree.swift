@_exported import CollectionErrors

/// A set of sequences kept in a radix tree (Morrison, 1968): a trie in which every chain of
/// vertices with one child and no key is merged into one edge labelled with all its symbols.
///
/// It holds the same keys and answers the same queries as ``RadixTree``, with the same names, but has
/// a vertex per key and per branching point rather than per symbol: O(*n*) vertices for *n* keys,
/// however long they are. That suits keys with long shared prefixes, such as file paths or URLs.
/// Lookup, insertion and removal follow the key down from the root, O(*m* + *d*·*σ*) for a key of
/// *m* symbols that passes *d* vertices of at most *σ* children.
///
/// ```swift
/// let paths = RadixTree(["/usr/bin", "/usr/lib", "/usr/local/bin"])
/// paths.contains("/usr/lib")                                   // true
/// paths.elements(withPrefix: "/usr/l").map { String($0) }      // ["/usr/lib", "/usr/local/bin"]
/// paths.longestPrefix(of: "/usr/bin/swift").map { String($0) } // "/usr/bin"
/// ```
///
/// Iteration visits each key before the keys it is a prefix of. When the symbols are
/// `Comparable`, each vertex keeps its children sorted, so the keys come in lexicographic order;
/// otherwise children come in the order they were first added.
///
/// The vertices live in flat arrays with `Int32` links, and the edge labels are slices of one
/// buffer of symbols, so the tree holds fewer than 2³¹ − 1 vertices and label symbols, and copying
/// it copies a few arrays only when one copy is mutated.
@frozen
public struct RadixTree<Symbol: Hashable> {
    @usableFromInline
    package var _core: _RadixCore<Symbol, Void>

    /// An empty tree.
    @inlinable
    public init() {
        _core = _RadixCore()
    }

    /// The tree holding the distinct keys of `keys`.
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

    /// Whether the tree holds no keys. O(1).
    @inlinable
    public var isEmpty: Bool { _core.count == 0 }

    /// Whether the tree holds `key`. O(*m* + *d*·*σ*) for a key of *m* symbols.
    @inlinable
    public func contains(_ key: some Sequence<Symbol>) -> Bool {
        _core.value(forKey: key) != nil
    }

    /// Whether some key starts with `prefix`; for the empty prefix, whether the tree holds any
    /// key. O(*m* + *d*·*σ*).
    @inlinable
    public func hasPrefix(_ prefix: some Sequence<Symbol>) -> Bool {
        let vertex = _core.vertex(for: prefix)
        return vertex >= 0 && _core.counts[Int(vertex)] > 0
    }

    /// The keys that start with `prefix`, `prefix` itself included when the tree holds it, in
    /// iteration order.
    ///
    /// - Parameter prefix: The prefix.
    /// - Returns: A view of those keys; its `count` is O(1).
    /// - Complexity: O(*m* + *d*·*σ*) to find the prefix.
    @inlinable
    public func elements(withPrefix prefix: some Sequence<Symbol>) -> PrefixView {
        PrefixView(_core, vertex: _core.vertex(for: prefix))
    }

    /// The longest key that is a prefix of `query`, `query` itself included, or nil when no key
    /// is. O(*m* + *d*·*σ*), plus the length of the key returned.
    @inlinable
    public func longestPrefix(of query: some Sequence<Symbol>) -> [Symbol]? {
        let vertex = _core.longestKeyVertex(along: query)
        return vertex < 0 ? nil : _core.key(of: vertex)
    }

    /// Inserts `key` unless the tree holds it.
    ///
    /// - Returns: Whether it was inserted, and the key, as the tree stores it.
    /// - Complexity: O(*m* + *d*·*σ*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func insert(_ key: some Sequence<Symbol>) -> (inserted: Bool, memberAfterInsert: [Symbol]) {
        let (inserted, vertex) = _core.insert(key, ())
        return (inserted, _core.key(of: vertex))
    }

    /// Removes `key`, and the vertices left with no key below them.
    ///
    /// - Returns: The key removed, or nil when the tree doesn't hold it.
    /// - Complexity: O(*m* + *d*·*σ*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: some Sequence<Symbol>) -> [Symbol]? {
        let symbols = Array(key)
        return _core.removeValue(forKey: symbols) == nil ? nil : symbols
    }
}

extension RadixTree {
    /// The keys of a tree that start with a prefix, read from the tree's storage; see
    /// ``RadixTree/elements(withPrefix:)``.
    @frozen
    public struct PrefixView: Sequence {
        @usableFromInline let _core: _RadixCore<Symbol, Void>
        @usableFromInline let _vertex: Int32

        @inlinable
        init(_ core: _RadixCore<Symbol, Void>, vertex: Int32) {
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

    /// An iterator over a tree's keys, each before the keys it is a prefix of: O(1) per vertex,
    /// plus a copy of each key.
    @frozen
    public struct Iterator: IteratorProtocol {
        @usableFromInline var _preorder: _RadixCore<Symbol, Void>.Preorder

        @inlinable
        init(_ core: _RadixCore<Symbol, Void>, from vertex: Int32) {
            _preorder = _RadixCore.Preorder(core, from: vertex)
        }

        @inlinable
        public mutating func next() -> [Symbol]? {
            _preorder.next()?.key
        }
    }
}

extension RadixTree: Sequence {
    @inlinable
    public var underestimatedCount: Int { _core.count }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_core, from: 0)
    }
}

extension RadixTree: SetAlgebra {
    /// Whether the tree holds `member`. O(*m* + *d*·*σ*).
    @inlinable
    public func contains(_ member: [Symbol]) -> Bool {
        _core.value(forKey: member) != nil
    }

    /// Inserts `newMember` unless the tree holds it.
    ///
    /// - Returns: Whether it was inserted, and the key equal to it afterwards.
    /// - Complexity: O(*m* + *d*·*σ*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func insert(_ newMember: [Symbol]) -> (inserted: Bool, memberAfterInsert: [Symbol]) {
        (_core.insert(newMember, ()).inserted, newMember)
    }

    /// Inserts `newMember`.
    ///
    /// - Returns: `newMember` when the tree already held it, nil when it was added.
    /// - Complexity: O(*m* + *d*·*σ*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func update(with newMember: [Symbol]) -> [Symbol]? {
        _core.insert(newMember, ()).inserted ? nil : newMember
    }

    /// Removes `member`, and the vertices left with no key below them.
    ///
    /// - Returns: The key removed, or nil when the tree doesn't hold it.
    /// - Complexity: O(*m* + *d*·*σ*), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func remove(_ member: [Symbol]) -> [Symbol]? {
        _core.removeValue(forKey: member) == nil ? nil : member
    }

    /// The keys of either tree. O(*L*·*σ*) for *L* symbols in `other`'s keys.
    @inlinable
    public func union(_ other: RadixTree) -> RadixTree {
        var result = self
        result.formUnion(other)
        return result
    }

    /// The keys of both trees. O(*L*·*σ*) for *L* symbols in this tree's keys.
    @inlinable
    public func intersection(_ other: RadixTree) -> RadixTree {
        var result = RadixTree()
        for key in self where other.contains(key) {
            _ = result._core.insert(key, ())
        }
        return result
    }

    /// The keys of exactly one of the trees. O(*L*·*σ*) for *L* symbols in both trees' keys.
    @inlinable
    public func symmetricDifference(_ other: RadixTree) -> RadixTree {
        var result = RadixTree()
        for key in self where !other.contains(key) {
            _ = result._core.insert(key, ())
        }
        for key in other where !contains(key) {
            _ = result._core.insert(key, ())
        }
        return result
    }

    /// The keys of this tree that are not in `other`. O(*L*·*σ*) for *L* symbols in this tree's
    /// keys.
    @inlinable
    public func subtracting(_ other: RadixTree) -> RadixTree {
        var result = RadixTree()
        for key in self where !other.contains(key) {
            _ = result._core.insert(key, ())
        }
        return result
    }

    /// Adds the keys of `other`. O(*L*·*σ*) for *L* symbols in `other`'s keys.
    @inlinable
    public mutating func formUnion(_ other: RadixTree) {
        for key in other {
            _ = _core.insert(key, ())
        }
    }

    /// Keeps only the keys also in `other`. O(*L*·*σ*).
    @inlinable
    public mutating func formIntersection(_ other: RadixTree) {
        self = intersection(other)
    }

    /// Keeps the keys of exactly one of the trees. O(*L*·*σ*).
    @inlinable
    public mutating func formSymmetricDifference(_ other: RadixTree) {
        self = symmetricDifference(other)
    }

    /// Removes the keys also in `other`. O(*L*·*σ*).
    @inlinable
    public mutating func subtract(_ other: RadixTree) {
        for key in other {
            _ = _core.removeValue(forKey: key)
        }
    }
}

extension RadixTree: ExpressibleByArrayLiteral {
    /// The tree holding the literal's distinct keys. O(*L*·*σ*).
    @inlinable
    public init(arrayLiteral keys: [Symbol]...) {
        self.init(keys)
    }
}

extension RadixTree: Equatable {
    /// Whether two trees hold the same keys, whatever order their children were added in.
    /// O(*L*·*σ*).
    @inlinable
    public static func == (lhs: RadixTree, rhs: RadixTree) -> Bool {
        lhs.count == rhs.count && lhs.allSatisfy { rhs.contains($0) }
    }
}

extension RadixTree: Hashable {
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

extension RadixTree: Encodable where Symbol: Encodable {
    /// Encodes the keys in iteration order as an unkeyed container of arrays. O(*L*).
    @inlinable
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for key in self {
            try container.encode(key)
        }
    }
}

extension RadixTree: Decodable where Symbol: Decodable {
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

extension RadixTree: Sendable where Symbol: Sendable {}
extension RadixTree.Iterator: Sendable where Symbol: Sendable {}
extension RadixTree.PrefixView: Sendable where Symbol: Sendable {}

extension RadixTree: CustomStringConvertible {
    /// The keys in iteration order, written as an array of arrays.
    public var description: String {
        Array(self).description
    }
}
