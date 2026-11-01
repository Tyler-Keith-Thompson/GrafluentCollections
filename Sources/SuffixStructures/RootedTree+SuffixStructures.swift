import Trees

extension RootedTree where Vertex == Int {
    /// The shape of a suffix tree: a vertex per node, numbered as the tree numbers them, the root
    /// at 0, with the tree's parent links. Edge labels stay with the suffix tree
    /// (``SuffixTree/edgeLabel(of:)``).
    ///
    /// - Parameter tree: The suffix tree whose shape is converted.
    /// - Complexity: O(*n*) for *n* nodes.
    @inlinable
    public init<Symbol: Hashable>(_ tree: SuffixTree<Symbol>) {
        let parents = tree._nodes.parents.map { $0 < 0 ? nil : Int($0) }
        guard let shape = RootedTree(parents: parents) else {
            preconditionFailure("A suffix tree's nodes form one tree")
        }
        self = shape
    }
}
