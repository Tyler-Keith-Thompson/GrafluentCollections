# ``Caches``

Bounded dictionaries that evict by recency.

## Overview

An ``LRUCache`` holds at most a fixed number of entries. Storing one more when it is full evicts
the least recently used entry, where reading a value or storing it counts as a use.

```swift
import Caches

var cache = LRUCache<String, Int>(capacity: 2)
cache["a"] = 1
cache["b"] = 2
_ = cache["a"]                     // 1, and "a" is now the most recent
cache["c"] = 3                     // evicts "b", the least recent
cache.map(\.key)                   // ["c", "a"]
```

The entries live in one flat array, linked by indices from the most recent to the least, beside
a hash table from keys to positions, so every operation is O(1) on average. ``LRUCache/peek(_:)``
and ``LRUCache/contains(_:)`` read without promoting, ``LRUCache/insert(_:forKey:)`` reports the
entry it evicted, and iterating visits the entries from most to least recent. The cache is a
value: a copy is a snapshot whose order changes independently.

The recency list converts to Grafluent's `RootedTree` with `RootedTree(_:)`, a path from the most
recent entry down.

## Topics

### Caches

- ``LRUCache``
