// The storage a quadtree and an octree share: a tree over a box in which each cell either is a
// leaf holding a bucket of items or has 2ᵈ children, one per orthant of the cell, for d =
// `Point.scalarCount`. Cells and items live in flat arrays with Int32 links.

/// An item of a quadtree or octree: a point and the element stored at it.
@frozen
public struct SpatialItem<Point: SIMD, Element> where Point.Scalar: FloatingPoint {
    /// Where the element is.
    public var point: Point
    /// The element.
    public var element: Element

    @inlinable
    public init(point: Point, element: Element) {
        self.point = point
        self.element = element
    }
}

extension SpatialItem: Equatable where Element: Equatable {}
extension SpatialItem: Hashable where Element: Hashable {}
extension SpatialItem: Sendable where Point: Sendable, Element: Sendable {}

@frozen
@usableFromInline
struct _Orthtree<Point: SIMD, Element> where Point.Scalar: FloatingPoint {
    /// The region covered, both corners included.
    @usableFromInline let bounds: BoundingBox<Point>
    /// The most items a leaf holds before it splits, unless it is at `maximumDepth`.
    @usableFromInline let bucketCapacity: Int

    /// Each cell's first child, its 2ᵈ children being consecutive, or −1 for a leaf.
    @usableFromInline var firstChild: ContiguousArray<Int32>
    /// Each leaf's first item, or −1; −1 for a cell with children.
    @usableFromInline var head: ContiguousArray<Int32>
    /// The number of items in each cell's subtree.
    @usableFromInline var cellCounts: ContiguousArray<Int32>
    /// Blocks of 2ᵈ cells freed by a collapse, by their first cell.
    @usableFromInline var freeBlocks: ContiguousArray<Int32>

    @usableFromInline var points: ContiguousArray<Point>
    @usableFromInline var elements: ContiguousArray<Element>
    /// Each item's successor in its leaf's bucket, or −1.
    @usableFromInline var next: ContiguousArray<Int32>
    /// Each item's leaf.
    @usableFromInline var leaf: ContiguousArray<Int32>

    /// Cells this deep never split, so coincident points share one leaf rather than recurse.
    @inlinable
    static var maximumDepth: Int { 24 }

    @inlinable
    static var childCount: Int { 1 &<< Point.scalarCount }

    @inlinable
    init(bounds: BoundingBox<Point>, bucketCapacity: Int) {
        self.bounds = bounds
        self.bucketCapacity = bucketCapacity
        firstChild = [-1]
        head = [-1]
        cellCounts = [0]
        freeBlocks = []
        points = []
        elements = []
        next = []
        leaf = []
    }

    @inlinable
    var count: Int { points.count }

    // MARK: Geometry

    /// The orthant of the cell `lower ... upper` holding `point`: bit `a` is set when the point's
    /// coordinate `a` is at least the centre's.
    @inlinable @inline(__always)
    static func orthant(of point: Point, center: Point) -> Int {
        var orthant = 0
        for axis in 0 ..< Point.scalarCount where point[axis] >= center[axis] {
            orthant |= 1 &<< axis
        }
        return orthant
    }

    @inlinable @inline(__always)
    static func center(_ lower: Point, _ upper: Point) -> Point {
        lower + (upper - lower) / 2
    }

    /// The box of orthant `orthant` of the cell `lower ... upper` with centre `center`.
    @inlinable @inline(__always)
    static func child(_ orthant: Int, _ lower: Point, _ upper: Point, _ center: Point) -> (lower: Point, upper: Point) {
        var childLower = lower, childUpper = upper
        for axis in 0 ..< Point.scalarCount {
            if orthant & (1 &<< axis) != 0 {
                childLower[axis] = center[axis]
            } else {
                childUpper[axis] = center[axis]
            }
        }
        return (childLower, childUpper)
    }

    /// The squared distance from `point` to the nearest point of the box `lower ... upper`.
    @inlinable @inline(__always)
    static func distanceSquared(from point: Point, toBox lower: Point, _ upper: Point) -> Point.Scalar {
        var total = Point.Scalar.zero
        for axis in 0 ..< Point.scalarCount {
            let below = lower[axis] - point[axis]
            let above = point[axis] - upper[axis]
            let gap = below > 0 ? below : (above > 0 ? above : 0)
            total += gap * gap
        }
        return total
    }

    @inlinable @inline(__always)
    static func distanceSquared(_ a: Point, _ b: Point) -> Point.Scalar {
        let difference = a - b
        return (difference * difference).sum()
    }

    // MARK: Mutations

    @inlinable
    mutating func insert(_ element: Element, at point: Point) {
        precondition(points.count < Int(Int32.max) - 1, "A spatial tree holds fewer than 2³¹ − 1 items")
        let item = Int32(truncatingIfNeeded: points.count)
        points.append(point)
        elements.append(element)
        next.append(-1)
        leaf.append(-1)
        var cell = 0
        var lower = bounds.lower, upper = bounds.upper
        var depth = 0
        while true {
            cellCounts[cell] &+= 1
            let first = firstChild[cell]
            if first < 0 { break }
            let center = Self.center(lower, upper)
            let orthant = Self.orthant(of: point, center: center)
            (lower, upper) = Self.child(orthant, lower, upper, center)
            cell = Int(first) &+ orthant
            depth &+= 1
        }
        next[Int(item)] = head[cell]
        head[cell] = item
        leaf[Int(item)] = Int32(truncatingIfNeeded: cell)
        if Int(cellCounts[cell]) > bucketCapacity && depth < Self.maximumDepth {
            split(cell, lower, upper, depth: depth)
        }
    }

    /// Gives the leaf `cell`, the box `lower ... upper`, 2ᵈ children and moves its items into
    /// them, splitting again any child still over capacity.
    @inlinable
    mutating func split(_ cell: Int, _ lower: Point, _ upper: Point, depth: Int) {
        let first: Int32
        if let block = freeBlocks.popLast() {
            first = block
            for k in 0 ..< Self.childCount {
                firstChild[Int(block) &+ k] = -1
                head[Int(block) &+ k] = -1
                cellCounts[Int(block) &+ k] = 0
            }
        } else {
            precondition(firstChild.count <= Int(Int32.max) - Self.childCount, "A spatial tree holds fewer than 2³¹ cells")
            first = Int32(truncatingIfNeeded: firstChild.count)
            for _ in 0 ..< Self.childCount {
                firstChild.append(-1)
                head.append(-1)
                cellCounts.append(0)
            }
        }
        let center = Self.center(lower, upper)
        var item = head[cell]
        head[cell] = -1
        firstChild[cell] = first
        while item >= 0 {
            let following = next[Int(item)]
            let child = Int(first) &+ Self.orthant(of: points[Int(item)], center: center)
            next[Int(item)] = head[child]
            head[child] = item
            leaf[Int(item)] = Int32(truncatingIfNeeded: child)
            cellCounts[child] &+= 1
            item = following
        }
        guard depth &+ 1 < Self.maximumDepth else { return }
        for orthant in 0 ..< Self.childCount {
            let child = Int(first) &+ orthant
            if Int(cellCounts[child]) > bucketCapacity {
                let box = Self.child(orthant, lower, upper, center)
                split(child, box.lower, box.upper, depth: depth &+ 1)
            }
        }
    }

    /// Removes the first item found at `point` whose element satisfies `predicate`, and returns
    /// its element.
    @inlinable
    mutating func remove(at point: Point, where predicate: (Element) throws -> Bool) rethrows -> Element? {
        guard bounds.contains(point) else { return nil }
        // The path down to the leaf holding `point`.
        var path: [Int] = []
        var cell = 0
        var lower = bounds.lower, upper = bounds.upper
        while firstChild[cell] >= 0 {
            path.append(cell)
            let center = Self.center(lower, upper)
            let orthant = Self.orthant(of: point, center: center)
            (lower, upper) = Self.child(orthant, lower, upper, center)
            cell = Int(firstChild[cell]) &+ orthant
        }
        path.append(cell)
        var previous: Int32 = -1
        var item = head[cell]
        while item >= 0 {
            if points[Int(item)] == point, try predicate(elements[Int(item)]) { break }
            previous = item
            item = next[Int(item)]
        }
        guard item >= 0 else { return nil }
        if previous < 0 {
            head[cell] = next[Int(item)]
        } else {
            next[Int(previous)] = next[Int(item)]
        }
        for cell in path {
            cellCounts[cell] &-= 1
        }
        // The highest cell on the path that now fits in one bucket gathers its subtree back.
        if let top = path.first(where: { firstChild[$0] >= 0 && Int(cellCounts[$0]) <= bucketCapacity }) {
            collapse(top)
        }
        return discard(item)
    }

    /// Makes `cell` a leaf holding every item of its subtree, freeing its descendants' blocks.
    @inlinable
    mutating func collapse(_ cell: Int) {
        var gathered: Int32 = -1
        var blocks: [Int32] = [firstChild[cell]]
        while let block = blocks.popLast() {
            freeBlocks.append(block)
            for k in 0 ..< Self.childCount {
                let child = Int(block) &+ k
                if firstChild[child] >= 0 {
                    blocks.append(firstChild[child])
                } else {
                    var item = head[child]
                    while item >= 0 {
                        let following = next[Int(item)]
                        next[Int(item)] = gathered
                        gathered = item
                        leaf[Int(item)] = Int32(truncatingIfNeeded: cell)
                        item = following
                    }
                }
                firstChild[child] = -1
                head[child] = -1
                cellCounts[child] = 0
            }
        }
        firstChild[cell] = -1
        head[cell] = gathered
    }

    /// Removes the unlinked item `item`, moving the last item into its slot.
    @inlinable
    mutating func discard(_ item: Int32) -> Element {
        let last = Int32(truncatingIfNeeded: points.count &- 1)
        if item != last {
            // Whoever links to the last item links to its new slot instead.
            let lastLeaf = Int(leaf[Int(last)])
            if head[lastLeaf] == last {
                head[lastLeaf] = item
            } else {
                var x = head[lastLeaf]
                while next[Int(x)] != last {
                    x = next[Int(x)]
                }
                next[Int(x)] = item
            }
            points.swapAt(Int(item), Int(last))
            elements.swapAt(Int(item), Int(last))
            next.swapAt(Int(item), Int(last))
            leaf.swapAt(Int(item), Int(last))
        }
        points.removeLast()
        next.removeLast()
        leaf.removeLast()
        return elements.removeLast()
    }

    // MARK: Queries

    @inlinable
    func items(in box: BoundingBox<Point>) -> [SpatialItem<Point, Element>] {
        var found: [SpatialItem<Point, Element>] = []
        visit(0, bounds.lower, bounds.upper, box, &found)
        return found
    }

    @inlinable
    func visit(_ cell: Int, _ lower: Point, _ upper: Point, _ box: BoundingBox<Point>, _ found: inout [SpatialItem<Point, Element>]) {
        guard cellCounts[cell] > 0, all(box.lower .<= upper), all(lower .<= box.upper) else { return }
        let first = firstChild[cell]
        if first < 0 {
            var item = head[cell]
            while item >= 0 {
                if box.contains(points[Int(item)]) {
                    found.append(SpatialItem(point: points[Int(item)], element: elements[Int(item)]))
                }
                item = next[Int(item)]
            }
            return
        }
        let center = Self.center(lower, upper)
        for orthant in 0 ..< Self.childCount {
            let child = Self.child(orthant, lower, upper, center)
            visit(Int(first) &+ orthant, child.lower, child.upper, box, &found)
        }
    }

    @inlinable
    func items(within radius: Point.Scalar, of center: Point) -> [SpatialItem<Point, Element>] {
        var found: [SpatialItem<Point, Element>] = []
        guard radius >= 0 else { return found }
        visit(0, bounds.lower, bounds.upper, center, radius * radius, &found)
        return found
    }

    @inlinable
    func visit(_ cell: Int, _ lower: Point, _ upper: Point, _ query: Point, _ radiusSquared: Point.Scalar, _ found: inout [SpatialItem<Point, Element>]) {
        guard cellCounts[cell] > 0, Self.distanceSquared(from: query, toBox: lower, upper) <= radiusSquared else { return }
        let first = firstChild[cell]
        if first < 0 {
            var item = head[cell]
            while item >= 0 {
                if Self.distanceSquared(points[Int(item)], query) <= radiusSquared {
                    found.append(SpatialItem(point: points[Int(item)], element: elements[Int(item)]))
                }
                item = next[Int(item)]
            }
            return
        }
        let center = Self.center(lower, upper)
        for orthant in 0 ..< Self.childCount {
            let child = Self.child(orthant, lower, upper, center)
            visit(Int(first) &+ orthant, child.lower, child.upper, query, radiusSquared, &found)
        }
    }

    /// The `count` items nearest `query`, nearest first, by a depth-first descent that visits
    /// each cell's children nearest first and skips any farther than the `count`-th found.
    @inlinable
    func nearest(to query: Point, count wanted: Int) -> [SpatialItem<Point, Element>] {
        let wanted = Swift.min(wanted, points.count)
        guard wanted > 0 else { return [] }
        var heap = _NeighbourHeap<Point.Scalar>(capacity: wanted)
        nearest(0, bounds.lower, bounds.upper, query, &heap)
        return heap.sortedIndices().map { SpatialItem(point: points[$0], element: elements[$0]) }
    }

    @inlinable
    func nearest(_ cell: Int, _ lower: Point, _ upper: Point, _ query: Point, _ heap: inout _NeighbourHeap<Point.Scalar>) {
        guard cellCounts[cell] > 0 else { return }
        if heap.isFull && Self.distanceSquared(from: query, toBox: lower, upper) > heap.worstDistance { return }
        let first = firstChild[cell]
        if first < 0 {
            var item = head[cell]
            while item >= 0 {
                heap.offer(Self.distanceSquared(points[Int(item)], query), item)
                item = next[Int(item)]
            }
            return
        }
        let center = Self.center(lower, upper)
        // The children in order of their distance from the query, nearest first.
        var order = (0 ..< Self.childCount).map { orthant -> (distance: Point.Scalar, orthant: Int) in
            let child = Self.child(orthant, lower, upper, center)
            return (Self.distanceSquared(from: query, toBox: child.lower, child.upper), orthant)
        }
        order.sort { $0.distance < $1.distance }
        for (_, orthant) in order {
            let child = Self.child(orthant, lower, upper, center)
            nearest(Int(first) &+ orthant, child.lower, child.upper, query, &heap)
        }
    }

    /// The cells, renumbered from the root in breadth-first order, as each one's parent.
    @inlinable
    func cellParents() -> [Int?] {
        var parents: [Int?] = [nil]
        var queue = [0]
        var cursor = 0
        while cursor < queue.count {
            let cell = queue[cursor]
            let number = cursor
            cursor &+= 1
            let first = firstChild[cell]
            guard first >= 0 else { continue }
            for k in 0 ..< Self.childCount {
                queue.append(Int(first) &+ k)
                parents.append(number)
            }
        }
        return parents
    }
}

extension _Orthtree: Sendable where Point: Sendable, Element: Sendable {}
