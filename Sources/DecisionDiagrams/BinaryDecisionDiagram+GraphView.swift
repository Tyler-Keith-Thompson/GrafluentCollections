import GraphProtocols

extension BinaryDecisionDiagram {
    /// The table's vertices as a directed acyclic graph: a vertex per diagram vertex, 0 the false
    /// constant and 1 the true one, and from each other vertex a low edge and a high edge, which
    /// ``GraphView/isHighEdge(at:)`` tells apart. A function's diagram is the part reachable from
    /// its root, ``Function/vertex``.
    ///
    /// The view reads the table and builds nothing. O(1).
    public var graphView: GraphView { GraphView(self) }

    /// A binary decision diagram table as a directed graph; see
    /// ``BinaryDecisionDiagram/graphView``.
    ///
    /// `vertices` is `0 ..< tableVertexCount`, and `edges` lists each non-constant vertex's low
    /// edge and then its high edge, by vertex.
    @frozen
    public struct GraphView: DirectedGraph {
        @usableFromInline let _diagram: BinaryDecisionDiagram

        @inlinable
        init(_ diagram: BinaryDecisionDiagram) {
            _diagram = diagram
        }

        /// Every low and high edge, by source.
        @frozen
        public struct Edges: RandomAccessCollection {
            @usableFromInline let _view: GraphView

            @inlinable
            init(_ view: GraphView) {
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
        public var vertices: Range<Int> { 0 ..< _diagram._table.count }

        @inlinable
        public var edges: Edges { Edges(self) }

        @inlinable
        public var vertexCount: Int { _diagram._table.count }

        @inlinable
        public var edgeCount: Int { 2 &* (_diagram._table.count &- 2) }

        @inlinable
        public func contains(_ vertex: Int) -> Bool {
            vertex >= 0 && vertex < _diagram._table.count
        }

        /// The vertex's low child and then its high child, or nothing for a constant.
        @inlinable
        public func successors(of vertex: Int) -> [Int] {
            outEdges(of: vertex).map { target(ofEdgeAt: $0) }
        }

        /// The positions of the vertex's low edge and then its high edge, or nothing for a
        /// constant.
        @inlinable
        public func outEdges(of vertex: Int) -> [Int] {
            guard vertex > 1 && vertex < _diagram._table.count else { return [] }
            let low = 2 &* (vertex &- 2)
            return [low, low &+ 1]
        }

        @inlinable
        public func source(ofEdgeAt position: Int) -> Int { position / 2 &+ 2 }

        @inlinable
        public func target(ofEdgeAt position: Int) -> Int {
            let source = position / 2 &+ 2
            return Int(position & 1 == 1 ? _diagram._table.highs[source] : _diagram._table.lows[source])
        }

        /// Whether the edge is its source's high edge, taken when the source's variable is true.
        ///
        /// - Parameter position: A position in ``edges``. Traps unless it is one.
        /// - Complexity: O(1).
        @inlinable
        public func isHighEdge(at position: Int) -> Bool {
            precondition(position >= 0 && position < edgeCount, "Edge position out of range")
            return position & 1 == 1
        }

        /// The variable the vertex tests, or nil for a constant.
        ///
        /// - Parameter vertex: A vertex. Traps unless it is in `vertices`.
        /// - Complexity: O(1).
        @inlinable
        public func variable(of vertex: Int) -> Int? {
            precondition(contains(vertex), "The vertex is not in the diagram")
            return vertex <= 1 ? nil : Int(_diagram._table.variables[vertex])
        }
    }
}

extension BinaryDecisionDiagram.Function {
    /// The function's root, as a vertex of ``BinaryDecisionDiagram/graphView``: 0 for false, 1
    /// for true.
    @inlinable
    public var vertex: Int { Int(_vertex) }
}
