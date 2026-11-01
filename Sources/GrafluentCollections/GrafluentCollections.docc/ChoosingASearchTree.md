# Choosing a search tree

Pick a sorted set or sorted dictionary by the workload it will see.

## Overview

The sorted sets share one API: `insert(_:)`, `remove(_:)`, `contains(_:)`, `SetAlgebra`'s set
operations, `lowerBound(_:)`, `upperBound(_:)`, `elements(in:)`, and the elements as a
random-access collection in ascending order, indexed by rank. Changing which one a program uses
is a change of type name:

```swift
let avl: AVLTree = [40, 10, 30, 20]
let redBlack: RedBlackTree = [40, 10, 30, 20]
let bTree: BTree = [40, 10, 30, 20]
let skipList: SkipList = [40, 10, 30, 20]

Array(avl)              // [10, 20, 30, 40], and the same for the others
avl.lowerBound(25)      // 2, the index of 30
bTree.lowerBound(25)    // 2
```

Every one takes O(log *n*) per lookup, insertion and removal (expected for the treap and skip
list, amortized for the splay tree). They differ in the constant, in what else they offer, and in
which workloads they suit.

### Lookups and scans over a large set: BTree

A B-tree node ([`BTrees`](https://tyler-keith-thompson.github.io/GrafluentCollections/documentation/btrees)) holds tens of elements side by side, so a lookup reads a few nodes and few
cache lines, and iteration walks contiguous arrays. For a large set that is read far more often
than it is changed, and for range scans, a `BTree` is the default. Copying a B-tree shares its
nodes, and a mutated copy copies only the nodes on the path it changes. `BTreeDictionary` is
its sorted dictionary.

### Balanced binary trees: AVLTree and RedBlackTree

An `AVLTree` keeps the heights of every vertex's subtrees within one of each other, so it is the
shallowest of the binary trees and the quickest of them to search. A `RedBlackTree` allows a
taller tree and in return rotates at most two or three times per insertion or removal; prefer it
when changes outnumber lookups. Both convert to a Grafluent `BinaryTree` that shows the exact
shape. `AVLDictionary` is the sorted dictionary in an AVL tree.

### Splitting and joining: Treap

A `Treap` keeps a random priority on each vertex, which makes its shape a random binary search
tree's whatever order the elements arrive in, and gives it `split(at:)` and `join(_:)`:

```swift
let numbers: Treap = [8, 3, 5, 1, 9]
let parts = numbers.split(at: 5)
Array(parts.lower)            // [1, 3]
Array(parts.upper)            // [5, 8, 9]
var rejoined = parts.lower
try rejoined.join(parts.upper)
rejoined == numbers           // true
```

`join(_:)` throws `OverlappingKeys` when the sets interleave. Pass a seeded generator to
`Treap(_:using:)` to make every shape reproducible. `BTree` splits too.

### A working set of hot elements: SplayTree

A `SplayTree` keeps no balance information. `access(_:)` and each mutation rotate the element
they reach to the root, so a run of lookups that keeps returning to a few elements finds them
near the top:

```swift
var recent: SplayTree = [10, 20, 30, 40, 50]
recent.access(40)             // 40, now at the root
```

Its other reads, `contains(_:)` among them, leave the tree as it is, so they keep value
semantics; use `access(_:)` where the splay is wanted.

### A sorted queue with a simple structure: SkipList

A skip list ([`SkipLists`](https://tyler-keith-thompson.github.io/GrafluentCollections/documentation/skiplists)) stacks sorted linked levels, each holding about half the elements of
the one below. Its insertions touch only the levels an element reaches, and its levels are a
Grafluent graph through `layersView`.

### Keeping every version: PersistentTreeSet

When old versions must stay readable, as in undo histories, snapshots handed to other tasks or
backtracking searches, a persistent set ([`PersistentTrees`](https://tyler-keith-thompson.github.io/GrafluentCollections/documentation/persistenttrees)) shares all but the vertices an edit touched:

```swift
let empty = PersistentTreeSet<Int>()
let one = empty.inserting(5)
let two = one.inserting(3)
let three = two.removing(5)
Array(one)                    // [5]
Array(two)                    // [3, 5]
Array(three)                  // [3]
```

Each version costs O(log *n*) new vertices rather than a copy of the whole tree.
`PersistentTreeDictionary` is the sorted dictionary.

### Summary

| Workload | Type |
|---|---|
| Large sets, mostly lookups, range scans | `BTree`, `BTreeDictionary` |
| Mostly lookups, a binary shape to inspect | `AVLTree`, `AVLDictionary` |
| Mostly insertions and removals | `RedBlackTree` |
| Splitting and joining sets | `Treap`, `BTree` |
| Repeated access to a few elements | `SplayTree` |
| Every version kept | `PersistentTreeSet`, `PersistentTreeDictionary` |
| A simple sorted queue | `SkipList` |
