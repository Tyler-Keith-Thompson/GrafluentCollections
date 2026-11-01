# ``DecisionDiagrams``

Canonical diagrams of Boolean functions.

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

## Topics

### Binary decision diagrams

- ``BinaryDecisionDiagram``
