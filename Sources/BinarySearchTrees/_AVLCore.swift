/// One vertex of an AVL tree: its key, its children's slots (−1 for none), the number of
/// vertices in its subtree, and its height, counted in vertices (a leaf is 1). The key sits beside
/// the links so a descent reads one array per level.
@frozen
@usableFromInline
package struct _AVLNode<Key> {
    @usableFromInline package var key: Key
    @usableFromInline package var left: Int32
    @usableFromInline package var right: Int32
    @usableFromInline package var size: Int32
    @usableFromInline package var height: Int32

    @inlinable
    init(key: Key, left: Int32, right: Int32, size: Int32, height: Int32) {
        self.key = key
        self.left = left
        self.right = right
        self.size = size
        self.height = height
    }

    /// A vertex with no children.
    @inlinable
    init(leaf key: Key) {
        self.init(key: key, left: -1, right: -1, size: 1, height: 1)
    }
}

extension _AVLNode: Sendable where Key: Sendable {}

/// The storage shared by `AVLTree` and `AVLDictionary`: an AVL tree whose vertices (keys with
/// their links) and values live in two parallel flat arrays indexed by slot, with links as
/// `Int32` slots and −1 for none.
///
/// The slots are always `0 ..< count`: a removal moves the last slot into the hole, so the arrays
/// stay dense. Every subtree records its size, so a vertex's in-order rank is found from the
/// root in O(log *n*). Mutations walk down once, recording the path (at most 64 vertices, since
/// an AVL tree of fewer than 2³¹ vertices is at most 45 high), and rebalance back up it.
@frozen
@usableFromInline
package struct _AVLCore<Key: Comparable, Value> {
    @usableFromInline package var nodes: ContiguousArray<_AVLNode<Key>>
    @usableFromInline package var values: ContiguousArray<Value>
    @usableFromInline package var root: Int32

    /// The longest path a mutation records.
    @inlinable
    static var _pathCapacity: Int { 64 }

    @inlinable
    init() {
        values = []
        nodes = []
        root = -1
    }

    /// The perfectly balanced tree over keys sorted in strictly ascending order, and their values.
    /// Slot `k` holds the `k`-th key. O(*n*).
    @inlinable
    init(sortedUniqueKeys keys: ContiguousArray<Key>, values: ContiguousArray<Value>) {
        precondition(keys.count < Int(Int32.max), "An AVL tree holds fewer than 2³¹ − 1 elements")
        self.values = values
        let count = keys.count
        var nodes = ContiguousArray<_AVLNode<Key>>()
        nodes.reserveCapacity(count)
        for key in keys {
            nodes.append(_AVLNode(leaf: key))
        }
        root = nodes.withUnsafeMutableBufferPointer { nodes in
            Self._build(nodes, 0, count)
        }
        self.nodes = nodes
    }

    /// Links `lo ..< hi` into a balanced subtree rooted at its middle slot. Recurses to the height.
    @inlinable
    static func _build(_ nodes: UnsafeMutableBufferPointer<_AVLNode<Key>>, _ lo: Int, _ hi: Int) -> Int32 {
        guard lo < hi else { return -1 }
        let middle = lo &+ (hi &- lo) / 2
        let left = _build(nodes, lo, middle)
        let right = _build(nodes, middle &+ 1, hi)
        let height = Swift.max(_height(nodes, left), _height(nodes, right)) &+ 1
        nodes[middle].left = left
        nodes[middle].right = right
        nodes[middle].size = Int32(truncatingIfNeeded: hi &- lo)
        nodes[middle].height = height
        return Int32(truncatingIfNeeded: middle)
    }

    @inlinable
    var count: Int { nodes.count }

    /// The key at `slot`.
    @inlinable
    func key(at slot: Int32) -> Key { nodes[Int(slot)].key }

    /// The height in vertices: 0 when empty.
    @inlinable
    var height: Int { root < 0 ? 0 : Int(nodes[Int(root)].height) }

    // MARK: Queries

    /// The slot holding `key`, or −1.
    ///
    /// Descends two ways, remembering the last vertex not less than `key`, and compares for
    /// equality once at the bottom: one comparison per level, which the compiler can turn into
    /// selects rather than branches a random key would mispredict.
    @inlinable
    func slot(of key: Key) -> Int32 {
        nodes.withUnsafeBufferPointer { nodes in
            var x = root
            var candidate: Int32 = -1
            while x >= 0 {
                let goesRight = nodes[Int(x)].key < key
                candidate = goesRight ? candidate : x
                x = goesRight ? nodes[Int(x)].right : nodes[Int(x)].left
            }
            return candidate >= 0 && !(key < nodes[Int(candidate)].key) ? candidate : -1
        }
    }

    /// The in-order rank of `key`, or nil when absent.
    @inlinable
    func rank(of key: Key) -> Int? {
        nodes.withUnsafeBufferPointer { nodes in
            var x = root
            var before = 0
            var candidate: Int32 = -1
            while x >= 0 {
                let goesRight = nodes[Int(x)].key < key
                if goesRight {
                    before &+= Int(Self._size(nodes, nodes[Int(x)].left)) &+ 1
                    x = nodes[Int(x)].right
                } else {
                    candidate = x
                    x = nodes[Int(x)].left
                }
            }
            // `before` counts the keys less than `key`, which is the candidate's rank.
            return candidate >= 0 && !(key < nodes[Int(candidate)].key) ? before : nil
        }
    }

    /// The number of keys below `key`, or with `orEqual`, at most `key`.
    @inlinable
    func countBelow(_ key: Key, orEqual: Bool) -> Int {
        nodes.withUnsafeBufferPointer { nodes in
            var x = root
            var before = 0
            while x >= 0 {
                let candidate = nodes[Int(x)].key
                let right = orEqual ? !(key < candidate) : candidate < key
                if right {
                    before &+= Int(Self._size(nodes, nodes[Int(x)].left)) &+ 1
                    x = nodes[Int(x)].right
                } else {
                    x = nodes[Int(x)].left
                }
            }
            return before
        }
    }

    /// The slot of the vertex of in-order rank `rank`.
    ///
    /// - Precondition: `0 <= rank < count`.
    @inlinable
    func slot(atRank rank: Int) -> Int32 {
        nodes.withUnsafeBufferPointer { nodes in
            var x = root
            var remaining = Int32(truncatingIfNeeded: rank)
            while true {
                let left = nodes[Int(x)].left
                let leftSize = Self._size(nodes, left)
                if remaining < leftSize {
                    x = left
                } else if remaining == leftSize {
                    return x
                } else {
                    remaining &-= leftSize &+ 1
                    x = nodes[Int(x)].right
                }
            }
        }
    }

    /// The slot of the smallest or (with `last`) largest key, or −1 when empty.
    @inlinable
    func extremeSlot(last: Bool) -> Int32 {
        nodes.withUnsafeBufferPointer { nodes in
            var x = root
            guard x >= 0 else { return -1 }
            while true {
                let next = last ? nodes[Int(x)].right : nodes[Int(x)].left
                if next < 0 { return x }
                x = next
            }
        }
    }

    // MARK: Mutations

    /// Inserts `key` with `value` unless an equal key is present.
    ///
    /// - Returns: Whether it was inserted, and the slot holding the key equal to `key` afterwards.
    /// - Complexity: O(log *n*), plus O(*n*) when the storage is shared or must grow.
    @inlinable
    mutating func insert(_ key: Key, _ value: Value) -> (inserted: Bool, slot: Int32) {
        withUnsafeTemporaryAllocation(of: Int32.self, capacity: Self._pathCapacity) { path in
            withUnsafeTemporaryAllocation(of: Bool.self, capacity: Self._pathCapacity) { wentRight in
                var depth = 0
                let found = _descend(to: key, path, wentRight, &depth)
                if found >= 0 { return (false, found) }
                precondition(nodes.count < Int(Int32.max) - 1, "An AVL tree holds fewer than 2³¹ − 1 elements")
                let slot = Int32(truncatingIfNeeded: nodes.count)
                nodes.append(_AVLNode(leaf: key))
                values.append(value)
                root = nodes.withUnsafeMutableBufferPointer { nodes in
                    Self._rebalancePath(nodes, path, wentRight, depth, child: slot)
                }
                return (true, slot)
            }
        }
    }

    /// Descends two ways toward `key`, recording each vertex passed and the side taken, as
    /// `slot(of:)` does. Returns the slot holding `key` with `depth` cut back to the path above
    /// it, or −1 with the whole path, at whose end a new vertex for `key` hangs.
    @inlinable
    func _descend(
        to key: Key,
        _ path: UnsafeMutableBufferPointer<Int32>,
        _ wentRight: UnsafeMutableBufferPointer<Bool>,
        _ depth: inout Int
    ) -> Int32 {
        nodes.withUnsafeBufferPointer { nodes in
            var x = root
            var candidate: Int32 = -1
            var candidateDepth = 0
            var reached = 0
            while x >= 0 {
                let goesRight = nodes[Int(x)].key < key
                path[reached] = x
                wentRight[reached] = goesRight
                if !goesRight {
                    candidate = x
                    candidateDepth = reached
                }
                reached &+= 1
                x = goesRight ? nodes[Int(x)].right : nodes[Int(x)].left
            }
            if candidate >= 0 && !(key < nodes[Int(candidate)].key) {
                depth = candidateDepth
                return candidate
            }
            depth = reached
            return -1
        }
    }

    /// Removes `key` and its value, if present. O(log *n*), plus O(*n*) when the storage is shared.
    @inlinable
    mutating func remove(_ key: Key) -> (key: Key, value: Value)? {
        withUnsafeTemporaryAllocation(of: Int32.self, capacity: Self._pathCapacity) { path in
            withUnsafeTemporaryAllocation(of: Bool.self, capacity: Self._pathCapacity) { wentRight in
                var depth = 0
                let found = _descend(to: key, path, wentRight, &depth)
                guard found >= 0 else { return nil }
                return _removeFound(found, path, wentRight, depth)
            }
        }
    }

    /// Removes the key of in-order rank `rank` and its value. O(log *n*), plus O(*n*) when the
    /// storage is shared.
    ///
    /// - Precondition: `0 <= rank < count`.
    @inlinable
    mutating func remove(atRank rank: Int) -> (key: Key, value: Value) {
        withUnsafeTemporaryAllocation(of: Int32.self, capacity: Self._pathCapacity) { path in
            withUnsafeTemporaryAllocation(of: Bool.self, capacity: Self._pathCapacity) { wentRight in
                var depth = 0
                let found: Int32 = nodes.withUnsafeBufferPointer { nodes in
                    var x = root
                    var remaining = Int32(truncatingIfNeeded: rank)
                    while true {
                        let left = nodes[Int(x)].left
                        let leftSize = Self._size(nodes, left)
                        if remaining < leftSize {
                            path[depth] = x
                            wentRight[depth] = false
                            x = left
                        } else if remaining == leftSize {
                            return x
                        } else {
                            remaining &-= leftSize &+ 1
                            path[depth] = x
                            wentRight[depth] = true
                            x = nodes[Int(x)].right
                        }
                        depth &+= 1
                    }
                }
                return _removeFound(found, path, wentRight, depth)
            }
        }
    }

    /// Unlinks the vertex at `found`, reached by the `depth` vertices of `path`, rebalances, and
    /// moves the last slot into the freed one.
    @inlinable
    mutating func _removeFound(
        _ found: Int32,
        _ path: UnsafeMutableBufferPointer<Int32>,
        _ wentRight: UnsafeMutableBufferPointer<Bool>,
        _ depth: Int
    ) -> (key: Key, value: Value) {
        var depth = depth
        var target = found
        let hasBoth = nodes[Int(found)].left >= 0 && nodes[Int(found)].right >= 0
        if hasBoth {
            // The successor, the leftmost vertex of the right subtree, takes the found vertex's
            // place; its own slot, which has no left child, is the one unlinked.
            nodes.withUnsafeBufferPointer { nodes in
                path[depth] = found
                wentRight[depth] = true
                depth &+= 1
                var y = nodes[Int(found)].right
                while nodes[Int(y)].left >= 0 {
                    path[depth] = y
                    wentRight[depth] = false
                    depth &+= 1
                    y = nodes[Int(y)].left
                }
                target = y
            }
            let successorKey = nodes[Int(target)].key
            nodes[Int(target)].key = nodes[Int(found)].key
            nodes[Int(found)].key = successorKey
            values.swapAt(Int(found), Int(target))
        }
        let unlinked = target
        let finalDepth = depth
        root = nodes.withUnsafeMutableBufferPointer { nodes in
            let only = nodes[Int(unlinked)].left >= 0 ? nodes[Int(unlinked)].left : nodes[Int(unlinked)].right
            return Self._rebalancePath(nodes, path, wentRight, finalDepth, child: only)
        }
        let last = Int32(truncatingIfNeeded: nodes.count &- 1)
        if target != last {
            _relink(last, to: target)
            nodes.swapAt(Int(target), Int(last))
            values.swapAt(Int(target), Int(last))
        }
        return (nodes.removeLast().key, values.removeLast())
    }

    /// Points the link that leads to `slot` (from its parent, or the root) at `newSlot` instead.
    @inlinable
    mutating func _relink(_ slot: Int32, to newSlot: Int32) {
        if root == slot {
            root = newSlot
            return
        }
        let key = nodes[Int(slot)].key
        let link: (parent: Int32, right: Bool) = nodes.withUnsafeBufferPointer { nodes in
            var x = root
            while true {
                let right = nodes[Int(x)].key < key
                let next = right ? nodes[Int(x)].right : nodes[Int(x)].left
                if next == slot { return (x, right) }
                x = next
            }
        }
        if link.right {
            nodes[Int(link.parent)].right = newSlot
        } else {
            nodes[Int(link.parent)].left = newSlot
        }
    }

    // MARK: Balancing

    @inlinable @inline(__always)
    static func _height(_ nodes: UnsafeMutableBufferPointer<_AVLNode<Key>>, _ x: Int32) -> Int32 {
        x < 0 ? 0 : nodes[Int(x)].height
    }

    @inlinable @inline(__always)
    static func _size(_ nodes: UnsafeBufferPointer<_AVLNode<Key>>, _ x: Int32) -> Int32 {
        x < 0 ? 0 : nodes[Int(x)].size
    }

    @inlinable @inline(__always)
    static func _size(_ nodes: UnsafeMutableBufferPointer<_AVLNode<Key>>, _ x: Int32) -> Int32 {
        x < 0 ? 0 : nodes[Int(x)].size
    }

    /// Recomputes `x`'s height and size from its children's.
    @inlinable @inline(__always)
    static func _update(_ nodes: UnsafeMutableBufferPointer<_AVLNode<Key>>, _ x: Int32) {
        let left = nodes[Int(x)].left
        let right = nodes[Int(x)].right
        nodes[Int(x)].height = Swift.max(_height(nodes, left), _height(nodes, right)) &+ 1
        nodes[Int(x)].size = _size(nodes, left) &+ _size(nodes, right) &+ 1
    }

    @inlinable
    static func _rotateRight(_ nodes: UnsafeMutableBufferPointer<_AVLNode<Key>>, _ x: Int32) -> Int32 {
        let left = nodes[Int(x)].left
        nodes[Int(x)].left = nodes[Int(left)].right
        nodes[Int(left)].right = x
        _update(nodes, x)
        _update(nodes, left)
        return left
    }

    @inlinable
    static func _rotateLeft(_ nodes: UnsafeMutableBufferPointer<_AVLNode<Key>>, _ x: Int32) -> Int32 {
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
    static func _rebalance(_ nodes: UnsafeMutableBufferPointer<_AVLNode<Key>>, _ x: Int32) -> Int32 {
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
    static func _rebalancePath(
        _ nodes: UnsafeMutableBufferPointer<_AVLNode<Key>>,
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
            if wentRight[i] {
                nodes[Int(parent)].right = child
            } else {
                nodes[Int(parent)].left = child
            }
            child = _rebalance(nodes, parent)
        }
        return child
    }

    // MARK: Iteration

    /// The slots in key order, by an explicit stack of the left spine.
    @frozen
    @usableFromInline
    struct InorderSlots {
        @usableFromInline let nodes: ContiguousArray<_AVLNode<Key>>
        @usableFromInline var stack: ContiguousArray<Int32>

        @inlinable
        init(_ core: _AVLCore) {
            nodes = core.nodes
            stack = []
            stack.reserveCapacity(core.height)
            var x = core.root
            while x >= 0 {
                stack.append(x)
                x = nodes[Int(x)].left
            }
        }

        @inlinable
        mutating func next() -> Int32? {
            guard let x = stack.popLast() else { return nil }
            var y = nodes[Int(x)].right
            while y >= 0 {
                stack.append(y)
                y = nodes[Int(y)].left
            }
            return x
        }
    }
}

extension _AVLCore: Sendable where Key: Sendable, Value: Sendable {}
extension _AVLCore.InorderSlots: Sendable where Key: Sendable, Value: Sendable {}
