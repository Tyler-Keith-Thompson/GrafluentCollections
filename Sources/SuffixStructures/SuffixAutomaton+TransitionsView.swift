import GraphProtocols

extension SuffixAutomaton {
    /// The automaton's transitions as a directed acyclic graph: a vertex per state, numbered from
    /// 0 for the start state, and an edge per transition, whose symbol
    /// ``TransitionsView/symbol(ofEdgeAt:)`` gives.
    ///
    /// The view reads the automaton's storage and builds nothing. O(1).
    @inlinable
    public var transitionsView: TransitionsView { TransitionsView(self) }

    /// A suffix automaton's transitions as a directed graph; see
    /// ``SuffixAutomaton/transitionsView``.
    ///
    /// `vertices` is `0 ..< stateCount`, and `edges` lists the transitions by source and then by
    /// symbol.
    @frozen
    public struct TransitionsView: DirectedGraph {
        @usableFromInline let _automaton: SuffixAutomaton

        @inlinable
        init(_ automaton: SuffixAutomaton) {
            _automaton = automaton
        }

        /// Every transition, by source and then by symbol.
        @frozen
        public struct Edges: RandomAccessCollection {
            @usableFromInline let _view: TransitionsView

            @inlinable
            init(_ view: TransitionsView) {
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
        public var edgeCount: Int { _automaton.transitionCount }

        @inlinable
        public func contains(_ vertex: Int) -> Bool {
            vertex >= 0 && vertex < _automaton.stateCount
        }

        /// The states the state's transitions lead to, by symbol.
        @inlinable
        public func successors(of vertex: Int) -> [Int] {
            outEdges(of: vertex).map { target(ofEdgeAt: $0) }
        }

        /// The positions of the state's transitions, by symbol.
        @inlinable
        public func outEdges(of vertex: Int) -> [Int] {
            guard contains(vertex) else { return [] }
            let rows = _automaton._states.rowStarts
            return Array(Int(rows[vertex]) ..< Int(rows[vertex &+ 1]))
        }

        @inlinable
        public func source(ofEdgeAt position: Int) -> Int {
            // The last state whose row starts at or before `position`.
            let rows = _automaton._states.rowStarts
            var low = 0
            var high = rows.count &- 1
            while low < high {
                let middle = low &+ (high &- low &+ 1) >> 1
                if Int(rows[middle]) <= position {
                    low = middle
                } else {
                    high = middle &- 1
                }
            }
            return low
        }

        @inlinable
        public func target(ofEdgeAt position: Int) -> Int {
            Int(_automaton._states.targets[position])
        }

        /// The symbol a transition reads.
        ///
        /// - Parameter position: A position in ``edges``. Traps unless it is one.
        /// - Complexity: O(1).
        @inlinable
        public func symbol(ofEdgeAt position: Int) -> Symbol {
            precondition(position >= 0 && position < edgeCount, "Edge position out of range")
            return _automaton._symbol(ofCode: _automaton._states.codes[position])
        }

        /// The length of the longest substring the state stands for: the longest path to it from
        /// the start state.
        ///
        /// - Parameter vertex: A state. Traps unless it is in `vertices`.
        /// - Complexity: O(1).
        @inlinable
        public func length(of vertex: Int) -> Int {
            precondition(contains(vertex), "The vertex is not a state")
            return Int(_automaton._states.lengths[vertex])
        }

        /// Whether the state stands for suffixes of the text, so that the automaton accepts at it.
        ///
        /// - Parameter vertex: A state. Traps unless it is in `vertices`.
        /// - Complexity: O(1).
        @inlinable
        public func isTerminal(_ vertex: Int) -> Bool {
            precondition(contains(vertex), "The vertex is not a state")
            return _automaton._states.isTerminal[vertex]
        }
    }
}

extension SuffixAutomaton.TransitionsView: Sendable where Symbol: Sendable {}
extension SuffixAutomaton.TransitionsView.Edges: Sendable where Symbol: Sendable {}
