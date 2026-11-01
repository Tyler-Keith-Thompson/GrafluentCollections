/// A shared table of zero-suppressed decision diagrams: families of sets drawn from the elements
/// `0 ..< elementCount`, each a directed acyclic graph whose vertices test one element and branch
/// to a low child (the sets without it) and a high child (the sets with it, the element removed),
/// down to the constants: the empty family and the family holding only the empty set (Minato,
/// "Zero-Suppressed BDDs for Set Manipulation in Combinatorial Problems", 1993).
///
/// Elements are tested in index order, 0 nearest the root. The table never holds two vertices
/// that test the same element with the same children, nor a vertex whose high child is the empty
/// family, so each family has one vertex: two ``Family`` values are equal exactly when they hold
/// the same sets. An element no set of a family contains never appears in its diagram, which keeps
/// the diagrams of sparse families small.
///
/// ```swift
/// var diagram = ZeroSuppressedDecisionDiagram(elementCount: 3)
/// let f = diagram.family([[0, 1], [1, 2], [2]])
/// diagram.count(of: f)                                  // 3
/// let g = diagram.including(2, in: f)                   // {{1, 2}, {2}}
/// diagram.minimalSets(of: g) == diagram.family([[2]])   // true
/// diagram.join(diagram.single(0), g)                    // {{0, 1, 2}, {0, 2}}
/// ```
///
/// Families are built by the mutating methods, which add vertices to the table and leave every
/// existing family as it was; a family belongs to the table it was built in and its copies. The
/// table keeps every vertex it has made until ``collectGarbage(keeping:)`` drops the ones no kept
/// family reaches.
@frozen
public struct ZeroSuppressedDecisionDiagram {
    /// A family of sets in a ``ZeroSuppressedDecisionDiagram``: the vertex at its root.
    @frozen
    public struct Family: Hashable, Sendable {
        @usableFromInline let _vertex: Int32

        @inlinable
        init(_ vertex: Int32) {
            _vertex = vertex
        }
    }

    /// The number of elements the sets are drawn from.
    public let elementCount: Int

    /// The vertices, the unique table and the computed table.
    @usableFromInline var _table: _DecisionTable

    /// An empty table over the elements `0 ..< elementCount`, holding only the two constants.
    ///
    /// - Parameter elementCount: The number of elements. Traps unless it is in `0 ..< 1 << 20`.
    public init(elementCount: Int) {
        precondition(elementCount >= 0 && elementCount < 1 << 20, "Element count out of range")
        self.elementCount = elementCount
        _table = _DecisionTable(variableCount: elementCount)
    }

    // MARK: - Building families

    /// The family with no sets, ∅.
    public var empty: Family { Family(0) }

    /// The family whose one set is the empty set, {∅}.
    public var unit: Family { Family(1) }

    /// The family whose one set is `{element}`.
    ///
    /// - Parameter element: Traps unless it is in `0 ..< elementCount`; use
    ///   ``single(checked:)`` to throw instead.
    /// - Complexity: O(1) expected.
    public mutating func single(_ element: Int) -> Family {
        precondition(element >= 0 && element < elementCount, "Element out of range")
        return Family(_vertex(Int32(truncatingIfNeeded: element), low: 0, high: 1))
    }

    /// The family whose one set is `{element}`, throwing instead of trapping on an element out of
    /// range.
    ///
    /// - Parameter element: The element.
    /// - Throws: ``IndexOutOfRange`` unless `element` is in `0 ..< elementCount`.
    /// - Complexity: O(1) expected.
    public mutating func single(checked element: Int) throws(IndexOutOfRange) -> Family {
        guard element >= 0 && element < elementCount else { throw IndexOutOfRange() }
        return single(element)
    }

    /// The family of the given sets; repeated sets and repeated elements within a set count once.
    ///
    /// - Parameter sets: The sets. Traps unless every element is in `0 ..< elementCount`.
    /// - Complexity: O(*k* *m* + *m* log *m*) per set for *k* sets of up to *m* elements.
    public mutating func family(_ sets: some Sequence<some Sequence<Int>>) -> Family {
        var result = empty
        for set in sets {
            var vertex: Int32 = 1
            for element in Set(set).sorted(by: >) {
                precondition(element >= 0 && element < elementCount, "Element out of range")
                vertex = _vertex(Int32(truncatingIfNeeded: element), low: 0, high: vertex)
            }
            result = union(result, Family(vertex))
        }
        return result
    }

    /// The sets in `f` or in `g`, `f ∪ g`.
    ///
    /// - Parameters:
    ///   - f: A family. Traps unless it belongs to this table.
    ///   - g: A family. Traps unless it belongs to this table.
    /// - Complexity: O(|*f*| |*g*|) for diagrams of |*f*| and |*g*| vertices.
    public mutating func union(_ f: Family, _ g: Family) -> Family {
        _check(f)
        _check(g)
        return Family(_binary(Self._union, f._vertex, g._vertex))
    }

    /// The sets in both `f` and `g`, `f ∩ g`. O(|*f*| |*g*|).
    public mutating func intersection(_ f: Family, _ g: Family) -> Family {
        _check(f)
        _check(g)
        return Family(_binary(Self._intersection, f._vertex, g._vertex))
    }

    /// The sets in `f` but not in `g`, `f ∖ g`. O(|*f*| |*g*|).
    public mutating func subtracting(_ g: Family, from f: Family) -> Family {
        _check(f)
        _check(g)
        return Family(_binary(Self._difference, f._vertex, g._vertex))
    }

    /// Every union of a set in `f` with a set in `g`, `f ⊔ g`: `{a ∪ b | a ∈ f, b ∈ g}`.
    ///
    /// Joining with ``single(_:)`` adds an element to every set.
    ///
    /// - Complexity: O(|*f*|² |*g*|²) in the worst case.
    public mutating func join(_ f: Family, _ g: Family) -> Family {
        _check(f)
        _check(g)
        return Family(_binary(Self._join, f._vertex, g._vertex))
    }

    /// Every intersection of a set in `f` with a set in `g`, `f ⊓ g`: `{a ∩ b | a ∈ f, b ∈ g}`.
    ///
    /// - Complexity: O(|*f*|² |*g*|²) in the worst case.
    public mutating func meet(_ f: Family, _ g: Family) -> Family {
        _check(f)
        _check(g)
        return Family(_binary(Self._meet, f._vertex, g._vertex))
    }

    /// The sets of `f` that contain `element`.
    ///
    /// - Parameters:
    ///   - element: Traps unless it is in `0 ..< elementCount`.
    ///   - f: The family. Traps unless it belongs to this table.
    /// - Complexity: O(|*f*|).
    public mutating func including(_ element: Int, in f: Family) -> Family {
        _check(f)
        precondition(element >= 0 && element < elementCount, "Element out of range")
        return Family(_including(Int32(truncatingIfNeeded: element), f._vertex))
    }

    /// The sets of `f` that do not contain `element`.
    ///
    /// - Parameters:
    ///   - element: Traps unless it is in `0 ..< elementCount`.
    ///   - f: The family. Traps unless it belongs to this table.
    /// - Complexity: O(|*f*|).
    public mutating func excluding(_ element: Int, in f: Family) -> Family {
        _check(f)
        precondition(element >= 0 && element < elementCount, "Element out of range")
        return Family(_excluding(Int32(truncatingIfNeeded: element), f._vertex))
    }

    /// The sets of `f` that contain no other set of `f`.
    ///
    /// - Parameter f: The family. Traps unless it belongs to this table.
    /// - Complexity: O(|*f*|²) in the worst case.
    public mutating func minimalSets(of f: Family) -> Family {
        _check(f)
        return Family(_minimal(f._vertex))
    }

    /// The sets of `f` that no other set of `f` contains.
    ///
    /// - Parameter f: The family. Traps unless it belongs to this table.
    /// - Complexity: O(|*f*|²) in the worst case.
    public mutating func maximalSets(of f: Family) -> Family {
        _check(f)
        return Family(_maximal(f._vertex))
    }

    // MARK: - Reading families

    /// The number of sets in `f`.
    ///
    /// A `Double`, exact while the count is below 2⁵³, since it can reach 2^`elementCount`.
    ///
    /// - Parameter f: The family. Traps unless it belongs to this table.
    /// - Complexity: O(|*f*| log |*f*|).
    public func count(of f: Family) -> Double {
        _check(f)
        // Children come before their parents, so ascending vertex order counts bottom-up.
        var counts: [Int32: Double] = [0: 0, 1: 1]
        for vertex in _table.reachable(from: f._vertex) where vertex > 1 {
            counts[vertex] = counts[_table.lows[Int(vertex)]]! + counts[_table.highs[Int(vertex)]]!
        }
        return counts[f._vertex]!
    }

    /// Whether `set` is one of the sets of `f`.
    ///
    /// - Parameters:
    ///   - set: The set's elements, in any order. Traps unless each is in `0 ..< elementCount`.
    ///   - f: The family. Traps unless it belongs to this table.
    /// - Complexity: O(`elementCount` + *m* log *m*) for a set of *m* elements.
    public func contains(_ set: some Sequence<Int>, in f: Family) -> Bool {
        _check(f)
        let elements = Set(set).sorted()
        precondition(elements.allSatisfy { $0 >= 0 && $0 < elementCount }, "Element out of range")
        var vertex = Int(f._vertex)
        var next = 0
        while vertex > 1 {
            let element = Int(_table.variables[vertex])
            if next < elements.count && elements[next] == element {
                vertex = Int(_table.highs[vertex])
                next += 1
            } else if next < elements.count && elements[next] < element {
                return false
            } else {
                vertex = Int(_table.lows[vertex])
            }
        }
        return vertex == 1 && next == elements.count
    }

    /// The sets of `f`, each as its elements ascending, read lazily from the diagram.
    ///
    /// - Parameter f: The family. Traps unless it belongs to this table.
    /// - Complexity: O(1); iterating costs O(`elementCount`) per set.
    public func setsView(of f: Family) -> SetsView {
        _check(f)
        return SetsView(table: _table, root: f._vertex)
    }

    /// The number of vertices in `f`'s diagram, the constants it reaches included.
    ///
    /// - Parameter f: The family. Traps unless it belongs to this table.
    /// - Complexity: O(|*f*| log |*f*|).
    public func vertexCount(of f: Family) -> Int {
        _check(f)
        return _table.reachable(from: f._vertex).count
    }

    /// The number of vertices in the table, the constants included.
    public var tableVertexCount: Int { _table.count }

    /// Drops every vertex that none of `families` reaches, and returns them renumbered, in the
    /// same order: garbage collection, for the intermediate results a long computation leaves in
    /// the table.
    ///
    /// Afterward only the returned families and the constants belong to this table. Every other
    /// family built in it, including the ones passed in, names a different family or none, and
    /// must not be used. The computed table is emptied.
    ///
    /// - Parameter families: The families to keep. Each traps unless it belongs to this table.
    /// - Returns: The kept families, in the order given.
    /// - Complexity: O(*n*) in the vertices of the table before the call.
    public mutating func collectGarbage(keeping families: [Family]) -> [Family] {
        for f in families {
            _check(f)
        }
        return _table.collectGarbage(keeping: families.map(\._vertex)).map(Family.init)
    }

    /// The sets of a family, read from its diagram; see
    /// ``ZeroSuppressedDecisionDiagram/setsView(of:)``.
    ///
    /// Each set is its elements ascending. The sets come in ascending order of the binary numbers
    /// they spell with element 0 as the most significant bit: for {∅, {0}, {1}, {0, 1}}, the
    /// order is `[]`, `[1]`, `[0]`, `[0, 1]`.
    public struct SetsView: Sequence {
        let table: _DecisionTable
        let root: Int32

        /// Iterates over the sets by a depth-first walk with an explicit stack.
        public struct Iterator: IteratorProtocol {
            let table: _DecisionTable
            /// Vertices to visit, each with the path length to cut back to and the element to
            /// append on the way in, or −1.
            var stack: [(vertex: Int32, depth: Int32, element: Int32)]
            var path: [Int] = []

            init(table: _DecisionTable, root: Int32) {
                self.table = table
                stack = [(root, 0, -1)]
            }

            public mutating func next() -> [Int]? {
                while let (vertex, depth, element) = stack.popLast() {
                    path.removeSubrange(Int(depth)...)
                    if element >= 0 { path.append(Int(element)) }
                    if vertex == 1 { return path }
                    if vertex == 0 { continue }
                    let length = Int32(truncatingIfNeeded: path.count)
                    let v = Int(vertex)
                    stack.append((table.highs[v], length, table.variables[v]))
                    stack.append((table.lows[v], length, -1))
                }
                return nil
            }
        }

        public func makeIterator() -> Iterator {
            Iterator(table: table, root: root)
        }

        public var underestimatedCount: Int { root == 0 ? 0 : 1 }
    }

    // MARK: - Internals

    @usableFromInline
    func _check(_ f: Family) {
        precondition(f._vertex >= 0 && Int(f._vertex) < _table.count, "The family belongs to another diagram")
    }

    /// The vertex testing `element` with children `low` and `high`: `low` itself when `high` is
    /// the empty family, else the one in the unique table, added if new.
    mutating func _vertex(_ element: Int32, low: Int32, high: Int32) -> Int32 {
        high == 0 ? low : _table.vertex(element, low: low, high: high)
    }

    /// The element `vertex` tests, or `elementCount` for a constant.
    func _element(_ vertex: Int32) -> Int32 {
        _table.variables[Int(vertex)]
    }

    /// `vertex`'s family split on `element`, at or above its own: the sets without the element,
    /// and those with it, the element removed.
    func _split(_ vertex: Int32, on element: Int32) -> (low: Int32, high: Int32) {
        _element(vertex) == element ? (_table.lows[Int(vertex)], _table.highs[Int(vertex)]) : (vertex, 0)
    }

    // Computed-table codes, one per operation.
    static let _union: UInt8 = 0
    static let _intersection: UInt8 = 1
    static let _difference: UInt8 = 2
    static let _join: UInt8 = 3
    static let _meet: UInt8 = 4
    static let _nonsubsets: UInt8 = 5
    static let _nonsupersets: UInt8 = 6
    static let _minimalCode: UInt8 = 7
    static let _maximalCode: UInt8 = 8
    static let _includingCode: UInt8 = 9
    static let _excludingCode: UInt8 = 10

    /// The binary operation `operation` on `f` and `g`, by recursion on the first element either
    /// tests.
    mutating func _binary(_ operation: UInt8, _ f: Int32, _ g: Int32) -> Int32 {
        var (f, g) = (f, g)
        switch operation {
        case Self._union:
            if f == 0 || f == g { return g }
            if g == 0 { return f }
            if g < f { swap(&f, &g) }
        case Self._intersection:
            if f == 0 || g == 0 { return 0 }
            if f == g { return f }
            if g < f { swap(&f, &g) }
        case Self._difference:
            if f == 0 || f == g { return 0 }
            if g == 0 { return f }
        case Self._join:
            if f == 0 || g == 0 { return 0 }
            if f == 1 { return g }
            if g == 1 { return f }
            if g < f { swap(&f, &g) }
        case Self._meet:
            if f == 0 || g == 0 { return 0 }
            if f == 1 || g == 1 { return 1 }
            if g < f { swap(&f, &g) }
        case Self._nonsubsets:
            // The sets of f that no set of g contains.
            if g == 0 { return f }
            if f == 0 || f == 1 || f == g { return 0 }
            if g == 1 { return _binary(Self._difference, f, 1) }
        default:
            // The sets of f that contain no set of g.
            if g == 0 { return f }
            if f == 0 || g == 1 || f == g { return 0 }
        }
        let key = _DecisionTable.key(operation, f, g)
        if let known = _table.cached(key) { return known }
        let element = Swift.min(_element(f), _element(g))
        let (f0, f1) = _split(f, on: element)
        let (g0, g1) = _split(g, on: element)
        let low: Int32, high: Int32
        switch operation {
        case Self._join:
            low = _binary(operation, f0, g0)
            let a = _binary(operation, f1, g0)
            let b = _binary(operation, f0, g1)
            let c = _binary(operation, f1, g1)
            high = _binary(Self._union, _binary(Self._union, a, b), c)
        case Self._meet:
            let a = _binary(operation, f0, g0)
            let b = _binary(operation, f0, g1)
            let c = _binary(operation, f1, g0)
            low = _binary(Self._union, _binary(Self._union, a, b), c)
            high = _binary(operation, f1, g1)
        case Self._nonsubsets:
            low = _binary(operation, f0, _binary(Self._union, g0, g1))
            high = _binary(operation, f1, g1)
        case Self._nonsupersets:
            low = _binary(operation, f0, g0)
            high = _binary(operation, f1, _binary(Self._union, g0, g1))
        default:
            low = _binary(operation, f0, g0)
            high = _binary(operation, f1, g1)
        }
        let result = _vertex(element, low: low, high: high)
        _table.store(key, result)
        return result
    }

    mutating func _including(_ element: Int32, _ f: Int32) -> Int32 {
        let tested = _element(f)
        if tested > element { return 0 }
        if tested == element { return _vertex(element, low: 0, high: _table.highs[Int(f)]) }
        let key = _DecisionTable.key(Self._includingCode, f, element)
        if let known = _table.cached(key) { return known }
        let low = _including(element, _table.lows[Int(f)])
        let high = _including(element, _table.highs[Int(f)])
        let result = _vertex(tested, low: low, high: high)
        _table.store(key, result)
        return result
    }

    mutating func _excluding(_ element: Int32, _ f: Int32) -> Int32 {
        let tested = _element(f)
        if tested > element { return f }
        if tested == element { return _table.lows[Int(f)] }
        let key = _DecisionTable.key(Self._excludingCode, f, element)
        if let known = _table.cached(key) { return known }
        let low = _excluding(element, _table.lows[Int(f)])
        let high = _excluding(element, _table.highs[Int(f)])
        let result = _vertex(tested, low: low, high: high)
        _table.store(key, result)
        return result
    }

    /// A set with the root's element is minimal when its rest is minimal among the high sets and
    /// contains no low set; a set without it, when it is minimal among the low sets.
    mutating func _minimal(_ f: Int32) -> Int32 {
        if f <= 1 { return f }
        let key = _DecisionTable.key(Self._minimalCode, f, 0)
        if let known = _table.cached(key) { return known }
        let f0 = _table.lows[Int(f)]
        let f1 = _table.highs[Int(f)]
        let low = _minimal(f0)
        let high = _binary(Self._nonsupersets, _minimal(f1), f0)
        let result = _vertex(_element(f), low: low, high: high)
        _table.store(key, result)
        return result
    }

    /// A set with the root's element is maximal when its rest is maximal among the high sets; a
    /// set without it, when it is maximal among the low sets and no high set contains it.
    mutating func _maximal(_ f: Int32) -> Int32 {
        if f <= 1 { return f }
        let key = _DecisionTable.key(Self._maximalCode, f, 0)
        if let known = _table.cached(key) { return known }
        let f0 = _table.lows[Int(f)]
        let f1 = _table.highs[Int(f)]
        let low = _binary(Self._nonsubsets, _maximal(f0), f1)
        let high = _maximal(f1)
        let result = _vertex(_element(f), low: low, high: high)
        _table.store(key, result)
        return result
    }
}

extension ZeroSuppressedDecisionDiagram: Sendable {}
