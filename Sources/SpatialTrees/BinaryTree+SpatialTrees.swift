import Trees

extension BinaryTree where Vertex == Int {
    /// The shape of a k-d tree: its points' indices as vertices, the median of the whole set at
    /// the root and the medians of each side below it; nil when the tree is empty.
    ///
    /// A vertex at depth *d* splits its subtree on coordinate *d* mod `Point.scalarCount`: its
    /// left subtree's points have that coordinate at most its own, its right subtree's at least.
    ///
    /// - Parameter tree: The k-d tree whose shape is converted.
    /// - Complexity: O(*n*).
    @inlinable
    public init?<Point>(_ tree: KDTree<Point>) {
        let count = tree.count
        guard count > 0 else { return nil }
        // Each position's children, from the runs the median layout splits it into.
        var left = [Int32](repeating: -1, count: count)
        var right = [Int32](repeating: -1, count: count)
        var runs: [(lower: Int, upper: Int)] = [(0, count)]
        while let run = runs.popLast() {
            let middle = run.lower + (run.upper - run.lower) / 2
            if run.lower < middle {
                left[middle] = Int32(run.lower + (middle - run.lower) / 2)
                runs.append((run.lower, middle))
            }
            if middle + 1 < run.upper {
                right[middle] = Int32(middle + 1 + (run.upper - middle - 1) / 2)
                runs.append((middle + 1, run.upper))
            }
        }
        let indices = tree._indices
        let positions = tree._positions
        let shape = BinaryTree(root: Int(indices[count / 2])) { vertex in
            let position = Int(positions[vertex])
            return (left[position] >= 0 ? Int(indices[Int(left[position])]) : nil,
                    right[position] >= 0 ? Int(indices[Int(right[position])]) : nil)
        }
        guard let shape else {
            preconditionFailure("A k-d tree's median layout forms a binary tree")
        }
        self = shape
    }
}
