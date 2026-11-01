# Differential testing

Runs the library and independent Python implementations on the same random cases and compares
the answers. The references are pinned and run through `uv`, so nothing is installed globally.

| Command | Does |
|---|---|
| `just diff` | 300 random cases per section with a random seed, every section (seconds) |
| `just diff --cases 3000 --seed 7` | More cases, reproducibly |
| `just diff --section tries` | One section; repeat the flag for several |

`GrafluentCollectionsDifferential` (this package, built with SwiftPM in release) reads a section's
cases as JSON on standard input and answers them with the library; `scripts/differential.py`
generates the cases, asks the references the same questions, and compares. A failing case is
written to `Differential/Failures/` (not committed) for a regression test.

## What is compared

Only answers, never shapes: a tree's balance, a trie's vertices or a cache's internal order are
the library's own business.

| Section | Library | Reference (pin) |
|---|---|---|
| `sortedsets` | `AVLTree`, `RedBlackTree`, `Treap`, `SplayTree`, `BTree`, `SkipList`, `PersistentTreeSet`: each insert's and removal's result, membership, `lowerBound`, the element at a rank, the final elements | `sortedcontainers.SortedSet` (sortedcontainers 2.4.0) |
| `sorteddicts` | `AVLDictionary`, `BTreeDictionary`, `PersistentTreeDictionary`: the value each store replaces, each removal's value, lookups, the final pairs | `sortedcontainers.SortedDict` (2.4.0) |
| `tries` | `Trie<Character>` and `RadixTree<Character>`: insert, remove, membership, the keys with a prefix, the longest stored prefix of a query | `pygtrie.CharTrie` (pygtrie 2.5.0) |
| `ahocorasick` | `AhoCorasickAutomaton` matches of distinct patterns, as pattern and range | `ahocorasick.Automaton.iter` (pyahocorasick 2.1.0) |
| `suffix` | `SuffixArray` positions, distinct-substring count, longest repeat; occurrence counts in all three structures | Python's sort of the suffixes and a scan at every offset |
| `bdd` | `BinaryDecisionDiagram` model counts after and, or, xor, not, if-then-else and existential quantification | `dd.autoref.BDD.count` (dd 0.6.0) |
| `intervals` | `IntervalTree` overlapping, containing and contained-in searches; the earliest interval removed | `intervaltree.IntervalTree` `overlap`, `at`, `envelop` (intervaltree 3.1.0) |
| `spatial` | `KDTree` and `Quadtree` k-nearest distances and the points within a radius | `scipy.spatial.cKDTree` `query`, `query_ball_point` (scipy 1.18.1) |
| `lru` | `LRUCache` reads, writes, removals, membership and the final keys | `cachetools.LRUCache` (cachetools 6.2.0) |

`ZeroSuppressedDecisionDiagram`, the range-sum trees, `Octree` and `Rope` have no maintained
Python reference; `Fuzz/` checks them against models of its own.
