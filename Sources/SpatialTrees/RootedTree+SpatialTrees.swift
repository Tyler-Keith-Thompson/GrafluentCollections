import Trees

extension RootedTree where Vertex == Int {
    /// The cells of a quadtree: the whole region at vertex 0, and below each cell that has split
    /// its four quadrants, numbered in breadth-first order. A quadrant's position among its
    /// siblings is its orthant: bit 0 set for the upper *x* half, bit 1 for the upper *y* half.
    ///
    /// - Parameter tree: The quadtree whose cells are converted. Its elements are not read.
    /// - Complexity: O(*c*) for *c* cells.
    @inlinable
    public init<Element>(_ tree: Quadtree<Element>) {
        self.init(_cellParents: tree._core.cellParents())
    }

    /// The cells of an octree, as for a ``Quadtree``: the whole region at vertex 0, and below
    /// each cell that has split its eight octants, numbered in breadth-first order. Bit 2 of an
    /// octant is set for the upper *z* half.
    ///
    /// - Parameter tree: The octree whose cells are converted. Its elements are not read.
    /// - Complexity: O(*c*) for *c* cells.
    @inlinable
    public init<Element>(_ tree: Octree<Element>) {
        self.init(_cellParents: tree._core.cellParents())
    }

    @inlinable
    init(_cellParents parents: [Int?]) {
        guard let tree = RootedTree(parents: parents) else {
            preconditionFailure("A spatial tree's cells form a rooted tree")
        }
        self = tree
    }
}
