import GraphProtocols

extension AhoCorasickAutomaton {
    /// The automaton's states as a directed graph: a vertex per state, numbered from 0 for the
    /// root, a goto edge from each state to each of its trie children, and a failure edge from
    /// each state but the root to its failure state. ``StatesView/symbol(ofEdgeAt:)`` tells the two
    /// apart.
    ///
    /// The view reads the automaton's storage and builds nothing. O(1).
    @inlinable
    public var statesView: StatesView { StatesView(self) }

    /// An Aho–Corasick automaton's states and links as a directed graph; see
    /// ``AhoCorasickAutomaton/statesView``.
    ///
    /// `vertices` is `0 ..< stateCount`, states numbered as the patterns were read, so a state
    /// comes after its parent. `edges` lists the goto edges, by source and then by symbol index,
    /// and then the failure edges, by source.
    @frozen
    public struct StatesView: DirectedGraph {
        @usableFromInline let _automaton: AhoCorasickAutomaton

        @inlinable
        init(_ automaton: AhoCorasickAutomaton) {
            _automaton = automaton
        }

        /// The number of goto edges.
        @inlinable
        var _gotoCount: Int { _automaton._gotoTargets.count }

        /// Every edge: the goto edges, by source and then by symbol index, then the failure edges,
        /// by source.
        @frozen
        public struct Edges: RandomAccessCollection {
            @usableFromInline let _view: StatesView

            @inlinable
            init(_ view: StatesView) {
                _view = view
            }

            @inlinable public var startIndex: Int { 0 }
            @inlinable public var endIndex: Int { _view.edgeCount }

            @inlinable
            public subscript(position: Int) -> DirectedEdge<Int> {
                DirectedEdge(from: _view.source(ofEdgeAt: position), to: _view.target(ofEdgeAt: position))
            }
        }

        @inlinable
        public var vertices: Range<Int> { 0 ..< _automaton.stateCount }

        @inlinable
        public var edges: Edges { Edges(self) }

        @inlinable
        public var vertexCount: Int { _automaton.stateCount }

        @inlinable
        public var edgeCount: Int { _gotoCount &+ _automaton.stateCount &- 1 }

        @inlinable
        public func contains(_ vertex: Int) -> Bool {
            vertex >= 0 && vertex < _automaton.stateCount
        }

        /// The state's trie children, by symbol index, then its failure state unless it is the
        /// root.
        @inlinable
        public func successors(of vertex: Int) -> [Int] {
            outEdges(of: vertex).map { target(ofEdgeAt: $0) }
        }

        /// The positions of the state's goto edges, then of its failure edge unless it is the
        /// root.
        @inlinable
        public func outEdges(of vertex: Int) -> [Int] {
            guard contains(vertex) else { return [] }
            var positions = Array(Int(_automaton._gotoOffsets[vertex]) ..< Int(_automaton._gotoOffsets[vertex &+ 1]))
            if vertex > 0 {
                positions.append(_gotoCount &+ vertex &- 1)
            }
            return positions
        }

        @inlinable
        public func source(ofEdgeAt position: Int) -> Int {
            if position >= _gotoCount {
                return position &- _gotoCount &+ 1
            }
            // The last state whose goto row starts at or before `position`.
            let offsets = _automaton._gotoOffsets
            var low = 0
            var high = offsets.count &- 1
            while low < high {
                let middle = low &+ (high &- low &+ 1) >> 1
                if Int(offsets[middle]) <= position {
                    low = middle
                } else {
                    high = middle &- 1
                }
            }
            return low
        }

        @inlinable
        public func target(ofEdgeAt position: Int) -> Int {
            if position >= _gotoCount {
                return Int(_automaton._failures[position &- _gotoCount &+ 1])
            }
            return Int(_automaton._gotoTargets[position])
        }

        /// The symbol a goto edge reads, or nil for a failure edge.
        ///
        /// - Parameter position: A position in ``edges``. Traps unless it is one.
        /// - Complexity: O(1).
        @inlinable
        public func symbol(ofEdgeAt position: Int) -> Symbol? {
            precondition(position >= 0 && position < edgeCount, "Edge position out of range")
            guard position < _gotoCount else { return nil }
            return _automaton._alphabet[Int(_automaton._gotoSymbols[position])]
        }

        /// The patterns that end at a state, by index, ascending: those whose every symbol the
        /// path from the root to the state reads.
        ///
        /// - Parameter vertex: A state. Traps unless it is in `vertices`.
        /// - Complexity: O(*k*) for *k* patterns.
        @inlinable
        public func patternIndices(endingAt vertex: Int) -> [Int] {
            precondition(contains(vertex), "The vertex is not a state")
            let range = Int(_automaton._outputOffsets[vertex]) ..< Int(_automaton._outputOffsets[vertex &+ 1])
            return range.map { Int(_automaton._outputPatterns[$0]) }
        }
    }
}

extension AhoCorasickAutomaton.StatesView: Sendable where Symbol: Sendable {}
extension AhoCorasickAutomaton.StatesView.Edges: Sendable where Symbol: Sendable {}
