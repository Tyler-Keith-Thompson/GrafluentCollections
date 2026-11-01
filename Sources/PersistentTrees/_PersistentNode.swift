/// One immutable vertex of a persistent weight-balanced tree: a key, its value, its subtrees and
/// the number of keys in its subtree.
///
/// Vertices are never changed after they are made, so any number of versions share them, and a
/// version's edit makes new vertices only on the path to the change. Balance follows Adams
/// ("Efficient sets: a balancing act", 1993) with the parameters (3, 2) that Hirai and Yamamoto
/// proved correct ("Balancing weight-balanced trees", 2011): neither subtree holds more than three
/// times the other's keys, once the two hold two or more.
@usableFromInline
package final class _PersistentNode<Key, Value> {
    @usableFromInline package let key: Key
    @usableFromInline package let value: Value
    @usableFromInline package let left: _PersistentNode?
    @usableFromInline package let right: _PersistentNode?
    @usableFromInline package let size: Int

    @inlinable
    init(key: Key, value: Value, left: _PersistentNode?, right: _PersistentNode?) {
        self.key = key
        self.value = value
        self.left = left
        self.right = right
        size = (left?.size ?? 0) &+ (right?.size ?? 0) &+ 1
    }
}

extension _PersistentNode: @unchecked Sendable where Key: Sendable, Value: Sendable {}

extension _PersistentNode where Key: Comparable {
    @inlinable @inline(__always)
    static func size(_ tree: _PersistentNode?) -> Int { tree?.size ?? 0 }

    /// The vertex holding `key`, or nil.
    @inlinable
    static func find(_ key: Key, in tree: _PersistentNode?) -> _PersistentNode? {
        var tree = tree
        while let node = tree {
            if key < node.key {
                tree = node.left
            } else if node.key < key {
                tree = node.right
            } else {
                return node
            }
        }
        return nil
    }

    /// The number of keys less than `key` (with `orEqual`, at most `key`).
    @inlinable
    static func rank(of key: Key, in tree: _PersistentNode?, orEqual: Bool) -> Int {
        var tree = tree
        var rank = 0
        while let node = tree {
            if key < node.key || (!orEqual && !(node.key < key)) {
                tree = node.left
            } else {
                rank &+= size(node.left) &+ 1
                tree = node.right
            }
        }
        return rank
    }

    /// The vertex with `rank` keys before it; `rank` must be in `0 ..< size(tree)`.
    @inlinable
    static func node(atRank rank: Int, in tree: _PersistentNode) -> _PersistentNode {
        var node = tree
        var rank = rank
        while true {
            let leftSize = size(node.left)
            if rank < leftSize {
                node = node.left.unsafelyUnwrapped
            } else if rank == leftSize {
                return node
            } else {
                rank &-= leftSize &+ 1
                node = node.right.unsafelyUnwrapped
            }
        }
    }

    /// A balanced tree of the sorted, distinct keys `keys[range]` and their values.
    @inlinable
    static func build(_ keys: ContiguousArray<Key>, _ values: ContiguousArray<Value>, _ range: Range<Int>) -> _PersistentNode? {
        guard !range.isEmpty else { return nil }
        let middle = range.lowerBound &+ range.count / 2
        return _PersistentNode(
            key: keys[middle], value: values[middle],
            left: build(keys, values, range.lowerBound ..< middle),
            right: build(keys, values, middle &+ 1 ..< range.upperBound))
    }

    // MARK: - Balancing

    /// A vertex over `left` and `right`, rotated once or twice when one side has grown or shrunk
    /// by at most one step past the balance bound.
    @inlinable
    static func balance(_ key: Key, _ value: Value, _ left: _PersistentNode?, _ right: _PersistentNode?) -> _PersistentNode {
        let leftSize = size(left), rightSize = size(right)
        if leftSize &+ rightSize > 1 {
            if rightSize > 3 &* leftSize, let right {
                if size(right.left) < 2 &* size(right.right) {
                    return _PersistentNode(
                        key: right.key, value: right.value,
                        left: _PersistentNode(key: key, value: value, left: left, right: right.left),
                        right: right.right)
                }
                let inner = right.left.unsafelyUnwrapped
                return _PersistentNode(
                    key: inner.key, value: inner.value,
                    left: _PersistentNode(key: key, value: value, left: left, right: inner.left),
                    right: _PersistentNode(key: right.key, value: right.value, left: inner.right, right: right.right))
            }
            if leftSize > 3 &* rightSize, let left {
                if size(left.right) < 2 &* size(left.left) {
                    return _PersistentNode(
                        key: left.key, value: left.value,
                        left: left.left,
                        right: _PersistentNode(key: key, value: value, left: left.right, right: right))
                }
                let inner = left.right.unsafelyUnwrapped
                return _PersistentNode(
                    key: inner.key, value: inner.value,
                    left: _PersistentNode(key: left.key, value: left.value, left: left.left, right: inner.left),
                    right: _PersistentNode(key: key, value: value, left: inner.right, right: right))
            }
        }
        return _PersistentNode(key: key, value: value, left: left, right: right)
    }

    // MARK: - Insertion and removal

    /// The tree with `key` mapped to `value`. When `key` is present, `existing` is set to its
    /// vertex, and the tree is returned unchanged unless `replacing`.
    @inlinable
    static func inserting(_ key: Key, _ value: Value, into tree: _PersistentNode?, replacing: Bool, existing: inout _PersistentNode?) -> _PersistentNode {
        guard let tree else { return _PersistentNode(key: key, value: value, left: nil, right: nil) }
        if key < tree.key {
            let left = inserting(key, value, into: tree.left, replacing: replacing, existing: &existing)
            return left === tree.left ? tree : balance(tree.key, tree.value, left, tree.right)
        }
        if tree.key < key {
            let right = inserting(key, value, into: tree.right, replacing: replacing, existing: &existing)
            return right === tree.right ? tree : balance(tree.key, tree.value, tree.left, right)
        }
        existing = tree
        return replacing ? _PersistentNode(key: key, value: value, left: tree.left, right: tree.right) : tree
    }

    /// The tree without `key`; `removed` is set to its vertex when it was present.
    @inlinable
    static func removing(_ key: Key, from tree: _PersistentNode?, removed: inout _PersistentNode?) -> _PersistentNode? {
        guard let tree else { return nil }
        if key < tree.key {
            let left = removing(key, from: tree.left, removed: &removed)
            return left === tree.left ? tree : balance(tree.key, tree.value, left, tree.right)
        }
        if tree.key < key {
            let right = removing(key, from: tree.right, removed: &removed)
            return right === tree.right ? tree : balance(tree.key, tree.value, tree.left, right)
        }
        removed = tree
        return glue(tree.left, tree.right)
    }

    /// The tree's first vertex and the tree without it.
    @inlinable
    static func removingFirst(_ tree: _PersistentNode) -> (first: _PersistentNode, rest: _PersistentNode?) {
        guard let left = tree.left else { return (tree, tree.right) }
        let (first, rest) = removingFirst(left)
        return (first, balance(tree.key, tree.value, rest, tree.right))
    }

    /// The tree's last vertex and the tree without it.
    @inlinable
    static func removingLast(_ tree: _PersistentNode) -> (last: _PersistentNode, rest: _PersistentNode?) {
        guard let right = tree.right else { return (tree, tree.left) }
        let (last, rest) = removingLast(right)
        return (last, balance(tree.key, tree.value, tree.left, rest))
    }

    /// Two subtrees that were siblings, joined without a key between them.
    @inlinable
    static func glue(_ left: _PersistentNode?, _ right: _PersistentNode?) -> _PersistentNode? {
        guard let left else { return right }
        guard let right else { return left }
        if left.size > right.size {
            let (last, rest) = removingLast(left)
            return balance(last.key, last.value, rest, right)
        }
        let (first, rest) = removingFirst(right)
        return balance(first.key, first.value, left, rest)
    }

    // MARK: - Join and split

    @inlinable
    static func insertingFirst(_ key: Key, _ value: Value, into tree: _PersistentNode?) -> _PersistentNode {
        guard let tree else { return _PersistentNode(key: key, value: value, left: nil, right: nil) }
        return balance(tree.key, tree.value, insertingFirst(key, value, into: tree.left), tree.right)
    }

    @inlinable
    static func insertingLast(_ key: Key, _ value: Value, into tree: _PersistentNode?) -> _PersistentNode {
        guard let tree else { return _PersistentNode(key: key, value: value, left: nil, right: nil) }
        return balance(tree.key, tree.value, tree.left, insertingLast(key, value, into: tree.right))
    }

    /// The tree of `left`, then `key`, then `right`, whose keys are all less than `key` and all
    /// greater, in O(log(*n* / *m*)) for subtrees of *n* and *m* keys.
    @inlinable
    static func join(_ key: Key, _ value: Value, _ left: _PersistentNode?, _ right: _PersistentNode?) -> _PersistentNode {
        guard let left else { return insertingFirst(key, value, into: right) }
        guard let right else { return insertingLast(key, value, into: left) }
        if 3 &* left.size < right.size {
            return balance(right.key, right.value, join(key, value, left, right.left), right.right)
        }
        if 3 &* right.size < left.size {
            return balance(left.key, left.value, left.left, join(key, value, left.right, right))
        }
        return _PersistentNode(key: key, value: value, left: left, right: right)
    }

    /// The tree of `left` then `right`, whose keys are all less than all of `right`'s.
    @inlinable
    static func join(_ left: _PersistentNode?, _ right: _PersistentNode?) -> _PersistentNode? {
        guard let left else { return right }
        guard let right else { return left }
        if 3 &* left.size < right.size {
            return balance(right.key, right.value, join(left, right.left), right.right)
        }
        if 3 &* right.size < left.size {
            return balance(left.key, left.value, left.left, join(left.right, right))
        }
        return glue(left, right)
    }

    /// The keys of `tree` less than `key`, its vertex for `key` if any, and the keys greater.
    @inlinable
    static func split(_ tree: _PersistentNode?, at key: Key) -> (less: _PersistentNode?, found: _PersistentNode?, greater: _PersistentNode?) {
        guard let tree else { return (nil, nil, nil) }
        if key < tree.key {
            let (less, found, greater) = split(tree.left, at: key)
            return (less, found, join(tree.key, tree.value, greater, tree.right))
        }
        if tree.key < key {
            let (less, found, greater) = split(tree.right, at: key)
            return (join(tree.key, tree.value, tree.left, less), found, greater)
        }
        return (tree.left, tree, tree.right)
    }

    // MARK: - Set operations (Blelloch, Ferizovic and Sun, "Just Join for Parallel Ordered Sets", 2016)

    /// The keys of both, with the first tree's value for a key in both. A subtree the two share
    /// is returned as it is.
    @inlinable
    static func union(_ first: _PersistentNode?, _ second: _PersistentNode?) -> _PersistentNode? {
        guard let first else { return second }
        guard let second else { return first }
        if first === second { return first }
        let (less, _, greater) = split(second, at: first.key)
        let left = union(first.left, less)
        let right = union(first.right, greater)
        if left === first.left && right === first.right { return first }
        return join(first.key, first.value, left, right)
    }

    /// The keys of both, with `combine` of the first tree's value and the second's for a key in
    /// both.
    @inlinable
    static func union<E: Error>(_ first: _PersistentNode?, _ second: _PersistentNode?, combine: (Value, Value) throws(E) -> Value) throws(E) -> _PersistentNode? {
        guard let first else { return second }
        guard let second else { return first }
        let (less, found, greater) = split(second, at: first.key)
        let left = try union(first.left, less, combine: combine)
        let right = try union(first.right, greater, combine: combine)
        var value = first.value
        if let found {
            value = try combine(first.value, found.value)
        }
        return join(first.key, value, left, right)
    }

    /// The keys in both, with the first tree's values.
    @inlinable
    static func intersection(_ first: _PersistentNode?, _ second: _PersistentNode?) -> _PersistentNode? {
        guard let first, let second else { return nil }
        if first === second { return first }
        let (less, found, greater) = split(second, at: first.key)
        let left = intersection(first.left, less)
        let right = intersection(first.right, greater)
        guard found != nil else { return join(left, right) }
        if left === first.left && right === first.right { return first }
        return join(first.key, first.value, left, right)
    }

    /// The keys of the first tree not in the second.
    @inlinable
    static func subtracting(_ second: _PersistentNode?, from first: _PersistentNode?) -> _PersistentNode? {
        guard let first else { return nil }
        guard let second else { return first }
        if first === second { return nil }
        let (less, _, greater) = split(first, at: second.key)
        return join(subtracting(second.left, from: less), subtracting(second.right, from: greater))
    }

    /// The keys in exactly one of the two.
    @inlinable
    static func symmetricDifference(_ first: _PersistentNode?, _ second: _PersistentNode?) -> _PersistentNode? {
        guard let first else { return second }
        guard let second else { return first }
        if first === second { return nil }
        let (less, found, greater) = split(second, at: first.key)
        let left = symmetricDifference(first.left, less)
        let right = symmetricDifference(first.right, greater)
        return found == nil ? join(first.key, first.value, left, right) : join(left, right)
    }

    /// Whether every key of the first tree is in the second.
    @inlinable
    static func isSubset(_ first: _PersistentNode?, of second: _PersistentNode?) -> Bool {
        guard let first else { return true }
        guard let second, first.size <= second.size else { return false }
        if first === second { return true }
        let (less, found, greater) = split(second, at: first.key)
        return found != nil && isSubset(first.left, of: less) && isSubset(first.right, of: greater)
    }

    /// Whether the tree keeps the weight balance at every vertex and its sizes and order hold.
    @inlinable
    package static func isValid(_ tree: _PersistentNode?) -> Bool {
        guard let tree else { return true }
        let leftSize = size(tree.left), rightSize = size(tree.right)
        guard tree.size == leftSize &+ rightSize &+ 1 else { return false }
        guard leftSize &+ rightSize <= 1 || (leftSize <= 3 &* rightSize && rightSize <= 3 &* leftSize) else { return false }
        if let left = tree.left, !(left.key < tree.key) { return false }
        if let right = tree.right, !(tree.key < right.key) { return false }
        return isValid(tree.left) && isValid(tree.right)
    }

    /// The tree's keys in ascending order, one vertex at a time, by an explicit stack of the left
    /// spine.
    @usableFromInline
    struct InorderNodes {
        @usableFromInline var stack: ContiguousArray<Unmanaged<_PersistentNode>>
        /// Keeps every vertex on the stack alive.
        @usableFromInline let root: _PersistentNode?

        @inlinable
        init(_ root: _PersistentNode?) {
            self.root = root
            stack = []
            var tree = root
            while let node = tree {
                stack.append(Unmanaged.passUnretained(node))
                tree = node.left
            }
        }

        @inlinable
        mutating func next() -> Unmanaged<_PersistentNode>? {
            guard let top = stack.popLast() else { return nil }
            var tree = top._withUnsafeGuaranteedRef { $0.right }
            while let node = tree {
                stack.append(Unmanaged.passUnretained(node))
                tree = node.left
            }
            return top
        }
    }
}

extension _PersistentNode.InorderNodes: @unchecked Sendable where Key: Sendable, Value: Sendable {}
