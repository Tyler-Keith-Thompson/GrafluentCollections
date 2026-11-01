/// A quadtree: elements at points in a rectangle, which finds those in a box, within a radius
/// of a point, or nearest a point, and takes insertions and removals as the points move.
///
/// The rectangle is split into four equal quadrants, and each quadrant again, until every leaf
/// holds at most `bucketCapacity` elements (Finkel and Bentley, "Quad Trees: A Data Structure for
/// Retrieval on Composite Keys", 1974). A search visits only the cells that meet its region.
/// Cells and elements live in flat arrays; a removal that leaves a cell's quadrants holding no
/// more than one bucket merges them back. Cells at depth 24 never split, so any number of
/// elements may share one point.
///
/// ```swift
/// var map = Quadtree<String>(bounds: BoundingBox(lower: [0, 0], upper: [100, 100]))
/// map.insert("café", at: [10, 20])
/// map.insert("library", at: [12, 22])
/// map.insert("station", at: [80, 75])
/// map.nearest(to: [11, 19])?.element                          // "café"
/// map.items(within: 5, of: [11, 21]).count                    // 2
/// map.items(in: BoundingBox(lower: [50, 50], upper: [100, 100])).map(\.element)   // ["station"]
/// ```
///
/// A point on the line between two quadrants belongs to the upper one. The elements and their
/// points are a sequence, in no particular order.
@frozen
public struct Quadtree<Element> {
    @usableFromInline
    var _core: _Orthtree<SIMD2<Double>, Element>

    /// An empty quadtree over `bounds`.
    ///
    /// - Parameters:
    ///   - bounds: The region the points lie in, its edges included.
    ///   - bucketCapacity: The most elements a leaf holds before it splits. Traps unless it is
    ///     positive.
    @inlinable
    public init(bounds: BoundingBox<SIMD2<Double>>, bucketCapacity: Int = 8) {
        precondition(bucketCapacity > 0, "A bucket holds at least one element")
        _core = _Orthtree(bounds: bounds, bucketCapacity: bucketCapacity)
    }

    /// The region the points lie in, its edges included.
    @inlinable
    public var bounds: BoundingBox<SIMD2<Double>> { _core.bounds }

    /// The most elements a leaf holds before it splits.
    @inlinable
    public var bucketCapacity: Int { _core.bucketCapacity }

    /// The number of elements.
    @inlinable
    public var count: Int { _core.count }

    /// Whether the quadtree holds no elements.
    @inlinable
    public var isEmpty: Bool { _core.count == 0 }

    /// Inserts `element` at `point`, beside any elements already there.
    ///
    /// - Parameters:
    ///   - element: The element.
    ///   - point: Where it is. Traps unless it lies in ``bounds``; use ``insert(_:checkedAt:)`` to
    ///     throw instead.
    /// - Complexity: O(depth) amortized, plus O(*n*) when the storage is shared with another copy.
    @inlinable
    public mutating func insert(_ element: Element, at point: SIMD2<Double>) {
        precondition(_core.bounds.contains(point), "The point lies outside the quadtree's bounds")
        _core.insert(element, at: point)
    }

    /// Inserts `element` at `point`, throwing instead of trapping on a point outside the bounds.
    ///
    /// - Throws: ``OutOfBounds`` unless `point` lies in ``bounds``; the quadtree is unchanged.
    /// - Complexity: O(depth) amortized, plus O(*n*) when the storage is shared with another copy.
    @inlinable
    public mutating func insert(_ element: Element, checkedAt point: SIMD2<Double>) throws(OutOfBounds) {
        guard _core.bounds.contains(point) else { throw OutOfBounds() }
        _core.insert(element, at: point)
    }

    /// Removes an element at `point` that satisfies `predicate`, and returns it, or nil when
    /// none does.
    ///
    /// - Complexity: O(depth + *b*) for *b* elements in the point's leaf, plus O(*n*) when the
    ///   storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func remove(at point: SIMD2<Double>, where predicate: (Element) throws -> Bool) rethrows -> Element? {
        try _core.remove(at: point, where: predicate)
    }

    /// The elements and points inside `box`, its faces included, in no particular order.
    ///
    /// - Complexity: O(*c* + *k*) for the *c* cells that meet the box and *k* results.
    @inlinable
    public func items(in box: BoundingBox<SIMD2<Double>>) -> [SpatialItem<SIMD2<Double>, Element>] {
        _core.items(in: box)
    }

    /// The elements and points whose distance from `center` is at most `radius`, in no
    /// particular order; none when `radius` is negative or NaN.
    ///
    /// - Complexity: O(*c* + *k*) for the *c* cells that meet the disc and *k* results.
    @inlinable
    public func items(within radius: Double, of center: SIMD2<Double>) -> [SpatialItem<SIMD2<Double>, Element>] {
        _core.items(within: radius, of: center)
    }

    /// The element and point nearest `query`, or nil when the quadtree is empty or a coordinate
    /// of `query` is NaN; which of several equally near ones is unspecified.
    ///
    /// - Complexity: O(depth) expected for evenly spread points.
    @inlinable
    public func nearest(to query: SIMD2<Double>) -> SpatialItem<SIMD2<Double>, Element>? {
        guard !query.x.isNaN && !query.y.isNaN else { return nil }
        return _core.nearest(to: query, count: 1).first
    }

    /// The `count` elements and points nearest `query`, nearest first; all of them when there
    /// are fewer, none when `count` is not positive or a coordinate of `query` is NaN.
    ///
    /// - Complexity: O(depth + *k* log *k*) expected for evenly spread points and *k* = `count`.
    @inlinable
    public func nearest(to query: SIMD2<Double>, count: Int) -> [SpatialItem<SIMD2<Double>, Element>] {
        guard !query.x.isNaN && !query.y.isNaN else { return [] }
        return _core.nearest(to: query, count: count)
    }
}

extension Quadtree where Element: Equatable {
    /// Removes an element equal to `element` at `point`, and returns it, or nil when there is
    /// none.
    ///
    /// - Complexity: O(depth + *b*) for *b* elements in the point's leaf, plus O(*n*) when the
    ///   storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element, at point: SIMD2<Double>) -> Element? {
        _core.remove(at: point) { $0 == element }
    }
}

extension Quadtree: Sequence {
    /// The elements and their points in storage order.
    @frozen
    public struct Iterator: IteratorProtocol {
        @usableFromInline let _core: _Orthtree<SIMD2<Double>, Element>
        @usableFromInline var _position: Int

        @inlinable
        init(_ core: _Orthtree<SIMD2<Double>, Element>) {
            _core = core
            _position = 0
        }

        @inlinable
        public mutating func next() -> SpatialItem<SIMD2<Double>, Element>? {
            guard _position < _core.count else { return nil }
            defer { _position &+= 1 }
            return SpatialItem(point: _core.points[_position], element: _core.elements[_position])
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_core)
    }

    @inlinable
    public var underestimatedCount: Int { _core.count }
}

extension Quadtree: Sendable where Element: Sendable {}
