import Trees

extension Arborescence where Vertex == Int {
    /// The update tree of a Fenwick tree: the cells an `add` touches, as paths to one root.
    ///
    /// Vertex `k` below `tree.count` is cell `k`, and its parent is the next cell an add at `k`
    /// reaches, `k | (k + 1)`. The cells whose next step lands past the end hang from one more
    /// vertex, `tree.count`, which stands for the end and is the root. An empty tree gives the
    /// root alone.
    ///
    /// - Parameter tree: The Fenwick tree whose shape is converted. Its values are not read.
    /// - Complexity: O(*n*).
    @inlinable
    public init<Element>(_ tree: FenwickTree<Element>) {
        let count = tree.count
        var parents = [Int?](repeating: nil, count: count &+ 1)
        var k = 0
        while k < count {
            parents[k] = Swift.min(k | (k &+ 1), count)
            k &+= 1
        }
        guard let arborescence = Arborescence(parents: parents) else {
            preconditionFailure("A Fenwick tree's update tree has one root")
        }
        self = arborescence
    }
}
