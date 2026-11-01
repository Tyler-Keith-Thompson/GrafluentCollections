# Decision diagrams

Represent Boolean functions and families of sets as shared, canonical graphs.

## Overview

A decision diagram stores many Boolean functions, or many families of sets, in one table of
shared vertices. Equal functions are the same vertex, so comparing two functions is comparing
two integers, and operations that combine functions are memoized over the table.

### Binary decision diagrams

A `BinaryDecisionDiagram` is reduced and ordered: variables appear in one order on every path,
and no vertex is redundant. Build functions from variables with `and`, `or`, `not` and the other
operators, then ask about them:

```swift
var diagram = BinaryDecisionDiagram(variableCount: 3)
let x0 = diagram.variable(0), x1 = diagram.variable(1), x2 = diagram.variable(2)
let f = diagram.or(diagram.and(x0, x1), x2)
let g = diagram.or(x2, diagram.and(x1, x0))
f == g                                     // true: the same function, the same vertex
diagram.satisfyingAssignmentCount(of: f)   // 5
```

The functions are handles into the diagram that made them, so the diagram is the value that
mutates as functions are built. Use one when a problem is a constraint over Boolean variables:
configurations, reachability in a finite state system, equivalence of circuits.

### Zero-suppressed decision diagrams

A `ZeroSuppressedDecisionDiagram` drops a vertex when its "with this element" branch is empty,
rather than when both branches agree. That suits families of sparse sets, where most elements
are absent from most sets: combinations, paths in a graph, itemsets.

```swift
var diagram = ZeroSuppressedDecisionDiagram(elementCount: 3)
let f = diagram.family([[0, 1], [1, 2], [2]])
diagram.count(of: f)                                  // 3
let g = diagram.including(2, in: f)                   // {{1, 2}, {2}}
diagram.minimalSets(of: g) == diagram.family([[2]])   // true
```

### Choosing

Use a BDD for a Boolean function of the variables, and a ZDD for a family of sets over a
universe of elements, most of which are absent from each set. A family can be written as a BDD
too, and a function as a ZDD, but the other choice is usually smaller.

Both diagrams' `graphView` is a Grafluent `DirectedGraph` over the whole table, so Grafluent's
traversals and writers run over it.
