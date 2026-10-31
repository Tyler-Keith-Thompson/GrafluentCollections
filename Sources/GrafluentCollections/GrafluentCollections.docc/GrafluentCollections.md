# ``GrafluentCollections``

Graph-shaped collections for Swift: search trees, tries, suffix structures and decision diagrams
with value semantics, built on Grafluent.

## Overview

Every collection is a copy-on-write struct with the API shape of the standard library's
collections and Swift Collections. Where a structure is a tree or a graph, it also converts to the
Grafluent type of that shape (`BinaryTree`, `Arborescence`, `RootedTree`), so Grafluent's
algorithms and drawings run over it.

`import GrafluentCollections` imports every module. Each module also has its own documentation and
can be imported on its own. No structure has landed yet; `Greetings` is the template's placeholder
module.

```swift
import GrafluentCollections

let greeting = Greeting(name: "Ada").formal().punctuated(with: "!")
print(greeting.text)  // Good day, Ada!
```

## Topics

### Modules

- ``Greetings``
