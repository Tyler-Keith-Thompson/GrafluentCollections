# ``RangeTrees``

Trees over a sequence of values or a set of intervals that answer range queries and take updates
in O(log *n*).

## Overview

A ``FenwickTree`` keeps the prefix sums of a sequence of values in one flat array of partial
sums. Prefix sums, range sums and point updates each touch O(log *n*) cells, and
``FenwickTree/lowerBound(ofPrefixSum:)`` finds where a running total crosses a value by binary
lifting.

```swift
import RangeTrees

var scores: FenwickTree = [3, 1, 4, 1, 5, 9, 2, 6]
scores.prefixSum(through: 3)        // 9
scores.sum(in: 2 ..< 6)             // 19
scores.add(10, at: 1)
scores.lowerBound(ofPrefixSum: 15)  // 2
```

A Fenwick tree's update tree, in which each cell's parent is the next cell an add reaches,
converts to Grafluent's `Arborescence` with `Arborescence(_:)` (import Grafluent's `Trees`
module beside this one), so Grafluent's tree algorithms and drawings run over it.

A ``SegmentTree`` combines any range of values under a ``Monoid``: an associative operation with
an identity, written as a type such as ``Sum``, ``Minimum`` or one of your own, which need not be
commutative. Range queries and point updates take O(log *n*), and
``SegmentTree/maxRight(from:where:)`` and ``SegmentTree/minLeft(upTo:where:)`` find how far a
range can grow while a monotone condition on it holds.

```swift
var heights = SegmentTree<Maximum<Int>>([3, 1, 4, 1, 5, 9, 2, 6])
heights.combined(in: 0 ..< 4)        // 4
heights.update(at: 1, to: 7)
heights.maxRight(from: 0) { $0 < 9 } // 5
```

A ``LazySegmentTree`` also applies an update to every value in a range in O(log *n*), leaving it
pending at the cells that cover the range. A ``MonoidAction`` names the monoid, the updates and
how an update changes a combined value; it is told how many values the combination covers, so
adding a constant to a range of sums is `sum + update * count`.

An ``IntervalTree`` holds half-open intervals with a value each, in an AVL tree ordered by lower
bound whose vertices also record the largest upper bound below them. It finds the intervals that
contain a point, overlap a range or lie within one, skipping every subtree that ends too early.

```swift
var bookings = IntervalTree<Int, String>()
bookings.insert(9 ..< 11, value: "Ada")
bookings.insert(10 ..< 12, value: "Grace")
bookings.containing(10).map(\.value)          // ["Ada", "Grace"]
bookings.overlapping(11 ..< 13).map(\.value)  // ["Grace"]
```

The segment trees' and the interval tree's shapes convert to Grafluent's `BinaryTree` with
`BinaryTree(_:)`.

## Topics

### Fenwick trees

- ``FenwickTree``

### Segment trees

- ``SegmentTree``
- ``LazySegmentTree``

### Interval trees

- ``IntervalTree``

### Monoids

- ``Monoid``
- ``Sum``
- ``Product``
- ``Minimum``
- ``Maximum``
- ``MonoidAction``
