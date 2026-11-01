# Explore

Interactive pages that run GrafluentCollections itself in the browser. Each page builds a small
structure, runs the real operations on it, and draws the shape that results. The interface is
written with [ElementaryUI](https://github.com/elementary-swift/elementary-ui) and compiled with
the library to WebAssembly.

This is a separate SwiftPM package that depends on the library at `..`; Bazel ignores it. The
shared layer (`Shared/`, the snippet plugin, the build script, the template and the stylesheet)
follows Grafluent's own explorer.

## Pages

`web/contents.txt` is the reading order. Each `page` row has a page; `soon` rows are listed in the
contents and the menu without a link.

| Page | Runs |
|---|---|
| `avl` | `AVLTree`: `insert(_:)`, `remove(_:)`, `height`; `BinaryTree(_:)` for the shape, with `inorder`, `parent(of:)`, `left(of:)`, `right(of:)`, `depth(of:)` |
| `redblack` | `RedBlackTree`: `insert(_:)`, `remove(_:)`, `height`, `color(of:)`; `BinaryTree(_:)` for the shape |
| `treap` | `Treap`: `init(using:)` with a seeded generator, `insert(_:)`, `remove(_:)`, `height`, `priority(of:)`; `BinaryTree(_:)` for the shape |
| `splay` | `SplayTree`: `insert(_:)`, `remove(_:)`, `access(_:)`, `split(at:)`, `join(_:)`, `height`; `BinaryTree(_:)` for the shape |
| `btree` | `BTreeDictionary`: subscript stores, `removeValue(forKey:)`, `height`; `RootedTree(_:)` for the nodes, with `preorder`, `postorder`, `children(of:)`, `depth(of:)` |
| `skiplist` | `SkipList`: `init(using:)` with a seeded generator, `insert(_:)`, `remove(_:)`, `contains(_:)`; `layersView` for the towers |
| `trie` | `Trie` and `RadixTree`: `insert(_:)`, `elements(withPrefix:)`, `longestPrefix(of:)`; `PrefixTree(_:)` and `Arborescence(_:)` for the shapes |
| `ahocorasick` | `AhoCorasickAutomaton`: `init(patterns:)`, `stateCount`, `matches(in:)`; `statesView` for the goto edges and failure links, with `patternIndices(endingAt:)` |
| `fenwick` | `FenwickTree`: `init(_:)`, `prefixSum(through:)`, `add(_:at:)`, `sum(in:)`; `Arborescence(_:)` for the update tree, with `parent(of:)` and `root` |
| `segmenttree` | `LazySegmentTree` over `Sum` and `Minimum` with an add-to-range `MonoidAction`: `init(_:)`, `combined(in:)`, `apply(_:in:)`; `BinaryTree(_:)` for the shape, with `preorder`, `left(of:)`, `right(of:)` |
| `intervaltree` | `IntervalTree`: `insert(_:value:)`, `remove(_:)`, `containing(_:)`, `overlapping(_:)`, subscript by in-order position; `BinaryTree(_:)` for the shape, with `left(of:)`, `right(of:)`, `parent(of:)`, `depth(of:)` |
| `kdtree` | `KDTree`: `init(_:)`, `nearestIndex(to:)`, `indices(in:)`; `Quadtree`: `init(bounds:bucketCapacity:)`, `insert(_:at:)`, `nearest(to:)`, `items(in:)`; `BinaryTree(_:)` for the k-d tree's splits and `RootedTree(_:)` for the quadtree's cells |
| `suffix` | `SuffixArray`: `init(_:)`, `positions`, `longestCommonPrefixes`, `occurrences(of:)`; `SuffixTree`: `init(_:)`, `children(of:)`, `parent(of:)`, `isLeaf(_:)`, `edgeLabel(of:)`, `pathLabel(of:)`, `occurrences(of:)`, `longestRepeatedSubstring` |

## Requirements

- [swiftly](https://www.swift.org/install/) with the Swift 6.3.3 toolchain:
  `swiftly install 6.3.3`.
- The matching Swift SDK for WebAssembly from swift.org:

  ```sh
  swiftly run swift sdk install \
      https://download.swift.org/swift-6.3.3-release/wasm-sdk/swift-6.3.3-RELEASE/swift-6.3.3-RELEASE_wasm.artifactbundle.tar.gz \
      --checksum cabfa08b73bb8ac783927ecd15fa386e99d0c139c5f232445067bcf58379cae7 +6.3.3
  ```

- `wasm-opt` from binaryen (`brew install binaryen`) to optimize the binary. The build still
  works without it, with a larger `.wasm`.

Without swiftly, `build.sh` uses the `swift` on `PATH`, which must be 6.3.3.

## Build

```sh
just explore
```

This builds release WebAssembly at `-Osize`, strips it, runs `wasm-opt -Oz`, draws each page's
first frame into its HTML, and writes `Explore/dist/`: one `<page>.html` per page and
`index.html`, `explore.css`, `Explore.wasm`, the JavaScriptKit glue and the vendored WASI shim
(`vendor/browser_wasi_shim/`). Every URL is relative, so `dist/` works from any directory.
Nothing is loaded from another host except the Google Fonts stylesheet.

If the swift.org toolchain crashes compiling a package manifest against a newer Xcode's macOS SDK,
point the build at an older Xcode: `EXPLORE_XCODE=/Applications/Xcode-26.2.0.app just explore`.
`EXPLORE_SWIFT` and `EXPLORE_SDK` choose another toolchain version and SDK.

## Serve

```sh
cd Explore/dist && python3 -m http.server 8000
```

Then open <http://localhost:8000/>. Browsers do not load WebAssembly from `file://` URLs.

## First frames

Each page's HTML already holds its first frame. `build.sh` builds this package a second time for
the build machine, and run there, `main.swift` renders every mount point of every page to HTML
with the same views and fills it into `dist/<page>.html`. In the browser, `mountView` empties each
mount point and ElementaryUI mounts the live view in its place.

So the first frame matches what the browser mounts, a page's initial state must not depend on
the platform: no iteration over a `Dictionary` or `Set` where the order shows, and random draws
from a seeded generator through `next()`.

## Layout

| Path | Holds |
|---|---|
| `Sources/Explore/main.swift` | Mounts the page named by `<body data-page>`; on the build machine, writes the first frames |
| `Sources/Explore/Shared/` | `mountView` and the first-frame writer, `GraphCanvas`, `Timeline` and `Marble`, `Playback` and `PlaybackButtons`, `CodePanel` and `Snippet`, DOM event glue |
| `Sources/Explore/Pages/<Page>/<Page>Code.swift` | The library code the page runs, with its `// snippet:` regions |
| `Sources/Explore/Pages/<Page>/<Page>Page.swift` | The page's model (`@Reactive`) and views |
| `Sources/SnippetExtractor/`, `Plugins/Snippets/` | The build plugin that turns `// snippet:` regions into `Snippet` constants |
| `web/template.html` | The shell every page is poured into: head, top bar and menu, pager, loader |
| `web/pages/<page>.html` | A page's masthead and prose, with `#app` and `#code` mount points |
| `web/contents.txt` | Reading order, groups and summaries: the index, the menu and previous/next links |
| `web/explore.css` | The one stylesheet, light and dark |
| `build.sh` | What `just explore` runs |

### The code panel is the code that runs

A page's library code lives in `<Page>Code.swift` between `// snippet: name` and
`// snippet end` lines. The Snippets plugin copies each region, dedented, into a constant
(`snippet: avl-run` becomes `Snippet.avlRun`), and the page passes those constants to
`CodePanel`, so a snippet that stops compiling stops the build. A line ending in `// →` gets a
result the page computed, in order. The values a page passes in are shown as `let` lines in a
`Snippet` the page builds.

## Adding a page

1. Add the module to the `Explore` target's dependencies in `Package.swift` if it is not there.
2. `Sources/Explore/Pages/<Page>/<Page>Code.swift`: the operations the page runs, inside
   `// snippet:` regions, as in `AVLCode.swift`. Only public API reaches this package.
3. `Sources/Explore/Pages/<Page>/<Page>Page.swift`: a `@Reactive` model holding the state after
   each step and a `Playback`; a view that reads `playback.k` and draws that state with
   `GraphCanvas`, `PlaybackButtons` and a `Timeline`; a `CodePanel` view; and an enum whose
   `mount()` mounts them on `app` and `code`. `AVLPage.swift` is the model to copy.
4. A `case` for the page in `main.swift`'s `mountPage`.
5. `web/pages/<page>.html`: the title and description comments, then a masthead, an example,
   `<div id="app">`, *What it's for*, *The idea*, *Where it breaks* and *In Swift* with
   `<pre id="code">`.
6. Its row in `web/contents.txt` becomes `page`, and the table above gets a row.
7. `just explore`, then check the page in Chrome at 1280 and 400 px.
