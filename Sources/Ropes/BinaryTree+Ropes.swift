import Trees

extension BinaryTree where Vertex == Int {
    /// The shape of a rope: its chunks as vertices, numbered in sequence order, so an in-order
    /// traversal visits them from the first chunk to the last; nil when the rope is empty.
    ///
    /// - Parameter rope: The rope whose shape is converted. Its elements are not read.
    /// - Complexity: O(*m*) for *m* chunks.
    @inlinable
    public init?<Element>(_ rope: Rope<Element>) {
        guard rope._root >= 0 else { return nil }
        // Each slot's position in sequence order.
        var ordinals = [Int](repeating: -1, count: rope._nodes.count)
        var slots = Rope<Element>._ChunkSlots(rope._nodes, root: rope._root)
        var next = 0
        while let slot = slots.next() {
            ordinals[Int(slot)] = next
            next += 1
        }
        var bySlot = [Int32](repeating: -1, count: next)
        for (slot, ordinal) in ordinals.enumerated() where ordinal >= 0 {
            bySlot[ordinal] = Int32(slot)
        }
        let nodes = rope._nodes
        let shape = BinaryTree(root: ordinals[Int(rope._root)]) { vertex in
            let node = nodes[Int(bySlot[vertex])]
            return (node.left >= 0 ? ordinals[Int(node.left)] : nil,
                    node.right >= 0 ? ordinals[Int(node.right)] : nil)
        }
        guard let shape else {
            preconditionFailure("A rope's chunks form a binary tree")
        }
        self = shape
    }
}
