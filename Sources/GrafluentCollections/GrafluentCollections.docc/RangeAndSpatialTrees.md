# Range and spatial trees

Answer queries over ranges of a sequence, over intervals, and over points in space.

## Overview

The range trees keep a sequence of values and answer questions about a contiguous range of it;
the interval tree keeps ranges and answers which of them meet a point or another range; the
spatial trees keep points and answer which of them are near a point or inside a box.

### Prefix sums: FenwickTree

A `FenwickTree` keeps prefix sums of a sequence under point updates, each in O(log *n*), in one
array the size of the sequence. Use it for running totals, ranks and counts:

```swift
var scores: FenwickTree = [3, 1, 4, 1, 5, 9, 2, 6]
scores.prefixSum(through: 3)    // 9
scores.sum(in: 2 ..< 6)         // 19
```

### Any associative combination: SegmentTree

A `SegmentTree` combines any range under a monoid (`Sum`, `Minimum`, `Maximum`, or one of your
own), not only sums, and need not be commutative:

```swift
var tree = SegmentTree<Minimum<Int>>([5, 3, 8, 6, 1, 9])
tree.combined(in: 0 ..< 4)      // 3
tree.update(at: 2, to: 0)
tree.combined(in: 0 ..< 4)      // 0
```

A `LazySegmentTree` adds updates that apply to a whole range at once, such as adding to every
value in a range or setting each one, with the update and its effect on the monoid named by a
`MonoidAction`.

### Intervals: IntervalTree

An `IntervalTree` keeps half-open ranges with a value each and finds those that contain a point,
overlap a range or lie inside one:

```swift
var meetings = IntervalTree<Int, String>()
meetings.insert(9 ..< 10, value: "stand-up")
meetings.insert(10 ..< 12, value: "design review")
meetings.insert(11 ..< 13, value: "lunch")
meetings.containing(11).map(\.value)          // ["design review", "lunch"]
```

### Points: KDTree, Quadtree and Octree

A `KDTree` is built once from a set of points of any dimension and answers nearest-neighbor,
radius and box queries. It suits points that rarely change:

```swift
let tree = KDTree<SIMD2<Double>>([[2, 3], [5, 4], [9, 6], [4, 7], [8, 1], [7, 2]])
tree.nearestIndex(to: [9, 2])                                    // 4: the point [8, 1]
tree.indices(in: BoundingBox(lower: [0, 0], upper: [5, 5]))      // [0, 1]
```

A `Quadtree` (in the plane) and an `Octree` (in space) divide a fixed bounding box into buckets
and take insertions and removals as they come, which suits points that move or arrive over time:

```swift
var map = Quadtree<String>(bounds: BoundingBox(lower: [0, 0], upper: [100, 100]))
map.insert("café", at: [10, 20])
map.insert("library", at: [12, 22])
map.insert("station", at: [80, 75])
map.nearest(to: [11, 19])?.element              // "café"
map.items(within: 5, of: [11, 21]).count        // 2
```

### Choosing

| Question | Type |
|---|---|
| Prefix and range sums under point updates | `FenwickTree` |
| Any associative combination of a range | `SegmentTree` |
| The same, with updates to whole ranges | `LazySegmentTree` |
| Which intervals meet a point or a range | `IntervalTree` |
| Nearest points in a fixed set, any dimension | `KDTree` |
| Points that change, in two or three dimensions | `Quadtree`, `Octree` |
