# ``SpatialTrees``

Trees over points and boxes in space that find the points nearest a query or within a radius or a box, and the boxes that overlap.

## Overview

A ``KDTree`` holds a fixed set of points, SIMD vectors such as `SIMD2<Double>` or
`SIMD3<Float>`. It splits them at the median of the first coordinate, then each half at the
median of the second, cycling through the dimensions, and keeps the result in one flat array
with no links: every subtree is a contiguous run with its median in the middle.

```swift
import SpatialTrees

let tree = KDTree<SIMD2<Double>>([[2, 3], [5, 4], [9, 6], [4, 7], [8, 1], [7, 2]])
tree.nearestIndex(to: [9, 2])              // 4: the point [8, 1]
tree.nearestIndices(to: [9, 2], count: 2)  // [4, 5]
tree.indices(within: 3, of: [5, 5])        // [1, 3]
```

The six points split first on *x* at the median [7, 2], then each side on *y*:

| Vertex | Splits on | Left subtree | Right subtree |
|---|---|---|---|
| [7, 2] | *x* = 7 | [5, 4], [2, 3], [4, 7] | [9, 6], [8, 1] |
| [5, 4] | *y* = 4 | [2, 3] | [4, 7] |
| [9, 6] | *y* = 6 | [8, 1] | |

A search for the point nearest [9, 2] starts on the right of *x* = 7, finds [8, 1] at distance
√2, and skips the whole left side, since the plane *x* = 7 is 2 away, farther than that. Searches answer
with the indices the points were given at, and ``BoundingBox`` describes a box for
``KDTree/indices(in:)``.

The tree's shape converts to Grafluent's `BinaryTree` with `BinaryTree(_:)`, whose vertices are
the points' indices.

A ``Quadtree`` and an ``Octree`` hold elements at points, and unlike a k-d tree take insertions
and removals as the points move. Each splits its region into four (eight) equal cells, and each
cell again, until every leaf holds at most a bucket of elements; a removal that leaves a cell's
children holding no more than a bucket merges them back. Searches return ``SpatialItem`` values,
an element with its point.

```swift
var map = Quadtree<String>(bounds: BoundingBox(lower: [0, 0], upper: [100, 100]))
map.insert("café", at: [10, 20])
map.insert("station", at: [80, 75])
map.nearest(to: [11, 19])?.element   // "café"
map.remove("café", at: [10, 20])
```

Their cells convert to Grafluent's `RootedTree` with `RootedTree(_:)`, so Grafluent draws the
subdivision.

An ``MXCIFQuadtree`` and an ``MXCIFOctree`` hold elements over boxes. Each element hangs on the
smallest cell that wholly contains its box, so a box straddling a cell's centre line stays at
that cell, and cells are made on the way down and freed when they empty. Searches find the
boxes containing a point, those overlapping a box, and every overlapping pair, as
``SpatialBoxItem`` and ``OverlappingPair`` values. Boxes include their faces, so touching boxes
overlap.

```swift
var plan = MXCIFQuadtree<String>(bounds: BoundingBox(lower: [0, 0], upper: [100, 100]))
plan.insert("hall", in: BoundingBox(lower: [10, 10], upper: [60, 20]))
plan.insert("office", in: BoundingBox(lower: [10, 20], upper: [30, 40]))
plan.items(containing: [20, 15]).map(\.element)   // ["hall"]
plan.overlappingPairs().count                     // 1
```

## Topics

### k-d trees

- ``KDTree``
- ``BoundingBox``

### Quadtrees and octrees

- ``Quadtree``
- ``Octree``
- ``SpatialItem``

### Boxes

- ``MXCIFQuadtree``
- ``MXCIFOctree``
- ``SpatialBoxItem``
- ``OverlappingPair``
