# ``BinarySearchTrees``

Balanced binary search trees as sorted sets and sorted dictionaries.

## Overview

An ``AVLTree`` is a sorted set and an ``AVLDictionary`` a sorted dictionary, both kept in an AVL
tree (Adelson-Velsky and Landis, 1962): the heights of every vertex's subtrees differ by at most
one, so lookup, insertion and removal take O(log *n*) and the height stays below
1.4405 log₂(*n* + 2) − 0.3277. Their elements are random-access collections in ascending order,
indexed by rank, with `lowerBound(_:)`, `upperBound(_:)` and `elements(in:)` for range queries.

```swift
import BinarySearchTrees

var primes: AVLTree = [7, 2, 11, 3, 5]
primes.insert(13)
primes.contains(4)      // false
primes.lowerBound(6)    // 3, the index of 7

var stock: AVLDictionary = ["pear": 4, "apple": 7]
stock["fig"] = 2
stock.map(\.key)        // ["apple", "fig", "pear"]
```

The vertices live in flat arrays linked by `Int32` slots, so a tree is a copy-on-write value
that copies a few arrays, and only when a shared copy is mutated. Its shape converts to
Grafluent's `BinaryTree` with `BinaryTree(_:)` (import Grafluent's `Trees` module beside this
one), so Grafluent's tree algorithms and drawings run over it.

## Topics

### Sorted sets

- ``AVLTree``

### Sorted dictionaries

- ``AVLDictionary``
