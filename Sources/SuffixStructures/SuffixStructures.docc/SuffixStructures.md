# ``SuffixStructures``

Structures over a text's suffixes that answer substring queries.

## Overview

A ``SuffixArray`` holds the starting positions of a text's suffixes in sorted order, with the
length of the prefix each shares with the one before it (Manber and Myers, 1990). Every
occurrence of a pattern is a run of neighbouring suffixes, found by binary search, and the
prefix lengths give the longest repeated substring and the number of distinct substrings.

```swift
import SuffixStructures

let banana = SuffixArray("banana")
let found = banana.occurrences(of: "ana")
found.map { banana.positions[$0] }   // [3, 1]
banana.longestRepeatedSubstring      // 1 ..< 4, "ana"
banana.distinctSubstringCount        // 15
```

The text may be any sequence of `Comparable` symbols. For `UInt8`, such as a string's `utf8`,
construction sorts the bytes themselves in O(*n*) (induced sorting: Nong, Zhang and Chan, 2009);
any other symbol type is first replaced by its rank among the text's distinct symbols.

## Topics

### Suffix arrays

- ``SuffixArray``
