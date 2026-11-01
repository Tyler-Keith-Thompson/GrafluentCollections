# ``Tries``

Tries over sequences of any `Hashable` symbols, with prefix queries.

## Overview

A ``Trie`` is a set of sequences and a ``TrieDictionary`` a dictionary keyed by them, both kept in
a trie (Fredkin, 1960): a tree whose edges carry symbols and whose root-to-vertex paths spell the
keys. They answer the queries a hash set cannot: every key with a prefix
(`elements(withPrefix:)`, whose `count` is O(1)), whether any key has one (`hasPrefix(_:)`), and
the longest key that is a prefix of a query (`longestPrefix(of:)`).

```swift
import Tries

let words = Trie(["car", "cart", "cat", "dog"])
words.contains("cat")                                   // true
words.elements(withPrefix: "car").map { String($0) }    // ["car", "cart"]
words.longestPrefix(of: "carton").map { String($0) }    // "cart"
```

Keys are any sequence of the symbol type and are stored as `[Symbol]`. For text, the symbol
type decides what a step is: `Trie<Character>` steps by grapheme cluster, `Trie<Unicode.Scalar>`
by scalar, and `Trie<UInt8>` over `utf8` by byte, the fastest of the three, because comparing
bytes is cheaper than comparing `Character`s. When the symbols are `Comparable`, each vertex keeps
its children sorted, so iteration is in lexicographic order; otherwise children come in the order
they were added.

A ``RadixTree`` and a ``RadixTreeDictionary`` hold the same keys and answer the same queries,
with the same names, in a radix tree (Morrison, 1968): every chain of vertices with one child and
no key is merged into one edge labelled with all its symbols, so there is a vertex per key and per
branching point rather than per symbol. They suit keys with long shared prefixes, such as file
paths or URLs, and build faster and in less memory than a trie of the same keys.

A trie's shape converts to Grafluent's `PrefixTree` with `PrefixTree(_:)`, and a radix tree's to
an `Arborescence` of its vertices' prefixes with `Arborescence(_:)` (import Grafluent's `Trees`
module beside this one).

## Topics

### Sets of sequences

- ``Trie``
- ``RadixTree``

### Dictionaries keyed by sequences

- ``TrieDictionary``
- ``RadixTreeDictionary``
