# ``SkipLists``

Skip lists as sorted sets, with their levels as a directed graph.

## Overview

A ``SkipList`` is a sorted set kept in a skip list (Pugh, 1990): sorted linked lists stacked in
levels, each level a random sample of the one below, searched from the top level down. Each
element's tower gains a level with probability 1/4, so lookup, insertion and removal take
O(log *n*) expected time with no rebalancing. Its elements are a random-access collection in
ascending order, indexed by rank, with `lowerBound(_:)`, `upperBound(_:)` and `elements(in:)`;
the API matches the sorted sets of `BinarySearchTrees`.

```swift
import SkipLists

var numbers: SkipList = [8, 3, 5, 1, 9]
numbers.insert(4)
numbers.contains(2)     // false
numbers.lowerBound(5)   // 3, the index of 5
```

The tower heights come from a random number generator given at creation; a seeded one makes every
list reproducible. The list's levels are a directed acyclic graph, which
``SkipList/layersView`` exposes to Grafluent's algorithms and drawings as a `DirectedGraph`
(import Grafluent's `GraphProtocols` module beside this one): a vertex for each element on each
level of its tower, an edge along each level and an edge down each tower.

## Topics

### Sorted sets

- ``SkipList``
