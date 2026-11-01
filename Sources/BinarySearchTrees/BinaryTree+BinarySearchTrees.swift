import Trees

extension BinaryTree where Vertex: Comparable {
    /// The shape of an AVL tree: its elements as vertices, each with the same left and right
    /// children as in the tree; nil when the tree is empty.
    ///
    /// Its `height` counts edges, one less than the AVL tree's, which counts vertices.
    ///
    /// - Parameter tree: The AVL tree whose shape is converted.
    /// - Complexity: O(*n*).
    @inlinable
    public init?(_ tree: AVLTree<Vertex>) {
        self.init(_tree: tree._core)
    }

    /// The shape of a red–black tree: its elements as vertices, each with the same left and right
    /// children as in the tree; nil when the tree is empty. The colours are not part of the shape.
    ///
    /// - Parameter tree: The red–black tree whose shape is converted.
    /// - Complexity: O(*n*).
    @inlinable
    public init?(_ tree: RedBlackTree<Vertex>) {
        self.init(_tree: tree._core)
    }

    /// The shape of a treap: its elements as vertices, each with the same left and right children
    /// as in the treap; nil when the treap is empty. The priorities are not part of the shape.
    ///
    /// - Parameter tree: The treap whose shape is converted.
    /// - Complexity: O(*n*).
    @inlinable
    public init?(_ tree: Treap<Vertex>) {
        self.init(_tree: tree._core)
    }

    /// The shape of a splay tree: its elements as vertices, each with the same left and right
    /// children as in the tree; nil when the tree is empty. Reading the shape doesn't splay.
    ///
    /// - Parameter tree: The splay tree whose shape is converted.
    /// - Complexity: O(*n*).
    @inlinable
    public init?(_ tree: SplayTree<Vertex>) {
        self.init(_tree: tree._core)
    }

    /// The shape of an AVL dictionary: its keys as vertices, each with the same left and right
    /// children as in the tree; nil when the dictionary is empty.
    ///
    /// Its `height` counts edges, one less than the dictionary's, which counts vertices.
    ///
    /// - Parameter dictionary: The AVL dictionary whose shape is converted.
    /// - Complexity: O(*n*).
    @inlinable
    public init?<Value>(_ dictionary: AVLDictionary<Vertex, Value>) {
        self.init(_tree: dictionary._core)
    }

    /// The vertices are listed in level order, root first, so the shape's vertex order doesn't
    /// depend on where the core happens to keep each node. A breadth-first walk over the slots
    /// numbers them; a vertex's children then sit at the next two free numbers, so the child
    /// tables are filled in the same pass, with no key compared.
    @inlinable
    init?<Value, Balancing>(_tree core: _TreeCore<Vertex, Value, Balancing>) {
        guard core.root >= 0 else { return nil }
        let count = core.count
        var order = ContiguousArray<Int32>()
        order.reserveCapacity(count)
        order.append(core.root)
        var left = [Int?](repeating: nil, count: count)
        var right = [Int?](repeating: nil, count: count)
        core.nodes.withUnsafeBufferPointer { nodes in
            var index = 0
            while index < order.count {
                let node = nodes[Int(order[index])]
                if node.left >= 0 {
                    left[index] = order.count
                    order.append(node.left)
                }
                if node.right >= 0 {
                    right[index] = order.count
                    order.append(node.right)
                }
                index &+= 1
            }
        }
        let tree = BinaryTree(vertices: order.lazy.map { core.key(at: $0) }, left: left, right: right)
        guard let tree else {
            preconditionFailure("A search tree's keys are distinct and its links form one tree")
        }
        self = tree
    }
}
