@_exported import CollectionErrors

/// A shared table of reduced ordered binary decision diagrams: Boolean functions of a fixed number
/// of variables, each a directed acyclic graph whose vertices test one variable and branch to a
/// low child (the variable false) and a high child (true), down to the constants (Bryant,
/// "Graph-Based Algorithms for Boolean Function Manipulation", 1986).
///
/// Variables are tested in index order, 0 nearest the root. The table never holds two vertices
/// that test the same variable with the same children, nor a vertex whose children are equal, so
/// each function has one vertex: two ``Function`` values are equal exactly when they are the same
/// function.
///
/// ```swift
/// var diagram = BinaryDecisionDiagram(variableCount: 3)
/// let x0 = diagram.variable(0), x1 = diagram.variable(1), x2 = diagram.variable(2)
/// let f = diagram.or(diagram.and(x0, x1), x2)          // x0 ∧ x1 ∨ x2
/// diagram.satisfyingAssignmentCount(of: f)              // 5
/// diagram.vertexCount(of: f)                            // 5: x0, x1, x2 and both constants
/// let g = diagram.restrict(f, variable: 2, to: false)   // x0 ∧ x1
/// g == diagram.and(x0, x1)                              // true
/// ```
///
/// Functions are built by the mutating methods, which add vertices to the table and leave every
/// existing function as it was; a function belongs to the table it was built in and its copies.
/// The table keeps every vertex it has made.
@frozen
public struct BinaryDecisionDiagram {
    /// A Boolean function in a ``BinaryDecisionDiagram``: the vertex at its root.
    @frozen
    public struct Function: Hashable, Sendable {
        @usableFromInline let _vertex: Int32

        @inlinable
        init(_ vertex: Int32) {
            _vertex = vertex
        }
    }

    /// The number of variables the functions range over.
    public let variableCount: Int

    /// Each vertex's variable; the constants', at 0 for false and 1 for true, is `variableCount`.
    @usableFromInline var _variables: ContiguousArray<Int32>
    /// Each vertex's child for its variable false; the constants' are themselves.
    @usableFromInline var _lows: ContiguousArray<Int32>
    /// Each vertex's child for its variable true; the constants' are themselves.
    @usableFromInline var _highs: ContiguousArray<Int32>
    /// The unique table: open addressing over a power-of-two count of slots, each a vertex or −1.
    @usableFromInline var _unique: ContiguousArray<Int32>
    /// The computed table: a direct-mapped cache from an operator and two vertices, packed into
    /// one key, to the vertex of their result.
    @usableFromInline var _cacheKeys: ContiguousArray<UInt64>
    @usableFromInline var _cacheResults: ContiguousArray<Int32>
    @usableFromInline var _cacheLookups: Int
    @usableFromInline var _cacheHits: Int

    /// An empty table over `variableCount` variables, holding only the constants.
    ///
    /// - Parameter variableCount: The number of variables. Traps unless it is in
    ///   `0 ..< 1 << 20`.
    public init(variableCount: Int) {
        precondition(variableCount >= 0 && variableCount < 1 << 20, "Variable count out of range")
        self.variableCount = variableCount
        let terminal = Int32(truncatingIfNeeded: variableCount)
        _variables = [terminal, terminal]
        _lows = [0, 1]
        _highs = [0, 1]
        _unique = ContiguousArray(repeating: -1, count: 1 << 10)
        _cacheKeys = ContiguousArray(repeating: .max, count: 1 << 12)
        _cacheResults = ContiguousArray(repeating: 0, count: 1 << 12)
        _cacheLookups = 0
        _cacheHits = 0
    }

    // MARK: - Building functions

    /// The constant function `value`.
    public func constant(_ value: Bool) -> Function {
        Function(value ? 1 : 0)
    }

    /// The function that is the variable at `index`.
    ///
    /// - Parameter index: Traps unless it is in `0 ..< variableCount`; use
    ///   ``variable(checked:)`` to throw instead.
    /// - Complexity: O(1) expected.
    public mutating func variable(_ index: Int) -> Function {
        precondition(index >= 0 && index < variableCount, "Variable index out of range")
        return Function(_vertex(Int32(truncatingIfNeeded: index), low: 0, high: 1))
    }

    /// The function that is the variable at `index`, throwing instead of trapping on an index out
    /// of range.
    ///
    /// - Parameter index: The variable's index.
    /// - Throws: ``IndexOutOfRange`` unless `index` is in `0 ..< variableCount`.
    /// - Complexity: O(1) expected.
    public mutating func variable(checked index: Int) throws(IndexOutOfRange) -> Function {
        guard index >= 0 && index < variableCount else { throw IndexOutOfRange() }
        return variable(index)
    }

    /// `f` and `g` combined by `operator`: the function whose value at every assignment is the
    /// operator applied to theirs.
    ///
    /// - Parameters:
    ///   - operator: The binary Boolean operator.
    ///   - f: The left operand. Traps unless it belongs to this table.
    ///   - g: The right operand. Traps unless it belongs to this table.
    /// - Complexity: O(|*f*| |*g*|) for diagrams of |*f*| and |*g*| vertices.
    public mutating func apply(_ operator: Operator, _ f: Function, _ g: Function) -> Function {
        _check(f)
        _check(g)
        return Function(_apply(`operator`.truthTable, f._vertex, g._vertex))
    }

    /// `f ∧ g`. O(|*f*| |*g*|).
    public mutating func and(_ f: Function, _ g: Function) -> Function { apply(.and, f, g) }

    /// `f ∨ g`. O(|*f*| |*g*|).
    public mutating func or(_ f: Function, _ g: Function) -> Function { apply(.or, f, g) }

    /// `f ⊕ g`. O(|*f*| |*g*|).
    public mutating func xor(_ f: Function, _ g: Function) -> Function { apply(.xor, f, g) }

    /// `f → g`. O(|*f*| |*g*|).
    public mutating func implies(_ f: Function, _ g: Function) -> Function { apply(.implication, f, g) }

    /// `¬f`. O(|*f*|).
    public mutating func not(_ f: Function) -> Function { apply(.xor, f, constant(true)) }

    /// The function that is `g` where `f` holds and `h` elsewhere.
    ///
    /// - Complexity: O(|*f*| |*g*| |*h*|).
    public mutating func ifThenElse(_ f: Function, then g: Function, else h: Function) -> Function {
        let whenTrue = and(f, g)
        let whenFalse = apply(.converseNonimplication, f, h)
        return or(whenTrue, whenFalse)
    }

    /// `f` with the variable at `index` fixed to `value`.
    ///
    /// - Parameters:
    ///   - f: The function. Traps unless it belongs to this table.
    ///   - index: The variable. Traps unless it is in `0 ..< variableCount`.
    ///   - value: The value it is fixed to.
    /// - Complexity: O(|*f*|).
    public mutating func restrict(_ f: Function, variable index: Int, to value: Bool) -> Function {
        _check(f)
        precondition(index >= 0 && index < variableCount, "Variable index out of range")
        var memo: [Int32: Int32] = [:]
        return Function(_restrict(f._vertex, Int32(truncatingIfNeeded: index), value, &memo))
    }

    /// `f` with the variables at `indices` quantified existentially: true where some value of
    /// them makes `f` true.
    ///
    /// - Parameters:
    ///   - indices: The variables. Traps unless each is in `0 ..< variableCount`.
    ///   - f: The function. Traps unless it belongs to this table.
    /// - Complexity: O(|*f*|²) per variable.
    public mutating func exists(_ indices: some Sequence<Int>, in f: Function) -> Function {
        var result = f
        for index in indices {
            let low = restrict(result, variable: index, to: false)
            let high = restrict(result, variable: index, to: true)
            result = or(low, high)
        }
        return result
    }

    /// `f` with the variables at `indices` quantified universally: true where every value of them
    /// makes `f` true.
    ///
    /// - Parameters:
    ///   - indices: The variables. Traps unless each is in `0 ..< variableCount`.
    ///   - f: The function. Traps unless it belongs to this table.
    /// - Complexity: O(|*f*|²) per variable.
    public mutating func forall(_ indices: some Sequence<Int>, in f: Function) -> Function {
        var result = f
        for index in indices {
            let low = restrict(result, variable: index, to: false)
            let high = restrict(result, variable: index, to: true)
            result = and(low, high)
        }
        return result
    }

    // MARK: - Reading functions

    /// The function's value at `assignment`.
    ///
    /// - Parameters:
    ///   - f: The function. Traps unless it belongs to this table.
    ///   - assignment: A value per variable. Traps unless it has `variableCount` values.
    /// - Complexity: O(`variableCount`).
    public func evaluate(_ f: Function, at assignment: [Bool]) -> Bool {
        _check(f)
        precondition(assignment.count == variableCount, "An assignment needs one value per variable")
        var vertex = Int(f._vertex)
        while vertex > 1 {
            vertex = Int(assignment[Int(_variables[vertex])] ? _highs[vertex] : _lows[vertex])
        }
        return vertex == 1
    }

    /// The number of assignments to all `variableCount` variables that make `f` true.
    ///
    /// A `Double`, exact while the count is below 2⁵³, since it can reach 2^`variableCount`.
    ///
    /// - Parameter f: The function. Traps unless it belongs to this table.
    /// - Complexity: O(|*f*| log |*f*|).
    public func satisfyingAssignmentCount(of f: Function) -> Double {
        _check(f)
        // Children come before their parents, so ascending vertex order counts bottom-up.
        let vertices = _reachable(from: f._vertex)
        var counts: [Int32: Double] = [0: 0, 1: 1]
        let terminal = Int32(truncatingIfNeeded: variableCount)
        func level(_ vertex: Int32) -> Int32 { vertex <= 1 ? terminal : _variables[Int(vertex)] }
        for vertex in vertices where vertex > 1 {
            let variable = _variables[Int(vertex)]
            let low = _lows[Int(vertex)]
            let high = _highs[Int(vertex)]
            let lowCount = counts[low]! * _power(level(low) &- variable &- 1)
            let highCount = counts[high]! * _power(level(high) &- variable &- 1)
            counts[vertex] = lowCount + highCount
        }
        return counts[f._vertex]! * _power(level(f._vertex))
    }

    /// An assignment that makes `f` true, its free variables false, or nil when `f` is false.
    ///
    /// - Parameter f: The function. Traps unless it belongs to this table.
    /// - Returns: A value per variable.
    /// - Complexity: O(`variableCount`).
    public func anySatisfyingAssignment(of f: Function) -> [Bool]? {
        _check(f)
        guard f._vertex != 0 else { return nil }
        var assignment = [Bool](repeating: false, count: variableCount)
        var vertex = Int(f._vertex)
        while vertex > 1 {
            // A reduced diagram reaches true from every vertex but false.
            if _lows[vertex] != 0 {
                vertex = Int(_lows[vertex])
            } else {
                assignment[Int(_variables[vertex])] = true
                vertex = Int(_highs[vertex])
            }
        }
        return assignment
    }

    /// The variables `f` depends on, ascending.
    ///
    /// - Parameter f: The function. Traps unless it belongs to this table.
    /// - Complexity: O(|*f*| log |*f*|).
    public func support(of f: Function) -> [Int] {
        _check(f)
        var variables = Set<Int32>()
        for vertex in _reachable(from: f._vertex) where vertex > 1 {
            variables.insert(_variables[Int(vertex)])
        }
        return variables.map { Int($0) }.sorted()
    }

    /// The number of vertices in `f`'s diagram, the constants it reaches included.
    ///
    /// - Parameter f: The function. Traps unless it belongs to this table.
    /// - Complexity: O(|*f*| log |*f*|).
    public func vertexCount(of f: Function) -> Int {
        _check(f)
        return _reachable(from: f._vertex).count
    }

    /// The number of vertices in the table, the constants included.
    public var tableVertexCount: Int { _variables.count }

    /// How often ``apply(_:_:_:)`` found a result in its computed table.
    public var computedTableStatistics: ComputedTableStatistics {
        ComputedTableStatistics(lookups: _cacheLookups, hits: _cacheHits)
    }

    /// Counts of computed-table lookups; see ``BinaryDecisionDiagram/computedTableStatistics``.
    @frozen
    public struct ComputedTableStatistics: Hashable, Sendable {
        /// The lookups made, one per recursive step that was not settled by its operands alone.
        public var lookups: Int
        /// The lookups that found their result.
        public var hits: Int

        @inlinable
        public init(lookups: Int, hits: Int) {
            self.lookups = lookups
            self.hits = hits
        }
    }

    // MARK: - Internals

    @usableFromInline
    func _check(_ f: Function) {
        precondition(f._vertex >= 0 && Int(f._vertex) < _variables.count, "The function belongs to another diagram")
    }

    /// 2 raised to `exponent`.
    func _power(_ exponent: Int32) -> Double {
        Double(sign: .plus, exponent: Int(exponent), significand: 1)
    }

    /// The vertices reachable from `root`, ascending.
    func _reachable(from root: Int32) -> [Int32] {
        var seen = Set<Int32>([root])
        var stack = [root]
        while let vertex = stack.popLast() {
            guard vertex > 1 else { continue }
            for child in [_lows[Int(vertex)], _highs[Int(vertex)]] where seen.insert(child).inserted {
                stack.append(child)
            }
        }
        return seen.sorted()
    }

    static func _hash(_ variable: Int32, _ low: Int32, _ high: Int32) -> Int {
        var x = UInt64(UInt32(bitPattern: variable)) &* 0x9E37_79B9_7F4A_7C15
        x ^= UInt64(UInt32(bitPattern: low)) &* 0xC2B2_AE3D_27D4_EB4F
        x ^= UInt64(UInt32(bitPattern: high)) &* 0x1656_67B1_9E37_79F9
        x ^= x >> 29
        x &*= 0xBF58_476D_1CE4_E5B9
        x ^= x >> 32
        return Int(truncatingIfNeeded: x)
    }

    /// The vertex testing `variable` with children `low` and `high`: `low` itself when the two
    /// are equal, else the one in the unique table, added if new.
    mutating func _vertex(_ variable: Int32, low: Int32, high: Int32) -> Int32 {
        if low == high { return low }
        let mask = _unique.count &- 1
        var slot = Self._hash(variable, low, high) & mask
        while true {
            let vertex = _unique[slot]
            if vertex < 0 { break }
            let v = Int(vertex)
            if _variables[v] == variable && _lows[v] == low && _highs[v] == high {
                return vertex
            }
            slot = (slot &+ 1) & mask
        }
        let vertex = Int32(truncatingIfNeeded: _variables.count)
        precondition(_variables.count < 1 << 30, "A binary decision diagram holds at most 2³⁰ vertices")
        _variables.append(variable)
        _lows.append(low)
        _highs.append(high)
        _unique[slot] = vertex
        if _variables.count &* 2 > _unique.count {
            _growUniqueTable()
        }
        return vertex
    }

    @inline(never)
    mutating func _growUniqueTable() {
        let capacity = _unique.count &* 2
        var unique = ContiguousArray<Int32>(repeating: -1, count: capacity)
        let mask = capacity &- 1
        for v in 2 ..< _variables.count {
            var slot = Self._hash(_variables[v], _lows[v], _highs[v]) & mask
            while unique[slot] >= 0 {
                slot = (slot &+ 1) & mask
            }
            unique[slot] = Int32(truncatingIfNeeded: v)
        }
        _unique = unique
        // The computed table grows with the vertices, its entries dropped.
        if _cacheKeys.count < capacity {
            _cacheKeys = ContiguousArray(repeating: .max, count: capacity)
            _cacheResults = ContiguousArray(repeating: 0, count: capacity)
        }
    }

    /// The vertex of `f` and `g` combined by the operator whose truth table is `table`: bit
    /// `2a + b` is the result for `a` and `b`.
    mutating func _apply(_ table: UInt8, _ f: Int32, _ g: Int32) -> Int32 {
        // Settled by the operands alone.
        if f <= 1 && g <= 1 {
            return Int32((table >> UInt8(f &* 2 &+ g)) & 1)
        }
        if f <= 1 {
            // The operator with its left operand fixed is a function of g alone.
            let atFalse = (table >> UInt8(f &* 2)) & 1
            let atTrue = (table >> UInt8(f &* 2 &+ 1)) & 1
            if atFalse == atTrue { return Int32(atFalse) }
            if atTrue == 1 { return g }
        } else if g <= 1 {
            let atFalse = (table >> UInt8(g)) & 1
            let atTrue = (table >> UInt8(2 &+ g)) & 1
            if atFalse == atTrue { return Int32(atFalse) }
            if atTrue == 1 { return f }
        } else if f == g {
            let atFalse = table & 1
            let atTrue = (table >> 3) & 1
            if atFalse == atTrue { return Int32(atFalse) }
            if atTrue == 1 { return f }
        }
        // A symmetric operator's operands are put in order, so f op g and g op f share an entry.
        var (f, g) = (f, g)
        if (table >> 1) & 1 == (table >> 2) & 1 && g < f {
            swap(&f, &g)
        }
        let key = UInt64(table) << 60 | UInt64(UInt32(bitPattern: f)) << 30 | UInt64(UInt32(bitPattern: g))
        let slot = Self._hash(Int32(table), f, g) & (_cacheKeys.count &- 1)
        _cacheLookups &+= 1
        if _cacheKeys[slot] == key {
            _cacheHits &+= 1
            return _cacheResults[slot]
        }
        let fVariable = _variables[Int(f)]
        let gVariable = _variables[Int(g)]
        let variable = Swift.min(fVariable, gVariable)
        let (fLow, fHigh) = fVariable == variable ? (_lows[Int(f)], _highs[Int(f)]) : (f, f)
        let (gLow, gHigh) = gVariable == variable ? (_lows[Int(g)], _highs[Int(g)]) : (g, g)
        let low = _apply(table, fLow, gLow)
        let high = _apply(table, fHigh, gHigh)
        let result = _vertex(variable, low: low, high: high)
        // The table may have grown during the recursion.
        let resultSlot = Self._hash(Int32(table), f, g) & (_cacheKeys.count &- 1)
        _cacheKeys[resultSlot] = key
        _cacheResults[resultSlot] = result
        return result
    }

    mutating func _restrict(_ vertex: Int32, _ variable: Int32, _ value: Bool, _ memo: inout [Int32: Int32]) -> Int32 {
        let tested = _variables[Int(vertex)]
        if tested > variable { return vertex }
        if tested == variable { return value ? _highs[Int(vertex)] : _lows[Int(vertex)] }
        if let known = memo[vertex] { return known }
        let low = _restrict(_lows[Int(vertex)], variable, value, &memo)
        let high = _restrict(_highs[Int(vertex)], variable, value, &memo)
        let result = _vertex(tested, low: low, high: high)
        memo[vertex] = result
        return result
    }
}

extension BinaryDecisionDiagram: Sendable {}
