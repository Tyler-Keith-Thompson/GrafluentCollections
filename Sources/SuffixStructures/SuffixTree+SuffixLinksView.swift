import GraphProtocols

extension SuffixTree {
    /// The tree's suffix links as a directed graph: a vertex per node, and an edge from each
    /// internal node but the root to the node whose path label is its own without the first
    /// symbol.
    ///
    /// The view reads the tree's storage and builds nothing. O(1).
    @inlinable
    public var suffixLinksView: SuffixLinksView { SuffixLinksView(self) }

    /// A suffix tree's suffix links as a directed graph; see ``SuffixTree/suffixLinksView``.
    ///
    /// `vertices` is the tree's ``SuffixTree/nodes``, and `edges` lists the suffix links by
    /// source in preorder. An edge's position is its source node, so the root's and the leaves'
    /// positions are skipped.
    @frozen
    public struct SuffixLinksView: DirectedGraph {
        @usableFromInline let _tree: SuffixTree

        @inlinable
        init(_ tree: SuffixTree) {
            _tree = tree
        }

        /// Every suffix link, by source in preorder.
        @frozen
        public struct Edges: Collection {
            @usableFromInline let _tree: SuffixTree

            @inlinable
            init(_ tree: SuffixTree) {
                _tree = tree
            }

            /// The first internal node at or after `node` other than the root, or the node count.
            @inlinable
            func _linked(from node: Int) -> Int {
                var node = node
                while node < _tree._nodes.count && (node == 0 || _tree._nodes.isLeaf(node)) {
                    node &+= 1
                }
                return node
            }

            @inlinable public var startIndex: Int { _linked(from: 1) }
            @inlinable public var endIndex: Int { _tree._nodes.count }

            @inlinable
            public func index(after position: Int) -> Int { _linked(from: position &+ 1) }

            @inlinable
            public subscript(position: Int) -> DirectedEdge<Int> {
                precondition(position > 0 && position < _tree._nodes.count && !_tree._nodes.isLeaf(position), "Edge position out of range")
                return DirectedEdge(from: position, to: Int(_tree._nodes.suffixLinks[position]))
            }
        }

        @inlinable
        public var vertices: Range<Int> { _tree.nodes }

        @inlinable
        public var edges: Edges { Edges(_tree) }

        @inlinable
        public var vertexCount: Int { _tree.nodeCount }

        @inlinable
        public func contains(_ vertex: Int) -> Bool {
            vertex >= 0 && vertex < _tree.nodeCount
        }

        /// The node the vertex's suffix link leads to, or nothing for the root, a leaf or a vertex
        /// not in the graph.
        @inlinable
        public func successors(of vertex: Int) -> [Int] {
            outEdges(of: vertex).map { Int(_tree._nodes.suffixLinks[$0]) }
        }

        /// The position of the vertex's suffix link, which is the vertex itself, or nothing for
        /// the root, a leaf or a vertex not in the graph.
        @inlinable
        public func outEdges(of vertex: Int) -> [Int] {
            guard vertex > 0 && vertex < _tree.nodeCount && !_tree._nodes.isLeaf(vertex) else { return [] }
            return [vertex]
        }
    }
}

extension SuffixTree.SuffixLinksView: Sendable where Symbol: Sendable {}
extension SuffixTree.SuffixLinksView.Edges: Sendable where Symbol: Sendable {}
