import GraphProtocols

extension SkipList where Element: Hashable {
    /// The list's levels as a directed graph: a vertex for each element on each level of its
    /// tower, an edge from each to the next element on the same level, and an edge from each down
    /// to the same element on the level below. The head is not a vertex.
    ///
    /// ```swift
    /// let list: SkipList = [1, 2, 3]
    /// let layers = list.layersView
    /// layers.successors(of: .init(level: 0, element: 1))
    /// // [Vertex(level: 0, element: 2)]: the next element on the bottom level
    /// ```
    ///
    /// The view reads the list's storage and builds nothing. O(1).
    @inlinable
    public var layersView: LayersView { LayersView(_core) }

    /// A skip list's levels as a directed acyclic graph; see ``SkipList/layersView``.
    ///
    /// `vertices` lists the elements in ascending order, each from the bottom of its tower up;
    /// `edges` lists, for each vertex in that order, its edge along the level and then its edge
    /// down. Looking a vertex up searches the list, O(log *n*) expected.
    @frozen
    public struct LayersView: DirectedGraph {
        @usableFromInline let _core: _SkipListCore<Element>

        @inlinable
        init(_ core: _SkipListCore<Element>) {
            _core = core
        }

        /// An element on one level of its tower; level 0 is the bottom.
        @frozen
        public struct Vertex: Hashable {
            /// The level, from 0 at the bottom.
            public var level: Int
            /// The element.
            public var element: Element

            /// The vertex for `element` on `level`.
            ///
            /// - Parameters:
            ///   - level: The level, from 0 at the bottom.
            ///   - element: The element.
            @inlinable
            public init(level: Int, element: Element) {
                self.level = level
                self.element = element
            }
        }

        /// A vertex's place in ``vertices``: its element's rank and its level.
        @frozen
        public struct VertexPosition: Comparable, Hashable {
            @usableFromInline let rank: Int
            @usableFromInline let level: Int
            @usableFromInline let slot: Int32

            @inlinable
            init(rank: Int, level: Int, slot: Int32) {
                self.rank = rank
                self.level = level
                self.slot = slot
            }

            @inlinable
            public static func == (lhs: VertexPosition, rhs: VertexPosition) -> Bool {
                lhs.rank == rhs.rank && lhs.level == rhs.level
            }

            @inlinable
            public static func < (lhs: VertexPosition, rhs: VertexPosition) -> Bool {
                (lhs.rank, lhs.level) < (rhs.rank, rhs.level)
            }

            @inlinable
            public func hash(into hasher: inout Hasher) {
                hasher.combine(rank)
                hasher.combine(level)
            }
        }

        /// An edge's place in ``edges``: its source's position and whether it leads down.
        @frozen
        public struct EdgePosition: Comparable, Hashable {
            @usableFromInline let source: VertexPosition
            @usableFromInline let isDown: Bool

            @inlinable
            init(source: VertexPosition, isDown: Bool) {
                self.source = source
                self.isDown = isDown
            }

            @inlinable
            public static func < (lhs: EdgePosition, rhs: EdgePosition) -> Bool {
                lhs.source < rhs.source || (lhs.source == rhs.source && !lhs.isDown && rhs.isDown)
            }
        }

        /// Every vertex: the elements in ascending order, each from the bottom of its tower up.
        @frozen
        public struct Vertices: Collection {
            @usableFromInline let _core: _SkipListCore<Element>

            @inlinable
            init(_ core: _SkipListCore<Element>) {
                _core = core
            }

            @inlinable
            public var startIndex: VertexPosition {
                VertexPosition(rank: 0, level: 0, slot: _core.firstSlot)
            }

            @inlinable
            public var endIndex: VertexPosition {
                VertexPosition(rank: _core.count, level: 0, slot: -1)
            }

            @inlinable
            public func index(after position: VertexPosition) -> VertexPosition {
                if position.level &+ 1 < Int(_core.heights[Int(position.slot)]) {
                    return VertexPosition(rank: position.rank, level: position.level &+ 1, slot: position.slot)
                }
                return VertexPosition(rank: position.rank &+ 1, level: 0, slot: _core.slot(after: position.slot))
            }

            @inlinable
            public subscript(position: VertexPosition) -> Vertex {
                Vertex(level: position.level, element: _core.elements[Int(position.slot)])
            }
        }

        /// Every edge: for each vertex in ``vertices`` order, its edge along the level and then
        /// its edge down.
        @frozen
        public struct Edges: Collection {
            @usableFromInline let _core: _SkipListCore<Element>

            @inlinable
            init(_ core: _SkipListCore<Element>) {
                _core = core
            }

            @inlinable
            public var startIndex: EdgePosition {
                _first(from: Vertices(_core).startIndex, isDown: false)
            }

            @inlinable
            public var endIndex: EdgePosition {
                EdgePosition(source: Vertices(_core).endIndex, isDown: false)
            }

            @inlinable
            public func index(after position: EdgePosition) -> EdgePosition {
                position.isDown
                    ? _first(from: Vertices(_core).index(after: position.source), isDown: false)
                    : _first(from: position.source, isDown: true)
            }

            /// The first edge at or after the given edge's place, which need not be an edge.
            @inlinable
            func _first(from source: VertexPosition, isDown: Bool) -> EdgePosition {
                let vertices = Vertices(_core)
                var source = source
                var isDown = isDown
                while source.slot >= 0 {
                    if !isDown && _core.links[Int(_core.towers[Int(source.slot)]) &+ source.level].next >= 0 {
                        return EdgePosition(source: source, isDown: false)
                    }
                    if source.level > 0 {
                        return EdgePosition(source: source, isDown: true)
                    }
                    source = vertices.index(after: source)
                    isDown = false
                }
                return endIndex
            }

            @inlinable
            public subscript(position: EdgePosition) -> DirectedEdge<Vertex> {
                let source = position.source
                let element = _core.elements[Int(source.slot)]
                if position.isDown {
                    return DirectedEdge(
                        from: Vertex(level: source.level, element: element),
                        to: Vertex(level: source.level &- 1, element: element)
                    )
                }
                let next = _core.links[Int(_core.towers[Int(source.slot)]) &+ source.level].next
                return DirectedEdge(
                    from: Vertex(level: source.level, element: element),
                    to: Vertex(level: source.level, element: _core.elements[Int(next)])
                )
            }
        }

        @inlinable
        public var vertices: Vertices { Vertices(_core) }

        @inlinable
        public var edges: Edges { Edges(_core) }

        /// The next element on the vertex's level, then the same element a level down, where
        /// they exist. O(log *n*) expected.
        @inlinable
        public func successors(of vertex: Vertex) -> [Vertex] {
            let edges = self.edges
            return outEdges(of: vertex).map { edges[$0].target }
        }

        /// The edges leaving the vertex, along its level and then down. O(log *n*) expected.
        @inlinable
        public func outEdges(of vertex: Vertex) -> [EdgePosition] {
            let slot = _core.slot(of: vertex.element)
            guard slot >= 0, vertex.level >= 0, vertex.level < Int(_core.heights[Int(slot)]) else { return [] }
            let source = VertexPosition(
                rank: _core.countBelow(vertex.element, orEqual: false),
                level: vertex.level,
                slot: slot
            )
            var result: [EdgePosition] = []
            if _core.links[Int(_core.towers[Int(slot)]) &+ vertex.level].next >= 0 {
                result.append(EdgePosition(source: source, isDown: false))
            }
            if vertex.level > 0 {
                result.append(EdgePosition(source: source, isDown: true))
            }
            return result
        }

        /// Whether the list holds the element with a tower reaching the vertex's level.
        /// O(log *n*) expected.
        @inlinable
        public func contains(_ vertex: Vertex) -> Bool {
            let slot = _core.slot(of: vertex.element)
            return slot >= 0 && vertex.level >= 0 && vertex.level < Int(_core.heights[Int(slot)])
        }

        /// The number of vertices: the sum of the tower heights. O(*n*).
        @inlinable
        public var vertexCount: Int {
            _core.heights.reduce(0) { $0 &+ Int($1) }
        }
    }
}

extension SkipList.LayersView: Sendable where Element: Sendable {}
extension SkipList.LayersView.Vertex: Sendable where Element: Sendable {}
extension SkipList.LayersView.Vertices: Sendable where Element: Sendable {}
extension SkipList.LayersView.Edges: Sendable where Element: Sendable {}
extension SkipList.LayersView.VertexPosition: Sendable {}
extension SkipList.LayersView.EdgePosition: Sendable {}
