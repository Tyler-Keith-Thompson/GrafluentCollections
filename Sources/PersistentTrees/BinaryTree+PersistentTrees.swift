import Trees

extension BinaryTree where Vertex: Comparable {
    /// The shape of one version of a persistent set: its elements as vertices, each with the
    /// same left and right children as in the tree; nil when the set is empty.
    ///
    /// - Parameter set: The version whose shape is converted.
    /// - Complexity: O(*n*).
    @inlinable
    public init?(_ set: PersistentTreeSet<Vertex>) {
        self.init(_root: set._root)
    }

    /// The shape of one version of a persistent dictionary: its keys as vertices, each with the
    /// same left and right children as in the tree; nil when the dictionary is empty.
    ///
    /// - Parameter dictionary: The version whose shape is converted.
    /// - Complexity: O(*n*).
    @inlinable
    public init?<Value>(_ dictionary: PersistentTreeDictionary<Vertex, Value>) {
        self.init(_root: dictionary._root)
    }

    /// `BinaryTree(root:children:)` asks for each vertex's children level by level, so the
    /// vertices are queued in the same order and each answer is the next one in the queue.
    @inlinable
    init?<Value>(_root root: _PersistentNode<Vertex, Value>?) {
        guard let root else { return nil }
        var queue = ContiguousArray<_PersistentNode<Vertex, Value>>()
        queue.reserveCapacity(root.size)
        queue.append(root)
        var cursor = 0
        let tree = BinaryTree(root: root.key) { vertex in
            var node = cursor < queue.count ? queue[cursor] : nil
            if node == nil || node?.key != vertex {
                node = _PersistentNode.find(vertex, in: root)
            }
            cursor &+= 1
            guard let node else { return (nil, nil) }
            if let left = node.left { queue.append(left) }
            if let right = node.right { queue.append(right) }
            return (node.left?.key, node.right?.key)
        }
        guard let tree else {
            preconditionFailure("A search tree's keys are distinct")
        }
        self = tree
    }
}
