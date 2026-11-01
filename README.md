# GrafluentCollections

GrafluentCollections is a library of graph-shaped collections for Swift: balanced search trees,
tries, suffix structures, decision diagrams and the other data structures whose shape is a tree or a
graph. Every collection is a copy-on-write value with the API shape of the standard library's
collections and Swift Collections, and where a structure is a tree or a graph it converts to the
[Grafluent](https://github.com/Tyler-Keith-Thompson/Grafluent) type of that shape, so Grafluent's
algorithms and drawings run over it.

[Documentation](https://tyler-keith-thompson.github.io/GrafluentCollections/documentation/)

## Installation

GrafluentCollections requires Swift 6.3 and supports macOS 15, iOS 18, tvOS 18, watchOS 11 and
visionOS 2 or later.

```swift
dependencies: [
    .package(url: "https://github.com/Tyler-Keith-Thompson/GrafluentCollections", from: "0.0.1"),
],
```

Then add a product to your target, either the umbrella or individual modules:

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "GrafluentCollections", package: "GrafluentCollections"),
    // or, for example:
    // .product(name: "RangeTrees", package: "GrafluentCollections"),
]),
```

## Usage

Every example here is a test in `Tests/GrafluentCollectionsTests`, so it cannot drift from the code.

A `FenwickTree` answers prefix and range sums over a sequence of values, and takes point updates,
in O(log *n*) each:

```swift
import GrafluentCollections

var scores: FenwickTree = [3, 1, 4, 1, 5, 9, 2, 6]
print(scores.prefixSum(through: 3))  // 9
print(scores.sum(in: 2 ..< 6))       // 19
scores.add(10, at: 1)
print(scores.prefixSum(through: 3))  // 19
print(scores.lowerBound(ofPrefixSum: 15))  // 2
```

Its shape converts to Grafluent's `Arborescence`, so Grafluent's tree algorithms and drawings run
over it:

```swift
import GrafluentCollections
import Trees

let updates = Arborescence(FenwickTree([1, 2, 3, 4, 5, 6, 7, 8]))
print(updates.root)              // 8
print(updates.parent(of: 2)!)    // 3
```

An `AVLTree` is a sorted set and an `AVLDictionary` a sorted dictionary, each a balanced binary
search tree with O(log *n*) lookup, insertion and removal, indexed by rank. `RedBlackTree` is the
same sorted set balanced by colours instead of heights, `Treap` the same again balanced by
random priorities, and `SplayTree` one that moves each element it accesses to the root, so
recently used elements are fast to reach. Treaps and splay trees also split at an element and
join two sets that don't interleave:

```swift
import GrafluentCollections

var primes: AVLTree = [7, 2, 11, 3, 5]
primes.insert(13)
print(primes.contains(4))     // false
print(Array(primes))          // [2, 3, 5, 7, 11, 13]
print(primes.lowerBound(6))   // 3, the index of 7

var stock: AVLDictionary = ["pear": 4, "apple": 7]
stock["fig"] = 2
stock["apple", default: 0] += 1
print(stock.map(\.key))       // ["apple", "fig", "pear"]
```

A `BTree` is the same sorted set with many elements to a node, so a lookup follows a few node
references rather than one per level, and `BTreeDictionary` is its dictionary:

```swift
import GrafluentCollections

var readings: BTree = [40, 10, 30, 20]
readings.insert(25)
print(Array(readings))        // [10, 20, 25, 30, 40]
print(readings[2])            // 25
print(readings.popFirst()!)   // 10
```

A `SkipList` is the same sorted set kept in levels of sorted linked lists, each a random sample of
the one below, with no rebalancing; its levels are a Grafluent `DirectedGraph`:

```swift
import GrafluentCollections

var queue: SkipList = [30, 10, 20]
queue.insert(15)
print(Array(queue))           // [10, 15, 20, 30]
print(queue.lowerBound(20))   // 2
print(queue.layersView.vertices.filter { $0.level == 0 }.map(\.element))  // [10, 15, 20, 30]
```

A `Trie` is a set of sequences, such as words, that answers prefix queries, and a
`TrieDictionary` a dictionary keyed by them. `RadixTree` and `RadixTreeDictionary` answer the same
queries with one vertex per branching point, which suits long shared prefixes such as paths, and
an `AhoCorasickAutomaton` finds every occurrence of a set of patterns in one pass over a text:

```swift
import GrafluentCollections

let words = Trie(["car", "cart", "cat", "dog"])
print(words.elements(withPrefix: "car").map { String($0) })  // ["car", "cart"]
print(String(words.longestPrefix(of: "carton")!))            // cart
print(words.hasPrefix("do"))                                  // true

let paths = RadixTree(["/usr/bin", "/usr/lib", "/var/log"])
print(paths.elements(withPrefix: "/usr/").count)              // 2

let automaton = AhoCorasickAutomaton(patterns: ["he", "she", "his", "hers"])
print(automaton.matches(in: "ushers").map(\.patternIndex))     // [1, 0, 3]
```

A `SuffixArray` sorts a text's suffixes, so every occurrence of a pattern is one run of them:

```swift
import GrafluentCollections

let banana = SuffixArray("banana")
print(banana.occurrences(of: "ana").map { banana.positions[$0] })  // [3, 1]
print(banana.longestRepeatedSubstring!)                              // 1..<4, "ana"
print(banana.distinctSubstringCount)                                 // 15
```

A `BinaryDecisionDiagram` keeps Boolean functions in canonical form, so equal functions are
equal values:

```swift
import GrafluentCollections

var diagram = BinaryDecisionDiagram(variableCount: 3)
let x0 = diagram.variable(0), x1 = diagram.variable(1), x2 = diagram.variable(2)
let f = diagram.or(diagram.and(x0, x1), x2)
print(diagram.satisfyingAssignmentCount(of: f))                  // 5.0
print(diagram.restrict(f, variable: 2, to: false) == diagram.and(x0, x1))  // true
```

## Modules

One module per family of structures. `BinarySearchTrees` (`AVLTree`, `AVLDictionary`, `RedBlackTree`, `Treap`, `SplayTree`),
`BTrees` (`BTree`, `BTreeDictionary`), `SkipLists` (`SkipList`),
`Tries` (`Trie`, `TrieDictionary`, `RadixTree`, `RadixTreeDictionary`, `AhoCorasickAutomaton`), `SuffixStructures` (`SuffixArray`, `SuffixTree`, `SuffixAutomaton`), `DecisionDiagrams` (`BinaryDecisionDiagram`) and `RangeTrees` (`FenwickTree`) have shipped; the others are planned. The backlog tracks each planned structure, and `.kanban/triage.md` says what belongs
here.

| Group | Modules |
|---|---|
| Search trees | `BinarySearchTrees` (AVL, red–black and splay trees, treaps), `BTrees` (B-trees), `SkipLists` (skip lists) |
| Tries | `Tries` (tries over any sequence of symbols, radix and Patricia trees, Aho–Corasick automata) |
| Suffix structures | `SuffixStructures` (suffix arrays with LCP, suffix trees, suffix automata) |
| Decision diagrams | `DecisionDiagrams` (reduced ordered BDDs; ZDDs planned) |
| Range and spatial trees | `RangeTrees` (Fenwick trees; segment and interval trees planned), `SpatialTrees` (k-d trees, quadtrees, octrees) |
| Sequences and persistence | `Ropes`, `PersistentTrees` (path-copying balanced trees) |
| Caches | `Caches` (LRU structures) |
| Shared | `CollectionErrors`: the errors the `checked:` spellings throw, re-exported by every module that throws them |

## Development

Bazel is the development build; SwiftPM is the published package. Both are generated from
`scripts/modules.py`.

| Command | Does |
|---|---|
| `just test` | Build and run every test |
| `just verify` | The tests under Bazel and under SwiftPM |
| `just modules` | Regenerate `Package.swift` and every `BUILD.bazel` |
| `just docs` | The DocC site into `.build/docs` |
| `just bench` | The benchmarks (`Benchmarks/README.md`) |
| `just generate` | An Xcode project from the Bazel graph |

`AGENTS.md` describes the layout, the workflow and the house rules in full.

## License

Apache 2.0. See `LICENSE`.
