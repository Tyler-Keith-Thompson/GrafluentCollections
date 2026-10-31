/// One key of a B-tree with its value.
@frozen
@usableFromInline
package struct _BTreeElement<Key, Value> {
    @usableFromInline package var key: Key
    @usableFromInline package var value: Value

    @inlinable
    init(key: Key, value: Value) {
        self.key = key
        self.value = value
    }
}

extension _BTreeElement: Sendable where Key: Sendable, Value: Sendable {}

/// What a node records beside its elements: how many it holds, how many its whole subtree holds,
/// and its children, none for a leaf and one more than its elements otherwise.
@frozen
@usableFromInline
package struct _BTreeHeader<Key, Value> {
    @usableFromInline package var elementCount: Int
    @usableFromInline package var subtreeCount: Int
    @usableFromInline package var children: ContiguousArray<_BTreeNode<Key, Value>>

    @inlinable
    init(elementCount: Int, subtreeCount: Int, children: ContiguousArray<_BTreeNode<Key, Value>>) {
        self.elementCount = elementCount
        self.subtreeCount = subtreeCount
        self.children = children
    }
}

/// A B-tree vertex: up to `capacity` elements in ascending key order, stored inline in one
/// allocation, and the references to its children in its header. Nodes are shared between copies
/// of a tree; a mutation copies only the nodes it changes that another copy also holds.
@usableFromInline
package final class _BTreeNode<Key, Value>: ManagedBuffer<_BTreeHeader<Key, Value>, _BTreeElement<Key, Value>> {
    /// An empty node with room for `capacity` elements.
    @inlinable
    static func make(capacity: Int, children: ContiguousArray<_BTreeNode> = []) -> _BTreeNode {
        let buffer = create(minimumCapacity: capacity) { _ in
            _BTreeHeader(elementCount: 0, subtreeCount: 0, children: children)
        }
        return unsafeDowncast(buffer, to: _BTreeNode.self)
    }

    deinit {
        // A class's deinit runs unspecialized, so deinitializing trivial elements one by one
        // through their value witness would cost a call each for nothing.
        guard !_isPOD(_BTreeElement<Key, Value>.self) else { return }
        _ = withUnsafeMutablePointers { header, elements in
            elements.deinitialize(count: header.pointee.elementCount)
        }
    }

    /// The header's address. A node never moves, so the address is good for as long as the node
    /// lives; reading through it skips the exclusivity check a stored class property costs.
    @inlinable
    var _header: UnsafeMutablePointer<_BTreeHeader<Key, Value>> {
        withUnsafeMutablePointerToHeader { $0 }
    }

    /// Child `index`, unretained: valid while the tree holding this node lives.
    @inlinable
    func unretainedChild(_ index: Int) -> Unmanaged<_BTreeNode> {
        _header.pointee.children.withUnsafeBufferPointer { Unmanaged.passUnretained($0[index]) }
    }

    /// The element count of child `index`'s subtree.
    @inlinable
    func childSubtreeCount(_ index: Int) -> Int {
        _header.pointee.children.withUnsafeBufferPointer { children in
            children[index]._header.pointee.subtreeCount
        }
    }

    /// The elements in the subtrees of the children before `index`.
    @inlinable
    func childCount(below index: Int) -> Int {
        _header.pointee.children.withUnsafeBufferPointer { children in
            var total = 0
            var c = 0
            while c < index {
                total &+= children[c]._header.pointee.subtreeCount
                c &+= 1
            }
            return total
        }
    }

    @inlinable
    package var elementCount: Int { _header.pointee.elementCount }

    @inlinable
    var isLeaf: Bool { _header.pointee.children.isEmpty }

    /// A copy of this node with room for `capacity` elements, sharing its children.
    @inlinable
    func copy(capacity: Int) -> _BTreeNode {
        let node = _BTreeNode.make(capacity: capacity, children: _header.pointee.children)
        let count = elementCount
        withUnsafeMutablePointerToElements { source in
            node.withUnsafeMutablePointerToElements { destination in
                destination.initialize(from: source, count: count)
            }
        }
        node._header.pointee.elementCount = count
        node._header.pointee.subtreeCount = _header.pointee.subtreeCount
        return node
    }

    /// The element at `index`.
    @inlinable
    func element(at index: Int) -> _BTreeElement<Key, Value> {
        withUnsafeMutablePointerToElements { $0[index] }
    }

    /// The key at `index`.
    @inlinable
    package func key(at index: Int) -> Key {
        withUnsafeMutablePointerToElements { $0[index].key }
    }

    /// Replaces the element at `index`; returns the one it held.
    @inlinable
    func replaceElement(at index: Int, with element: _BTreeElement<Key, Value>) -> _BTreeElement<Key, Value> {
        withUnsafeMutablePointerToElements { elements in
            let old = elements.advanced(by: index).move()
            elements.advanced(by: index).initialize(to: element)
            return old
        }
    }

    /// Replaces the value at `index`; returns the one it held.
    @inlinable
    func replaceValue(at index: Int, with value: Value) -> Value {
        withUnsafeMutablePointerToElements { elements in
            let old = elements[index].value
            elements[index].value = value
            return old
        }
    }

    /// Inserts `element` at `index`, shifting the later ones up. The node must have room.
    @inlinable
    func insertElement(_ element: _BTreeElement<Key, Value>, at index: Int) {
        let count = elementCount
        withUnsafeMutablePointerToElements { elements in
            (elements + index + 1).moveInitialize(from: elements + index, count: count &- index)
            (elements + index).initialize(to: element)
        }
        _header.pointee.elementCount = count &+ 1
    }

    /// Removes and returns the element at `index`, shifting the later ones down.
    @inlinable
    func removeElement(at index: Int) -> _BTreeElement<Key, Value> {
        let count = elementCount
        let removed = withUnsafeMutablePointerToElements { elements in
            let removed = (elements + index).move()
            (elements + index).moveInitialize(from: elements + index + 1, count: count &- index &- 1)
            return removed
        }
        _header.pointee.elementCount = count &- 1
        return removed
    }

    /// Moves the elements from `start` on to the end of `other`, which must have room.
    @inlinable
    func moveElements(from start: Int, appendingTo other: _BTreeNode) {
        let count = elementCount
        let moved = count &- start
        let otherCount = other.elementCount
        withUnsafeMutablePointerToElements { source in
            other.withUnsafeMutablePointerToElements { destination in
                (destination + otherCount).moveInitialize(from: source + start, count: moved)
            }
        }
        _header.pointee.elementCount = start
        other._header.pointee.elementCount = otherCount &+ moved
    }

    /// The index of the first element whose key is not less than `key`, or with `orEqual`,
    /// greater than `key`; `elementCount` when there is none.
    @inlinable
    func boundary(of key: Key, orEqual: Bool) -> Int where Key: Comparable {
        withUnsafeMutablePointerToElements { elements in
            // Branch-free: each step halves the range with a select, not a jump a random key
            // would mispredict.
            var first = 0
            var length = elementCount
            while length > 0 {
                let half = length >> 1
                let candidate = elements[first &+ half].key
                let goesRight = orEqual ? !(key < candidate) : candidate < key
                first = goesRight ? first &+ half &+ 1 : first
                length = goesRight ? length &- half &- 1 : half
            }
            return first
        }
    }
}
