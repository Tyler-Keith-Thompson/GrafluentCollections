/// A trie's storage (Fredkin, 1960; de la Briandais, 1959). Vertex 0 is the root, the empty
/// prefix; every other vertex `v` extends its parent's prefix by `symbols[v − 1]`. A vertex's
/// children form a chain through `nextSiblings`, starting at `firstChildren[v]`: sorted by symbol
/// when the symbols are `Comparable`, in the order they were added otherwise. `values[v]` is the
/// value of the key ending at `v`, nil when none does, and `counts[v]` the number of keys at or
/// below `v`, so every vertex but an empty trie's root has a key at or below it.
///
/// When the symbols are bytes, a vertex with at least ``denseThreshold`` children also gets a
/// row of 256 child links, one per byte, so a lookup through it takes one step instead of a walk
/// along the chain; the chain stays, for order. `denseRows[v]` is that row's number, −1 for none.
///
/// A removal prunes the vertices left with no key below them and fills each one's slot with the
/// last vertex, redirecting the links to it.
@frozen
@usableFromInline
package struct _TrieCore<Symbol: Hashable, Value> {
    @usableFromInline package var symbols: ContiguousArray<Symbol>
    @usableFromInline package var parents: ContiguousArray<Int32>
    @usableFromInline package var firstChildren: ContiguousArray<Int32>
    @usableFromInline package var nextSiblings: ContiguousArray<Int32>
    @usableFromInline package var counts: ContiguousArray<Int32>
    @usableFromInline package var values: ContiguousArray<Value?>
    /// Each vertex's row in `denseChildren`, or −1; empty unless the symbols are bytes.
    @usableFromInline package var denseRows: ContiguousArray<Int32>
    /// Rows of 256 child links, each the child along that byte or −1.
    @usableFromInline package var denseChildren: ContiguousArray<Int32>
    /// Rows no vertex uses, every link in them −1.
    @usableFromInline package var freeRows: ContiguousArray<Int32>

    /// Whether vertices with many children get a row of byte-indexed links.
    @inlinable
    static var usesDenseRows: Bool { Symbol.self == UInt8.self }

    /// The number of children at which a vertex gets a row.
    @inlinable
    static var denseThreshold: Int { 8 }

    /// The link in row `row` for `symbol`, a byte.
    @inlinable @inline(__always)
    static func denseSlot(_ row: Int32, _ symbol: Symbol) -> Int {
        Int(row) &<< 8 | Int(unsafeBitCast(symbol, to: UInt8.self))
    }

    /// The trie holding no keys: the root alone.
    @inlinable
    init() {
        symbols = []
        parents = [-1]
        firstChildren = [-1]
        nextSiblings = [-1]
        counts = [0]
        values = ContiguousArray(repeating: nil, count: 1)
        denseRows = Self.usesDenseRows ? [-1] : []
        denseChildren = []
        freeRows = []
    }

    /// The number of keys.
    @inlinable
    package var count: Int { Int(counts[0]) }

    /// The number of vertices, the root included.
    @inlinable
    package var vertexCount: Int { parents.count }

    // MARK: Reads

    /// The child of `vertex` along `symbol`, or −1. O(*σ*) for *σ* children.
    @inlinable
    func child(of vertex: Int32, _ symbol: Symbol) -> Int32 {
        if Self.usesDenseRows {
            let row = denseRows[Int(vertex)]
            if row >= 0 { return denseChildren[Self.denseSlot(row, symbol)] }
        }
        var child = firstChildren[Int(vertex)]
        while child >= 0 && symbols[Int(child) &- 1] != symbol {
            child = nextSiblings[Int(child)]
        }
        return child
    }

    /// The vertex whose prefix is `key`, or −1 when no key starts with it.
    @inlinable
    package func vertex(for key: some Sequence<Symbol>) -> Int32 {
        symbols.withUnsafeBufferPointer { symbols in
            firstChildren.withUnsafeBufferPointer { firstChildren in
                nextSiblings.withUnsafeBufferPointer { nextSiblings in
                    if Self.usesDenseRows {
                        return denseRows.withUnsafeBufferPointer { denseRows in
                            denseChildren.withUnsafeBufferPointer { denseChildren in
                                var vertex: Int32 = 0
                                for symbol in key {
                                    let row = denseRows[Int(vertex)]
                                    var child: Int32
                                    if row >= 0 {
                                        child = denseChildren[Self.denseSlot(row, symbol)]
                                    } else {
                                        child = firstChildren[Int(vertex)]
                                        while child >= 0 && symbols[Int(child) &- 1] != symbol {
                                            child = nextSiblings[Int(child)]
                                        }
                                    }
                                    if child < 0 { return -1 }
                                    vertex = child
                                }
                                return vertex
                            }
                        }
                    }
                    var vertex: Int32 = 0
                    for symbol in key {
                        var child = firstChildren[Int(vertex)]
                        while child >= 0 && symbols[Int(child) &- 1] != symbol {
                            child = nextSiblings[Int(child)]
                        }
                        if child < 0 { return -1 }
                        vertex = child
                    }
                    return vertex
                }
            }
        }
    }

    /// The value of `key`, or nil when the trie doesn't hold it.
    @inlinable
    package func value(forKey key: some Sequence<Symbol>) -> Value? {
        let vertex = vertex(for: key)
        return vertex < 0 ? nil : values[Int(vertex)]
    }

    /// The deepest vertex along `query` at which a key ends, or −1 when none does.
    @inlinable
    package func longestKeyVertex(along query: some Sequence<Symbol>) -> Int32 {
        var vertex: Int32 = 0
        var found: Int32 = values[0] == nil ? -1 : 0
        for symbol in query {
            vertex = child(of: vertex, symbol)
            if vertex < 0 { break }
            if values[Int(vertex)] != nil { found = vertex }
        }
        return found
    }

    /// The prefix that `vertex` stands for. O(depth).
    @inlinable
    package func key(of vertex: Int32) -> [Symbol] {
        var key: [Symbol] = []
        var v = vertex
        while v > 0 {
            key.append(symbols[Int(v) &- 1])
            v = parents[Int(v)]
        }
        key.reverse()
        return key
    }

    // MARK: Mutations

    /// Sets the value of `key`, adding the key when absent.
    ///
    /// - Returns: The value it replaced, or nil when the key was added.
    @inlinable
    package mutating func updateValue(_ value: Value, forKey key: some Sequence<Symbol>) -> Value? {
        let vertex = _makeVertex(for: key)
        let old = values[Int(vertex)]
        values[Int(vertex)] = value
        if old == nil { _addToCounts(from: vertex, 1) }
        return old
    }

    /// Adds `key` with `value` unless the trie holds it.
    ///
    /// - Returns: Whether it was added, and the vertex where the key ends.
    @inlinable
    package mutating func insert(_ key: some Sequence<Symbol>, _ value: Value) -> (inserted: Bool, vertex: Int32) {
        let vertex = _makeVertex(for: key)
        guard values[Int(vertex)] == nil else { return (false, vertex) }
        values[Int(vertex)] = value
        _addToCounts(from: vertex, 1)
        return (true, vertex)
    }

    /// Removes `key`, pruning the vertices left with no key below them.
    ///
    /// - Returns: The key's value, or nil when the trie doesn't hold it.
    @inlinable
    package mutating func removeValue(forKey key: some Sequence<Symbol>) -> Value? {
        let found = vertex(for: key)
        guard found >= 0, let old = values[Int(found)] else { return nil }
        values[Int(found)] = nil
        _addToCounts(from: found, -1)
        var vertex = found
        while vertex > 0 && counts[Int(vertex)] == 0 {
            var parent = parents[Int(vertex)]
            _unlink(vertex, from: parent)
            if _delete(vertex) == parent {
                parent = vertex
            }
            vertex = parent
        }
        return old
    }

    /// The vertex for `key`, adding the vertices along it that are missing.
    @inlinable
    mutating func _makeVertex(for key: some Sequence<Symbol>) -> Int32 {
        var vertex: Int32 = 0
        for symbol in key {
            if Self.usesDenseRows {
                let row = denseRows[Int(vertex)]
                if row >= 0 {
                    let slot = Self.denseSlot(row, symbol)
                    let child = denseChildren[slot]
                    if child >= 0 {
                        vertex = child
                        continue
                    }
                    // The chain is in byte order, so the new child follows the nearest smaller
                    // byte present in the row.
                    let rowStart = Int(row) &<< 8
                    var previous: Int32 = -1
                    var k = slot
                    while k > rowStart {
                        k &-= 1
                        if denseChildren[k] >= 0 {
                            previous = denseChildren[k]
                            break
                        }
                    }
                    let next = previous < 0 ? firstChildren[Int(vertex)] : nextSiblings[Int(previous)]
                    vertex = _addVertex(parent: vertex, symbol: symbol, previous: previous, next: next, siblingCount: Self.denseThreshold)
                    continue
                }
            }
            var previous: Int32 = -1
            var siblingCount = 0
            var child = firstChildren[Int(vertex)]
            while child >= 0 && symbols[Int(child) &- 1] != symbol {
                previous = child
                siblingCount &+= 1
                child = nextSiblings[Int(child)]
            }
            if child >= 0 {
                vertex = child
                continue
            }
            var next: Int32 = -1
            if let order = Symbol.self as? any Comparable.Type {
                (previous, next) = _insertionPoint(of: symbol, under: vertex, order)
            }
            vertex = _addVertex(parent: vertex, symbol: symbol, previous: previous, next: next, siblingCount: siblingCount)
        }
        return vertex
    }

    /// Where `symbol` goes in the sorted chain of `parent`'s children: between `previous` and
    /// `next`, −1 for the chain's ends. `Order` is `Symbol`, found to be `Comparable` at run time.
    @inlinable
    func _insertionPoint<Order: Comparable>(
        of symbol: Symbol,
        under parent: Int32,
        _: Order.Type
    ) -> (previous: Int32, next: Int32) {
        let ordered = unsafeBitCast(symbol, to: Order.self)
        var previous: Int32 = -1
        var child = firstChildren[Int(parent)]
        while child >= 0 && unsafeBitCast(symbols[Int(child) &- 1], to: Order.self) < ordered {
            previous = child
            child = nextSiblings[Int(child)]
        }
        return (previous, child)
    }

    /// A new childless vertex under `parent`, between `previous` and `next` in its chain, beside
    /// `siblingCount` children already there.
    @inlinable
    mutating func _addVertex(parent: Int32, symbol: Symbol, previous: Int32, next: Int32, siblingCount: Int) -> Int32 {
        precondition(parents.count < Int(Int32.max), "A trie holds fewer than 2³¹ − 1 vertices")
        let vertex = Int32(truncatingIfNeeded: parents.count)
        symbols.append(symbol)
        parents.append(parent)
        firstChildren.append(-1)
        nextSiblings.append(next)
        counts.append(0)
        values.append(nil)
        if previous < 0 {
            firstChildren[Int(parent)] = vertex
        } else {
            nextSiblings[Int(previous)] = vertex
        }
        if Self.usesDenseRows {
            denseRows.append(-1)
            let row = denseRows[Int(parent)]
            if row >= 0 {
                denseChildren[Self.denseSlot(row, symbol)] = vertex
            } else if siblingCount &+ 1 >= Self.denseThreshold {
                _addDenseRow(parent)
            }
        }
        return vertex
    }

    /// Gives `parent`, which has ``denseThreshold`` children, a row of byte-indexed links.
    @inlinable
    mutating func _addDenseRow(_ parent: Int32) {
        let row: Int32
        if let free = freeRows.popLast() {
            row = free
        } else {
            row = Int32(truncatingIfNeeded: denseChildren.count &>> 8)
            denseChildren.append(contentsOf: repeatElement(-1, count: 256))
        }
        denseRows[Int(parent)] = row
        var child = firstChildren[Int(parent)]
        while child >= 0 {
            denseChildren[Self.denseSlot(row, symbols[Int(child) &- 1])] = child
            child = nextSiblings[Int(child)]
        }
    }

    /// Adds `delta` to the counts of `vertex` and every vertex above it.
    @inlinable
    mutating func _addToCounts(from vertex: Int32, _ delta: Int32) {
        var v = vertex
        while v >= 0 {
            counts[Int(v)] &+= delta
            v = parents[Int(v)]
        }
    }

    /// Takes `vertex` out of its parent's chain of children.
    @inlinable
    mutating func _unlink(_ vertex: Int32, from parent: Int32) {
        if Self.usesDenseRows {
            let row = denseRows[Int(parent)]
            if row >= 0 { denseChildren[Self.denseSlot(row, symbols[Int(vertex) &- 1])] = -1 }
        }
        let next = nextSiblings[Int(vertex)]
        if firstChildren[Int(parent)] == vertex {
            firstChildren[Int(parent)] = next
            return
        }
        var sibling = firstChildren[Int(parent)]
        while nextSiblings[Int(sibling)] != vertex {
            sibling = nextSiblings[Int(sibling)]
        }
        nextSiblings[Int(sibling)] = next
    }

    /// Deletes `vertex`, unlinked and childless, by moving the last vertex into its slot.
    ///
    /// - Returns: The vertex that moved into the slot, or −1 when `vertex` was the last.
    @inlinable
    @discardableResult
    mutating func _delete(_ vertex: Int32) -> Int32 {
        let last = Int32(truncatingIfNeeded: parents.count &- 1)
        let v = Int(vertex)
        if Self.usesDenseRows {
            // A childless vertex's row holds no links, so it is free for another.
            let row = denseRows[v]
            if row >= 0 { freeRows.append(row) }
            if vertex != last {
                let l = Int(last)
                denseRows[v] = denseRows[l]
                let parentRow = denseRows[Int(parents[l])]
                if parentRow >= 0 { denseChildren[Self.denseSlot(parentRow, symbols[l &- 1])] = vertex }
            }
            denseRows.removeLast()
        }
        if vertex != last {
            let l = Int(last)
            symbols.swapAt(v &- 1, l &- 1)
            parents[v] = parents[l]
            firstChildren[v] = firstChildren[l]
            nextSiblings[v] = nextSiblings[l]
            counts[v] = counts[l]
            values.swapAt(v, l)
            let parent = parents[v]
            if firstChildren[Int(parent)] == last {
                firstChildren[Int(parent)] = vertex
            } else {
                var sibling = firstChildren[Int(parent)]
                while nextSiblings[Int(sibling)] != last {
                    sibling = nextSiblings[Int(sibling)]
                }
                nextSiblings[Int(sibling)] = vertex
            }
            var child = firstChildren[v]
            while child >= 0 {
                parents[Int(child)] = vertex
                child = nextSiblings[Int(child)]
            }
        }
        symbols.removeLast()
        parents.removeLast()
        firstChildren.removeLast()
        nextSiblings.removeLast()
        counts.removeLast()
        values.removeLast()
        return vertex == last ? -1 : last
    }

    // MARK: Traversal

    /// The keys at or below a vertex with their values, in preorder: a key before the keys it is
    /// a prefix of, and children in chain order. O(1) per vertex, plus a copy of each key.
    @frozen
    @usableFromInline
    package struct Preorder {
        @usableFromInline let core: _TrieCore
        @usableFromInline let start: Int32
        /// The vertex to visit next, −1 when done, and the prefix it stands for.
        @usableFromInline var vertex: Int32
        @usableFromInline var key: [Symbol]

        @inlinable
        init(_ core: _TrieCore, from start: Int32) {
            self.core = core
            self.start = start
            vertex = start
            key = start > 0 ? core.key(of: start) : []
        }

        @inlinable
        package mutating func next() -> (key: [Symbol], value: Value)? {
            while vertex >= 0 {
                let current = Int(vertex)
                let value = core.values[current]
                let found = value == nil ? nil : key
                _advance()
                if let value, let found {
                    return (found, value)
                }
            }
            return nil
        }

        /// Moves to the next vertex in preorder within the start's subtree.
        @inlinable
        mutating func _advance() {
            let child = core.firstChildren[Int(vertex)]
            if child >= 0 {
                vertex = child
                key.append(core.symbols[Int(child) &- 1])
                return
            }
            while vertex != start && core.nextSiblings[Int(vertex)] < 0 {
                vertex = core.parents[Int(vertex)]
                key.removeLast()
            }
            if vertex == start {
                vertex = -1
                return
            }
            vertex = core.nextSiblings[Int(vertex)]
            key[key.count &- 1] = core.symbols[Int(vertex) &- 1]
        }
    }
}

extension _TrieCore: Sendable where Symbol: Sendable, Value: Sendable {}
extension _TrieCore.Preorder: Sendable where Symbol: Sendable, Value: Sendable {}
