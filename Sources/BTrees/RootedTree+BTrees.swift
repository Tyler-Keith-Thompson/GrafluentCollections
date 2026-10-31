import Trees

extension RootedTree {
    /// The shape of a B-tree: one vertex per node, the node's elements in ascending order, each
    /// node's children in key order; nil when the tree is empty.
    ///
    /// - Parameter tree: The B-tree whose shape is converted.
    /// - Complexity: O(*n*).
    @inlinable
    public init?<Element: Hashable>(_ tree: BTree<Element>) where Vertex == [Element] {
        self.init(_tree: tree._core)
    }

    /// The shape of a B-tree dictionary: one vertex per node, the node's keys in ascending order,
    /// each node's children in key order; nil when the dictionary is empty.
    ///
    /// - Parameter dictionary: The B-tree dictionary whose shape is converted.
    /// - Complexity: O(*n*).
    @inlinable
    public init?<Key: Hashable, Value>(_ dictionary: BTreeDictionary<Key, Value>) where Vertex == [Key] {
        self.init(_tree: dictionary._core)
    }

    /// Lists the nodes in preorder, children in key order, so `children(of:)` keeps that order.
    @inlinable
    init?<Key: Hashable, Value>(_tree core: _BTreeCore<Key, Value>) where Vertex == [Key] {
        guard core.count > 0 else { return nil }
        var order: [[Key]] = []
        var parents: [[Key]: [Key]] = [:]
        var stack: [(node: _BTreeNode<Key, Value>, parent: [Key]?)] = [(core.root, nil)]
        while let (node, parent) = stack.popLast() {
            var keys: [Key] = []
            keys.reserveCapacity(node.elementCount)
            for index in 0 ..< node.elementCount {
                keys.append(node.key(at: index))
            }
            order.append(keys)
            if let parent { parents[keys] = parent }
            for child in node._header.pointee.children.reversed() {
                stack.append((child, keys))
            }
        }
        guard let tree = RootedTree(vertices: order, parent: { parents[$0] }) else {
            preconditionFailure("A B-tree's nodes form one tree")
        }
        self = tree
    }
}
