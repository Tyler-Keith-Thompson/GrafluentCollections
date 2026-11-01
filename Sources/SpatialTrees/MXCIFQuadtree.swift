/// An MX-CIF quadtree: elements over boxes in a rectangle, which finds those overlapping a box,
/// those containing a point, and every pair that overlaps, and takes insertions and removals as
/// the boxes move.
///
/// The rectangle is split into four equal quadrants, and each quadrant again, and each element
/// hangs on the smallest cell that wholly contains its box, so a box that straddles a cell's
/// centre line stays at that cell (Kedem, "The Quad-CIF Tree", 1982). A search visits only the
/// cells that meet its region. Cells are made on the way down to an element and freed when their
/// subtree empties. Cells at depth 24 have no quadrants, so smaller boxes stay there.
///
/// ```swift
/// var plan = MXCIFQuadtree<String>(bounds: BoundingBox(lower: [0, 0], upper: [100, 100]))
/// plan.insert("hall", in: BoundingBox(lower: [10, 10], upper: [60, 20]))
/// plan.insert("office", in: BoundingBox(lower: [10, 20], upper: [30, 40]))
/// plan.insert("garden", in: BoundingBox(lower: [70, 70], upper: [90, 90]))
/// plan.items(containing: [20, 15]).map(\.element)          // ["hall"]
/// plan.items(overlapping: BoundingBox(lower: [25, 18], upper: [35, 25])).count   // 2
/// plan.overlappingPairs().count                            // 1: the hall and the office touch
/// ```
///
/// Boxes include their faces, so two that touch overlap. A box whose lower edge lies on a centre
/// line belongs to the upper quadrant. The elements and their boxes are a sequence, in no
/// particular order.
@frozen
public struct MXCIFQuadtree<Element> {
    @usableFromInline
    var _core: _MXCIFTree<SIMD2<Double>, Element>

    /// An empty quadtree over `bounds`.
    ///
    /// - Parameter bounds: The region the boxes lie in, its edges included.
    @inlinable
    public init(bounds: BoundingBox<SIMD2<Double>>) {
        _core = _MXCIFTree(bounds: bounds)
    }

    /// The region the boxes lie in, its edges included.
    @inlinable
    public var bounds: BoundingBox<SIMD2<Double>> { _core.bounds }

    /// The number of elements.
    @inlinable
    public var count: Int { _core.count }

    /// Whether the quadtree holds no elements.
    @inlinable
    public var isEmpty: Bool { _core.count == 0 }

    /// Inserts `element` over `box`, beside any elements already there.
    ///
    /// - Parameters:
    ///   - element: The element.
    ///   - box: The region it covers. Traps unless it lies inside ``bounds``; use
    ///     ``insert(_:checkedIn:)`` to throw instead.
    /// - Complexity: O(depth), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    public mutating func insert(_ element: Element, in box: BoundingBox<SIMD2<Double>>) {
        precondition(_core.bounds.contains(box), "The box lies outside the quadtree's bounds")
        _core.insert(element, in: box)
    }

    /// Inserts `element` over `box`, throwing instead of trapping on a box outside the bounds.
    ///
    /// - Throws: ``OutOfBounds`` unless `box` lies inside ``bounds``; the quadtree is unchanged.
    /// - Complexity: O(depth), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    public mutating func insert(_ element: Element, checkedIn box: BoundingBox<SIMD2<Double>>) throws(OutOfBounds) {
        guard _core.bounds.contains(box) else { throw OutOfBounds() }
        _core.insert(element, in: box)
    }

    /// Removes an element over exactly `box` that satisfies `predicate`, and returns it, or nil
    /// when none does.
    ///
    /// - Complexity: O(depth + *b*) for *b* elements at the box's cell, plus O(*n*) when the
    ///   storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func remove(in box: BoundingBox<SIMD2<Double>>, where predicate: (Element) throws -> Bool) rethrows -> Element? {
        try _core.remove(in: box, where: predicate)
    }

    /// The elements and boxes that share a point with `box`, in no particular order.
    ///
    /// - Complexity: O(*c* + *m*) for the *c* cells that meet the box and the *m* elements they
    ///   hold.
    @inlinable
    public func items(overlapping box: BoundingBox<SIMD2<Double>>) -> [SpatialBoxItem<SIMD2<Double>, Element>] {
        _core.items(overlapping: box)
    }

    /// The elements and boxes whose box contains `point`, in no particular order; none when the
    /// point lies outside ``bounds``.
    ///
    /// - Complexity: O(depth + *m*) for the *m* elements on the cells containing the point.
    @inlinable
    public func items(containing point: SIMD2<Double>) -> [SpatialBoxItem<SIMD2<Double>, Element>] {
        _core.items(containing: point)
    }

    /// Every pair of elements whose boxes share a point, each pair once, in no particular order.
    ///
    /// - Complexity: O(*n* · *c* + *k*) in the worst case, for *c* cells and *k* pairs; each
    ///   element reads only its own cell and the cells below it that meet its box.
    @inlinable
    public func overlappingPairs() -> [OverlappingPair<SIMD2<Double>, Element>] {
        _core.overlappingPairs()
    }
}

extension MXCIFQuadtree where Element: Equatable {
    /// Removes an element equal to `element` over exactly `box`, and returns it, or nil when
    /// there is none.
    ///
    /// - Complexity: O(depth + *b*) for *b* elements at the box's cell, plus O(*n*) when the
    ///   storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element, in box: BoundingBox<SIMD2<Double>>) -> Element? {
        _core.remove(in: box) { $0 == element }
    }
}

extension MXCIFQuadtree: Sequence {
    /// The elements and their boxes in storage order.
    @frozen
    public struct Iterator: IteratorProtocol {
        @usableFromInline let _core: _MXCIFTree<SIMD2<Double>, Element>
        @usableFromInline var _position: Int

        @inlinable
        init(_ core: _MXCIFTree<SIMD2<Double>, Element>) {
            _core = core
            _position = 0
        }

        @inlinable
        public mutating func next() -> SpatialBoxItem<SIMD2<Double>, Element>? {
            guard _position < _core.count else { return nil }
            defer { _position &+= 1 }
            return SpatialBoxItem(box: _core.boxes[_position], element: _core.elements[_position])
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_core)
    }

    @inlinable
    public var underestimatedCount: Int { _core.count }
}

extension MXCIFQuadtree: Sendable where Element: Sendable {}
