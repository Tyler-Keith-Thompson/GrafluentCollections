# Tries and suffix structures

Search a set of keys by prefix, or a text by substring.

## Overview

A trie answers questions about many keys: which keys start with this prefix, which key is the
longest prefix of this input. A suffix structure answers questions about one text, or a few:
where does this pattern occur, what repeats. Both work over any sequence of `Hashable` symbols,
so a key or a text can be a `String`, an array of bytes or an array of tokens.

### Tries

A `Trie` stores a set of keys one symbol per edge, and a `TrieDictionary` maps each key to a
value. A `RadixTree` and a `RadixTreeDictionary` answer the same queries but merge each chain of
single-child vertices into one edge, which keeps them small when keys share long runs, such as
paths or URLs:

```swift
var routes: TrieDictionary<Character, String> = [:]
routes["/"] = "home"
routes["/users"] = "user list"
routes.longestPrefix(of: "/users/42")?.value   // "user list"
routes.elements(withPrefix: "/u").count         // 1

let paths = RadixTree(["/usr/bin", "/usr/lib", "/usr/local/bin"])
paths.contains("/usr/lib")                                   // true
paths.elements(withPrefix: "/usr/l").map { String($0) }      // ["/usr/lib", "/usr/local/bin"]
paths.longestPrefix(of: "/usr/bin/swift").map { String($0) } // "/usr/bin"
```

An `AhoCorasickAutomaton` turns a fixed set of patterns into a trie with failure links, and then
finds every occurrence of every pattern in a text in one pass, in time linear in the text plus
the matches:

```swift
let automaton = AhoCorasickAutomaton(patterns: ["he", "she", "his", "hers"])
automaton.matches(in: "ushers").map(\.patternIndex)   // [1, 0, 3]: "she", "he", "hers"
```

### Suffix structures

A `SuffixArray` holds a text's suffixes in sorted order with their longest-common-prefix array.
It is the most compact of the three, finds a pattern by binary search and answers repeat and
distinct-substring questions from the LCP array:

```swift
let banana = SuffixArray("banana")
banana.occurrences(of: "ana").map { banana.positions[$0] }   // [3, 1]
banana.distinctSubstringCount                                // 15
```

A `SuffixTree` is the compressed trie of every suffix, built in linear time. It finds a pattern
in time proportional to the pattern, and over several texts it finds their longest common
substring:

```swift
let both = SuffixTree(texts: ["xabxac", "abcabxabcd"])
both.longestCommonSubstring                // text 1, 3 ..< 7: "abxa"
```

A `SuffixAutomaton` is the smallest automaton that accepts every substring of a text. It counts
occurrences without listing them and matches another text against this one as it streams by:

```swift
let automaton = SuffixAutomaton("abcbc")
automaton.contains("cbc")              // true
automaton.occurrenceCount(of: "bc")    // 2
automaton.firstOccurrence(of: "cb")    // 2 ..< 4
```

### Choosing

| Question | Type |
|---|---|
| Keys by prefix, keys as a set | `Trie`, `RadixTree` |
| Values by key or by longest prefix | `TrieDictionary`, `RadixTreeDictionary` |
| Many fixed patterns in a stream of text | `AhoCorasickAutomaton` |
| Occurrences in one text, little memory | `SuffixArray` |
| Common substrings of several texts | `SuffixTree` |
| Occurrence counts, matching a second text | `SuffixAutomaton` |

Tries convert to Grafluent's `PrefixTree`, radix trees to `Arborescence`, the suffix tree to
`RootedTree` and the suffix automaton's suffix links to `Arborescence`. The Aho–Corasick
automaton's `statesView`, the suffix automaton's `transitionsView` and the suffix tree's
`suffixLinksView` are Grafluent graphs over the rest of their edges.
