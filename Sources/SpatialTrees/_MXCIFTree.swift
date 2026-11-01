// The storage an MX-CIF quadtree and octree share: a tree over a box in which each item, a box
// of its own, hangs on the deepest cell that wholly contains it, so a box that straddles a cell's
// centre line stays at that cell. Cells are made on the way down to an item and freed when their
// subtree empties. Cells and items live in flat arrays with Int32 links.

/// An item of an MX-CIF quadtree or octree: a box and the element stored over it.
@frozen
public struct SpatialBoxItem<Point: SIMD, Element> where Point.Scalar: FloatingPoint {
    /// The region the element covers, its faces included.
    public var box: BoundingBox<Point>
    /// The element.
    public var element: Element

    /// An item of `element` over `box`.
    @inlinable
    public init(box: BoundingBox<Point>, element: Element) {
        self.box = box
        self.element = element
    }
}

extension SpatialBoxItem: Equatable where Element: Equatable {}
extension SpatialBoxItem: Hashable where Element: Hashable {}
extension SpatialBoxItem: Sendable where Point: Sendable, Element: Sendable {}

/// Two items of an MX-CIF quadtree or octree whose boxes overlap.
@frozen
public struct OverlappingPair<Point: SIMD, Element> where Point.Scalar: FloatingPoint {
    /// One item of the pair.
    public var first: SpatialBoxItem<Point, Element>
    /// The other item.
    public var second: SpatialBoxItem<Point, Element>

    /// The pair of `first` and `second`.
    @inlinable
    public init(first: SpatialBoxItem<Point, Element>, second: SpatialBoxItem<Point, Element>) {
        self.first = first
        self.second = second
    }
}

extension OverlappingPair: Equatable where Element: Equatable {}
extension OverlappingPair: Hashable where Element: Hashable {}
extension OverlappingPair: Sendable where Point: Sendable, Element: Sendable {}

@frozen
@usableFromInline
struct _MXCIFTree<Point: SIMD, Element> where Point.Scalar: FloatingPoint {
    /// The region covered, both corners included.
    @usableFromInline let bounds: BoundingBox<Point>

    /// Each cell's first child, its 2ᵈ children being consecutive, or −1 for a cell without.
    @usableFromInline var firstChild: ContiguousArray<Int32>
    /// Each cell's first item, or −1.
    @usableFromInline var head: ContiguousArray<Int32>
    /// The number of items in each cell's subtree.
    @usableFromInline var cellCounts: ContiguousArray<Int32>
    /// Blocks of 2ᵈ cells freed when their subtree emptied, by their first cell.
    @usableFromInline var freeBlocks: ContiguousArray<Int32>

    @usableFromInline var boxes: ContiguousArray<BoundingBox<Point>>
    @usableFromInline var elements: ContiguousArray<Element>
    /// Each item's successor among its cell's items, or −1.
    @usableFromInline var next: ContiguousArray<Int32>
    /// Each item's cell.
    @usableFromInline var cell: ContiguousArray<Int32>

    /// Cells this deep have no children, so a box smaller than such a cell stays there.
    @inlinable
    static var maximumDepth: Int { 24 }

    @inlinable
    static var childCount: Int { 1 &<< Point.scalarCount }

    @inlinable
    init(bounds: BoundingBox<Point>) {
        self.bounds = bounds
        firstChild = [-1]
        head = [-1]
        cellCounts = [0]
        freeBlocks = []
        boxes = []
        elements = []
        next = []
        cell = []
    }

    @inlinable
    var count: Int { boxes.count }

    // MARK: Geometry

    /// The orthant of a cell with centre `center` that wholly holds `box`, or nil when the box
    /// reaches across the centre on some axis. A box whose lower coordinate is the centre's lies
    /// in the upper half, as a point on the centre line does.
    @inlinable @inline(__always)
    static func orthant(holding box: BoundingBox<Point>, center: Point) -> Int? {
        var orthant = 0
        for axis in 0 ..< Point.scalarCount {
            if box.lower[axis] >= center[axis] {
                orthant |= 1 &<< axis
            } else if !(box.upper[axis] < center[axis]) {
                return nil
            }
        }
        return orthant
    }

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

    // MARK: Mutations

    /// Gives `cell` 2ᵈ children with no items, reusing a freed block when there is one.
    @inlinable
    mutating func makeChildren(_ cell: Int) -> Int32 {
        let first: Int32
        if let block = freeBlocks.popLast() {
            first = block
        } else {
            precondition(firstChild.count <= Int(Int32.max) - Self.childCount, "A spatial tree holds fewer than 2³¹ cells")
            first = Int32(truncatingIfNeeded: firstChild.count)
            for _ in 0 ..< Self.childCount {
                firstChild.append(-1)
                head.append(-1)
                cellCounts.append(0)
            }
        }
        firstChild[cell] = first
        return first
    }

    @inlinable
    mutating func insert(_ element: Element, in box: BoundingBox<Point>) {
        precondition(boxes.count < Int(Int32.max) - 1, "A spatial tree holds fewer than 2³¹ − 1 items")
        let item = Int32(truncatingIfNeeded: boxes.count)
        var current = 0
        var lower = bounds.lower, upper = bounds.upper
        var depth = 0
        while true {
            cellCounts[current] &+= 1
            guard depth < Self.maximumDepth else { break }
            let center = Self.center(lower, upper)
            guard let orthant = Self.orthant(holding: box, center: center) else { break }
            var first = firstChild[current]
            if first < 0 {
                first = makeChildren(current)
            }
            (lower, upper) = Self.child(orthant, lower, upper, center)
            current = Int(first) &+ orthant
            depth &+= 1
        }
        boxes.append(box)
        elements.append(element)
        next.append(head[current])
        cell.append(Int32(truncatingIfNeeded: current))
        head[current] = item
    }

    /// Removes the first item over exactly `box` whose element satisfies `predicate`, and returns
    /// its element.
    @inlinable
    mutating func remove(in box: BoundingBox<Point>, where predicate: (Element) throws -> Bool) rethrows -> Element? {
        guard bounds.contains(box) else { return nil }
        // The path down to the cell an item over `box` hangs on.
        var path: [Int] = [0]
        var current = 0
        var lower = bounds.lower, upper = bounds.upper
        var depth = 0
        while depth < Self.maximumDepth {
            let center = Self.center(lower, upper)
            guard let orthant = Self.orthant(holding: box, center: center) else { break }
            let first = firstChild[current]
            // No cell below: no item was ever placed deeper on this path.
            guard first >= 0 else { return nil }
            (lower, upper) = Self.child(orthant, lower, upper, center)
            current = Int(first) &+ orthant
            path.append(current)
            depth &+= 1
        }
        var previous: Int32 = -1
        var item = head[current]
        while item >= 0 {
            if boxes[Int(item)] == box, try predicate(elements[Int(item)]) { break }
            previous = item
            item = next[Int(item)]
        }
        guard item >= 0 else { return nil }
        if previous < 0 {
            head[current] = next[Int(item)]
        } else {
            next[Int(previous)] = next[Int(item)]
        }
        for cell in path {
            cellCounts[cell] &-= 1
        }
        // The highest cell on the path whose children now hold nothing frees them.
        for cell in path where firstChild[cell] >= 0 {
            let first = Int(firstChild[cell])
            var below: Int32 = 0
            for k in 0 ..< Self.childCount {
                below &+= cellCounts[first &+ k]
            }
            if below == 0 {
                freeChildren(cell)
                break
            }
        }
        return discard(item)
    }

    /// Frees the children of `cell` and every cell below them; none of them holds an item.
    @inlinable
    mutating func freeChildren(_ cell: Int) {
        var blocks: [Int32] = [firstChild[cell]]
        firstChild[cell] = -1
        while let block = blocks.popLast() {
            freeBlocks.append(block)
            for k in 0 ..< Self.childCount {
                let child = Int(block) &+ k
                if firstChild[child] >= 0 {
                    blocks.append(firstChild[child])
                }
                firstChild[child] = -1
                head[child] = -1
                cellCounts[child] = 0
            }
        }
    }

    /// Removes the unlinked item `item`, moving the last item into its slot.
    @inlinable
    mutating func discard(_ item: Int32) -> Element {
        let last = Int32(truncatingIfNeeded: boxes.count &- 1)
        if item != last {
            // Whoever links to the last item links to its new slot instead.
            let lastCell = Int(cell[Int(last)])
            if head[lastCell] == last {
                head[lastCell] = item
            } else {
                var x = head[lastCell]
                while next[Int(x)] != last {
                    x = next[Int(x)]
                }
                next[Int(x)] = item
            }
            boxes.swapAt(Int(item), Int(last))
            elements.swapAt(Int(item), Int(last))
            next.swapAt(Int(item), Int(last))
            cell.swapAt(Int(item), Int(last))
        }
        boxes.removeLast()
        next.removeLast()
        cell.removeLast()
        return elements.removeLast()
    }

    // MARK: Queries

    @inlinable
    func item(_ item: Int32) -> SpatialBoxItem<Point, Element> {
        SpatialBoxItem(box: boxes[Int(item)], element: elements[Int(item)])
    }

    @inlinable
    func items(overlapping box: BoundingBox<Point>) -> [SpatialBoxItem<Point, Element>] {
        var found: [Int32] = []
        collect(0, bounds.lower, bounds.upper, box, &found)
        return found.map(item)
    }

    /// Appends the items in the subtree of `cell`, the box `lower ... upper`, that overlap `box`.
    @inlinable
    func collect(_ current: Int, _ lower: Point, _ upper: Point, _ box: BoundingBox<Point>, _ found: inout [Int32]) {
        guard cellCounts[current] > 0, all(box.lower .<= upper), all(lower .<= box.upper) else { return }
        var item = head[current]
        while item >= 0 {
            if box.intersects(boxes[Int(item)]) {
                found.append(item)
            }
            item = next[Int(item)]
        }
        let first = firstChild[current]
        guard first >= 0 else { return }
        let center = Self.center(lower, upper)
        for orthant in 0 ..< Self.childCount {
            let child = Self.child(orthant, lower, upper, center)
            collect(Int(first) &+ orthant, child.lower, child.upper, box, &found)
        }
    }

    /// The items whose boxes contain `point`. Every such item hangs on a cell that contains the
    /// point, so only the cells on the point's path down from the root are read.
    @inlinable
    func items(containing point: Point) -> [SpatialBoxItem<Point, Element>] {
        var found: [SpatialBoxItem<Point, Element>] = []
        guard bounds.contains(point) else { return found }
        var current = 0
        var lower = bounds.lower, upper = bounds.upper
        while cellCounts[current] > 0 {
            var item = head[current]
            while item >= 0 {
                if boxes[Int(item)].contains(point) {
                    found.append(self.item(item))
                }
                item = next[Int(item)]
            }
            let first = firstChild[current]
            guard first >= 0 else { break }
            let center = Self.center(lower, upper)
            let orthant = Self.orthant(of: point, center: center)
            (lower, upper) = Self.child(orthant, lower, upper, center)
            current = Int(first) &+ orthant
        }
        return found
    }

    /// Every pair of items whose boxes overlap, once each. An item meets only the items at its
    /// own cell and below it, since any overlapping item at an ancestor finds it from there.
    @inlinable
    func overlappingPairs() -> [OverlappingPair<Point, Element>] {
        var pairs: [OverlappingPair<Point, Element>] = []
        var found: [Int32] = []
        var stack: [(cell: Int, lower: Point, upper: Point)] = [(0, bounds.lower, bounds.upper)]
        while let (current, lower, upper) = stack.popLast() {
            guard cellCounts[current] > 0 else { continue }
            let first = firstChild[current]
            let center = Self.center(lower, upper)
            var item = head[current]
            while item >= 0 {
                let box = boxes[Int(item)]
                var other = next[Int(item)]
                while other >= 0 {
                    if box.intersects(boxes[Int(other)]) {
                        pairs.append(OverlappingPair(first: self.item(item), second: self.item(other)))
                    }
                    other = next[Int(other)]
                }
                if first >= 0 {
                    found.removeAll(keepingCapacity: true)
                    for orthant in 0 ..< Self.childCount {
                        let child = Self.child(orthant, lower, upper, center)
                        collect(Int(first) &+ orthant, child.lower, child.upper, box, &found)
                    }
                    for other in found {
                        pairs.append(OverlappingPair(first: self.item(item), second: self.item(other)))
                    }
                }
                item = next[Int(item)]
            }
            if first >= 0 {
                for orthant in 0 ..< Self.childCount {
                    let child = Self.child(orthant, lower, upper, center)
                    stack.append((Int(first) &+ orthant, child.lower, child.upper))
                }
            }
        }
        return pairs
    }

    /// The cells, renumbered from the root in breadth-first order, as each one's parent.
    @inlinable
    func cellParents() -> [Int?] {
        var parents = [Int?](repeating: nil, count: 1)
        var queue = [0]
        var cursor = 0
        while cursor < queue.count {
            let current = queue[cursor]
            let number = cursor
            cursor &+= 1
            let first = firstChild[current]
            guard first >= 0 else { continue }
            for k in 0 ..< Self.childCount {
                queue.append(Int(first) &+ k)
                parents.append(number)
            }
        }
        return parents
    }
}

extension _MXCIFTree: Sendable where Point: Sendable, Element: Sendable {}
