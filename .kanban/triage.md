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
- D9. A collection over `Hashable` symbols orders them when they are `Comparable`, found at run
  time (2026-10-31): a trie keeps each vertex's children sorted when `Symbol: Comparable`, so
  iteration is lexicographic, and in insertion order otherwise, with one type rather than a
  `Comparable` variant. A trie is a `Sequence` with an O(1) `count`, not a `Collection`, since
  its keys have no cheap position.
- D10. A compressed trie converts to `Arborescence` with each vertex's prefix as its vertex
  (2026-10-31): `Arborescence<[Symbol]>` for a `RadixTree`, so an edge's label is the child's
  prefix past its parent's and no edge map is needed.
- D11. An automaton over `Hashable` symbols numbers its alphabet and keeps a dense transition
  table only while it is small (2026-10-31): `AhoCorasickAutomaton` maps each pattern symbol to
  an index (a 256-entry table when `Symbol` is `UInt8`), a symbol no pattern has to one shared
  index that leads to the root, and builds a states × alphabet table when it fits in 2²² entries,
  following failure links otherwise. Matches are a lazy `MatchesView`, reported by where they
  end and longest first, with ranges as symbol offsets.
- D12. A structure over a whole text stores its indices in 32 bits while they fit (2026-11-01):
  `SuffixArray` keeps positions and prefix lengths as `Int32` when the text has at most
  `Int32.max` symbols and as `Int` beyond, exposed as `Int` collections either way, and counts
  substrings in `Int64`, which holds *n*(*n* + 1)/2 for any text that fits in memory on wasm32.
  A byte text is sorted as bytes; any other `Comparable` symbol type is replaced by its rank,
  so construction needs no `Hashable`. Names are spelled out (`longestCommonPrefixes`, not
  `lcp`).
- D13. A suffix tree works over codes and numbers its nodes in preorder (2026-11-01):
  `SuffixTree` maps each symbol to an `Int32` code (its rank when `Symbol` is `Comparable`,
  else its order of first occurrence; a byte is its own code), ends each text in a negative
  terminator of its own, and renumbers the finished tree in preorder, so a subtree is a range of
  nodes and the leaves of a `Comparable` text are its suffix array. Labels are `Occurrence`
  values (a text index and a range in that text) rather than symbols. Nodes are `Int32`, so the
  texts' total length traps at `Int32.max / 2`. The generalized tree is `init(texts:)`, labelled
  apart from `init(_:)` so a collection of strings is never read as one text.
- D14. A suffix automaton keeps its transitions in sorted rows, not a dense table (2026-11-01):
  `SuffixAutomaton` uses D13's codes, grows each state's transitions in a chain and compacts
  them into rows sorted by code; a 256-wide table for `UInt8` would take 1 KB per state, about
  2 GB for 10⁶ symbols. Its suffix-link tree is a conversion on the Grafluent type,
  `Arborescence(_:)`, as every other conversion is, rather than a property.
- D15. A decision diagram's functions are roots in a table value, built by its mutating methods
  (2026-11-01): `BinaryDecisionDiagram` is the unique and computed tables as copy-on-write arrays,
  and a `Function` is a root vertex in it, so `diagram.and(f, g)` rather than `f & g`: an
  operator on functions alone would have to reach a shared, mutable table, which value semantics
  rule out. The variable count is fixed when the table is made; variables are tested in index
  order. Operators are four-bit truth tables, so `apply` covers all sixteen. Satisfying
  assignments are counted in `Double`, exact below 2⁵³. The table keeps every vertex it makes
  until `collectGarbage(keeping:)` (D32).
- D16. A zero-suppressed decision diagram follows D15 over families of sets (2026-11-01):
  `ZeroSuppressedDecisionDiagram` shares the binary diagram's vertex arrays, unique table and
  computed table, and differs only in its reduction rule (no vertex whose high child is the empty
  family). A `Family` is a root vertex; the constants are `empty` (∅) and `unit` ({∅}). The
  operations are the set operations, `join` and `meet` (pairwise unions and intersections),
  `including`/`excluding` (filters, the element kept), and `minimalSets`/`maximalSets` by
  Knuth's nonsuperset and nonsubset recursions. Counts are `Double`, as in D15. Sets are read
  through a lazy `setsView(of:)`, each set ascending.
- D17. A segment tree's operation is a type, not a closure (2026-11-01): `SegmentTree<Operation:
  Monoid>` takes a `Monoid` whose static `identity` and `combine` specialize into the loops, where
  stored closures would be called indirectly at every cell. `Sum`, `Product`, `Minimum` and
  `Maximum` (the last two over fixed-width integers, whose bounds are the identities) are
  provided; anything else is a few-line enum. Grafluent's `Semirings` has no plain monoid, so
  `Monoid` lives here, with a Grafluent item filed to host it. `LazySegmentTree<Action:
  MonoidAction>` has one parameter naming both monoid and updates, and `apply` is told the number
  of values a combination covers, so range-add over sums needs no (sum, length) pairs. The tree
  is padded to a power of two (2*s* cells) so that `maxRight`/`minLeft` descend one perfect tree.
  Lazy reads compose pending updates on the way down and change nothing (as D7 for splay
  trees); range updates push them down.
- D18. An interval tree reuses the AVL tree's storage, with a summary per vertex (2026-11-01):
  `IntervalTree<Bound, Value>` is a `_TreeCore` from `BinarySearchTrees` balanced by
  `_AugmentedAVLBalancing`, the AVL scheme made generic over a `_TreeAugmentation` that every
  vertex update recomputes (`_AVLBalancing` is the same scheme with none, so the AVL trees are
  unchanged). The largest upper bound in each subtree lives inside the key, which ordering
  ignores, so the core's slot moves and key swaps carry it. Keys are (lower, upper, insertion
  serial), so equal intervals may repeat and keep insertion order; `remove(_:)` takes the
  earliest. Intervals are `Range` (half-open) and must be non-empty: the plain spelling traps,
  `checked:` throws `EmptyRange`. Searches are lazy `SearchView`s in key order, costing
  O(min(n, (k + 1) log n)). `ClosedRange` was left out until a caller needs it.
- D19. A k-d tree is static, over SIMD points, and answers with indices (2026-11-01):
  `KDTree<Point: SIMD>` with floating-point scalars takes its dimension from `scalarCount`, so
  `SIMD2<Double>` and `SIMD3<Float>` work with no protocol to adopt and distances use SIMD
  arithmetic. It is built once by median splits (Hoare selection), stored with no links in the
  implicit median layout, and has no insertion until a caller needs one. As a collection it
  holds the points in the order given, and searches (`nearestIndex(to:)`,
  `nearestIndices(to:count:)`, `indices(within:of:)`, `indices(in:)`) return those indices,
  nearest first or ascending, ties to the smaller index, so duplicates stay distinguishable.
  NaN coordinates trap (`checked:` throws `NotANumber`); a NaN query or negative radius finds
  nothing. `BoundingBox` is shared with the planned quadtree and octree. Module `SpatialTrees`.
- D20. Quadtrees and octrees share one core over SIMD points and hold points only (2026-11-01):
  `Quadtree<Element>` (`SIMD2<Double>`) and `Octree<Element>` (`SIMD3<Double>`) wrap one
  `_Orthtree<Point, Element>` with 2ᵈ children per cell, in flat arrays: per-cell first child
  (children consecutive), bucket head and subtree count; per-item point, element, bucket link
  and leaf. Elements are inserted at a point given beside them, not read from the element by a
  closure or protocol. Leaves split past `bucketCapacity` (default 8) down to depth 24, where
  coincident points share a leaf; a removal merges the highest cell on its path that fits one
  bucket again, and freed child blocks are reused. Points outside `bounds` trap (`checked:`
  throws `OutOfBounds`). Searches return `SpatialItem` (point and element) in no particular
  order, nearest first for `nearest(to:count:)`. The cells convert to `RootedTree` in
  breadth-first order. The boxes variant (items at the deepest cell containing them) is a
  backlog item of its own; the Morton-coded linear layout was not used, since it makes
  insertion O(n).
- D21. A rope is an AVL tree of ContiguousArray chunks with integer offsets (2026-11-01):
  `Rope<Element>` in module `Ropes` is a `RandomAccessCollection`, `MutableCollection` and
  `RangeReplaceableCollection` indexed by offsets `0 ..< count`. Vertices live in one flat array
  (chunk, children, height, subtree element count); each chunk is its own copy-on-write
  `ContiguousArray` of up to about 2 KB (at least 16 elements), so copies share unchanged chunks
  and `append(contentsOf:)`, `+` and `extracting(_:)` share whole chunks. An AVL of chunks was
  chosen over a B-tree of chunks: the tree has n/c vertices, so its depth is small either way, and
  the AVL reuses the rotation pattern already in the library. A small insertion into a full
  chunk splits it in half, or starts a new chunk at a chunk's end so appends fill chunks; large
  insertions become chunks of their own. `split(at:)` is spelled `extracting(_:)` (the standard
  library's name for a sub-range copy). `SubSequence` stays `Slice<Rope>`, since offsets in a
  slice must match its base. Removals do not merge small neighbouring chunks yet, and the
  summary-monoid hook (BigString-style metrics) is left for a later item. swift-collections'
  `_RopeModule` is not public API, so it could not be used.
- D22. Persistent trees are weight-balanced trees of immutable reference-counted vertices
  (2026-11-01): `PersistentTreeSet<Element>` and `PersistentTreeDictionary<Key, Value>` in module
  `PersistentTrees` share one `_PersistentNode<Key, Value>` final class with `let` key, value,
  children and subtree size. This departs from D3's flat arrays on purpose: versions are
  independent values that share vertices, so a shared append-only arena would be mutable state
  reached from many values (a lock on every read and write, or a data race), and it could never
  free a vertex without tracing every live version; reference counting frees exactly the
  vertices no version reaches. Balance is Adams' weight balance with (Δ, Γ) = (3, 2), proved by
  Hirai and Yamamoto, because sizes give ranks and O(1) `count` and make join simple. Set
  operations are Blelloch–Ferizovic–Sun split and join, and return a shared subtree whole when
  both operands hold the same vertex. Non-mutating `inserting(_:)`/`removing(_:)` (sets) and
  `updatingValue(_:forKey:)`/`removingValue(forKey:)` (dictionaries) sit beside the
  `SetAlgebra` and `Dictionary` mutating spellings, which path-copy too; in-place mutation of
  uniquely referenced vertices is left for later. Iteration holds unretained references under
  the root it keeps alive.
- D23. An LRU cache is one flat array of entries linked by Int32 indices, beside a Dictionary
  (2026-11-01): `LRUCache<Key: Hashable, Value>` in module `Caches` stores key, value, previous
  and next per entry in one array; a removal moves the last entry into the hole, so there is no
  free list and no stale value is kept alive, and an eviction when full reuses the tail's slot.
  A new key costs one hash for lookup and insertion together. Capacity 0 is allowed and holds
  nothing (every stored entry is evicted at once, as Python's `lru_cache(maxsize=0)`); a negative
  capacity traps, and `init(checkedCapacity:)` throws the new `NegativeCapacity`. The reading
  subscript is a `mutating get` that promotes; `peek(_:)` and `contains(_:)` do not.
  `insert(_:forKey:)` returns the evicted `Entry`, `updateValue(_:forKey:)` the replaced value.
  Hit and miss counters were left out, since they would cost every read. LFU and ARC variants
  wait for a caller.
- D24. The shared benchmark workloads apply to set-shaped structures, in one comparison target
  (2026-11-01): `SetComparisonsBenchmarks` runs seven workloads (insert ascending and random,
  lookup hit and miss, iterate, remove then insert, copy then insert) on 10⁴ integer keys over
  every sorted set (`AVLTree`, `RedBlackTree`, `Treap`, `SplayTree`, `BTree`, `SkipList`,
  `PersistentTreeSet`), a hand-written sorted array as `BASELINE`, `Set`, and swift-collections'
  `TreeSet` and `BitSet`. swift-collections is a dependency of the Benchmarks package only (N10).
  `OrderedSet` and `Heap` were left out: neither is a sorted set, so the workloads would not
  compare like with like. The dictionaries share their sets' tree cores and keep their own
  per-module store benchmarks. Structures that aren't sets (tries, suffix structures, decision
  diagrams, range and spatial trees, ropes, caches) keep workloads from their own domain, listed
  in `Benchmarks/README.md`. The existing targets keep their own generators so their committed
  baselines stay comparable; `BenchmarkWorkloads` (SplitMix64, `IntegerWorkload`) serves new
  targets. Every module has a release ratio test; a ratio that the library loses (the trie
  against `Set<String>`) is bounded as a slowdown and filed.
- D25. Fuzz and differential harnesses follow Grafluent's layout, with local corpora
  (2026-11-01): `Fuzz/` holds one libFuzzer target per module (not per structure: a module's
  structures share a target, chosen by the first byte), each checking every public answer
  against a naive model after every operation, built with swiftly's 6.3.3 toolchain and
  AddressSanitizer by `scripts/fuzz.py` (`just fuzz`, `just fuzz-regress`, `just fuzz-repro`).
  Corpora stay local, as in Grafluent, rather than committed: thousands of inputs per target
  would churn the history, and a crash is kept as a regression test instead. `Differential/` is
  an executable that answers JSON cases per section, and `scripts/differential.py` (`just
  diff`) compares it with pinned Python references run through `uv`: sortedcontainers, pygtrie,
  pyahocorasick, dd, intervaltree, scipy's cKDTree, cachetools; the suffix structures compare
  with Python's own sort and scans. ZDDs, range-sum trees, octrees and ropes have no maintained
  Python reference and are covered by fuzzing alone. The differential executable builds with
  SwiftPM only (no Bazel target), since it is a local tool. No CI job runs either harness.
- D26. The guides live in the umbrella catalog, and link modules by URL
  (2026-11-01): the landing page and the five guides (choosing a search tree, tries and suffix
  structures, decision diagrams, range and spatial trees, seeing a collection as a graph) sit in
  `GrafluentCollections.docc`, so one page leads to each family. Their code samples are tests in
  `Tests/GrafluentCollectionsTests/ArticleExamplesTests.swift`, which depends on Grafluent's
  `GraphFormats` and `GraphDrawing` for the graph article. The umbrella links to the module
  pages with absolute URLs on the published site: ``Module`` symbol links and
  `<doc://Module/...>` links don't resolve across archives in Swift 6.3's docc, even with the
  `--dependency` archives (it reports no external resolver), and a topic group takes only doc
  links, so the module list is the overview's table rather than a Topics group. The
  `docc convert` rule discards docc's output, so its warnings are checked by running docc by
  hand in the `swift:6.3` image; the umbrella catalog has none.
- D27. In-order iteration walks the tree with an inline spine stack, not slot order or threads
  (2026-11-01): the iterator keeps its first 64 spine entries in a fixed tuple, which holds the
  whole spine of any AVL or red–black tree, and spills deeper entries of a treap or splay tree
  into an array. What a step costs beyond that is the walk itself (a pop and two link loads
  per element). Iterating slots in rank order would only help a tree that was bulk-built and
  never changed, and would need a flag kept right through every insert, remove, split and
  join of five types and `IntervalTree`. Threaded successor links would cost every balancing
  scheme's rotations. Neither is worth that for iteration alone.
- D28. AVL repairs stop rebalancing where a subtree keeps its height (2026-11-01): after an
  insert or remove, each vertex up the path is rebalanced until its subtree's height comes out
  unchanged; above that point heights cannot change, so each vertex only adjusts its size by
  one and recomputes its augmentation summary. The summary is still recomputed on every
  vertex of the path, because a removal's successor swap changes a key on the path, which can
  change an interval tree's largest upper bound even where no height moves.
- D29. B-trees split and merge bottom-up, and do not redistribute on overflow (2026-11-01):
  insertion splits a node only when the new element overflows it, and never for a key already
  present; removal borrows or merges only when a node falls below *t* − 1, so a merge leaves a
  node one short of full rather than full. Moving an element into a sibling with room before
  splitting (as B*-trees do) cut allocations under random churn, but each move shifts up to
  2*t* − 1 elements in two nodes, and it raised the instructions of one-at-a-time insertion by
  far more than the allocations it saved, so it was measured and left out.
- D30. The explorer is a separate package that follows Grafluent's, one page at a time
  (2026-11-01): `Explore/` copies Grafluent's shared explorer layer (canvas, timeline, playback,
  code panel, snippet plugin, build script, template, stylesheet), since that layer lives in
  Grafluent's executable rather than in a library. Pages use only public API, as any user
  would. Search trees are drawn with x as in-order rank and y as depth from the `BinaryTree`
  conversion, not by a general tree layout, which has no left and right and would put a lone
  right child under its parent. Each structure becomes a page as its own item; the rest stay
  `soon` rows. Publishing beside the docs needs a CI job, which waits for the owner.
- D31. Exit tests live in their own `<Type>ExitTests.swift` files (2026-11-01): the template's
  wasm piece (`just wasi-test`) leaves out every test file holding an exit test, since WASI
  cannot start a child process, so a hand-worked file with one trap test in it would drop all
  its other tests from the 32-bit run. Each type's trap tests sit in a `"<Type>: traps"` suite
  beside its hand-worked suite. The wasm piece was taken from a render of the template with
  `--wasm`, because `template-update` carries changes to the pieces a project has, not new ones.
  The 32-bit run is local only; a CI job for it waits for the owner.
- D32. Decision diagrams drop unreachable vertices on request, not by reference counting
  (2026-11-01): `collectGarbage(keeping:)` takes the functions (or families) to keep, marks what
  they reach in one descending pass (children sit below parents), compacts the kept vertices in
  order, rebuilds the unique table and empties the computed table, and returns the kept roots
  renumbered, in the order given. Every other function value from before is invalid afterward;
  no generation stamp guards that, since a function was already an unchecked index into its
  table. The name follows BuDDy's and CUDD's garbage collection; reference counts per vertex
  were rejected for the cost they add to every apply.
- D33. Boxes get their own MX-CIF types, not a mode of the point trees (2026-11-01):
  `MXCIFQuadtree<Element>` and `MXCIFOctree<Element>` (Kedem's MX-CIF quadtree; Samet §3.4)
  wrap one `_MXCIFTree<Point, Element>`, since points split buckets and boxes never do. An item
  hangs on the deepest cell that wholly contains its box, cells are made on the way down to it
  (to depth 24) and freed when their subtree empties; a box whose lower coordinate is a centre's
  goes to the upper half, as a point does. Boxes include their faces, so touching boxes
  overlap; `BoundingBox` gains `contains(_ box:)` and `intersects(_:)`. Searches return
  `SpatialBoxItem` (box and element); `overlappingPairs()` returns materialized
  `OverlappingPair`s, each pair once. A box outside `bounds` traps (`checked:` throws
  `OutOfBounds`). There is no `update` for a moving box: remove and insert it. Loose quadtrees
  (enlarged cells) were not built.
- D34. A byte trie's busy vertices get a row of 256 child links (2026-11-01): when `Symbol` is
  `UInt8`, a vertex that reaches 8 children gets a row in one flat `Int32` array, indexed by the
  byte, so a lookup through it takes one load instead of a walk along the sibling chain; the
  chain stays, so D9's order and one type hold. A new child under a row finds its place in the
  sorted chain from the nearest smaller byte in the row. Rows are freed with their vertex and
  reused; other symbol types keep the chain alone. Contiguous sorted rows with binary search
  (D14's layout) were not built, since they make every insertion move a row; RadixTree remains
  the pick for long shared prefixes.
- D35. Red–black colours and treap priorities are public reads (2026-11-01):
  `RedBlackTree.color(of:) -> RedBlackTree.Color?` and `Treap.priority(of:) -> Int?`, nil for an
  element the tree doesn't hold. They let callers draw the trees and check the invariants
  without the `package` core; the balance fields stay internal and nothing can set them. Splay
  trees need no such read, since their shape alone is the state. AVL balance factors are not
  exposed: they follow from the shape.

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
