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
    // .product(name: "BinarySearchTrees", package: "GrafluentCollections"),
]),
```

## Usage

Every example here is a test in `Tests/GrafluentCollectionsTests`, so it cannot drift from the code.
No collection has landed yet; the package holds the project template's placeholder module,
`Greetings`, until the first one does:

```swift
import GrafluentCollections

let greeting = Greeting(name: "Ada").formal().punctuated(with: "!")
print(greeting.text)  // Good day, Ada!
```

## Modules

The planned modules, one per family of structures. None has shipped yet; the backlog tracks each
structure, and `.kanban/triage.md` says what belongs here.

| Group | Modules (planned) |
|---|---|
| Search trees | `BinarySearchTrees` (AVL, red–black, treap, splay), `BTrees`, `SkipLists` |
| Tries | `Tries` (tries over any sequence of symbols, radix and Patricia trees, Aho–Corasick automata) |
| Suffix structures | `SuffixStructures` (suffix arrays with LCP, suffix trees, suffix automata) |
| Decision diagrams | `DecisionDiagrams` (reduced ordered BDDs, ZDDs) |
| Range and spatial trees | `RangeTrees` (Fenwick and segment trees, interval trees), `SpatialTrees` (k-d trees, quadtrees, octrees) |
| Sequences and persistence | `Ropes`, `PersistentTrees` (path-copying balanced trees) |
| Caches | `Caches` (LRU structures) |
| Placeholder | `Greetings`: the template's example module, replaced by the first real one |

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
