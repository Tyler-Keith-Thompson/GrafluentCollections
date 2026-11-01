// The tables a decision diagram keeps: its vertices in flat arrays, a unique table so no vertex is
// made twice, and a computed table of results already found. Binary and zero-suppressed diagrams
// share them and differ in the rule that removes a vertex.

@usableFromInline
struct _DecisionTable: Sendable {
    /// Each vertex's variable; the two constants', at 0 and 1, is one past the last variable.
    @usableFromInline var variables: ContiguousArray<Int32>
    /// Each vertex's low child; the constants' are themselves.
    @usableFromInline var lows: ContiguousArray<Int32>
    /// Each vertex's high child; the constants' are themselves.
    @usableFromInline var highs: ContiguousArray<Int32>
    /// Open addressing over a power-of-two count of slots, each a vertex or −1.
    @usableFromInline var unique: ContiguousArray<Int32>
    /// A direct-mapped cache from an operation and two vertices, packed into one key, to a vertex.
    @usableFromInline var cacheKeys: ContiguousArray<UInt64>
    @usableFromInline var cacheResults: ContiguousArray<Int32>
    @usableFromInline var cacheLookups: Int
    @usableFromInline var cacheHits: Int

    /// A table holding the two constants, past `variableCount` variables.
    init(variableCount: Int) {
        let terminal = Int32(truncatingIfNeeded: variableCount)
        variables = [terminal, terminal]
        lows = [0, 1]
        highs = [0, 1]
        unique = ContiguousArray(repeating: -1, count: 1 << 10)
        cacheKeys = ContiguousArray(repeating: .max, count: 1 << 12)
        cacheResults = ContiguousArray(repeating: 0, count: 1 << 12)
        cacheLookups = 0
        cacheHits = 0
    }

    @usableFromInline
    var count: Int { variables.count }

    static func hash(_ a: Int32, _ b: Int32, _ c: Int32) -> Int {
        var x = UInt64(UInt32(bitPattern: a)) &* 0x9E37_79B9_7F4A_7C15
        x ^= UInt64(UInt32(bitPattern: b)) &* 0xC2B2_AE3D_27D4_EB4F
        x ^= UInt64(UInt32(bitPattern: c)) &* 0x1656_67B1_9E37_79F9
        x ^= x >> 29
        x &*= 0xBF58_476D_1CE4_E5B9
        x ^= x >> 32
        return Int(truncatingIfNeeded: x)
    }

    /// The vertex testing `variable` with children `low` and `high`, from the unique table or
    /// added to it. The caller has applied its reduction rule.
    mutating func vertex(_ variable: Int32, low: Int32, high: Int32) -> Int32 {
        let mask = unique.count &- 1
        var slot = Self.hash(variable, low, high) & mask
        while true {
            let vertex = unique[slot]
            if vertex < 0 { break }
            let v = Int(vertex)
            if variables[v] == variable && lows[v] == low && highs[v] == high {
                return vertex
            }
            slot = (slot &+ 1) & mask
        }
        precondition(variables.count < 1 << 30, "A decision diagram holds at most 2³⁰ vertices")
        let vertex = Int32(truncatingIfNeeded: variables.count)
        variables.append(variable)
        lows.append(low)
        highs.append(high)
        unique[slot] = vertex
        if variables.count &* 2 > unique.count {
            grow()
        }
        return vertex
    }

    @inline(never)
    mutating func grow() {
        let capacity = unique.count &* 2
        var grown = ContiguousArray<Int32>(repeating: -1, count: capacity)
        let mask = capacity &- 1
        for v in 2 ..< variables.count {
            var slot = Self.hash(variables[v], lows[v], highs[v]) & mask
            while grown[slot] >= 0 {
                slot = (slot &+ 1) & mask
            }
            grown[slot] = Int32(truncatingIfNeeded: v)
        }
        unique = grown
        // The computed table grows with the vertices, its entries dropped.
        if cacheKeys.count < capacity {
            cacheKeys = ContiguousArray(repeating: .max, count: capacity)
            cacheResults = ContiguousArray(repeating: 0, count: capacity)
        }
    }

    /// The key for operation `operation`, below 16, on `f` and `g`.
    static func key(_ operation: UInt8, _ f: Int32, _ g: Int32) -> UInt64 {
        UInt64(operation) << 60 | UInt64(UInt32(bitPattern: f)) << 30 | UInt64(UInt32(bitPattern: g))
    }

    /// The computed result for `key`, or nil.
    mutating func cached(_ key: UInt64) -> Int32? {
        let slot = Self.hash(Int32(truncatingIfNeeded: key >> 30), Int32(truncatingIfNeeded: key & 0x3FFF_FFFF), 0) & (cacheKeys.count &- 1)
        cacheLookups &+= 1
        guard cacheKeys[slot] == key else { return nil }
        cacheHits &+= 1
        return cacheResults[slot]
    }

    mutating func store(_ key: UInt64, _ result: Int32) {
        let slot = Self.hash(Int32(truncatingIfNeeded: key >> 30), Int32(truncatingIfNeeded: key & 0x3FFF_FFFF), 0) & (cacheKeys.count &- 1)
        cacheKeys[slot] = key
        cacheResults[slot] = result
    }

    /// Keeps the constants and the vertices `roots` reach, dropping every other vertex, and returns
    /// each root's new number. The kept vertices keep their order, so children still come before
    /// their parents; the unique table is rebuilt for them and the computed table emptied.
    ///
    /// - Precondition: Every root is a vertex of this table.
    mutating func collectGarbage(keeping roots: [Int32]) -> [Int32] {
        let n = variables.count
        var kept = ContiguousArray<Bool>(repeating: false, count: n)
        kept[0] = true
        kept[1] = true
        for root in roots {
            precondition(root >= 0 && Int(root) < n, "The root is not a vertex of this table")
            kept[Int(root)] = true
        }
        // A vertex's children have lower numbers than it, so one pass downward marks all it reaches.
        var v = n &- 1
        while v >= 2 {
            if kept[v] {
                kept[Int(lows[v])] = true
                kept[Int(highs[v])] = true
            }
            v &-= 1
        }
        var renumbered = ContiguousArray<Int32>(repeating: -1, count: n)
        var newVariables = ContiguousArray<Int32>()
        var newLows = ContiguousArray<Int32>()
        var newHighs = ContiguousArray<Int32>()
        for v in 0 ..< n where kept[v] {
            renumbered[v] = Int32(truncatingIfNeeded: newVariables.count)
            newVariables.append(variables[v])
            newLows.append(v < 2 ? lows[v] : renumbered[Int(lows[v])])
            newHighs.append(v < 2 ? highs[v] : renumbered[Int(highs[v])])
        }
        variables = newVariables
        lows = newLows
        highs = newHighs
        var capacity = 1 << 10
        while capacity < variables.count &* 2 {
            capacity &*= 2
        }
        unique = ContiguousArray(repeating: -1, count: capacity)
        let mask = capacity &- 1
        for v in 2 ..< variables.count {
            var slot = Self.hash(variables[v], lows[v], highs[v]) & mask
            while unique[slot] >= 0 {
                slot = (slot &+ 1) & mask
            }
            unique[slot] = Int32(truncatingIfNeeded: v)
        }
        let cacheCapacity = Swift.max(1 << 12, capacity)
        cacheKeys = ContiguousArray(repeating: .max, count: cacheCapacity)
        cacheResults = ContiguousArray(repeating: 0, count: cacheCapacity)
        return roots.map { renumbered[Int($0)] }
    }

    /// The vertices reachable from `root`, ascending: children come before their parents.
    func reachable(from root: Int32) -> [Int32] {
        var seen = Set<Int32>([root])
        var stack = [root]
        while let vertex = stack.popLast() {
            guard vertex > 1 else { continue }
            for child in [lows[Int(vertex)], highs[Int(vertex)]] where seen.insert(child).inserted {
                stack.append(child)
            }
        }
        return seen.sorted()
    }
}
