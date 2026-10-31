# ``GrafluentCollections``

Graph-shaped collections for Swift: search trees, tries, suffix structures and decision diagrams
with value semantics, built on Grafluent.

## Overview

Every collection is a copy-on-write struct with the API shape of the standard library's
collections and Swift Collections. Where a structure is a tree or a graph, it also converts to the
Grafluent type of that shape (`BinaryTree`, `Arborescence`, `RootedTree`), so Grafluent's
algorithms and drawings run over it.

`import GrafluentCollections` imports every module. Each module also has its own documentation and
can be imported on its own.

```swift
import GrafluentCollections

var scores: FenwickTree = [3, 1, 4, 1, 5, 9, 2, 6]
print(scores.prefixSum(through: 3))  // 9
print(scores.sum(in: 2 ..< 6))       // 19
```

## Topics

### Modules

- ``BinarySearchTrees``
- ``RangeTrees``
- ``CollectionErrors``
