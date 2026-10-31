# ``RangeTrees``

Trees over a sequence of values that answer range queries and take updates in O(log *n*).

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

## Topics

### Fenwick trees

- ``FenwickTree``
