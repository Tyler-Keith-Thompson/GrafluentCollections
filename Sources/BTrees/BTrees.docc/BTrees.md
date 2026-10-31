# ``BTrees``

B-trees as sorted sets and sorted dictionaries.

## Overview

A ``BTree`` is a sorted set and a ``BTreeDictionary`` a sorted dictionary, both kept in a B-tree
(Bayer and McCreight, 1972): each node holds tens of elements side by side in ascending order, and
every leaf lies at the same depth. A lookup reads a few nodes, and few cache lines, so lookup,
insertion and removal take O(log *n*) with a node-sized constant. Their elements are random-access
collections in ascending order, indexed by rank, with `lowerBound(_:)`, `upperBound(_:)`,
`elements(in:)` and `split(at:)`; the API matches the sorted sets and dictionaries of
`BinarySearchTrees`.

```swift
import BTrees

var primes: BTree = [7, 2, 11, 3, 5]
primes.insert(13)
primes.contains(4)      // false
primes.lowerBound(6)    // 3, the index of 7

var stock: BTreeDictionary = ["pear": 4, "apple": 7]
stock["fig"] = 2
stock.map(\.key)        // ["apple", "fig", "pear"]
```

Each node is one allocation, shared between copies of the tree: mutating a copy copies only the
nodes on the path it changes and leaves the rest shared. The shape converts to Grafluent's
`RootedTree` with `RootedTree(_:)`, a vertex per node (import Grafluent's `Trees` module beside
this one).

## Topics

### Sorted sets

- ``BTree``

### Sorted dictionaries

- ``BTreeDictionary``
