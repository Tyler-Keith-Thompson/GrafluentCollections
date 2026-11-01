import Trees

extension Arborescence {
    /// The shape of a radix tree: a vertex per vertex of the tree, standing for the prefix it
    /// spells, so the root is the empty prefix and each edge's label is the child's prefix past
    /// its parent's. Vertices are listed in the tree's iteration order.
    ///
    /// - Parameter tree: The radix tree whose shape is converted.
    /// - Complexity: O(*P*) expected, for *P* symbols in all the vertices' prefixes.
    @inlinable
    public init<Symbol: Hashable>(_ tree: RadixTree<Symbol>) where Vertex == [Symbol] {
        self.init(_radix: tree._core)
    }

    /// The shape of a radix-tree dictionary, as ``Arborescence/init(_:)-(RadixTree<Symbol>)``
    /// gives a radix tree's.
    ///
    /// - Parameter dictionary: The dictionary whose shape is converted.
    /// - Complexity: O(*P*) expected, for *P* symbols in all the vertices' prefixes.
    @inlinable
    public init<Symbol: Hashable, Value>(_ dictionary: RadixTreeDictionary<Symbol, Value>) where Vertex == [Symbol] {
        self.init(_radix: dictionary._core)
    }

    /// Lists the vertices' prefixes in preorder, children in chain order.
    @inlinable
    init<Symbol: Hashable, Value>(_radix core: _RadixCore<Symbol, Value>) where Vertex == [Symbol] {
        var order: [[Symbol]] = []
        var parents: [[Symbol]: [Symbol]] = [:]
        order.reserveCapacity(core.vertexCount)
        var stack: [(vertex: Int32, prefix: [Symbol])] = [(0, [])]
        while let (vertex, prefix) = stack.popLast() {
            order.append(prefix)
            var children: [Int32] = []
            var child = core.firstChildren[Int(vertex)]
            while child >= 0 {
                children.append(child)
                child = core.nextSiblings[Int(child)]
            }
            for child in children.reversed() {
                let start = Int(core.labelStarts[Int(child)])
                let childPrefix = prefix + core.labels[start ..< start + Int(core.labelLengths[Int(child)])]
                parents[childPrefix] = prefix
                stack.append((child, childPrefix))
            }
        }
        guard let tree = Arborescence(vertices: order, parent: { parents[$0] }) else {
            preconditionFailure("A radix tree's vertices form one tree")
        }
        self = tree
    }
}
