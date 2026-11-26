# Benchmarks

A separate SwiftPM package built on [ordo-one/benchmark](https://github.com/ordo-one/benchmark),
so the library and its tests never depend on the benchmark framework. Bazel ignores its SwiftPM
build (`.bazelignore`) and loads only `BUILD.bazel`, which caches the simulated counts.

Requires `brew install jemalloc`.

| Command | Does |
|---|---|
| `just bench` | Run every benchmark (`--target X` for one) |
| `just bench-baseline` | Save the current results as the `main` baseline |
| `just bench-compare` | Compare the current results against `main` |
| `just bench-simulated [--target X]` | Record simulated counts as the `simulated` baseline |
| `just bench-simulated-compare [--target X]` | Record simulated counts as `simulated-current` and compare them against `simulated` |

`Package.swift` and `BUILD.bazel` are generated from `BENCHMARKS` in `scripts/modules.py`: a row
per target, with what it imports (library modules, `BenchmarkWorkloads`, or a package's product).
`BENCHMARK_SUPPORT` describes `BenchmarkWorkloads` and `BENCHMARK_PACKAGES` the packages only the
benchmarks use. Add a target there, then `just modules`.

Each module's benchmarks live in `Benchmarks/<Module>Benchmarks/` and start with a `BASELINE`
entry: the hand-written form the library must keep pace with. The `simulated` baseline is
committed for every target (and `main` where it was recorded on a quiet machine); other names are
local before/after comparisons. `BenchmarkWorkloads` holds the seeded generators and key sets the
targets share, and swift-collections is a dependency of this package only, for comparison.

| Target | Workloads | Compared against |
|---|---|---|
| `SetComparisonsBenchmarks` | For 10⁴ integer keys: insert ascending, insert random, lookup hit, lookup miss, iterate, remove then insert, copy then insert | A hand-written sorted array (`BASELINE`), `Set`, swift-collections' `TreeSet` and `BitSet`, over `AVLTree`, `RedBlackTree`, `Treap`, `SplayTree`, `BTree`, `SkipList` and `PersistentTreeSet` |
| `BinarySearchTreesBenchmarks` | Build, lookup, one-at-a-time insert, remove then insert, iterate, union, split and join, Zipf-skewed access, dictionary stores | Binary search in a sorted array, `Array(Set(keys)).sorted()`, `Set.union`, `Dictionary` lookups |
| `BTreesBenchmarks` | Build, lookup, insert, remove then insert, iterate, subscript by rank, dictionary stores | Binary search and iteration over a sorted array, `AVLTree` |
| `SkipListsBenchmarks` | Build, lookup, insert, remove then insert, iterate, subscript by rank | Binary search and iteration over a sorted array, `AVLTree` |
| `TriesBenchmarks` | Build, lookup over `Character` and UTF-8, prefix queries, remove then insert, dictionary stores, path-like keys, Aho–Corasick matching | `Set<String>`, a prefix range by binary search in a sorted array, a dictionary lookup at every offset |
| `SuffixStructuresBenchmarks` | Suffix array, suffix tree and suffix automaton construction and substring queries | Comparison sort of the suffixes, a naive suffix trie, a `Set` of every substring |
| `DecisionDiagramsBenchmarks` | BDDs for *n* queens and model counting, ZDDs of independent sets | A truth table, brute-force enumeration |
| `RangeTreesBenchmarks` | Fenwick, segment, lazy segment and interval tree build, queries and updates | Linear scans and prefix-sum arrays |
| `SpatialTreesBenchmarks` | k-d tree and quadtree build, nearest, k-nearest, radius and box searches, insertion | Brute-force scans |
| `RopesBenchmarks` | Random insertions, build, iteration, `Character` edits | `Array.insert`, `String` insertion, `Array` iteration |
| `PersistentTreesBenchmarks` | Insertions keeping every version, union of unrelated sets and of nearby versions, lookup | Copying an `AVLTree` per version, `Set.union` then sort |
| `CachesBenchmarks` | Mixed reads and writes at an 80% hit rate, evicting writes | `Dictionary` |

Every target except `SetComparisonsBenchmarks` has release ratio tests in
`Tests/<Module>Tests/Performance/` that bound its speed against the `BASELINE`, the factor in
each test's name.

The `bench-simulated` recipes run the same benchmarks, unchanged, in a Linux virtual machine under
Callgrind (the `benchmark-harness` tool from `~/workspace/BenchmarkHarness`, or `$BENCHMARK_HARNESS`)
and record instructions, cache misses, mispredicted branches and an estimated cycle count instead of
time. Those counts come from a fixed simulated machine, so they don't move when the host is busy.
Wall-clock results (`just bench`) only mean something on a quiet machine.

Simulated counts are deterministic, so each target's are a cached Bazel output
(`//Benchmarks:<Target>`, `tools/benchmarks.bzl`): `just bench-simulated` measures again only the
targets whose sources, imported modules, manifests or harness changed, and takes the rest from the
disk cache or BuildBuddy. Each measurement stages the package under
`~/Library/Caches/<project>-benchmarks/<checkout>/<Target>` (`~/.cache` on Linux; one per checkout,
so worktrees don't share one) and runs outside Bazel's sandbox, which can't start a VM.
`Benchmarks/.harness/` (untracked) holds this checkout's copy of the harness binary and its resource
bundles, and a stamp of the host and Swift version, all inputs. `--filter`, `--skip` and the
harness's other options measure directly, uncached, and the result is written in the same format.

The `simulated` baseline is pretty-printed, keys and benchmarks sorted, so each benchmark's entry
has lines of its own. Re-recording rewrites only the entries whose instruction or malloc counts
moved past `baseline compare`'s threshold (5% at p25, p50 and p75), or that were measured over a
different number of iterations; the others keep their recorded entry, whose cache-miss and branch
counts would otherwise vary a little from run to run. Branches that change different benchmarks of
one target therefore merge cleanly. `bench-simulated-compare` writes `simulated-current` as
measured.
