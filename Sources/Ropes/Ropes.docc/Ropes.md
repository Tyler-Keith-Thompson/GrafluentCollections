# ``Ropes``

Sequences stored as balanced trees of chunks, so edits anywhere cost O(log *n*).

## Overview

A ``Rope`` is a random-access, range-replaceable collection like `Array`, but an insertion or a
removal in the middle moves only the elements of one chunk, not everything after the edit. Its
chunks, each a few kilobytes of elements, are the vertices of an AVL tree that records how many
elements each subtree holds, and an offset is found from the root.

```swift
import Ropes

var text = Rope("Hello, world!")
text.insert(contentsOf: "brave new ", at: 7)
String(text)                       // "Hello, brave new world!"
text.removeSubrange(5 ..< 16)
String(text)                       // "Hello world!"
```

Each chunk is its own copy-on-write buffer. A copy of a rope shares every chunk until one side
edits it, and then copies only that chunk; ``Rope/extracting(_:)`` and ``Rope/+(_:_:)`` share the
chunks they take whole.

The chunks convert to Grafluent's `BinaryTree` with `BinaryTree(_:)`, numbered in sequence order.

## Topics

### Ropes

- ``Rope``
