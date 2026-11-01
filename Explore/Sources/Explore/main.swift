import JavaScriptKit

// One WebAssembly module serves every page: the page names itself in `<body data-page="…">`, and
// this mounts that page's views. web/contents.txt lists the pages in reading order.
//
// Built for the build machine instead, it draws each page's first frame into the HTML: run as
// `Explore <dist> <page>…`, it fills the mount points of each `<dist>/<page>.html`.

/// Mounts the views of page `page`; false if there is no such page.
func mountPage(_ page: String) -> Bool {
    switch page {
    case "avl": AVLPage.mount()
    case "redblack": RedBlackPage.mount()
    case "treap": TreapPage.mount()
    case "splay": SplayPage.mount()
    case "btree": BTreePage.mount()
    case "skiplist": SkipListPage.mount()
    case "trie": TriePage.mount()
    case "ahocorasick": AhoCorasickPage.mount()
    case "fenwick": FenwickPage.mount()
    case "segmenttree": SegmentTreePage.mount()
    case "intervaltree": IntervalTreePage.mount()
    case "kdtree": KDTreePage.mount()
    case "suffix": SuffixPage.mount()
    case "decisiondiagrams": DecisionDiagramsPage.mount()
    case "rope": RopePage.mount()
    case "persistent": PersistentPage.mount()
    case "lru": CachePage.mount()
    default: return false
    }
    return true
}

#if arch(wasm32)
let page = JSObject.global.document.body.getAttribute("data-page").string ?? ""
if !mountPage(page) {
    _ = JSObject.global.console.error("No explorer page is called “\(page)”.")
}
#else
writeFirstFrames(arguments: Array(CommandLine.arguments.dropFirst()))
#endif
