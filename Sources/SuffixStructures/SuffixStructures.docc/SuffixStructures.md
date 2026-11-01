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

A ``SuffixTree`` is the compressed trie of the same suffixes, built left to right by Ukkonen's
algorithm (1995), over one text or several. A pattern is found in O(*m*) steps down from the
root; the deepest internal node is the longest repeated substring, and the deepest node with
suffixes of every text below it the longest common substring. Its nodes convert to Grafluent's
`RootedTree` with `RootedTree(_:)`, and its suffix links are a `DirectedGraph`,
``SuffixTree/suffixLinksView``.

```swift
let both = SuffixTree(texts: ["xabxac", "abcabxabcd"])
both.longestCommonSubstring?.range.count   // 4, "abxa"
both.occurrences(of: "ab").count           // 4
```

A ``SuffixAutomaton`` is the smallest automaton whose paths from its start state spell the
text's substrings (Blumer et al., 1985), built one symbol at a time with at most 2*n* − 1
states. It answers membership, occurrence counts and first occurrences in O(*m*) transitions, and
finds the longest substring another text shares by walking that text over it. Its transitions
are a `DirectedGraph`, ``SuffixAutomaton/transitionsView``, and its suffix links convert to
Grafluent's `Arborescence` with `Arborescence(_:)`.

```swift
let automaton = SuffixAutomaton("abcbc")
automaton.occurrenceCount(of: "bc")                         // 2
automaton.longestCommonSubstring(with: "xbcbz")?.textRange  // 1 ..< 4, "bcb"
```

## Topics

### Suffix arrays

- ``SuffixArray``

### Suffix trees

- ``SuffixTree``

### Suffix automata

- ``SuffixAutomaton``
