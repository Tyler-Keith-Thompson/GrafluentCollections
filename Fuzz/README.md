# Fuzzing

Coverage-guided fuzz targets for [libFuzzer](https://llvm.org/docs/LibFuzzer.html), one per
module, in their own package so the library never links the fuzzer runtime.

| Target | Checks against |
|---|---|
| `FuzzBinarySearchTrees` | A `Set`: `AVLTree`, `RedBlackTree`, `Treap` and `SplayTree` after inserts, removals and set operations, every element, rank and membership; the AVL and red–black height bounds; `AVLDictionary` against a `Dictionary`; a snapshot copy |
| `FuzzBTrees` | A `Set` and a `Dictionary` over a wide key range, so nodes split and merge: elements, ranks, `lowerBound`, reversed iteration, a snapshot |
| `FuzzSkipLists` | A `Set`: elements, bounds, `min`/`max`, `remove(at:)`, a snapshot |
| `FuzzPersistentTrees` | One `Set` or `Dictionary` per version: every version made by inserts, removals, unions, intersections, differences and merges of earlier ones still equals its model at the end |
| `FuzzTries` | A `Set` and a `Dictionary` of keys over three symbols: `Trie`, `RadixTree` and `TrieDictionary` membership, prefix queries, `longestPrefix`, a snapshot; `AhoCorasickAutomaton` against a scan of every pattern at every offset |
| `FuzzSuffixStructures` | Sorted suffixes and scans: `SuffixArray` positions, LCPs, distinct substrings and longest repeat; occurrences in all three structures; `hasSuffix`; the longest common substring's length |
| `FuzzDecisionDiagrams` | Truth tables over up to six variables for every `BinaryDecisionDiagram` operation, and sets of bitmasks for every `ZeroSuppressedDecisionDiagram` operation; equal functions and families are equal handles |
| `FuzzRangeTrees` | An array: `FenwickTree`, `SegmentTree` (sum and minimum), `LazySegmentTree` range sums after point and range updates, `maxRight`'s guarantee; `IntervalTree` searches against a filtered list |
| `FuzzSpatialTrees` | Brute force on a coarse grid (coincident points, points on cell boundaries): `Quadtree`, `Octree` and `KDTree` box, radius and nearest searches after insertions and removals |
| `FuzzRopes` | An `Array`: inserts and replacements crossing chunks, removals, writes, extractions and concatenations, a snapshot |
| `FuzzCaches` | A list from most to least recent: `LRUCache` reads, peeks, writes, removals and evictions at capacities 0 to 5, a snapshot |

## Running

| Command | Does |
|---|---|
| `just fuzz` | Every target for 60 s, all at once, splitting the cores between them |
| `just fuzz FuzzTries -t 600 -j 8` | One target for 10 minutes on 8 workers |
| `just fuzz-regress` | Replays every local corpus once (seconds); run after changing a fuzzed module |
| `just fuzz-repro <target> <crash file>` | Replays a crash and writes a minimized copy beside it |

A run is bounded by wall time. New inputs that add coverage are merged into `Fuzz/Corpus/<target>/`
(local, not committed), so the next run resumes from there. Crashes are written to
`Fuzz/Crashes/<target>/`; each one becomes a test in the module's suite, and then the file is
deleted.

## Toolchain

Xcode's toolchain does not include the libFuzzer runtime; the swift.org toolchains do. The
scripts build with `swiftly run swift build +6.3.3` (override with
`GRAFLUENT_COLLECTIONS_FUZZ_SWIFT`), so install it once with `swiftly install 6.3.3`. Targets are
built in release mode with AddressSanitizer: preconditions stay on, and unsafe buffer code is
checked for out-of-bounds access.

SwiftPM links each executable against its own `main`, which conflicts with libFuzzer's, so each
target has an `@main` that calls `runFuzzer`, which starts libFuzzer through
`LLVMFuzzerRunDriver`.

## Adding a target

Add a directory `Sources/Fuzz<Module>/` with an `@main` enum calling `runFuzzer`, and a line in
`Package.swift`. Check against a model simple enough to be obviously right, check after every
operation, keep values small so collisions and ties are common, and include a snapshot copy to
catch copy-on-write bugs. The targets use only public API, since they live in another package.
