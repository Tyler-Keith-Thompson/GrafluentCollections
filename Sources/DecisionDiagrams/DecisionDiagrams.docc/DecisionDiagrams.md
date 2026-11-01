# ``DecisionDiagrams``

Canonical diagrams of Boolean functions and families of sets.

## Overview

A ``BinaryDecisionDiagram`` is a table of reduced ordered binary decision diagrams (Bryant,
1986). Each function is a directed acyclic graph whose vertices test variables in index order,
with a low child for the variable false and a high child for true, down to the constants. No two
vertices test the same variable with the same children, and none has equal children, so each
function has exactly one root, and checking whether two functions are equal is comparing roots.

```swift
import DecisionDiagrams

var diagram = BinaryDecisionDiagram(variableCount: 3)
let x0 = diagram.variable(0), x1 = diagram.variable(1), x2 = diagram.variable(2)
let f = diagram.or(diagram.and(x0, x1), x2)   // x0 ∧ x1 ∨ x2
diagram.satisfyingAssignmentCount(of: f)       // 5
diagram.anySatisfyingAssignment(of: f)         // [false, false, true]
```

The diagram of `f` has five vertices: three tests and the two constants. Following the low edge
means the variable is false, the high edge that it is true.

| Vertex | Tests | Low child | High child |
|---|---|---|---|
| root | `x0` | the test of `x2` | the test of `x1` |
| | `x1` | the test of `x2` | true |
| | `x2` | false | true |

The test of `x2` is shared: `x0` false and `x0 ∧ ¬x1` both leave `f` equal to `x2`, so both lead
to the one vertex that stands for it.

Functions combine under any of the sixteen binary operators with
``BinaryDecisionDiagram/apply(_:_:_:)`` in O(|*f*| |*g*|), through a computed table of results
already found. ``BinaryDecisionDiagram/restrict(_:variable:to:)`` fixes a variable, and
``BinaryDecisionDiagram/exists(_:in:)`` and ``BinaryDecisionDiagram/forall(_:in:)`` quantify
over variables. The table's vertices are a `DirectedGraph`, ``BinaryDecisionDiagram/graphView``,
so Grafluent's traversals and drawings run over a function's diagram from its root.

A ``ZeroSuppressedDecisionDiagram`` is a table of families of sets (Minato, 1993). Its vertices
test elements in index order, with a low child for the sets without the element and a high child
for those with it. In place of the rule that removes a vertex with equal children, it removes one
whose high child is the empty family, so an element no set contains never appears in a diagram,
and a sparse family over many elements stays small.

```swift
var diagram = ZeroSuppressedDecisionDiagram(elementCount: 3)
let f = diagram.family([[0, 1], [1, 2], [2]])
diagram.count(of: f)                                 // 3
diagram.minimalSets(of: diagram.including(2, in: f)) // {{2}}
```

Families combine by ``ZeroSuppressedDecisionDiagram/union(_:_:)``,
``ZeroSuppressedDecisionDiagram/intersection(_:_:)`` and
``ZeroSuppressedDecisionDiagram/subtracting(_:from:)``, and set by set by
``ZeroSuppressedDecisionDiagram/join(_:_:)`` and ``ZeroSuppressedDecisionDiagram/meet(_:_:)``.
``ZeroSuppressedDecisionDiagram/setsView(of:)`` lists a family's sets, and its
``ZeroSuppressedDecisionDiagram/graphView`` is a `DirectedGraph` like the binary diagram's.

## Topics

### Binary decision diagrams

- ``BinaryDecisionDiagram``

### Zero-suppressed decision diagrams

- ``ZeroSuppressedDecisionDiagram``
