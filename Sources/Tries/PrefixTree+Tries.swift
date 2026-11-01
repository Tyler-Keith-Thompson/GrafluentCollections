import Trees

extension PrefixTree {
    /// The shape of `trie`: a vertex per prefix of its keys, numbered in the trie's iteration
    /// order with the root, the empty prefix, as 0, and an edge into each vertex labelled with the
    /// symbol it appends. `sequenceEnds` lists the vertex of each key in iteration order.
    ///
    /// - Parameter trie: The trie.
    /// - Complexity: O(*L*) expected for *L* symbols in its keys.
    @inlinable
    public init(_ trie: Trie<Symbol>) {
        self = prefixTree(of: trie)
    }

    /// The shape of `dictionary`'s keys, as ``PrefixTree/init(_:)-(Trie<Symbol>)`` gives a
    /// trie's.
    ///
    /// - Parameter dictionary: The dictionary.
    /// - Complexity: O(*L*) expected for *L* symbols in its keys.
    @inlinable
    public init<Value>(_ dictionary: TrieDictionary<Symbol, Value>) {
        self = prefixTree(of: dictionary.lazy.map(\.key))
    }
}
