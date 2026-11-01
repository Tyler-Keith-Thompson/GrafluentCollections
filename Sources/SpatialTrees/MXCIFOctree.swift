/// An MX-CIF octree: elements over boxes in a box in space, which finds those overlapping a box,
/// those containing a point, and every pair that overlaps, and takes insertions and removals as
/// the boxes move.
///
/// It is ``MXCIFQuadtree`` in three dimensions, with the same storage: the box is split into
/// eight equal octants, and each octant again, and each element hangs on the smallest cell that
/// wholly contains its box, so a box that straddles a cell's centre plane stays at that cell. A
/// search visits only the cells that meet its region; cells are made on the way down to an
/// element and freed when their subtree empties, and cells at depth 24 have no octants.
///
/// ```swift
/// var space = MXCIFOctree<Int>(bounds: BoundingBox(lower: [0, 0, 0], upper: [1, 1, 1]))
/// space.insert(1, in: BoundingBox(lower: [0.1, 0.1, 0.1], upper: [0.6, 0.2, 0.2]))
/// space.insert(2, in: BoundingBox(lower: [0.5, 0.1, 0.1], upper: [0.9, 0.3, 0.3]))
/// space.overlappingPairs().count                  // 1
/// space.items(containing: [0.55, 0.15, 0.15]).count   // 2
/// ```
///
/// Boxes include their faces, so two that touch overlap. A box whose lower face lies on a centre
/// plane belongs to the upper octant. The elements and their boxes are a sequence, in no
/// particular order.
@frozen
public struct MXCIFOctree<Element> {
    @usableFromInline
    var _core: _MXCIFTree<SIMD3<Double>, Element>

    /// An empty octree over `bounds`.
    ///
    /// - Parameter bounds: The region the boxes lie in, its edges included.
    @inlinable
    public init(bounds: BoundingBox<SIMD3<Double>>) {
        _core = _MXCIFTree(bounds: bounds)
    }

    /// The region the boxes lie in, its edges included.
    @inlinable
    public var bounds: BoundingBox<SIMD3<Double>> { _core.bounds }

    /// The number of elements.
    @inlinable
    public var count: Int { _core.count }

    /// Whether the octree holds no elements.
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
    public mutating func insert(_ element: Element, in box: BoundingBox<SIMD3<Double>>) {
        precondition(_core.bounds.contains(box), "The box lies outside the octree's bounds")
        _core.insert(element, in: box)
    }

    /// Inserts `element` over `box`, throwing instead of trapping on a box outside the bounds.
    ///
    /// - Throws: ``OutOfBounds`` unless `box` lies inside ``bounds``; the octree is unchanged.
    /// - Complexity: O(depth), plus O(*n*) when the storage is shared with another copy.
    @inlinable
    public mutating func insert(_ element: Element, checkedIn box: BoundingBox<SIMD3<Double>>) throws(OutOfBounds) {
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
    public mutating func remove(in box: BoundingBox<SIMD3<Double>>, where predicate: (Element) throws -> Bool) rethrows -> Element? {
        try _core.remove(in: box, where: predicate)
    }

    /// The elements and boxes that share a point with `box`, in no particular order.
    ///
    /// - Complexity: O(*c* + *m*) for the *c* cells that meet the box and the *m* elements they
    ///   hold.
    @inlinable
    public func items(overlapping box: BoundingBox<SIMD3<Double>>) -> [SpatialBoxItem<SIMD3<Double>, Element>] {
        _core.items(overlapping: box)
    }

    /// The elements and boxes whose box contains `point`, in no particular order; none when the
    /// point lies outside ``bounds``.
    ///
    /// - Complexity: O(depth + *m*) for the *m* elements on the cells containing the point.
    @inlinable
    public func items(containing point: SIMD3<Double>) -> [SpatialBoxItem<SIMD3<Double>, Element>] {
        _core.items(containing: point)
    }

    /// Every pair of elements whose boxes share a point, each pair once, in no particular order.
    ///
    /// - Complexity: O(*n* · *c* + *k*) in the worst case, for *c* cells and *k* pairs; each
    ///   element reads only its own cell and the cells below it that meet its box.
    @inlinable
    public func overlappingPairs() -> [OverlappingPair<SIMD3<Double>, Element>] {
        _core.overlappingPairs()
    }
}

extension MXCIFOctree where Element: Equatable {
    /// Removes an element equal to `element` over exactly `box`, and returns it, or nil when
    /// there is none.
    ///
    /// - Complexity: O(depth + *b*) for *b* elements at the box's cell, plus O(*n*) when the
    ///   storage is shared with another copy.
    @inlinable
    @discardableResult
    public mutating func remove(_ element: Element, in box: BoundingBox<SIMD3<Double>>) -> Element? {
        _core.remove(in: box) { $0 == element }
    }
}

extension MXCIFOctree: Sequence {
    /// The elements and their boxes in storage order.
    @frozen
    public struct Iterator: IteratorProtocol {
        @usableFromInline let _core: _MXCIFTree<SIMD3<Double>, Element>
        @usableFromInline var _position: Int

        @inlinable
        init(_ core: _MXCIFTree<SIMD3<Double>, Element>) {
            _core = core
            _position = 0
        }

        @inlinable
        public mutating func next() -> SpatialBoxItem<SIMD3<Double>, Element>? {
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

extension MXCIFOctree: Sendable where Element: Sendable {}
