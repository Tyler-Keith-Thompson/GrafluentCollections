/// What an insertion does when the tree already holds an equal key.
@usableFromInline
package enum _BTreeExisting {
    /// Keep the stored element.
    case keep
    /// Keep the stored key and replace its value.
    case replaceValue
    /// Replace the stored key and value.
    case replaceElement
}

/// The storage of a B-tree (Bayer and McCreight, 1972) of minimum degree *t*: every node but the
/// root holds between *t* − 1 and 2*t* − 1 elements in ascending key order, an inner node with
/// *k* elements has *k* + 1 children, every leaf lies at the same depth, and each node records
/// its subtree's element count, so ranks are found from the root.
///
/// Insertion splits each full node on the way down (Cormen, Leiserson, Rivest and Stein,
/// *Introduction to Algorithms*, chapter 18), and removal tops up each minimal node on the way
/// down by borrowing from a sibling or merging with one, so neither walks back up. Recursion goes
/// only as deep as the tree is high. Before changing a node, each walk copies it if another tree
/// shares it, so copies of a tree share every node neither has changed.
@frozen
@usableFromInline
package struct _BTreeCore<Key: Comparable, Value> {
    @usableFromInline package var root: _BTreeNode<Key, Value>

    /// The minimum degree *t*: nodes of about 512 bytes of elements, and at least 4.
    @inlinable
    package static var minimumDegree: Int {
        Swift.max(4, Swift.min(128, 256 / Swift.max(1, MemoryLayout<_BTreeElement<Key, Value>>.stride)))
    }

    /// The most elements a node holds, 2*t* − 1.
    @inlinable
    package static var maxElements: Int { 2 &* minimumDegree &- 1 }

    /// The fewest elements a node other than the root holds, *t* − 1.
    @inlinable
    package static var minElements: Int { minimumDegree &- 1 }

    @inlinable
    init() {
        root = _BTreeNode.make(capacity: Self.maxElements)
    }

    @inlinable
    var count: Int { root._header.pointee.subtreeCount }

    // MARK: Building

    /// The B-tree over keys sorted in strictly ascending order, and their values, as low as it
    /// can be with its subtrees evenly filled. O(*n*).
    @inlinable
    init(sortedUniqueKeys keys: ContiguousArray<Key>, values: ContiguousArray<Value>) {
        let count = keys.count
        guard count > 0 else {
            root = _BTreeNode.make(capacity: Self.maxElements)
            return
        }
        // fullSizes[h] is the most elements a tree h levels high holds, (2t)^h − 1.
        var fullSizes = [0]
        while fullSizes[fullSizes.count &- 1] < count {
            fullSizes.append((fullSizes[fullSizes.count &- 1] &+ 1) &* (2 &* Self.minimumDegree) &- 1)
        }
        root = keys.withUnsafeBufferPointer { keys in
            values.withUnsafeBufferPointer { values in
                Self._build(keys, values, 0, count, height: fullSizes.count &- 1, fullSizes: fullSizes)
            }
        }
    }

    /// The subtree `height` levels high over `lo ..< hi`: as few children as fit, sharing the
    /// elements as evenly as they divide, which keeps every node at least half full.
    @inlinable
    static func _build(
        _ keys: UnsafeBufferPointer<Key>,
        _ values: UnsafeBufferPointer<Value>,
        _ lo: Int,
        _ hi: Int,
        height: Int,
        fullSizes: [Int]
    ) -> _BTreeNode<Key, Value> {
        let node = _BTreeNode<Key, Value>.make(capacity: maxElements)
        node._header.pointee.subtreeCount = hi &- lo
        if height == 1 {
            var k = lo
            while k < hi {
                node.insertElement(_BTreeElement(key: keys[k], value: values[k]), at: k &- lo)
                k &+= 1
            }
            return node
        }
        let count = hi &- lo
        let childFull = fullSizes[height &- 1]
        let childCount = (count &+ childFull &+ 1) / (childFull &+ 1)
        let inChildren = count &- (childCount &- 1)
        let base = inChildren / childCount
        let extra = inChildren % childCount
        var children = ContiguousArray<_BTreeNode<Key, Value>>()
        children.reserveCapacity(childCount)
        var start = lo
        var k = 0
        while k < childCount {
            let size = base &+ (k < extra ? 1 : 0)
            children.append(_build(keys, values, start, start &+ size, height: height &- 1, fullSizes: fullSizes))
            start &+= size
            if k < childCount &- 1 {
                node.insertElement(_BTreeElement(key: keys[start], value: values[start]), at: k)
                start &+= 1
            }
            k &+= 1
        }
        node._header.pointee.children = children
        return node
    }

    // MARK: Queries

    /// The number of levels, every leaf lying on the last: 0 when empty. O(log *n*).
    @inlinable
    var height: Int {
        guard count > 0 else { return 0 }
        var levels = 1
        var node = Unmanaged.passUnretained(root)
        while let next = node._withUnsafeGuaranteedRef({ $0.isLeaf ? nil : $0.unretainedChild(0) }) {
            node = next
            levels &+= 1
        }
        return levels
    }

    /// The element whose key equals `key`, or nil. O(log *n*).
    @inlinable
    func element(forKey key: Key) -> _BTreeElement<Key, Value>? {
        // The tree holds every node for the whole walk, so the walk retains none.
        var node = Unmanaged.passUnretained(root)
        while true {
            let step: (found: _BTreeElement<Key, Value>?, next: Unmanaged<_BTreeNode<Key, Value>>?) = node._withUnsafeGuaranteedRef { node in
                let i = node.boundary(of: key, orEqual: false)
                if i < node.elementCount {
                    let element = node.element(at: i)
                    if !(key < element.key) { return (element, nil) }
                }
                return (nil, node.isLeaf ? nil : node.unretainedChild(i))
            }
            if let found = step.found { return found }
            guard let next = step.next else { return nil }
            node = next
        }
    }

    /// The in-order rank of `key`, or nil when absent. O(log *n*).
    @inlinable
    func rank(of key: Key) -> Int? {
        var node = Unmanaged.passUnretained(root)
        var before = 0
        while true {
            let step: (rank: Int?, next: Unmanaged<_BTreeNode<Key, Value>>?) = node._withUnsafeGuaranteedRef { node in
                let i = node.boundary(of: key, orEqual: false)
                let found = i < node.elementCount && !(key < node.key(at: i))
                if node.isLeaf {
                    return (found ? before &+ i : nil, nil)
                }
                before &+= i &+ node.childCount(below: i)
                if found {
                    return (before &+ node.childSubtreeCount(i), nil)
                }
                return (nil, node.unretainedChild(i))
            }
            guard let next = step.next else { return step.rank }
            node = next
        }
    }

    /// The number of keys below `key`, or with `orEqual`, at most `key`. O(log *n*).
    @inlinable
    func countBelow(_ key: Key, orEqual: Bool) -> Int {
        var node = Unmanaged.passUnretained(root)
        var before = 0
        while let next = node._withUnsafeGuaranteedRef({ node -> Unmanaged<_BTreeNode<Key, Value>>? in
            let i = node.boundary(of: key, orEqual: orEqual)
            before &+= i
            if node.isLeaf { return nil }
            before &+= node.childCount(below: i)
            return node.unretainedChild(i)
        }) {
            node = next
        }
        return before
    }

    /// The element of in-order rank `rank`.
    ///
    /// - Precondition: `0 <= rank < count`.
    /// - Complexity: O(*t* log *n*).
    @inlinable
    func element(atRank rank: Int) -> _BTreeElement<Key, Value> {
        var node = Unmanaged.passUnretained(root)
        var rest = rank
        while true {
            let step: (found: _BTreeElement<Key, Value>?, next: Unmanaged<_BTreeNode<Key, Value>>?) = node._withUnsafeGuaranteedRef { node in
                if node.isLeaf { return (node.element(at: rest), nil) }
                var j = 0
                while true {
                    let size = node.childSubtreeCount(j)
                    if rest < size { break }
                    if rest == size { return (node.element(at: j), nil) }
                    rest &-= size &+ 1
                    j &+= 1
                }
                return (nil, node.unretainedChild(j))
            }
            if let found = step.found { return found }
            node = step.next.unsafelyUnwrapped
        }
    }

    /// The first or (with `last`) last element, or nil when empty. O(log *n*).
    @inlinable
    func extreme(last: Bool) -> _BTreeElement<Key, Value>? {
        guard count > 0 else { return nil }
        var node = Unmanaged.passUnretained(root)
        while let next = node._withUnsafeGuaranteedRef({ node in
            node.isLeaf ? nil : node.unretainedChild(last ? node.elementCount : 0)
        }) {
            node = next
        }
        return node._withUnsafeGuaranteedRef { node in node.element(at: last ? node.elementCount &- 1 : 0) }
    }

    // MARK: Copy-on-write

    @inlinable
    mutating func _makeRootUnique() {
        if !isKnownUniquelyReferenced(&root) {
            root = root.copy(capacity: Self.maxElements)
        }
    }

    /// Copies `node`'s child `index` unless `node` is its only holder.
    @inlinable
    static func _makeChildUnique(_ node: _BTreeNode<Key, Value>, _ index: Int) {
        if !isKnownUniquelyReferenced(&node._header.pointee.children[index]) {
            node._header.pointee.children[index] = node._header.pointee.children[index].copy(capacity: maxElements)
        }
    }

    // MARK: Insertion

    /// Inserts `key` with `value`, or, when an equal key is present, does what `existing` says.
    ///
    /// - Returns: The element stored for the equal key before, or nil when `key` was inserted.
    /// - Complexity: O(*t* log *n*), plus O(*t*) for each node copied because another tree shares it.
    @inlinable
    mutating func insert(_ key: Key, _ value: Value, existing: _BTreeExisting) -> _BTreeElement<Key, Value>? {
        _makeRootUnique()
        if root.elementCount == Self.maxElements {
            let newRoot = _BTreeNode<Key, Value>.make(capacity: Self.maxElements, children: [root])
            newRoot._header.pointee.subtreeCount = root._header.pointee.subtreeCount
            root = newRoot
            Self._splitChild(newRoot, 0)
        }
        return Self._insert(_BTreeElement(key: key, value: value), existing: existing, into: root)
    }

    /// Inserts into the subtree of `node`, which is not full and held by this tree alone.
    @inlinable
    static func _insert(
        _ element: _BTreeElement<Key, Value>,
        existing: _BTreeExisting,
        into node: _BTreeNode<Key, Value>
    ) -> _BTreeElement<Key, Value>? {
        var i = node.boundary(of: element.key, orEqual: false)
        if i < node.elementCount && !(element.key < node.key(at: i)) {
            return _resolve(existing, node, i, element)
        }
        if node.isLeaf {
            node.insertElement(element, at: i)
            node._header.pointee.subtreeCount &+= 1
            return nil
        }
        _makeChildUnique(node, i)
        if node._header.pointee.children[i].elementCount == maxElements {
            _splitChild(node, i)
            let separator = node.key(at: i)
            if separator < element.key {
                i &+= 1
            } else if !(element.key < separator) {
                return _resolve(existing, node, i, element)
            }
        }
        let previous = _insert(element, existing: existing, into: node._header.pointee.children[i])
        if previous == nil { node._header.pointee.subtreeCount &+= 1 }
        return previous
    }

    /// Applies `existing` to the element at `index` of `node`, whose key equals `element`'s.
    @inlinable
    static func _resolve(
        _ existing: _BTreeExisting,
        _ node: _BTreeNode<Key, Value>,
        _ index: Int,
        _ element: _BTreeElement<Key, Value>
    ) -> _BTreeElement<Key, Value> {
        switch existing {
        case .keep:
            return node.element(at: index)
        case .replaceValue:
            let key = node.key(at: index)
            return _BTreeElement(key: key, value: node.replaceValue(at: index, with: element.value))
        case .replaceElement:
            return node.replaceElement(at: index, with: element)
        }
    }

    /// Splits `parent`'s full child `index`, held by this tree alone, around its middle element,
    /// which moves up into `parent`, which is not full.
    @inlinable
    static func _splitChild(_ parent: _BTreeNode<Key, Value>, _ index: Int) {
        let t = minimumDegree
        let child = parent._header.pointee.children[index]
        let right = _BTreeNode<Key, Value>.make(capacity: maxElements)
        child.moveElements(from: t, appendingTo: right)
        let middle = child.removeElement(at: t &- 1)
        var rightCount = right.elementCount
        if !child.isLeaf {
            right._header.pointee.children = ContiguousArray(child._header.pointee.children[t...])
            child._header.pointee.children.removeSubrange(t...)
            for grandchild in right._header.pointee.children {
                rightCount &+= grandchild._header.pointee.subtreeCount
            }
        }
        right._header.pointee.subtreeCount = rightCount
        child._header.pointee.subtreeCount &-= rightCount &+ 1
        parent.insertElement(middle, at: index)
        parent._header.pointee.children.insert(right, at: index &+ 1)
    }

    // MARK: Removal

    /// Removes the element whose key equals `key`, if present. O(*t* log *n*), plus O(*t*) for
    /// each node copied because another tree shares it.
    @inlinable
    mutating func remove(_ key: Key) -> _BTreeElement<Key, Value>? {
        guard let rank = rank(of: key) else { return nil }
        return remove(atRank: rank)
    }

    /// Removes the element of in-order rank `rank`. O(*t* log *n*), plus O(*t*) for each node
    /// copied because another tree shares it.
    ///
    /// - Precondition: `0 <= rank < count`.
    @inlinable
    mutating func remove(atRank rank: Int) -> _BTreeElement<Key, Value> {
        _makeRootUnique()
        let removed = Self._remove(atRank: rank, from: root)
        if root.elementCount == 0 && !root.isLeaf {
            root = root._header.pointee.children[0]
        }
        return removed
    }

    /// Removes the element of rank `rank` from the subtree of `node`, which is held by this tree
    /// alone and, unless it is the root, holds more than the fewest elements.
    @inlinable
    static func _remove(atRank rank: Int, from node: _BTreeNode<Key, Value>) -> _BTreeElement<Key, Value> {
        node._header.pointee.subtreeCount &-= 1
        if node.isLeaf { return node.removeElement(at: rank) }
        while true {
            var j = 0
            var rest = rank
            var inChild = true
            while true {
                let size = node._header.pointee.children[j].header.subtreeCount
                if rest < size { break }
                if rest == size {
                    inChild = false
                    break
                }
                rest &-= size &+ 1
                j &+= 1
            }
            if inChild {
                if node._header.pointee.children[j].elementCount > minElements {
                    _makeChildUnique(node, j)
                    return _remove(atRank: rest, from: node._header.pointee.children[j])
                }
                _fill(node, j)
                continue
            }
            // The element is `node`'s own: replace it with its predecessor or successor, taken
            // from a child that can spare one, or merge the two children around it and go on.
            _makeChildUnique(node, j)
            _makeChildUnique(node, j &+ 1)
            let left = node._header.pointee.children[j]
            if left.elementCount > minElements {
                let predecessor = _remove(atRank: left._header.pointee.subtreeCount &- 1, from: left)
                return node.replaceElement(at: j, with: predecessor)
            }
            let right = node._header.pointee.children[j &+ 1]
            if right.elementCount > minElements {
                let successor = _remove(atRank: 0, from: right)
                return node.replaceElement(at: j, with: successor)
            }
            let leftCount = left._header.pointee.subtreeCount
            _merge(node, j)
            return _remove(atRank: leftCount, from: node._header.pointee.children[j])
        }
    }

    /// Gives `node`'s child `index`, which holds the fewest elements, one more: from a sibling
    /// that can spare one, or by merging it with a sibling.
    @inlinable
    static func _fill(_ node: _BTreeNode<Key, Value>, _ index: Int) {
        if index > 0 && node._header.pointee.children[index &- 1].elementCount > minElements {
            _borrowFromLeft(node, index)
        } else if index < node.elementCount && node._header.pointee.children[index &+ 1].elementCount > minElements {
            _borrowFromRight(node, index)
        } else if index < node.elementCount {
            _merge(node, index)
        } else {
            _merge(node, index &- 1)
        }
    }

    /// Rotates an element from child `index − 1` through `node` into child `index`.
    @inlinable
    static func _borrowFromLeft(_ node: _BTreeNode<Key, Value>, _ index: Int) {
        _makeChildUnique(node, index &- 1)
        _makeChildUnique(node, index)
        let left = node._header.pointee.children[index &- 1]
        let child = node._header.pointee.children[index]
        let lifted = left.removeElement(at: left.elementCount &- 1)
        child.insertElement(node.replaceElement(at: index &- 1, with: lifted), at: 0)
        var moved = 1
        if !left.isLeaf {
            let grandchild = left._header.pointee.children.removeLast()
            moved &+= grandchild._header.pointee.subtreeCount
            child._header.pointee.children.insert(grandchild, at: 0)
        }
        left._header.pointee.subtreeCount &-= moved
        child._header.pointee.subtreeCount &+= moved
    }

    /// Rotates an element from child `index + 1` through `node` into child `index`.
    @inlinable
    static func _borrowFromRight(_ node: _BTreeNode<Key, Value>, _ index: Int) {
        _makeChildUnique(node, index)
        _makeChildUnique(node, index &+ 1)
        let child = node._header.pointee.children[index]
        let right = node._header.pointee.children[index &+ 1]
        let lifted = right.removeElement(at: 0)
        child.insertElement(node.replaceElement(at: index, with: lifted), at: child.elementCount)
        var moved = 1
        if !right.isLeaf {
            let grandchild = right._header.pointee.children.removeFirst()
            moved &+= grandchild._header.pointee.subtreeCount
            child._header.pointee.children.append(grandchild)
        }
        right._header.pointee.subtreeCount &-= moved
        child._header.pointee.subtreeCount &+= moved
    }

    /// Merges `node`'s children `index` and `index + 1`, both holding the fewest elements, with
    /// the element between them into child `index`.
    @inlinable
    static func _merge(_ node: _BTreeNode<Key, Value>, _ index: Int) {
        _makeChildUnique(node, index)
        _makeChildUnique(node, index &+ 1)
        let left = node._header.pointee.children[index]
        let right = node._header.pointee.children[index &+ 1]
        left.insertElement(node.removeElement(at: index), at: left.elementCount)
        right.moveElements(from: 0, appendingTo: left)
        if !right.isLeaf {
            left._header.pointee.children.append(contentsOf: right._header.pointee.children)
        }
        left._header.pointee.subtreeCount &+= 1 &+ right._header.pointee.subtreeCount
        node._header.pointee.children.remove(at: index &+ 1)
    }

    // MARK: Iteration

    /// The elements in key order, by a stack of the nodes on the path to the next one. The stack
    /// holds the nodes unretained; `root` keeps them all alive.
    @frozen
    @usableFromInline
    package struct Elements {
        @usableFromInline let root: _BTreeNode<Key, Value>
        @usableFromInline var nodes: ContiguousArray<Unmanaged<_BTreeNode<Key, Value>>>
        @usableFromInline var positions: ContiguousArray<Int>
        /// The leaf being read, its next position and its element count, kept out of the stack.
        @usableFromInline var leaf: Unmanaged<_BTreeNode<Key, Value>>
        @usableFromInline var leafPosition: Int
        @usableFromInline var leafCount: Int

        @inlinable
        init(_ core: _BTreeCore) {
            root = core.root
            nodes = []
            positions = []
            nodes.reserveCapacity(8)
            positions.reserveCapacity(8)
            leaf = Unmanaged.passUnretained(core.root)
            leafPosition = 0
            leafCount = 0
            _descend(Unmanaged.passUnretained(core.root))
        }

        /// Pushes the inner nodes down the left spine from `node` and makes the leaf at its foot
        /// the one being read.
        @inlinable
        mutating func _descend(_ node: Unmanaged<_BTreeNode<Key, Value>>) {
            var node = node
            while let child = node._withUnsafeGuaranteedRef({ $0.isLeaf ? nil : $0.unretainedChild(0) }) {
                nodes.append(node)
                positions.append(0)
                node = child
            }
            leaf = node
            leafPosition = 0
            leafCount = node._withUnsafeGuaranteedRef { $0.elementCount }
        }

        @inlinable
        mutating func next() -> _BTreeElement<Key, Value>? {
            if leafPosition < leafCount {
                let position = leafPosition
                leafPosition = position &+ 1
                return leaf._withUnsafeGuaranteedRef { $0.element(at: position) }
            }
            // The leaf is done: the next element is the first unread one of the nearest inner
            // node, followed by the leftmost leaf of the subtree after it.
            while let node = nodes.last {
                let last = positions.count &- 1
                let i = positions[last]
                let next: (element: _BTreeElement<Key, Value>, child: Unmanaged<_BTreeNode<Key, Value>>)? = node._withUnsafeGuaranteedRef { node in
                    i < node.elementCount ? (node.element(at: i), node.unretainedChild(i &+ 1)) : nil
                }
                if let next {
                    positions[last] = i &+ 1
                    _descend(next.child)
                    return next.element
                }
                nodes.removeLast()
                positions.removeLast()
            }
            return nil
        }
    }
}

extension _BTreeCore: @unchecked Sendable where Key: Sendable, Value: Sendable {}
extension _BTreeCore.Elements: @unchecked Sendable where Key: Sendable, Value: Sendable {}
