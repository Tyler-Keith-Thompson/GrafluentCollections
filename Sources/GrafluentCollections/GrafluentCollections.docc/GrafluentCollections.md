# ``GrafluentCollections``

Graph-shaped collections for Swift: search trees, tries, suffix structures, decision diagrams,
range and spatial trees, ropes, persistent trees and caches, with value semantics, built on
Grafluent.

## Overview

`import GrafluentCollections` imports every module. Each module also has its own documentation
and can be imported on its own.

```swift
import GrafluentCollections

var scores: FenwickTree = [3, 1, 4, 1, 5, 9, 2, 6]
print(scores.prefixSum(through: 3))  // 9
print(scores.sum(in: 2 ..< 6))       // 19
```

### Values, not references

Every collection is a copy-on-write struct. Assigning one copies nothing until one of the copies
is mutated; then only that copy pays, once, and the other keeps its elements:

```swift
let original: BTree = [1, 2, 3]
var copy = original
copy.insert(4)
Array(original)   // [1, 2, 3]
Array(copy)       // [1, 2, 3, 4]
```

The vertices of a tree live in flat arrays linked by integer indices rather than in a class per
vertex, so a copy is a few array copies and a traversal reads memory almost in order. The API
follows the standard library and Swift Collections: the sorted sets are `SetAlgebra` and
random-access collections indexed by rank, the dictionaries take `subscript(_:default:)`, and the
range trees are collections of their values.

### Traps and checked spellings

A plain spelling traps when its precondition fails, like an `Array` subscript out of range: it is
the fast path, for callers who know the precondition holds. Beside it, a `checked:` spelling
throws a typed error instead, one of those in [`CollectionErrors`](https://tyler-keith-thompson.github.io/GrafluentCollections/documentation/collectionerrors); `try?` turns it into an
optional.

```swift
let primes: AVLTree = [2, 3, 5, 7]
primes[2]                    // 5
try primes[checked: 9]       // throws IndexOutOfRange
```

A mutation that would break a structure's invariant, such as joining two treaps whose elements
interleave, throws on its plain spelling and changes nothing. Where the standard library's
collections return an optional (`remove(_:)`, a dictionary's subscript, `min()`), these do too.

### Grafluent conversions

A collection whose shape is a tree converts to the Grafluent type of that shape: `BinaryTree`,
`Arborescence`, `RootedTree` or `PrefixTree`, with an initializer on the Grafluent type that
costs O(*n*) once. Structures whose shape is a general graph, such as decision diagrams and
automata, offer a view that is a Grafluent graph without copying. Either way, Grafluent's
algorithms, drawings and file formats run over the collection; its own operations never go
through the conversion. <doc:SeeingACollectionAsAGraph> shows the round trip.

### Modules

| Group | Modules |
|---|---|
| Search trees | [`BinarySearchTrees`](https://tyler-keith-thompson.github.io/GrafluentCollections/documentation/binarysearchtrees) (AVL, red–black and splay trees, treaps), [`BTrees`](https://tyler-keith-thompson.github.io/GrafluentCollections/documentation/btrees) (B-trees), [`SkipLists`](https://tyler-keith-thompson.github.io/GrafluentCollections/documentation/skiplists) (skip lists) |
| Tries | [`Tries`](https://tyler-keith-thompson.github.io/GrafluentCollections/documentation/tries) (tries over any sequence of symbols, radix and Patricia trees, Aho–Corasick automata) |
| Suffix structures | [`SuffixStructures`](https://tyler-keith-thompson.github.io/GrafluentCollections/documentation/suffixstructures) (suffix arrays with LCP, suffix trees, suffix automata) |
| Decision diagrams | [`DecisionDiagrams`](https://tyler-keith-thompson.github.io/GrafluentCollections/documentation/decisiondiagrams) (reduced ordered BDDs, zero-suppressed ZDDs) |
| Range and spatial trees | [`RangeTrees`](https://tyler-keith-thompson.github.io/GrafluentCollections/documentation/rangetrees) (Fenwick trees, segment trees with lazy propagation, interval trees), [`SpatialTrees`](https://tyler-keith-thompson.github.io/GrafluentCollections/documentation/spatialtrees) (k-d trees, quadtrees, octrees) |
| Sequences and persistence | [`Ropes`](https://tyler-keith-thompson.github.io/GrafluentCollections/documentation/ropes) (ropes: sequences as balanced trees of chunks), [`PersistentTrees`](https://tyler-keith-thompson.github.io/GrafluentCollections/documentation/persistenttrees) (path-copying weight-balanced trees that keep every version) |
| Caches | [`Caches`](https://tyler-keith-thompson.github.io/GrafluentCollections/documentation/caches) (LRU caches) |
| Shared | [`CollectionErrors`](https://tyler-keith-thompson.github.io/GrafluentCollections/documentation/collectionerrors): the errors the `checked:` spellings throw, re-exported by every module that throws them |

## Topics

### Guides

- <doc:ChoosingASearchTree>
- <doc:TriesAndSuffixStructures>
- <doc:DecisionDiagrams>
- <doc:RangeAndSpatialTrees>
- <doc:SeeingACollectionAsAGraph>
