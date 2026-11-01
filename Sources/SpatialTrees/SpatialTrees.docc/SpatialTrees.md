# ``SpatialTrees``

Trees over points in space that find the points nearest a query, or within a radius or a box.

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

## Topics

### k-d trees

- ``KDTree``
- ``BoundingBox``
