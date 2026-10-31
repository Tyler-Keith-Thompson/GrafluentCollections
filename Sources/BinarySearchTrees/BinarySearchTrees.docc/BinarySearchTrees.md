# ``BinarySearchTrees``

Balanced binary search trees as sorted sets and sorted dictionaries.

## Overview

An ``AVLTree`` is a sorted set and an ``AVLDictionary`` a sorted dictionary, both kept in an AVL
tree (Adelson-Velsky and Landis, 1962): the heights of every vertex's subtrees differ by at most
one, so lookup, insertion and removal take O(log *n*) and the height stays below
1.4405 log₂(*n* + 2) − 0.3277. A ``RedBlackTree`` is the same sorted set kept in a red–black
tree (Guibas and Sedgewick, 1978), whose height stays at most 2 log₂(*n* + 1) and whose
insertions and removals rotate at most two and three times. A ``Treap`` (Seidel and Aragon,
1996) keeps a random priority on each vertex, so its shape is a random binary search tree's
whatever order the elements came in: O(log *n*) expected for each operation, plus `split(at:)`
and `join(_:)`, which cut a set at an element and put two sets that don't interleave back
together. A ``SplayTree`` (Sleator and Tarjan, 1985) keeps no balance information: each
mutation, and each `access(_:)`, rotates the element it reaches to the root, for O(log *n*)
amortized per operation and fast repeated access to the elements in use. Its other reads leave
the tree as it is. The sets share one API, so any of them can stand in for another. Their elements are random-access collections in ascending order,
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
- ``RedBlackTree``
- ``Treap``
- ``SplayTree``

### Sorted dictionaries

- ``AVLDictionary``
