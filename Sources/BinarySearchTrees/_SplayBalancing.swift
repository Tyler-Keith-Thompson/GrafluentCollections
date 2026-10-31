/// Splay balancing (Sleator and Tarjan, 1985): no record per vertex. Each mutation, and each
/// `access`, rotates the vertex it reaches to the root by top-down splaying, which halves the
/// depth of every vertex on the way, so a sequence of *m* of them on *n* vertices costs
/// O((*m* + *n*) log *n*) in all. Reads that don't splay cost the vertex's depth, which a run of
/// ascending insertions can make *n*.
@usableFromInline
package enum _SplayBalancing: _BalancedBuild {
    @inlinable
    package static func balance(subtreeHeight: Int32, depth: Int32, treeHeight: Int32) -> Int32 {
        0
    }
}

extension _TreeCore where Balancing == _SplayBalancing {
    /// Splays the subtree rooted at `subtree` at `key`: the vertex holding `key`, or else the last
    /// vertex on the search path for it, becomes the root. Returns the new root. O(depth), and
    /// O(log *n*) amortized.
    ///
    /// Top-down splaying with subtree sizes (Sleator, `top-down-size-splay.c`): the walk down
    /// links the vertices passed into a left tree, of keys below `key`, and a right tree, of keys
    /// above it, rotating once more on each zig-zig step. The left tree's vertices hang down its
    /// right spine in the order they were linked, and the right tree's down its left spine, so a
    /// second walk down each spine sets their sizes from the known totals.
    @inlinable
    static func _splay(_ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>, _ subtree: Int32, at key: Key) -> Int32 {
        guard subtree >= 0 else { return -1 }
        var t = subtree
        // The first vertex linked into each side tree, and the last, whose open link takes the next.
        var leftTop: Int32 = -1
        var rightTop: Int32 = -1
        var leftTail: Int32 = -1
        var rightTail: Int32 = -1
        var leftSize: Int32 = 0
        var rightSize: Int32 = 0
        while true {
            if key < nodes[Int(t)].key {
                var child = nodes[Int(t)].left
                if child < 0 { break }
                if key < nodes[Int(child)].key {
                    // Zig-zig: rotate right at t first.
                    nodes[Int(t)].left = nodes[Int(child)].right
                    nodes[Int(child)].right = t
                    _Tree.updateSize(nodes, t)
                    t = child
                    child = nodes[Int(t)].left
                    if child < 0 { break }
                }
                // Link t into the right tree.
                if rightTail >= 0 {
                    nodes[Int(rightTail)].left = t
                } else {
                    rightTop = t
                }
                rightTail = t
                rightSize &+= 1 &+ _Tree.size(nodes, nodes[Int(t)].right)
                t = child
            } else if nodes[Int(t)].key < key {
                var child = nodes[Int(t)].right
                if child < 0 { break }
                if nodes[Int(child)].key < key {
                    // Zig-zig: rotate left at t first.
                    nodes[Int(t)].right = nodes[Int(child)].left
                    nodes[Int(child)].left = t
                    _Tree.updateSize(nodes, t)
                    t = child
                    child = nodes[Int(t)].right
                    if child < 0 { break }
                }
                // Link t into the left tree.
                if leftTail >= 0 {
                    nodes[Int(leftTail)].right = t
                } else {
                    leftTop = t
                }
                leftTail = t
                leftSize &+= 1 &+ _Tree.size(nodes, nodes[Int(t)].left)
                t = child
            } else {
                break
            }
        }
        leftSize &+= _Tree.size(nodes, nodes[Int(t)].left)
        rightSize &+= _Tree.size(nodes, nodes[Int(t)].right)
        nodes[Int(t)].size = leftSize &+ rightSize &+ 1
        // Each side tree's spine ends where t's own subtree on that side hangs.
        if leftTail >= 0 { nodes[Int(leftTail)].right = nodes[Int(t)].left }
        if rightTail >= 0 { nodes[Int(rightTail)].left = nodes[Int(t)].right }
        var y = leftTop
        var remaining = leftSize
        while y >= 0 {
            nodes[Int(y)].size = remaining
            remaining &-= 1 &+ _Tree.size(nodes, nodes[Int(y)].left)
            y = y == leftTail ? -1 : nodes[Int(y)].right
        }
        y = rightTop
        remaining = rightSize
        while y >= 0 {
            nodes[Int(y)].size = remaining
            remaining &-= 1 &+ _Tree.size(nodes, nodes[Int(y)].right)
            y = y == rightTail ? -1 : nodes[Int(y)].left
        }
        if leftTop >= 0 { nodes[Int(t)].left = leftTop }
        if rightTop >= 0 { nodes[Int(t)].right = rightTop }
        return t
    }

    /// Splays the whole tree at `key`; afterwards the root holds `key` when it is present.
    @inlinable
    mutating func splay(at key: Key) {
        let root = self.root
        self.root = nodes.withUnsafeMutableBufferPointer { nodes in
            Self._splay(nodes, root, at: key)
        }
    }

    /// Splays at `key`, then returns the root's slot when it holds `key`, or −1.
    @inlinable
    mutating func access(_ key: Key) -> Int32 {
        guard root >= 0 else { return -1 }
        splay(at: key)
        let top = nodes[Int(root)].key
        return top < key || key < top ? -1 : root
    }

    /// Inserts `key` with `value` unless an equal key is present, then leaves the key equal to
    /// `key` at the root.
    ///
    /// - Returns: Whether it was inserted, and the slot holding the key equal to `key` afterwards.
    /// - Complexity: O(log *n*) amortized, plus O(*n*) when the storage is shared or must grow.
    @inlinable
    mutating func insert(_ key: Key, _ value: Value) -> (inserted: Bool, slot: Int32) {
        precondition(nodes.count < Int(Int32.max) - 1, "A balanced tree holds fewer than 2³¹ − 1 elements")
        let slot = Int32(truncatingIfNeeded: nodes.count)
        guard root >= 0 else {
            nodes.append(_TreeNode(key: key, left: -1, right: -1, size: 1, balance: 0))
            values.append(value)
            root = slot
            return (true, slot)
        }
        splay(at: key)
        let top = root
        let topKey = nodes[Int(top)].key
        if !(topKey < key) && !(key < topKey) { return (false, top) }
        // The old root and the side of it beyond `key` become the new vertex's children.
        var node = _TreeNode(key: key, left: -1, right: -1, size: nodes[Int(top)].size &+ 1, balance: 0)
        if key < topKey {
            node.left = nodes[Int(top)].left
            node.right = top
            nodes[Int(top)].left = -1
        } else {
            node.right = nodes[Int(top)].right
            node.left = top
            nodes[Int(top)].right = -1
        }
        let moved = key < topKey ? node.left : node.right
        if moved >= 0 { nodes[Int(top)].size &-= nodes[Int(moved)].size }
        nodes.append(node)
        values.append(value)
        root = slot
        return (true, slot)
    }

    /// Removes `key` and its value, if present. O(log *n*) amortized, plus O(*n*) when the
    /// storage is shared.
    @inlinable
    mutating func remove(_ key: Key) -> (key: Key, value: Value)? {
        let found = access(key)
        guard found >= 0 else { return nil }
        return _removeRoot()
    }

    /// Removes the key of in-order rank `rank` and its value. O(log *n*) amortized, plus O(*n*)
    /// when the storage is shared.
    ///
    /// - Precondition: `0 <= rank < count`.
    @inlinable
    mutating func remove(atRank rank: Int) -> (key: Key, value: Value) {
        splay(at: key(at: slot(atRank: rank)))
        return _removeRoot()
    }

    /// Removes the root: splays its left subtree at its key, which lifts the subtree's largest
    /// key to the top with no right child, and hangs the right subtree there. The last slot is
    /// then splayed to the root, so moving it into the freed slot relinks only the root.
    @inlinable
    mutating func _removeRoot() -> (key: Key, value: Value) {
        let found = root
        let key = nodes[Int(found)].key
        root = nodes.withUnsafeMutableBufferPointer { nodes in
            let left = nodes[Int(found)].left
            let right = nodes[Int(found)].right
            guard left >= 0 else { return right }
            let top = Self._splay(nodes, left, at: key)
            nodes[Int(top)].right = right
            nodes[Int(top)].size &+= _Tree.size(nodes, right)
            return top
        }
        let last = Int32(truncatingIfNeeded: nodes.count &- 1)
        if found != last { splay(at: nodes[Int(last)].key) }
        return _discard(found)
    }

    /// Splits the tree into the keys below `key` and the rest, after splaying at `key`.
    ///
    /// Copies the smaller side into a tree of its own, and moves the larger side's vertices out of
    /// the slots it left, splaying each to the root first.
    ///
    /// - Complexity: O(*k* log *n*) amortized, where *k* is the smaller side's count.
    @inlinable
    consuming func split(at key: Key) -> (lower: _TreeCore, upper: _TreeCore) {
        guard root >= 0 else { return (self, _TreeCore()) }
        splay(at: key)
        let top = root
        let topIsLower = nodes[Int(top)].key < key
        let detached: Int32
        if topIsLower {
            detached = nodes[Int(top)].right
            nodes[Int(top)].right = -1
        } else {
            detached = nodes[Int(top)].left
            nodes[Int(top)].left = -1
        }
        let detachedCount = detached < 0 ? 0 : Int(nodes[Int(detached)].size)
        nodes[Int(top)].size &-= Int32(truncatingIfNeeded: detachedCount)
        // `top` and the side it keeps, or the detached side: whichever is smaller is copied out.
        let move: (inout _TreeCore, Int32, Int32) -> Void = { core, slot, hole in
            core.splay(at: core.nodes[Int(slot)].key)
            core.root = hole
        }
        if detachedCount <= count &- detachedCount {
            let copied = _extract(detached, move: move)
            return topIsLower ? (self, copied) : (copied, self)
        }
        root = detached
        let copied = _extract(top, move: move)
        return topIsLower ? (copied, self) : (self, copied)
    }

    /// Joins `other`'s vertices into this tree: every key of `other` is above every key here when
    /// `otherIsUpper`, below it otherwise. Appends `other`'s slots after these, splays the lower
    /// tree at its largest key, which leaves its root with no right child, and hangs the upper
    /// tree there. O(*m* + log *n*) amortized for *m* vertices of `other`, plus O(*n*) when the
    /// storage is shared or must grow.
    @inlinable
    mutating func join(_ other: _TreeCore, otherIsUpper: Bool) {
        let otherRoot = _append(other)
        let lower = otherIsUpper ? root : otherRoot
        let upper = otherIsUpper ? otherRoot : root
        guard lower >= 0 else {
            root = upper
            return
        }
        let largest: Key = nodes.withUnsafeBufferPointer { nodes in
            var x = lower
            while nodes[Int(x)].right >= 0 {
                x = nodes[Int(x)].right
            }
            return nodes[Int(x)].key
        }
        root = nodes.withUnsafeMutableBufferPointer { nodes in
            let top = Self._splay(nodes, lower, at: largest)
            nodes[Int(top)].right = upper
            nodes[Int(top)].size &+= _Tree.size(nodes, upper)
            return top
        }
    }
}
