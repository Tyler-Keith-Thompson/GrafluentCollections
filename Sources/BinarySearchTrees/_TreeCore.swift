/// One vertex of a balanced binary search tree: its key, its children's slots (−1 for none), the
/// number of vertices in its subtree, and what its balancing scheme records (an AVL tree's height
/// in vertices, a red–black tree's colour). The key sits beside the links so a descent reads one
/// array per level.
@frozen
@usableFromInline
package struct _TreeNode<Key> {
    @usableFromInline package var key: Key
    @usableFromInline package var left: Int32
    @usableFromInline package var right: Int32
    @usableFromInline package var size: Int32
    @usableFromInline package var balance: Int32

    @inlinable
    init(key: Key, left: Int32, right: Int32, size: Int32, balance: Int32) {
        self.key = key
        self.left = left
        self.right = right
        self.size = size
        self.balance = balance
    }
}

extension _TreeNode: Sendable where Key: Sendable {}

/// A scheme whose trees can start perfectly balanced: the record of each vertex of such a tree.
@usableFromInline
package protocol _BalancedBuild {
    /// The record of a vertex of a perfectly balanced tree, given its subtree's height, its depth
    /// and the tree's height (all counted in vertices, the root at depth 0).
    static func balance(subtreeHeight: Int32, depth: Int32, treeHeight: Int32) -> Int32
}

/// How a balanced tree keeps its shape: the record a new leaf starts with, and the repairs after
/// an insertion or removal. Each repair receives the path recorded on the way down (its vertices
/// and the side taken at each), hangs the new or surviving child at its end, keeps the subtree
/// sizes, and returns the new root.
@usableFromInline
package protocol _TreeBalancing: _BalancedBuild {
    /// The record of a newly inserted leaf.
    static var leafBalance: Int32 { get }

    /// Hangs the new leaf `slot` at the end of the path and restores the balance.
    static func afterInsert<Key>(
        _ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>,
        _ path: UnsafeMutableBufferPointer<Int32>,
        _ wentRight: UnsafeMutableBufferPointer<Bool>,
        _ depth: Int,
        inserted slot: Int32
    ) -> Int32

    /// Hangs `child` where the unlinked vertex `removed` was, at the end of the path, and
    /// restores the balance.
    static func afterRemove<Key>(
        _ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>,
        _ path: UnsafeMutableBufferPointer<Int32>,
        _ wentRight: UnsafeMutableBufferPointer<Bool>,
        _ depth: Int,
        child: Int32,
        removed: Int32
    ) -> Int32
}

/// Helpers every balancing scheme shares.
@usableFromInline
enum _Tree {
    @inlinable @inline(__always)
    static func size<Key>(_ nodes: UnsafeBufferPointer<_TreeNode<Key>>, _ x: Int32) -> Int32 {
        x < 0 ? 0 : nodes[Int(x)].size
    }

    @inlinable @inline(__always)
    static func size<Key>(_ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>, _ x: Int32) -> Int32 {
        x < 0 ? 0 : nodes[Int(x)].size
    }

    /// Recomputes `x`'s size from its children's.
    @inlinable @inline(__always)
    static func updateSize<Key>(_ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>, _ x: Int32) {
        nodes[Int(x)].size = size(nodes, nodes[Int(x)].left) &+ size(nodes, nodes[Int(x)].right) &+ 1
    }

    /// Makes `child` the right (or left) child of `parent`.
    @inlinable @inline(__always)
    static func hang<Key>(_ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>, _ parent: Int32, right: Bool, _ child: Int32) {
        if right {
            nodes[Int(parent)].right = child
        } else {
            nodes[Int(parent)].left = child
        }
    }
}

/// The storage of every balanced binary search tree here: vertices (keys with their links) and
/// values in two parallel flat arrays indexed by slot, with links as `Int32` slots and −1 for
/// none, balanced by `Balancing`.
///
/// The slots are always `0 ..< count`: a removal moves the last slot into the hole, so the arrays
/// stay dense. Every subtree records its size, so a vertex's in-order rank is found from the
/// root in O(log *n*). Under a `_TreeBalancing` scheme, mutations walk down once, recording the
/// path (at most 64 vertices: an AVL tree of fewer than 2³¹ vertices is at most 45 high, a
/// red–black tree at most 62), and rebalance back up it. A treap (`_TreapBalancing`) has no height
/// bound, so its mutations work top-down and record no path.
@frozen
@usableFromInline
package struct _TreeCore<Key: Comparable, Value, Balancing> {
    @usableFromInline package var nodes: ContiguousArray<_TreeNode<Key>>
    @usableFromInline package var values: ContiguousArray<Value>
    @usableFromInline package var root: Int32

    @inlinable
    init() {
        values = []
        nodes = []
        root = -1
    }

    @inlinable
    var count: Int { nodes.count }

    /// The key at `slot`.
    @inlinable
    func key(at slot: Int32) -> Key { nodes[Int(slot)].key }

    /// The height in vertices, 0 when empty, found by a walk over every vertex. O(*n*).
    @inlinable
    func measuredHeight() -> Int {
        guard root >= 0 else { return 0 }
        return nodes.withUnsafeBufferPointer { nodes in
            var stack: [(slot: Int32, depth: Int)] = [(root, 1)]
            var height = 0
            while let (x, depth) = stack.popLast() {
                height = Swift.max(height, depth)
                if nodes[Int(x)].left >= 0 { stack.append((nodes[Int(x)].left, depth &+ 1)) }
                if nodes[Int(x)].right >= 0 { stack.append((nodes[Int(x)].right, depth &+ 1)) }
            }
            return height
        }
    }

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
                    before &+= Int(_Tree.size(nodes, nodes[Int(x)].left)) &+ 1
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
                    before &+= Int(_Tree.size(nodes, nodes[Int(x)].left)) &+ 1
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
                let leftSize = _Tree.size(nodes, left)
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
}

extension _TreeCore where Balancing: _BalancedBuild {
    /// The perfectly balanced tree over keys sorted in strictly ascending order, and their values.
    /// Slot `k` holds the `k`-th key. O(*n*).
    @inlinable
    init(sortedUniqueKeys keys: ContiguousArray<Key>, values: ContiguousArray<Value>) {
        precondition(keys.count < Int(Int32.max), "A balanced tree holds fewer than 2³¹ − 1 elements")
        self.values = values
        let count = keys.count
        var nodes = ContiguousArray<_TreeNode<Key>>()
        nodes.reserveCapacity(count)
        for key in keys {
            nodes.append(_TreeNode(key: key, left: -1, right: -1, size: 1, balance: 0))
        }
        // The middle-split tree of `count` vertices is as high as `count` has bits.
        let treeHeight = Int32(truncatingIfNeeded: Int.bitWidth &- count.leadingZeroBitCount)
        root = nodes.withUnsafeMutableBufferPointer { nodes in
            Self._build(nodes, 0, count, depth: 0, treeHeight: treeHeight).slot
        }
        self.nodes = nodes
    }

    /// Links `lo ..< hi` into a balanced subtree rooted at its middle slot, whose sides differ in
    /// size by at most one, so every empty link lies on the last two levels. Recurses to the
    /// height.
    @inlinable
    static func _build(
        _ nodes: UnsafeMutableBufferPointer<_TreeNode<Key>>,
        _ lo: Int,
        _ hi: Int,
        depth: Int32,
        treeHeight: Int32
    ) -> (slot: Int32, height: Int32) {
        guard lo < hi else { return (-1, 0) }
        let middle = lo &+ (hi &- lo) / 2
        let left = _build(nodes, lo, middle, depth: depth &+ 1, treeHeight: treeHeight)
        let right = _build(nodes, middle &+ 1, hi, depth: depth &+ 1, treeHeight: treeHeight)
        let height = Swift.max(left.height, right.height) &+ 1
        nodes[middle].left = left.slot
        nodes[middle].right = right.slot
        nodes[middle].size = Int32(truncatingIfNeeded: hi &- lo)
        nodes[middle].balance = Balancing.balance(subtreeHeight: height, depth: depth, treeHeight: treeHeight)
        return (Int32(truncatingIfNeeded: middle), height)
    }
}

extension _TreeCore where Balancing: _TreeBalancing {
    /// The longest path a mutation records.
    @inlinable
    static var _pathCapacity: Int { 64 }

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
                precondition(nodes.count < Int(Int32.max) - 1, "A balanced tree holds fewer than 2³¹ − 1 elements")
                let slot = Int32(truncatingIfNeeded: nodes.count)
                nodes.append(_TreeNode(key: key, left: -1, right: -1, size: 1, balance: Balancing.leafBalance))
                values.append(value)
                root = nodes.withUnsafeMutableBufferPointer { nodes in
                    Balancing.afterInsert(nodes, path, wentRight, depth, inserted: slot)
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
                        let leftSize = _Tree.size(nodes, left)
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
            return Balancing.afterRemove(nodes, path, wentRight, finalDepth, child: only, removed: unlinked)
        }
        return _discard(target)
    }
}

extension _TreeCore {
    /// Moves the last slot into the unlinked slot `target`, then removes and returns the last
    /// slot's key and value: those `target` held.
    @inlinable
    mutating func _discard(_ target: Int32) -> (key: Key, value: Value) {
        let last = Int32(truncatingIfNeeded: nodes.count &- 1)
        if target != last {
            _relink(last, to: target)
            nodes.swapAt(Int(target), Int(last))
            values.swapAt(Int(target), Int(last))
        }
        return (nodes.removeLast().key, values.removeLast())
    }

    /// Copies the subtree rooted at `subtree`, which is no longer linked from the root, into a
    /// core of its own, and removes its slots here, moving vertices with `move` as
    /// `_removeSlots(_:move:)` does. O(*k* log *k*) for *k* vertices, plus the moves.
    @inlinable
    mutating func _extract(
        _ subtree: Int32,
        move: (inout _TreeCore, _ slot: Int32, _ hole: Int32) -> Void
    ) -> _TreeCore {
        var extracted = _TreeCore()
        guard subtree >= 0 else { return extracted }
        let size = Int(nodes[Int(subtree)].size)
        extracted.nodes.reserveCapacity(size)
        extracted.values.reserveCapacity(size)
        var holes = ContiguousArray<Int32>()
        holes.reserveCapacity(size)
        var stack: ContiguousArray<(slot: Int32, parent: Int32, right: Bool)> = [(subtree, -1, false)]
        while let (x, parent, right) = stack.popLast() {
            let copy = Int32(truncatingIfNeeded: extracted.nodes.count)
            var node = nodes[Int(x)]
            if node.left >= 0 { stack.append((node.left, copy, false)) }
            if node.right >= 0 { stack.append((node.right, copy, true)) }
            node.left = -1
            node.right = -1
            extracted.nodes.append(node)
            extracted.values.append(values[Int(x)])
            if parent < 0 {
                extracted.root = copy
            } else if right {
                extracted.nodes[Int(parent)].right = copy
            } else {
                extracted.nodes[Int(parent)].left = copy
            }
            holes.append(x)
        }
        _removeSlots(&holes, move: move)
        return extracted
    }

    /// Removes the slots `holes`, which nothing links to, keeping the slots dense: each vertex
    /// past the new end moves into a hole below it. `move` first points the link to that vertex
    /// at the hole; the vertex is copied there after. O(*k* log *k*) for *k* holes, plus the
    /// moves.
    @inlinable
    mutating func _removeSlots(
        _ holes: inout ContiguousArray<Int32>,
        move: (inout _TreeCore, _ slot: Int32, _ hole: Int32) -> Void
    ) {
        holes.sort()
        let newCount = nodes.count &- holes.count
        // holes[fill...] below newCount take the vertices at or past it, in order; holes[skip...]
        // at or past it are dropped.
        var fill = 0
        var skip = 0
        while skip < holes.count && Int(holes[skip]) < newCount {
            skip &+= 1
        }
        var s = newCount
        while s < nodes.count {
            if skip < holes.count && Int(holes[skip]) == s {
                skip &+= 1
            } else {
                let hole = holes[fill]
                fill &+= 1
                move(&self, Int32(truncatingIfNeeded: s), hole)
                nodes[Int(hole)] = nodes[s]
                values[Int(hole)] = values[s]
            }
            s &+= 1
        }
        nodes.removeLast(holes.count)
        values.removeLast(holes.count)
    }

    /// Appends `other`'s vertices and values after these, unlinked from this root; returns the
    /// slot of `other`'s root, or −1 when it is empty. O(*m*) for *m* vertices of `other`, plus
    /// O(*n*) when the storage is shared or must grow.
    @inlinable
    mutating func _append(_ other: _TreeCore) -> Int32 {
        precondition(nodes.count &+ other.nodes.count < Int(Int32.max), "A balanced tree holds fewer than 2³¹ − 1 elements")
        let offset = Int32(truncatingIfNeeded: nodes.count)
        nodes.reserveCapacity(nodes.count &+ other.nodes.count)
        for var node in other.nodes {
            if node.left >= 0 { node.left &+= offset }
            if node.right >= 0 { node.right &+= offset }
            nodes.append(node)
        }
        values.append(contentsOf: other.values)
        return other.root < 0 ? -1 : other.root &+ offset
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

    // MARK: Iteration

    /// The slots in key order, by an explicit stack of the left spine.
    @frozen
    @usableFromInline
    struct InorderSlots {
        @usableFromInline let nodes: ContiguousArray<_TreeNode<Key>>
        @usableFromInline var stack: ContiguousArray<Int32>

        @inlinable
        init(_ core: _TreeCore) {
            nodes = core.nodes
            stack = []
            // No AVL or red–black tree is higher than twice the bits of its count; a higher treap
            // grows the stack.
            stack.reserveCapacity(2 &* (Int.bitWidth &- core.count.leadingZeroBitCount))
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

extension _TreeCore: Sendable where Key: Sendable, Value: Sendable {}
extension _TreeCore.InorderSlots: Sendable where Key: Sendable, Value: Sendable {}
