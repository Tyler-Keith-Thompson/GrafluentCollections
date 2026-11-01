# ``PersistentTrees``

Balanced search trees that keep every version, sharing structure between them.

## Overview

A ``PersistentTreeSet`` or ``PersistentTreeDictionary`` never changes a vertex once it is made.
An edit builds new vertices along the path from the root to the change, O(log *n*) of them, and
points them at the untouched subtrees of the version it started from. Every earlier version
stays as it was, and a history of *n* edits costs O(*n* log *n*) space in all.

```swift
import PersistentTrees

let empty = PersistentTreeSet<Int>()
let one = empty.inserting(5)
let two = one.inserting(3)
let three = two.removing(5)
Array(one)                         // [5]
Array(two)                         // [3, 5]
Array(three)                       // [3]
```

The trees are weight-balanced: neither subtree of a vertex holds more than three times the keys
of the other. Union, intersection, difference and symmetric difference split one tree by the
other's root and join the halves, in O(*m* log(*n* / *m* + 1)) for sets of *m* ≤ *n* elements,
and a subtree both operands share is kept whole without being visited. Two versions a few edits
apart therefore merge in time proportional to those edits.

A version converts to Grafluent's `BinaryTree` with `BinaryTree(_:)`, its elements or keys as
vertices.

## Topics

### Sets and dictionaries

- ``PersistentTreeSet``
- ``PersistentTreeDictionary``
