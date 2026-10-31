# GrafluentCollections: triage charter

## What it is
GrafluentCollections is a library of graph-shaped collections for Swift 6.3: balanced search
trees, tries, suffix structures, decision diagrams and the other data structures whose shape is a
tree or a graph, as copy-on-write value types with the API shape of the standard library and Swift
Collections, built on Grafluent's protocols and tree types, for Swift developers on Apple
platforms, Linux and WebAssembly. It optimizes for one thing: generic code that runs at the speed
of a hand-written loop over arrays.

## In scope
- Binary search trees as sorted sets and sorted dictionaries: AVL, red–black, treap, splay,
  scapegoat, weight-balanced; B-trees and B+-trees; skip lists.
- Tries as collections: tries over any sequence of `Hashable` symbols with prefix queries, radix
  and Patricia trees, ternary search trees, Aho–Corasick automata.
- Suffix structures: suffix arrays with LCP, suffix trees (Ukkonen), suffix automata, their
  substring, repeat and longest-common-substring queries.
- Decision diagrams: reduced ordered binary decision diagrams (`apply`, `restrict`, satisfying
  assignments and their count, variable reordering), zero-suppressed decision diagrams.
- Indexed and range trees: Fenwick trees, segment trees (lazy propagation), interval trees,
  k-d trees, quadtrees and octrees, range trees, van Emde Boas layouts.
- Sequence structures whose shape is a tree: ropes, piece tables, finger trees.
- Persistent (path-copying, functional) trees and maps, HAMTs.
- Caches and ordered structures backed by the above: LRU and LFU structures, union-find-backed
  sets (partition refinement), order-statistic trees.
- For every tree or graph-shaped collection: a conversion to the Grafluent type of its shape
  (`BinaryTree`, `Arborescence`, `RootedTree`, `DirectedGraph`) so Grafluent's algorithms and
  drawings run over it.
- Benchmarks, fuzz and differential harnesses, DocC for every module.

## Not in scope
- N1. Graph algorithms and graph representations: shortest paths, flows, matchings, adjacency
  lists, CSR, DAGs, Grafluent's `Tree`/`RootedTree`/`Arborescence` themselves. They belong in
  Grafluent; this library consumes them.
- N2. Datasets, dictionaries, word lists or corpora shipped in the package. Tests and benchmarks
  generate their inputs.
- N3. Rendering: SwiftUI views, drawing a tree to a canvas, HTML or SVG. Convert to a Grafluent
  type and use `GraphDrawing` for coordinates; pixels belong to the app.
- N4. Persistence, databases, serialization formats beyond `Codable`, memory-mapped or on-disk
  variants of a structure (an on-disk B-tree is a storage engine).
- N5. Concurrent or lock-free variants of a structure (concurrent skip lists, concurrent tries).
  Values are `Sendable` when their elements are; sharing is the caller's `Mutex`.
- N6. Hooks, SPI or flags added only so tests can observe internals. Tests may read `package`
  and underscored storage as it is.
- N7. Apple private API (`@_silgen_name`, undocumented runtime entry points) and anything App
  Review rejects.
- N8. Invented names. A type or member is named as swift-collections, the standard library or
  the literature names it (`SortedSet`, `insert`, `contains`, `lowerBound`, `apply`, `restrict`);
  when neither has a name, the paper that introduced the structure does.
- N9. Synonym typealiases, a second spelling for an existing operation, or nil-returning variants
  beside a `checked:` spelling. One name per concept.
- N10. Reimplementing what swift-collections already ships (`Deque`, `OrderedSet`, `Heap`,
  `BitSet`, `TreeDictionary`/`TreeSet` as HAMTs). Depend on it instead; a structure is in scope
  only when swift-collections lacks it or its shape as a graph is the point.
- N11. Matching another library's tie-breaking or iteration order where the structure leaves it
  free (a treap's shape, a hash-ordered trie's child order). A differential comparison checks
  answers, not shapes.

## Rules a request must fit
- Public types are `@frozen` copy-on-write structs with `@usableFromInline` storage;
  hot generic code is `@inlinable` over `some` generics, never `any`. No classes in the public
  API except where reference semantics are the feature (a cache's eviction is still a value).
- Vertices live in flat arrays indexed by `Int32` or `Int`, never as a class per vertex; links
  are indices, −1 for none. Recursion is bounded by the height of a balanced tree, or replaced
  by an explicit stack.
- Plain spellings trap like an `Array` subscript (an index out of range, a key absent where the
  docs require it); `checked:` spellings throw a typed, payload-free error; invariant-breaking
  mutations throw on the plain spelling and change nothing. Where the standard library already
  returns an optional (`Set.remove`, `Dictionary` subscripts, `min`), follow the standard library.
- Results are dedicated types, not tuples. Lazy views end in `View`; materializing conversions
  are initializers on the target type (`BinaryTree(tree)`).
- API shape follows swift-collections: `Sequence`/`Collection` conformances with the standard
  members, `ExpressibleByArrayLiteral`/`ExpressibleByDictionaryLiteral`, `Equatable` over
  elements (not shape), `Hashable`, `Codable`, `Sendable` where elements are, `description`.
- Swift 6.3 minimum. Must build and pass on macOS, Linux arm64 and in 32-bit `Int` (wasm32):
  width-dependent bounds are comparisons on `Int64` or `Int.max`, never `1 << 32` on an `Int`.
  `Package.swift` stays free of Foundation.
- Grafluent is the only first-party dependency; swift-collections may be added when a module
  needs a container from it (N10). Nothing else without the owner.
- A feature ships with hand-worked tests, edge cases (empty, one element, duplicates, every
  rotation or split case), exit tests for traps, a property test against a naive reference (a
  sorted array, a `Set`, a brute-force scan), a benchmark with a `BASELINE` entry it must keep
  pace with, DocC, and a README example that is a test. Speed is judged by simulated counts; a
  noise-level gap (a few µs, ~10%) is not a bug.
- Docs describe the current API: no history, no comparisons with other libraries, no benchmark
  numbers. Complexity bounds and algorithm authors are fine.
- Third-party bugs are recorded locally, never filed upstream.

## Belongs elsewhere
- A graph algorithm, graph representation or tree type that is a graph (N1) → Grafluent
  (github.com/Tyler-Keith-Thompson/Grafluent).
- A container swift-collections ships (N10) → use it; a defect in it is recorded locally, not
  filed.
- An app's rendering of a tree (N3) → that app, through Grafluent's `GraphDrawing` coordinates.
- A storage engine or on-disk structure (N4) → a separate project; none exists.
- A change to the build template (justfile, workflows, `scripts/modules.py`'s generator) →
  ProjectTemplate (~/workspace/ProjectTemplate), then `just template-update` here.

## Kinds, labels and Ready
- **feature**: a new structure, a new operation on one, or a conversion to a Grafluent type.
  Ready when it names the structure with its literature or library precedent (the paper, or the
  swift-collections / C++ / Rust / Java type whose API it follows), the module it lands in, the
  entry points' shapes in the house conventions, and what naive reference the property test and
  benchmark compare against.
- **friction**: an existing API that works but is awkward (a spelling that fights the standard
  library's, an error path that cannot fire). Ready when it states the current spelling, the
  proposed one, and which rule above it fits.
- **bug**: a wrong answer, a broken invariant (an unbalanced AVL tree, a trie that forgets a
  key), a trap where docs promise otherwise, a hang, a quadratic blowup, memory unsafety or a
  race. Ready when it has a concrete failing input and the expected answer, ideally from a
  reference implementation.
- **docs**: a doc comment, README or DocC page that misleads or omits. Ready when it points at
  the file and says what a reader needed to know.
- Labels are the lowercase module name (`binarysearchtrees`, `tries`, `suffixstructures`,
  `decisiondiagrams`) plus one of `api`, `perf`, `grafluent` (a conversion or view onto a
  Grafluent type), `ci`, `tooling`.

## Decisions
- D1. Build on Grafluent's protocols where a structure is genuinely a graph: every tree-shaped
  collection converts to the Grafluent type of its shape (`BinaryTree`, `Arborescence`,
  `RootedTree`), and a structure whose edges carry the meaning (a decision diagram, a suffix
  automaton) exposes a view conforming to `DirectedGraph`. The conversion is an initializer on
  the Grafluent type and costs O(n) once. Don't force it where it costs speed: a collection's own
  operations (`insert`, `contains`, range queries) never go through a Grafluent protocol, and no
  collection conforms to `Graph` or `DirectedGraph` itself (owner's brief, 2026-10-31).
- D2. "Add a sorted set" → the balanced trees (AVL, red–black, treap, splay) ship as types of
  their own in `BinarySearchTrees`, not as a strategy parameter. A `SortedSet` or
  `SortedDictionary` name, if it ever appears, is one type with one implementation, chosen by
  measurement.
- D3. Elements are stored in flat arrays with index links (2026-10-31): one allocation per
  growth step rather than one per vertex, so copy-on-write copies a few arrays and iteration
  reads contiguous memory. A per-vertex class is a bug, not a style choice. Amended for multiway
  nodes (owner, 2026-10-31): a structure whose vertices hold many elements each (a B-tree)
  stores each vertex as one `ManagedBuffer` of its elements, shared between copies, so a
  mutation copies only the path it changes. A node per element is still a bug.
- D4. Grafluent becomes a package dependency (`PACKAGES` in `scripts/modules.py`, pinned
  `from: "0.0.1"`) with the first module that converts to one of its types, and is followed as it
  releases; this library never vendors Grafluent code. A Grafluent gap found here (a missing tree initializer,
  a conversion that costs more than O(n)) is filed in Grafluent's backlog, not patched around
  with a copy.
- D5. Modules are named for the family they hold (`BinarySearchTrees`, `Tries`,
  `SuffixStructures`, `DecisionDiagrams`, `RangeTrees`, `Ropes`, `Caches`), one per family, with
  a `Module` suffix only when the module would otherwise equal its main type's name. No catch-all
  modules.
- D6. A collection re-exports nothing: a caller who wants the `BinaryTree` view imports
  Grafluent's `Trees` beside this library. Revisit if the owner answers the open question below
  the other way.
- D7. A self-adjusting tree's reads don't adjust it (2026-10-31): a splay tree's `contains`,
  bounds, subscripts and iteration leave the shape alone, so it keeps the non-mutating API of
  the other sorted sets and their `SetAlgebra` and `RandomAccessCollection` conformances. A
  `mutating func access(_:)` and the mutations (insert, remove, split, join) splay, and the
  amortized and working-set bounds are stated for those. Reads never splay behind a value's back
  through shared storage.
- D8. A multiway tree converts to `RootedTree` with a node's elements, in order, as its vertex
  (owner, 2026-10-31): `RootedTree<[Element]>` for a `BTree` and `RootedTree<[Key]>` for a
  `BTreeDictionary`, so a vertex is what a node holds, not a key chosen to stand for it.

## Open questions
- Should the modules `@_exported import` the Grafluent modules whose types they return
  (`Trees` for `BinaryTree`), so `import BinarySearchTrees` alone suffices, or keep an explicit
  `import Trees` in callers? D6 keeps it explicit until the owner decides.
- Where does the line fall between this library and swift-collections' `TreeSet`/`TreeDictionary`
  (HAMTs) and `SortedSet` (if Apple ships one)? N10 says depend on what exists; does a persistent
  path-copying balanced tree still belong here once swift-collections has a persistent map?
- Does the owner want `SortedSet`/`SortedDictionary` as public names over one chosen tree (D2),
  or only the concrete tree names (`AVLTree`, `RedBlackTree`)?
- Which labels does the board want for size and demand (Grafluent's handoff uses H/M/L demand
  and S/M/L size)?
