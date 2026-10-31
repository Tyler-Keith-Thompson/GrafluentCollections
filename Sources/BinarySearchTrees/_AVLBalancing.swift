/// AVL balancing (Adelson-Velsky and Landis, 1962): each vertex records its height in vertices,
/// and the heights of its two subtrees differ by at most one. Every vertex on the path is
/// rebalanced on the way back up, with one or two rotations where the difference reaches two.
@usableFromInline
package enum _AVLBalancing: _TreeBalancing {
    @inlinable
    package static var leafBalance: Int32 { 1 }

    @inlinable
    package static func balance(subtreeHeight: Int32, depth: Int32, treeHeight: Int32) -> Int32 {
        subtreeHeight
    }

    @inlinable
    package static func afterInsert<Key>(
        _ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>,
        _ path: UnsafeMutableBufferPointer<Int32>,
        _ wentRight: UnsafeMutableBufferPointer<Bool>,
        _ depth: Int,
        inserted slot: Int32
    ) -> Int32 {
        _rebalancePath(nodes, path, wentRight, depth, child: slot)
    }

    @inlinable
    package static func afterRemove<Key>(
        _ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>,
        _ path: UnsafeMutableBufferPointer<Int32>,
        _ wentRight: UnsafeMutableBufferPointer<Bool>,
        _ depth: Int,
        child: Int32,
        removed: Int32
    ) -> Int32 {
        _rebalancePath(nodes, path, wentRight, depth, child: child)
    }

    /// The height of the tree whose root is `root`: the root's record. O(1).
    @inlinable
    static func height<Key>(_ nodes: ContiguousArray<_TreeNode<Key>>, root: Int32) -> Int {
        root < 0 ? 0 : Int(nodes[Int(root)].balance)
    }

    @inlinable @inline(__always)
    static func _height<Key>(_ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>, _ x: Int32) -> Int32 {
        x < 0 ? 0 : nodes[Int(x)].balance
    }

    /// Recomputes `x`'s height and size from its children's.
    @inlinable @inline(__always)
    static func _update<Key>(_ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>, _ x: Int32) {
        let left = nodes[Int(x)].left
        let right = nodes[Int(x)].right
        nodes[Int(x)].balance = Swift.max(_height(nodes, left), _height(nodes, right)) &+ 1
        nodes[Int(x)].size = _Tree.size(nodes, left) &+ _Tree.size(nodes, right) &+ 1
    }

    @inlinable
    static func _rotateRight<Key>(_ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>, _ x: Int32) -> Int32 {
        let left = nodes[Int(x)].left
        nodes[Int(x)].left = nodes[Int(left)].right
        nodes[Int(left)].right = x
        _update(nodes, x)
        _update(nodes, left)
        return left
    }

    @inlinable
    static func _rotateLeft<Key>(_ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>, _ x: Int32) -> Int32 {
        let right = nodes[Int(x)].right
        nodes[Int(x)].right = nodes[Int(right)].left
        nodes[Int(right)].left = x
        _update(nodes, x)
        _update(nodes, right)
        return right
    }

    /// Updates `x` and restores its balance with one or two rotations; returns the subtree's new
    /// root.
    @inlinable
    static func _rebalance<Key>(_ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>, _ x: Int32) -> Int32 {
        _update(nodes, x)
        let left = nodes[Int(x)].left
        let right = nodes[Int(x)].right
        let balance = _height(nodes, left) &- _height(nodes, right)
        if balance > 1 {
            if _height(nodes, nodes[Int(left)].left) < _height(nodes, nodes[Int(left)].right) {
                nodes[Int(x)].left = _rotateLeft(nodes, left)
            }
            return _rotateRight(nodes, x)
        }
        if balance < -1 {
            if _height(nodes, nodes[Int(right)].right) < _height(nodes, nodes[Int(right)].left) {
                nodes[Int(x)].right = _rotateRight(nodes, right)
            }
            return _rotateLeft(nodes, x)
        }
        return x
    }

    /// Hangs `child` where the path ended, then rebalances each vertex of the path from the bottom
    /// up; returns the new root.
    @inlinable
    static func _rebalancePath<Key>(
        _ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>,
        _ path: UnsafeMutableBufferPointer<Int32>,
        _ wentRight: UnsafeMutableBufferPointer<Bool>,
        _ depth: Int,
        child: Int32
    ) -> Int32 {
        var child = child
        var i = depth
        while i > 0 {
            i &-= 1
            let parent = path[i]
            _Tree.hang(nodes, parent, right: wentRight[i], child)
            child = _rebalance(nodes, parent)
        }
        return child
    }
}
