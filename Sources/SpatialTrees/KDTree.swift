@_exported import CollectionErrors

/// A k-d tree: a fixed set of points in *k* dimensions that finds the points nearest a query, or
/// within a radius or a box of it, without testing every point.
///
/// The tree splits the points at the median of one coordinate, then splits each half at the
/// median of the next coordinate, cycling through the dimensions (Bentley, "Multidimensional
/// Binary Search Trees Used for Associative Searching", 1975). It is stored with no links: the
/// points are permuted so that every subtree is a contiguous run with its median in the middle.
/// A search descends toward the query and visits the far side of a split only when the
/// splitting plane is closer than what it has found (Friedman, Bentley and Finkel, 1977).
///
/// ```swift
/// let tree = KDTree<SIMD2<Double>>([[2, 3], [5, 4], [9, 6], [4, 7], [8, 1], [7, 2]])
/// tree.nearestIndex(to: [9, 2])                    // 4: the point [8, 1]
/// tree.nearestIndices(to: [9, 2], count: 2)        // [4, 5]
/// tree.indices(within: 3, of: [5, 5])              // [1, 3]
/// tree.indices(in: BoundingBox(lower: [0, 0], upper: [5, 5]))   // [0, 1]
/// ```
///
/// Points are SIMD vectors of floating-point scalars, so `SIMD2<Double>` is a point in the
/// plane and `SIMD3<Float>` one in space; distances are Euclidean. As a collection, a k-d tree's
/// elements are its points in the order they were given, and searches answer with their indices.
@frozen
public struct KDTree<Point: SIMD> where Point.Scalar: FloatingPoint {
    /// The points, permuted so that each subtree is a contiguous run with its median in the
    /// middle, split on coordinate `depth % Point.scalarCount`.
    @usableFromInline
    var _points: ContiguousArray<Point>

    /// The given index of the point in each position of `_points`.
    @usableFromInline
    var _indices: ContiguousArray<Int32>

    /// The position in `_points` of each given index.
    @usableFromInline
    var _positions: ContiguousArray<Int32>

    /// An empty tree.
    @inlinable
    public init() {
        _points = []
        _indices = []
        _positions = []
    }

    /// The tree over `points`, whose indices are their positions in the sequence.
    ///
    /// - Parameter points: The points. Traps if a coordinate is NaN; use ``init(checked:)`` to
    ///   throw instead.
    /// - Complexity: O(*n* log *n*) expected.
    @inlinable
    public init(_ points: some Sequence<Point>) {
        let points = ContiguousArray(points)
        precondition(!Self._hasNaN(points), "A k-d tree's coordinates must not be NaN")
        self.init(_validated: points)
    }

    /// The tree over `points`, throwing instead of trapping on a NaN coordinate.
    ///
    /// - Parameter points: The points.
    /// - Throws: ``NotANumber`` if a coordinate is NaN.
    /// - Complexity: O(*n* log *n*) expected.
    @inlinable
    public init(checked points: some Sequence<Point>) throws(NotANumber) {
        let points = ContiguousArray(points)
        guard !Self._hasNaN(points) else { throw NotANumber() }
        self.init(_validated: points)
    }

    @inlinable
    static func _hasNaN(_ points: ContiguousArray<Point>) -> Bool {
        points.contains { point in (0 ..< Point.scalarCount).contains { point[$0].isNaN } }
    }

    @inlinable
    init(_validated points: ContiguousArray<Point>) {
        let count = points.count
        precondition(count < Int(Int32.max), "A k-d tree holds fewer than 2³¹ − 1 points")
        var points = points
        var indices = ContiguousArray<Int32>((0 ..< Int32(truncatingIfNeeded: count)))
        points.withUnsafeMutableBufferPointer { points in
            indices.withUnsafeMutableBufferPointer { indices in
                Self._build(points, indices, 0, count, axis: 0)
            }
        }
        var positions = ContiguousArray<Int32>(repeating: 0, count: count)
        for position in 0 ..< count {
            positions[Int(indices[position])] = Int32(truncatingIfNeeded: position)
        }
        _points = points
        _indices = indices
        _positions = positions
    }

    /// Places the median of `lower ..< upper` by `axis` in the middle, the smaller coordinates
    /// before it and the larger after, then does the same to each side by the next axis.
    @inlinable
    static func _build(
        _ points: UnsafeMutableBufferPointer<Point>,
        _ indices: UnsafeMutableBufferPointer<Int32>,
        _ lower: Int,
        _ upper: Int,
        axis: Int
    ) {
        guard upper &- lower > 1 else { return }
        let middle = lower &+ (upper &- lower) / 2
        _select(points, indices, lower, upper, middle, axis: axis)
        let next = axis &+ 1 == Point.scalarCount ? 0 : axis &+ 1
        _build(points, indices, lower, middle, axis: next)
        _build(points, indices, middle &+ 1, upper, axis: next)
    }

    /// Hoare's selection with a median-of-three pivot: afterwards position `target` holds the
    /// coordinate it would hold were `lower ..< upper` sorted by `axis`, with nothing larger
    /// before it and nothing smaller after.
    @inlinable
    static func _select(
        _ points: UnsafeMutableBufferPointer<Point>,
        _ indices: UnsafeMutableBufferPointer<Int32>,
        _ lower: Int,
        _ upper: Int,
        _ target: Int,
        axis: Int
    ) {
        var low = lower
        var high = upper &- 1
        while low < high {
            let a = points[low][axis]
            let b = points[low &+ (high &- low) / 2][axis]
            let c = points[high][axis]
            let pivot = a < b ? (b < c ? b : (a < c ? c : a)) : (a < c ? a : (b < c ? c : b))
            var i = low
            var j = high
            while i <= j {
                while points[i][axis] < pivot { i &+= 1 }
                while pivot < points[j][axis] { j &-= 1 }
                if i <= j {
                    points.swapAt(i, j)
                    indices.swapAt(i, j)
                    i &+= 1
                    j &-= 1
                }
            }
            if target <= j {
                high = j
            } else if target >= i {
                low = i
            } else {
                return
            }
        }
    }

    // MARK: - Searches

    /// The index of the point nearest `query`, the smallest index among equally near points, or
    /// nil when the tree is empty or a coordinate of `query` is NaN.
    ///
    /// - Complexity: O(log *n*) expected for points spread evenly in few dimensions; O(*n*) in
    ///   the worst case.
    @inlinable
    public func nearestIndex(to query: Point) -> Int? {
        guard !_points.isEmpty && !Self._isNaN(query) else { return nil }
        var best = (distance: Point.Scalar.infinity, index: Int32.max)
        _points.withUnsafeBufferPointer { points in
            _indices.withUnsafeBufferPointer { indices in
                Self._nearest(points, indices, 0, points.count, axis: 0, query, &best)
            }
        }
        return Int(best.index)
    }

    /// The indices of the `count` points nearest `query`, nearest first, ties by smaller index;
    /// every index when the tree holds fewer, none when `count` is not positive or a coordinate of
    /// `query` is NaN.
    ///
    /// - Complexity: O(*k* log *k* + log *n*) expected for *k* = `count` and points spread evenly
    ///   in few dimensions; O(*n* log *k*) in the worst case.
    @inlinable
    public func nearestIndices(to query: Point, count: Int) -> [Int] {
        let wanted = Swift.min(count, _points.count)
        guard wanted > 0 && !Self._isNaN(query) else { return [] }
        var heap = _NeighbourHeap<Point.Scalar>(capacity: wanted)
        _points.withUnsafeBufferPointer { points in
            _indices.withUnsafeBufferPointer { indices in
                Self._nearest(points, indices, 0, points.count, axis: 0, query, &heap)
            }
        }
        return heap.sortedIndices()
    }

    /// The indices of the points whose distance from `center` is at most `radius`, ascending;
    /// none when `radius` is negative or NaN.
    ///
    /// - Complexity: O(√*n* + *k*) expected in two dimensions for *k* results.
    @inlinable
    public func indices(within radius: Point.Scalar, of center: Point) -> [Int] {
        guard radius >= 0 && !Self._isNaN(center) else { return [] }
        var found: [Int] = []
        _points.withUnsafeBufferPointer { points in
            _indices.withUnsafeBufferPointer { indices in
                Self._within(points, indices, 0, points.count, axis: 0, center, radius, radius * radius, &found)
            }
        }
        found.sort()
        return found
    }

    /// The indices of the points in `box`, its faces included, ascending.
    ///
    /// - Complexity: O(√*n* + *k*) in two dimensions for *k* results.
    @inlinable
    public func indices(in box: BoundingBox<Point>) -> [Int] {
        var found: [Int] = []
        _points.withUnsafeBufferPointer { points in
            _indices.withUnsafeBufferPointer { indices in
                Self._inBox(points, indices, 0, points.count, axis: 0, box, &found)
            }
        }
        found.sort()
        return found
    }

    /// The point at `position`, the index it was given at, throwing instead of trapping on an
    /// invalid index.
    ///
    /// - Throws: ``IndexOutOfRange`` unless `position` is a valid index.
    /// - Complexity: O(1).
    @inlinable
    public subscript(checked position: Int) -> Point {
        get throws(IndexOutOfRange) {
            guard position >= 0 && position < _points.count else { throw IndexOutOfRange() }
            return _points[Int(_positions[position])]
        }
    }

    // MARK: - Internals

    @inlinable
    static func _isNaN(_ point: Point) -> Bool {
        (0 ..< Point.scalarCount).contains { point[$0].isNaN }
    }

    @inlinable @inline(__always)
    static func _distanceSquared(_ a: Point, _ b: Point) -> Point.Scalar {
        let difference = a - b
        return (difference * difference).sum()
    }

    @inlinable
    static func _nearest(
        _ points: UnsafeBufferPointer<Point>,
        _ indices: UnsafeBufferPointer<Int32>,
        _ lower: Int,
        _ upper: Int,
        axis: Int,
        _ query: Point,
        _ best: inout (distance: Point.Scalar, index: Int32)
    ) {
        guard lower < upper else { return }
        let middle = lower &+ (upper &- lower) / 2
        let point = points[middle]
        let distance = _distanceSquared(point, query)
        let index = indices[middle]
        if distance < best.distance || (distance == best.distance && index < best.index) {
            best = (distance, index)
        }
        let offset = query[axis] - point[axis]
        let next = axis &+ 1 == Point.scalarCount ? 0 : axis &+ 1
        if offset < 0 {
            _nearest(points, indices, lower, middle, axis: next, query, &best)
            if offset * offset <= best.distance {
                _nearest(points, indices, middle &+ 1, upper, axis: next, query, &best)
            }
        } else {
            _nearest(points, indices, middle &+ 1, upper, axis: next, query, &best)
            if offset * offset <= best.distance {
                _nearest(points, indices, lower, middle, axis: next, query, &best)
            }
        }
    }

    @inlinable
    static func _nearest(
        _ points: UnsafeBufferPointer<Point>,
        _ indices: UnsafeBufferPointer<Int32>,
        _ lower: Int,
        _ upper: Int,
        axis: Int,
        _ query: Point,
        _ heap: inout _NeighbourHeap<Point.Scalar>
    ) {
        guard lower < upper else { return }
        let middle = lower &+ (upper &- lower) / 2
        let point = points[middle]
        heap.offer(_distanceSquared(point, query), indices[middle])
        let offset = query[axis] - point[axis]
        let next = axis &+ 1 == Point.scalarCount ? 0 : axis &+ 1
        let (near, far) = offset < 0 ? ((lower, middle), (middle &+ 1, upper)) : ((middle &+ 1, upper), (lower, middle))
        _nearest(points, indices, near.0, near.1, axis: next, query, &heap)
        if !heap.isFull || offset * offset <= heap.worstDistance {
            _nearest(points, indices, far.0, far.1, axis: next, query, &heap)
        }
    }

    @inlinable
    static func _within(
        _ points: UnsafeBufferPointer<Point>,
        _ indices: UnsafeBufferPointer<Int32>,
        _ lower: Int,
        _ upper: Int,
        axis: Int,
        _ center: Point,
        _ radius: Point.Scalar,
        _ radiusSquared: Point.Scalar,
        _ found: inout [Int]
    ) {
        guard lower < upper else { return }
        let middle = lower &+ (upper &- lower) / 2
        let point = points[middle]
        if _distanceSquared(point, center) <= radiusSquared {
            found.append(Int(indices[middle]))
        }
        let offset = center[axis] - point[axis]
        let next = axis &+ 1 == Point.scalarCount ? 0 : axis &+ 1
        if offset <= radius {
            _within(points, indices, lower, middle, axis: next, center, radius, radiusSquared, &found)
        }
        if offset >= -radius {
            _within(points, indices, middle &+ 1, upper, axis: next, center, radius, radiusSquared, &found)
        }
    }

    @inlinable
    static func _inBox(
        _ points: UnsafeBufferPointer<Point>,
        _ indices: UnsafeBufferPointer<Int32>,
        _ lower: Int,
        _ upper: Int,
        axis: Int,
        _ box: BoundingBox<Point>,
        _ found: inout [Int]
    ) {
        guard lower < upper else { return }
        let middle = lower &+ (upper &- lower) / 2
        let point = points[middle]
        if box.contains(point) {
            found.append(Int(indices[middle]))
        }
        let next = axis &+ 1 == Point.scalarCount ? 0 : axis &+ 1
        if box.lower[axis] <= point[axis] {
            _inBox(points, indices, lower, middle, axis: next, box, &found)
        }
        if point[axis] <= box.upper[axis] {
            _inBox(points, indices, middle &+ 1, upper, axis: next, box, &found)
        }
    }
}

/// The nearest points found so far, as a max-heap of at most `capacity` (distance, index)
/// pairs, the farthest (ties by larger index) on top.
@usableFromInline
struct _NeighbourHeap<Scalar: FloatingPoint> {
    @usableFromInline var distances: [Scalar]
    @usableFromInline var indices: [Int32]
    @usableFromInline let capacity: Int

    @inlinable
    init(capacity: Int) {
        self.capacity = capacity
        distances = []
        indices = []
        distances.reserveCapacity(capacity)
        indices.reserveCapacity(capacity)
    }

    @inlinable var isFull: Bool { distances.count == capacity }
    @inlinable var worstDistance: Scalar { distances[0] }

    /// Whether (a, i) is farther than (b, j).
    @inlinable @inline(__always)
    static func _farther(_ a: Scalar, _ i: Int32, _ b: Scalar, _ j: Int32) -> Bool {
        a > b || (a == b && i > j)
    }

    @inlinable
    mutating func offer(_ distance: Scalar, _ index: Int32) {
        if !isFull {
            distances.append(distance)
            indices.append(index)
            var child = distances.count &- 1
            while child > 0 {
                let parent = (child &- 1) / 2
                guard Self._farther(distances[child], indices[child], distances[parent], indices[parent]) else { break }
                distances.swapAt(child, parent)
                indices.swapAt(child, parent)
                child = parent
            }
            return
        }
        guard Self._farther(distances[0], indices[0], distance, index) else { return }
        distances[0] = distance
        indices[0] = index
        var parent = 0
        let count = distances.count
        while true {
            let left = 2 &* parent &+ 1
            guard left < count else { break }
            let right = left &+ 1
            var largest = left
            if right < count && Self._farther(distances[right], indices[right], distances[left], indices[left]) {
                largest = right
            }
            guard Self._farther(distances[largest], indices[largest], distances[parent], indices[parent]) else { break }
            distances.swapAt(largest, parent)
            indices.swapAt(largest, parent)
            parent = largest
        }
    }

    /// The indices, nearest first.
    @inlinable
    func sortedIndices() -> [Int] {
        let order = distances.indices.sorted { Self._farther(distances[$1], indices[$1], distances[$0], indices[$0]) }
        return order.map { Int(indices[$0]) }
    }
}

extension KDTree: RandomAccessCollection {
    public typealias Element = Point
    public typealias Index = Int
    public typealias Indices = Range<Int>

    @inlinable public var startIndex: Int { 0 }
    @inlinable public var endIndex: Int { _points.count }
    @inlinable public var count: Int { _points.count }
    @inlinable public var isEmpty: Bool { _points.isEmpty }

    /// The point given at index `position`.
    ///
    /// - Parameter position: Traps unless it is a valid index; use ``subscript(checked:)`` to
    ///   throw instead.
    /// - Complexity: O(1).
    @inlinable
    public subscript(position: Int) -> Point {
        precondition(position >= 0 && position < _points.count, "Index out of range")
        return _points[Int(_positions[position])]
    }
}

extension KDTree: ExpressibleByArrayLiteral {
    /// The tree over the literal's points. O(*n* log *n*) expected.
    @inlinable
    public init(arrayLiteral elements: Point...) {
        self.init(elements)
    }
}

extension KDTree: Equatable {
    /// Whether two trees hold the same points at the same indices. O(*n*).
    @inlinable
    public static func == (lhs: KDTree, rhs: KDTree) -> Bool {
        lhs.count == rhs.count && lhs.elementsEqual(rhs)
    }
}

extension KDTree: Sendable where Point: Sendable {}

extension KDTree: CustomStringConvertible {
    /// The points, in index order, written as an array literal.
    public var description: String {
        Array(self).description
    }
}

/// An axis-aligned box: the points whose every coordinate lies between the lower corner's and
/// the upper corner's, both included.
@frozen
public struct BoundingBox<Point: SIMD>: Hashable where Point.Scalar: FloatingPoint {
    /// The corner with the smallest coordinates.
    public var lower: Point
    /// The corner with the largest coordinates.
    public var upper: Point

    /// The box between `lower` and `upper`.
    ///
    /// - Parameters:
    ///   - lower: The corner with the smallest coordinates.
    ///   - upper: The corner with the largest coordinates. Traps unless each of its coordinates
    ///     is at least `lower`'s; use ``init(checkedLower:upper:)`` to throw instead.
    @inlinable
    public init(lower: Point, upper: Point) {
        precondition(all(lower .<= upper), "A box's lower corner must not exceed its upper corner")
        self.lower = lower
        self.upper = upper
    }

    /// The box between `lower` and `upper`, throwing instead of trapping on corners out of order.
    ///
    /// - Throws: ``EmptyRange`` unless each of `upper`'s coordinates is at least `lower`'s.
    @inlinable
    public init(checkedLower lower: Point, upper: Point) throws(EmptyRange) {
        guard all(lower .<= upper) else { throw EmptyRange() }
        self.lower = lower
        self.upper = upper
    }

    /// Whether `point` lies in the box, its faces included.
    @inlinable
    public func contains(_ point: Point) -> Bool {
        all(lower .<= point) && all(point .<= upper)
    }

    /// Whether `box` lies wholly inside this box; a box sharing a face with this one counts.
    @inlinable
    public func contains(_ box: BoundingBox) -> Bool {
        all(lower .<= box.lower) && all(box.upper .<= upper)
    }

    /// Whether this box and `other` share a point; boxes that touch at a face or a corner do.
    @inlinable
    public func intersects(_ other: BoundingBox) -> Bool {
        all(lower .<= other.upper) && all(other.lower .<= upper)
    }
}

extension BoundingBox: Sendable where Point: Sendable {}
