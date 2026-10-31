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

    /// `BinaryTree(root:children:)` asks for each vertex's children level by level, so the
    /// slots are queued in the same order and each answer is a lookup of the next one; a key
    /// asked out of that order is found by a search instead.
    @inlinable
    init?<Value, Balancing>(_tree core: _TreeCore<Vertex, Value, Balancing>) {
        guard core.root >= 0 else { return nil }
        var queue = ContiguousArray<Int32>()
        queue.reserveCapacity(core.count)
        queue.append(core.root)
        var cursor = 0
        let tree = BinaryTree(root: core.key(at: core.root)) { vertex in
            var slot = cursor < queue.count ? queue[cursor] : -1
            if slot < 0 || core.key(at: slot) != vertex {
                slot = core.slot(of: vertex)
            }
            cursor &+= 1
            let left = core.nodes[Int(slot)].left
            let right = core.nodes[Int(slot)].right
            if left >= 0 { queue.append(left) }
            if right >= 0 { queue.append(right) }
            return (left >= 0 ? core.key(at: left) : nil, right >= 0 ? core.key(at: right) : nil)
        }
        guard let tree else {
            preconditionFailure("A search tree's keys are distinct")
        }
        self = tree
    }
}
