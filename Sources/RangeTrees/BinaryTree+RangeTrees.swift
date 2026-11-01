import BinarySearchTrees
import Trees

extension BinaryTree where Vertex == Int {
    /// The shape of a segment tree: a perfect binary tree with a vertex per cell, nil when the
    /// tree is empty.
    ///
    /// Vertex `k − 1` is cell `k`: vertex 0 is the root, vertex `k`'s children are `2k + 1` and
    /// `2k + 2`, and the leaves, from the left, are the values followed by the padding up to a
    /// power of two. The values are not read.
    ///
    /// - Parameter tree: The segment tree whose shape is converted.
    /// - Complexity: O(*n*).
    @inlinable
    public init?<Operation>(_ tree: SegmentTree<Operation>) {
        guard !tree.isEmpty else { return nil }
        self.init(_perfectWithLeaves: tree._size)
    }

    /// The shape of a lazy segment tree, as for a ``SegmentTree``; nil when the tree is empty.
    ///
    /// - Parameter tree: The lazy segment tree whose shape is converted.
    /// - Complexity: O(*n*).
    @inlinable
    public init?<Action>(_ tree: LazySegmentTree<Action>) {
        guard !tree.isEmpty else { return nil }
        self.init(_perfectWithLeaves: tree._size)
    }

    /// The shape of an interval tree: its in-order positions as vertices, each with the same
    /// left and right children as in the tree; nil when the tree is empty. Vertex `i` stands for
    /// the entry `tree[i]`.
    ///
    /// - Parameter tree: The interval tree whose shape is converted.
    /// - Complexity: O(*n*).
    @inlinable
    public init?<Bound, Value>(_ tree: IntervalTree<Bound, Value>) {
        let core = tree._core
        guard core.root >= 0 else { return nil }
        // Each slot's in-order position, by one in-order walk.
        var positions = [Int](repeating: 0, count: core.count)
        var slots = [Int32](repeating: 0, count: core.count)
        var walk = IntervalTree<Bound, Value>._Core.InorderSlots(core)
        var position = 0
        while let slot = walk.next() {
            positions[Int(slot)] = position
            slots[position] = slot
            position &+= 1
        }
        let rootPosition = positions[Int(core.root)]
        let tree = BinaryTree(root: rootPosition) { vertex in
            let node = core.nodes[Int(slots[vertex])]
            return (node.left >= 0 ? positions[Int(node.left)] : nil, node.right >= 0 ? positions[Int(node.right)] : nil)
        }
        guard let tree else {
            preconditionFailure("An interval tree's vertices form a binary tree")
        }
        self = tree
    }

    /// The perfect binary tree with `leaves` leaves, a power of two, numbered in level order.
    @inlinable
    init(_perfectWithLeaves leaves: Int) {
        let internalCount = leaves &- 1
        let tree = BinaryTree(root: 0) { vertex in
            vertex < internalCount ? (2 &* vertex &+ 1, 2 &* vertex &+ 2) : (nil, nil)
        }
        guard let tree else {
            preconditionFailure("A segment tree's cells form a perfect binary tree")
        }
        self = tree
    }
}
