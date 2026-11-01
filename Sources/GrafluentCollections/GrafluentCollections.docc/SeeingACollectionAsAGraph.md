# Seeing a collection as a graph

Convert a collection's shape to a Grafluent graph, then lay it out, write it or run an algorithm
over it.

## Overview

The collections keep their vertices in flat arrays private to each type. To look at a
collection's shape, convert it to the Grafluent type of that shape. The conversion is an
initializer on the Grafluent type and costs O(*n*) once; the result is a snapshot, and later
edits to the collection don't reach it:

```swift
import GrafluentCollections
import Trees

var primes: AVLTree = [2, 3, 5]
let shape = BinaryTree(primes)!   // nil when the collection is empty
primes.insert(7)
shape.vertexCount                 // 3
```

| Collection | Grafluent type |
|---|---|
| `AVLTree`, `AVLDictionary`, `RedBlackTree`, `Treap`, `SplayTree` | `BinaryTree` |
| `PersistentTreeSet`, `PersistentTreeDictionary` | `BinaryTree` |
| `BTree`, `BTreeDictionary` | `RootedTree`, one vertex per node |
| `Trie`, `TrieDictionary` | `PrefixTree` |
| `RadixTree`, `RadixTreeDictionary` | `Arborescence` |
| `SuffixTree` | `RootedTree` |
| `SuffixAutomaton` | `Arborescence` (the suffix-link tree) |
| `FenwickTree` | `Arborescence` (the update tree) |
| `SegmentTree`, `LazySegmentTree`, `IntervalTree`, `KDTree`, `Rope` | `BinaryTree` |
| `Quadtree`, `Octree` | `RootedTree` |
| `LRUCache` | `RootedTree` (the recency order, a path) |

A structure whose shape is not a tree offers a view instead: a Grafluent graph over the
collection's own storage, made in O(1). `BinaryDecisionDiagram.graphView` and
`ZeroSuppressedDecisionDiagram.graphView` are the diagrams' tables, `SkipList.layersView` is the
skip list's levels, `AhoCorasickAutomaton.statesView` is the automaton with its failure links,
and `SuffixAutomaton.transitionsView` and `SuffixTree.suffixLinksView` are those structures'
other edges.

### Writing the shape

Grafluent's `GraphFormats` module writes any graph as DOT, GraphML, GEXF, node-link JSON, an
edge list, an adjacency list or Mermaid. An `Arborescence` keeps every edge pointing from parent
to child:

```swift
import GraphFormats

let primes: AVLTree = [2, 3, 5, 7, 11, 13, 17]
let shape = Arborescence(BinaryTree(primes)!)
var text = ""
try shape.writeMermaid(to: &text)
print(text)
```

```
flowchart TD
    7
    3
    13
    2
    5
    11
    17
    7 --> 3
    7 --> 13
    3 --> 2
    3 --> 5
    13 --> 11
    13 --> 17
```

`writeDOT(to:)` gives Graphviz input the same way, with closures for each vertex's ID and
attributes when the default descriptions won't do.

### Drawing the shape

Grafluent's `GraphDrawing` module lays out a `RootedTree` with Reingold and Tilford's tidy
drawing: the root at the origin, each depth one unit lower, and every parent centred over its
children.

```swift
import GraphDrawing

let tree = RootedTree(Arborescence(BinaryTree(primes)!))
let drawing = tree.reingoldTilfordLayout()
drawing.position(of: 7)     // (0, 0)
drawing.position(of: 3)     // (-1, 1)
drawing.position(of: 17)    // (1.5, 2)
```

### Running an algorithm

A converted shape or a view is an ordinary Grafluent graph, so its traversals, shortest paths and
tree algorithms take it as they would any other:

```swift
var diagram = BinaryDecisionDiagram(variableCount: 2)
_ = diagram.and(diagram.variable(0), diagram.variable(1))
let view = diagram.graphView      // a DirectedGraph over the diagram's table
view.vertexCount                  // 5: two terminals and three decisions
view.edgeCount                    // 6
```
