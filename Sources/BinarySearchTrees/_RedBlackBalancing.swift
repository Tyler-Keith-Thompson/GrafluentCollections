/// Red–black balancing (Guibas and Sedgewick, 1978): each vertex is red (record 1) or black
/// (record 0), the root is black, no red vertex has a red child, and every path from the root to
/// an empty link passes the same number of black vertices, so the height stays at most
/// 2 log₂(*n* + 1). The repairs are the classical ones (Cormen, Leiserson, Rivest and Stein,
/// *Introduction to Algorithms*, chapter 13), driven from the recorded path instead of parent
/// links: an insertion recolours up the path and rotates at most twice, a removal at most three
/// times.
@usableFromInline
package enum _RedBlackBalancing: _TreeBalancing {
    @inlinable
    static var red: Int32 { 1 }

    @inlinable
    static var black: Int32 { 0 }

    @inlinable
    package static var leafBalance: Int32 { red }

    /// Black everywhere but the deepest level, which a middle-split tree fills only in part: every
    /// empty link hangs from the last two levels, so every path passes the same number of black
    /// vertices. The root is black even when it is the only level.
    @inlinable
    package static func balance(subtreeHeight: Int32, depth: Int32, treeHeight: Int32) -> Int32 {
        depth > 0 && depth == treeHeight &- 1 ? red : black
    }

    @inlinable @inline(__always)
    static func _isRed<Key>(_ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>, _ x: Int32) -> Bool {
        x >= 0 && nodes[Int(x)].balance == red
    }

    @inlinable
    static func _rotateLeft<Key>(_ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>, _ x: Int32) -> Int32 {
        let right = nodes[Int(x)].right
        nodes[Int(x)].right = nodes[Int(right)].left
        nodes[Int(right)].left = x
        nodes[Int(right)].size = nodes[Int(x)].size
        _Tree.updateSize(nodes, x)
        return right
    }

    @inlinable
    static func _rotateRight<Key>(_ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>, _ x: Int32) -> Int32 {
        let left = nodes[Int(x)].left
        nodes[Int(x)].left = nodes[Int(left)].right
        nodes[Int(left)].right = x
        nodes[Int(left)].size = nodes[Int(x)].size
        _Tree.updateSize(nodes, x)
        return left
    }

    /// Rotates `x` down away from its `right` (or left) side, lifting the child on that side.
    @inlinable @inline(__always)
    static func _rotate<Key>(_ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>, _ x: Int32, liftingRight right: Bool) -> Int32 {
        right ? _rotateLeft(nodes, x) : _rotateRight(nodes, x)
    }

    @inlinable
    package static func afterInsert<Key>(
        _ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>,
        _ path: UnsafeMutableBufferPointer<Int32>,
        _ wentRight: UnsafeMutableBufferPointer<Bool>,
        _ depth: Int,
        inserted slot: Int32
    ) -> Int32 {
        guard depth > 0 else {
            nodes[Int(slot)].balance = black
            return slot
        }
        _Tree.hang(nodes, path[depth &- 1], right: wentRight[depth &- 1], slot)
        var k = 0
        while k < depth {
            nodes[Int(path[k])].size &+= 1
            k &+= 1
        }
        var root = path[0]
        // `i` is the depth of the red vertex whose parent, path[i − 1], may also be red.
        var i = depth
        while i >= 2 && _isRed(nodes, path[i &- 1]) {
            let parent = path[i &- 1]
            let grandparent = path[i &- 2]
            let parentIsRight = wentRight[i &- 2]
            let uncle = parentIsRight ? nodes[Int(grandparent)].left : nodes[Int(grandparent)].right
            if _isRed(nodes, uncle) {
                nodes[Int(parent)].balance = black
                nodes[Int(uncle)].balance = black
                nodes[Int(grandparent)].balance = red
                i &-= 2
                continue
            }
            if wentRight[i &- 1] != parentIsRight {
                // The inner grandchild: rotate it up into the parent's place first.
                let lifted = _rotate(nodes, parent, liftingRight: !parentIsRight)
                _Tree.hang(nodes, grandparent, right: parentIsRight, lifted)
            }
            let top = _rotate(nodes, grandparent, liftingRight: parentIsRight)
            nodes[Int(top)].balance = black
            nodes[Int(grandparent)].balance = red
            if i >= 3 {
                _Tree.hang(nodes, path[i &- 3], right: wentRight[i &- 3], top)
            } else {
                root = top
            }
            break
        }
        nodes[Int(root)].balance = black
        return root
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
        guard depth > 0 else {
            if child >= 0 { nodes[Int(child)].balance = black }
            return child
        }
        _Tree.hang(nodes, path[depth &- 1], right: wentRight[depth &- 1], child)
        var k = 0
        while k < depth {
            nodes[Int(path[k])].size &-= 1
            k &+= 1
        }
        var root = path[0]
        if nodes[Int(removed)].balance == red { return root }
        if _isRed(nodes, child) {
            nodes[Int(child)].balance = black
            return root
        }
        // `x`, at depth `i` below path[i − 1], is short one black vertex; −1 when it is empty.
        var x = child
        var i = depth
        while i > 0 {
            let parent = path[i &- 1]
            let xIsRight = wentRight[i &- 1]
            var sibling = xIsRight ? nodes[Int(parent)].left : nodes[Int(parent)].right
            if _isRed(nodes, sibling) {
                // Rotate the red sibling above the parent, so `x` gets a black sibling; the path
                // grows by that vertex.
                nodes[Int(sibling)].balance = black
                nodes[Int(parent)].balance = red
                let top = _rotate(nodes, parent, liftingRight: !xIsRight)
                if i >= 2 {
                    _Tree.hang(nodes, path[i &- 2], right: wentRight[i &- 2], top)
                } else {
                    root = top
                }
                path[i &- 1] = top
                wentRight[i &- 1] = xIsRight
                path[i] = parent
                wentRight[i] = xIsRight
                i &+= 1
                sibling = xIsRight ? nodes[Int(parent)].left : nodes[Int(parent)].right
            }
            let near = xIsRight ? nodes[Int(sibling)].right : nodes[Int(sibling)].left
            let far = xIsRight ? nodes[Int(sibling)].left : nodes[Int(sibling)].right
            if !_isRed(nodes, near) && !_isRed(nodes, far) {
                nodes[Int(sibling)].balance = red
                if nodes[Int(parent)].balance == red {
                    nodes[Int(parent)].balance = black
                    return root
                }
                x = parent
                i &-= 1
                continue
            }
            if !_isRed(nodes, far) {
                // The near nephew is red: rotate it above the sibling, so the far one is red.
                nodes[Int(near)].balance = black
                nodes[Int(sibling)].balance = red
                sibling = _rotate(nodes, sibling, liftingRight: xIsRight)
                _Tree.hang(nodes, parent, right: !xIsRight, sibling)
            }
            let farNephew = xIsRight ? nodes[Int(sibling)].left : nodes[Int(sibling)].right
            nodes[Int(sibling)].balance = nodes[Int(parent)].balance
            nodes[Int(parent)].balance = black
            nodes[Int(farNephew)].balance = black
            let top = _rotate(nodes, parent, liftingRight: !xIsRight)
            if i >= 2 {
                _Tree.hang(nodes, path[i &- 2], right: wentRight[i &- 2], top)
            } else {
                root = top
            }
            return root
        }
        if x >= 0 { nodes[Int(x)].balance = black }
        return root
    }
}
