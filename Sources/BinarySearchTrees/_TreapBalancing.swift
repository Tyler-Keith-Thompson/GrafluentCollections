/// Treap balancing (Seidel and Aragon, 1996): each vertex records a random priority, and no vertex
/// has a higher priority than its parent. The shape is then the binary search tree that inserting
/// the keys in descending priority order would build, a random one whatever order the keys came
/// in, so a vertex's expected depth is O(log *n*). Every mutation works top-down from the root by
/// splitting and joining subtrees, so none records a path.
@usableFromInline
package enum _TreapBalancing {}

/// The priorities of a treap's vertices: SplitMix64 (Steele, Lea and Flood, 2014), seeded once
/// from the treap's random number generator and kept in the treap, so a copy draws the same
/// priorities as its original.
@frozen
@usableFromInline
package struct _TreapPriorities: RandomNumberGenerator, Sendable {
    @usableFromInline var state: UInt64

    @inlinable
    init(seed: UInt64) {
        state = seed
    }

    @inlinable
    init(using generator: inout some RandomNumberGenerator) {
        state = generator.next()
    }

    /// The next SplitMix64 output.
    @inlinable
    package mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// The next priority: the high half of the next output.
    @inlinable
    mutating func nextPriority() -> Int32 {
        Int32(truncatingIfNeeded: next() >> 32)
    }
}

extension _TreeCore where Balancing == _TreapBalancing {
    /// The treap over keys sorted in strictly ascending order, and their values, with priorities
    /// drawn from `priorities`. Slot `k` holds the `k`-th key. O(*n*).
    ///
    /// Builds the Cartesian tree with a stack of its right spine. While a vertex is on the spine,
    /// its size records the first slot of its subtree; when a later, higher-priority vertex lifts
    /// it off, the subtree ends just before that vertex.
    @inlinable
    init(sortedUniqueKeys keys: ContiguousArray<Key>, values: ContiguousArray<Value>, priorities: inout _TreapPriorities) {
        precondition(keys.count < Int(Int32.max), "A balanced tree holds fewer than 2³¹ − 1 elements")
        self.values = values
        let count = Int32(truncatingIfNeeded: keys.count)
        var nodes = ContiguousArray<_TreeNode<Key>>()
        nodes.reserveCapacity(keys.count)
        for key in keys {
            nodes.append(_TreeNode(key: key, left: -1, right: -1, size: 0, balance: priorities.nextPriority()))
        }
        var spine = ContiguousArray<Int32>()
        spine.reserveCapacity(64)
        nodes.withUnsafeMutableBufferPointer { nodes in
            var i: Int32 = 0
            while i < count {
                var lifted: Int32 = -1
                while let top = spine.last, nodes[Int(top)].balance < nodes[Int(i)].balance {
                    spine.removeLast()
                    nodes[Int(top)].size = i &- nodes[Int(top)].size
                    lifted = top
                }
                nodes[Int(i)].left = lifted
                if let top = spine.last {
                    nodes[Int(top)].right = i
                    nodes[Int(i)].size = top &+ 1
                } else {
                    nodes[Int(i)].size = 0
                }
                spine.append(i)
                i &+= 1
            }
            for top in spine {
                nodes[Int(top)].size = count &- nodes[Int(top)].size
            }
        }
        root = spine.first ?? -1
        self.nodes = nodes
    }

    /// The number of keys below `key` in the subtree rooted at `subtree`. O(depth).
    @inlinable
    static func _countBelow(_ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>, _ subtree: Int32, _ key: Key) -> Int32 {
        var x = subtree
        var below: Int32 = 0
        while x >= 0 {
            if nodes[Int(x)].key < key {
                below &+= _Tree.size(nodes, nodes[Int(x)].left) &+ 1
                x = nodes[Int(x)].right
            } else {
                x = nodes[Int(x)].left
            }
        }
        return below
    }

    /// Splits the subtree rooted at `subtree`, in place, into the keys below `key` and the rest;
    /// returns their roots. O(depth).
    ///
    /// Walks down once: each vertex passed keeps its subtree on the far side of `key` and joins the
    /// lower or upper side, whose next vertex hangs in the link it leaves open. Counting the keys
    /// below `key` first gives every vertex's new size on the way down.
    @inlinable
    static func _split(
        _ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>,
        _ subtree: Int32,
        at key: Key
    ) -> (lower: Int32, upper: Int32) {
        // The number of keys below `key` in the subtree rooted at `x`.
        var below = _countBelow(nodes, subtree, key)
        var lower: Int32 = -1
        var upper: Int32 = -1
        var lowerTail: Int32 = -1
        var upperTail: Int32 = -1
        var x = subtree
        while x >= 0 {
            if nodes[Int(x)].key < key {
                let next = nodes[Int(x)].right
                let nextBelow = below &- _Tree.size(nodes, nodes[Int(x)].left) &- 1
                nodes[Int(x)].size = below
                if lowerTail >= 0 {
                    nodes[Int(lowerTail)].right = x
                } else {
                    lower = x
                }
                lowerTail = x
                x = next
                below = nextBelow
            } else {
                let next = nodes[Int(x)].left
                nodes[Int(x)].size &-= below
                if upperTail >= 0 {
                    nodes[Int(upperTail)].left = x
                } else {
                    upper = x
                }
                upperTail = x
                x = next
            }
        }
        if lowerTail >= 0 { nodes[Int(lowerTail)].right = -1 }
        if upperTail >= 0 { nodes[Int(upperTail)].left = -1 }
        return (lower, upper)
    }

    /// Joins the subtrees rooted at `lower` and `upper`, every key of `lower` below every key of
    /// `upper`; returns the root. O(depth).
    ///
    /// Walks down the right spine of `lower` and the left spine of `upper`, taking the vertex of
    /// higher priority each step; the vertex taken gains the other side's remaining subtree.
    @inlinable
    static func _join(_ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>, _ lower: Int32, _ upper: Int32) -> Int32 {
        var a = lower
        var b = upper
        var root: Int32 = -1
        var parent: Int32 = -1
        var right = false
        while a >= 0 && b >= 0 {
            // The vertex taken keeps its outer subtree; its inner link takes what the join of
            // the rest returns.
            let takesLower = nodes[Int(a)].balance >= nodes[Int(b)].balance
            let top = takesLower ? a : b
            nodes[Int(top)].size &+= takesLower ? nodes[Int(b)].size : nodes[Int(a)].size
            if parent >= 0 {
                _Tree.hang(nodes, parent, right: right, top)
            } else {
                root = top
            }
            parent = top
            right = takesLower
            if takesLower {
                a = nodes[Int(a)].right
            } else {
                b = nodes[Int(b)].left
            }
        }
        let rest = a >= 0 ? a : b
        if parent >= 0 {
            _Tree.hang(nodes, parent, right: right, rest)
        } else {
            root = rest
        }
        return root
    }

    /// Inserts `key` with `value` and `priority` unless an equal key is present.
    ///
    /// Walks down past the vertices of priority at least `priority`, then splits the subtree there
    /// around `key` into the new vertex's children.
    ///
    /// - Returns: Whether it was inserted, and the slot holding the key equal to `key` afterwards.
    /// - Complexity: O(depth), plus O(*n*) when the storage is shared or must grow.
    @inlinable
    mutating func insert(_ key: Key, _ value: Value, priority: Int32) -> (inserted: Bool, slot: Int32) {
        let found = slot(of: key)
        if found >= 0 { return (false, found) }
        precondition(nodes.count < Int(Int32.max) - 1, "A balanced tree holds fewer than 2³¹ − 1 elements")
        let slot = Int32(truncatingIfNeeded: nodes.count)
        nodes.append(_TreeNode(key: key, left: -1, right: -1, size: 1, balance: priority))
        values.append(value)
        let root = self.root
        self.root = nodes.withUnsafeMutableBufferPointer { nodes in
            var parent: Int32 = -1
            var right = false
            var x = root
            while x >= 0 && nodes[Int(x)].balance >= priority {
                nodes[Int(x)].size &+= 1
                parent = x
                right = nodes[Int(x)].key < key
                x = right ? nodes[Int(x)].right : nodes[Int(x)].left
            }
            let children = Self._split(nodes, x, at: key)
            nodes[Int(slot)].left = children.lower
            nodes[Int(slot)].right = children.upper
            nodes[Int(slot)].size = _Tree.size(nodes, children.lower) &+ _Tree.size(nodes, children.upper) &+ 1
            guard parent >= 0 else { return slot }
            _Tree.hang(nodes, parent, right: right, slot)
            return root
        }
        return (true, slot)
    }

    /// Removes `key` and its value, if present. O(depth), plus O(*n*) when the storage is shared.
    @inlinable
    mutating func remove(_ key: Key) -> (key: Key, value: Value)? {
        let found = slot(of: key)
        guard found >= 0 else { return nil }
        return _remove(found)
    }

    /// Removes the key of in-order rank `rank` and its value. O(depth), plus O(*n*) when the
    /// storage is shared.
    ///
    /// - Precondition: `0 <= rank < count`.
    @inlinable
    mutating func remove(atRank rank: Int) -> (key: Key, value: Value) {
        _remove(slot(atRank: rank))
    }

    /// Unlinks the vertex at `found`, joining its children in its place, and moves the last slot
    /// into the freed one.
    @inlinable
    mutating func _remove(_ found: Int32) -> (key: Key, value: Value) {
        let root = self.root
        self.root = nodes.withUnsafeMutableBufferPointer { nodes in
            let key = nodes[Int(found)].key
            var parent: Int32 = -1
            var right = false
            var x = root
            while x != found {
                nodes[Int(x)].size &-= 1
                parent = x
                right = nodes[Int(x)].key < key
                x = right ? nodes[Int(x)].right : nodes[Int(x)].left
            }
            let joined = Self._join(nodes, nodes[Int(found)].left, nodes[Int(found)].right)
            guard parent >= 0 else { return joined }
            _Tree.hang(nodes, parent, right: right, joined)
            return root
        }
        return _discard(found)
    }

    /// Splits the treap into the keys below `key` and the rest.
    ///
    /// Splits the links in place, then copies the smaller side into a treap of its own and moves
    /// the larger side's vertices out of the slots it left.
    ///
    /// - Complexity: O(log *n*) expected for the split, then O(*k* log *n*) expected, where *k* is
    ///   the smaller side's count.
    @inlinable
    consuming func split(at key: Key) -> (lower: _TreeCore, upper: _TreeCore) {
        let root = self.root
        let sides = nodes.withUnsafeMutableBufferPointer { nodes in
            Self._split(nodes, root, at: key)
        }
        let lowerCount = nodes.withUnsafeBufferPointer { nodes in Int(_Tree.size(nodes, sides.lower)) }
        if lowerCount <= count &- lowerCount {
            self.root = sides.upper
            let lower = _extract(sides.lower) { core, slot, hole in core._relink(slot, to: hole) }
            return (lower, self)
        }
        self.root = sides.lower
        let upper = _extract(sides.upper) { core, slot, hole in core._relink(slot, to: hole) }
        return (self, upper)
    }

    /// Joins `other`'s vertices into this treap: every key of `other` is above every key here when
    /// `otherIsUpper`, below it otherwise. Appends `other`'s slots after these. O(*m* + depth) for
    /// *m* vertices of `other`, plus O(*n*) when the storage is shared or must grow.
    @inlinable
    mutating func join(_ other: _TreeCore, otherIsUpper: Bool) {
        let otherRoot = _append(other)
        let root = self.root
        self.root = nodes.withUnsafeMutableBufferPointer { nodes in
            otherIsUpper ? Self._join(nodes, root, otherRoot) : Self._join(nodes, otherRoot, root)
        }
    }
}
