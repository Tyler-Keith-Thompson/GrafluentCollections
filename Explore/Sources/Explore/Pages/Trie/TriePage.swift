import ElementaryUI
import Reactivity
import Trees
import Tries

/// A prefix tree to draw, by vertex: the prefix it spells, its parent, whether a word ends there,
/// and the label of the edge into it. Vertex 0 is the root.
struct DrawnPrefixTree {
    var prefixes: [String] = [""]
    var parents: [Int?] = [nil]
    var ends: [Bool] = [false]
    var labels: [String] = [""]

    var count: Int { prefixes.count }
}

/// The trie's vertices, one per prefix, with one letter on each edge.
func drawnTrie(_ trie: Trie<Character>) -> DrawnPrefixTree {
    let tree = PrefixTree(trie)
    var drawn = DrawnPrefixTree()
    for vertex in 1 ..< max(tree.arborescence.vertexCount, 1) {
        let parent = tree.arborescence.parent(of: vertex)!
        let symbol = String(tree.symbol(ofEdgeAt: vertex - 1))
        drawn.prefixes.append(drawn.prefixes[parent] + symbol)
        drawn.parents.append(parent)
        drawn.ends.append(tree.isSequenceEnd(vertex))
        drawn.labels.append(symbol)
    }
    drawn.ends[0] = tree.arborescence.vertexCount > 0 && tree.isSequenceEnd(0)
    return drawn
}

/// The radix tree's vertices, one per branch point or word end, with a run of letters on each
/// edge.
func drawnRadix(_ radix: RadixTree<Character>) -> DrawnPrefixTree {
    guard !radix.isEmpty else { return DrawnPrefixTree() }
    let tree = Arborescence(radix)
    let vertices = Array(tree.preorder)
    let index = Dictionary(uniqueKeysWithValues: vertices.enumerated().map { ($1, $0) })
    var drawn = DrawnPrefixTree(prefixes: [], parents: [], ends: [], labels: [])
    for vertex in vertices {
        let parent = tree.parent(of: vertex)
        drawn.prefixes.append(String(vertex))
        drawn.parents.append(parent.map { index[$0]! })
        drawn.ends.append(radix.contains(vertex))
        drawn.labels.append(String(vertex.dropFirst(parent?.count ?? 0)))
    }
    return drawn
}

/// Where each vertex goes: leaves left to right in label order, each parent over the middle of
/// its children, one row per depth.
func prefixTreeSpots(_ tree: DrawnPrefixTree) -> (x: [Double], y: [Double], height: Int) {
    var children = Array(repeating: [Int](), count: tree.count)
    for vertex in 0 ..< tree.count {
        if let parent = tree.parents[vertex] { children[parent].append(vertex) }
    }
    for vertex in children.indices { children[vertex].sort { tree.labels[$0] < tree.labels[$1] } }
    var x = Array(repeating: 0.0, count: tree.count), depth = Array(repeating: 0, count: tree.count)
    var leaves = 0
    func place(_ vertex: Int) {
        if children[vertex].isEmpty {
            x[vertex] = Double(leaves)
            leaves += 1
        } else {
            for child in children[vertex] {
                depth[child] = depth[vertex] + 1
                place(child)
            }
            x[vertex] = (x[children[vertex].first!] + x[children[vertex].last!]) / 2
        }
    }
    place(0)
    let gap = min(60.0, 620.0 / Double(max(leaves - 1, 1)))
    let left = 340 - gap * Double(leaves - 1) / 2
    let rows = depth.max() ?? 0
    let rowHeight = rows > 6 ? 46.0 : 56.0
    return (x.map { left + gap * $0 }, depth.map { 28 + rowHeight * Double($0) }, Int(28 + rowHeight * Double(rows) + 30))
}

/// The drawing of one tree, with the vertices the queries reach marked: words under `prefix` as
/// matches, the longest word `text` starts with as the answer.
func prefixTreeCanvas(_ tree: DrawnPrefixTree, label: String, prefix: String, longest: String?) -> GraphCanvas {
    let spots = prefixTreeSpots(tree)
    let nodes = (0 ..< tree.count).map { vertex in
        let spelled = tree.prefixes[vertex]
        let match = tree.ends[vertex] && spelled.hasPrefix(prefix)
        let classes = [
            tree.ends[vertex] ? "done" : "",
            match ? "match" : "",
            spelled == longest ? "current" : "",
        ].filter { !$0.isEmpty }.joined(separator: " ")
        return CanvasNode(x: spots.x[vertex], y: spots.y[vertex], name: "", radius: vertex == 0 ? 7 : 9, classes: classes)
    }
    let edges: [CanvasEdge] = (0 ..< tree.count).compactMap { vertex in
        guard let parent = tree.parents[vertex] else { return nil }
        let spelled = tree.prefixes[vertex]
        // On the way down to the prefix, or below it; an edge the prefix ends inside spells past it.
        let onPath = !prefix.isEmpty && (prefix.hasPrefix(spelled) || spelled.hasPrefix(prefix))
        return CanvasEdge(from: parent, to: vertex, label: tree.labels[vertex], classes: onPath ? "active" : "tree")
    }
    return GraphCanvas(label: label, width: 680, height: spots.height, nodes: nodes, edges: edges)
}

@Reactive
final class TrieModel {
    var text = "romane romanus romulus rubens ruber rubicon rubicundus"
    var prefixText = "rom"
    var queryText = "rubiconian"
    var words: [String] = []
    var tries: [DrawnPrefixTree] = [DrawnPrefixTree()]
    var radixes: [DrawnPrefixTree] = [DrawnPrefixTree()]
    var history: [Trie<Character>] = [Trie()]
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_200, scrubID: "scrub-trie")

    init() {
        set(text: text)
    }

    /// Inserts the words in `newText` into fresh trees and rewinds.
    func set(text newText: String) {
        text = String(newText.prefix(120))
        words = trieWords(text)
        let built = trieHistory(words)
        history = built.map(\.trie)
        tries = built.map { drawnTrie($0.trie) }
        radixes = built.map { drawnRadix($0.radix) }
        playback.reset(count: words.count)
    }
}

let trieModel = TrieModel()

func describeTrieStep(_ model: TrieModel, _ k: Int) -> String {
    let word = model.words[k - 1]
    let trieAdded = model.tries[k].count - model.tries[k - 1].count
    let radixAdded = model.radixes[k].count - model.radixes[k - 1].count
    guard trieAdded > 0 || model.tries[k].ends != model.tries[k - 1].ends else { return "Insert “\(word)”: it is already there, so nothing changes." }
    let shared = model.tries[k - 1].prefixes.filter { word.hasPrefix($0) }.max { $0.count < $1.count } ?? ""
    let start = shared.isEmpty ? "It shares nothing with the words before it" : "It shares “\(shared)” with the words before it"
    let trie = trieAdded == 0
        ? "so the trie only marks the vertex for “\(word)” as a word"
        : "so the trie adds \(trieAdded) \(trieAdded == 1 ? "vertex" : "vertices"), one per letter after that"
    let radix: String
    switch radixAdded {
    case 0: radix = "The radix tree already has a vertex where “\(word)” ends and marks it."
    case 1: radix = "The radix tree hangs one vertex off the end, its edge holding the rest of the word."
    default: radix = "The radix tree splits an edge where the words part, so the shared part ends at a new vertex, and hangs the rest of “\(word)” off it."
    }
    return "Insert “\(word)”. \(start), \(trie). \(radix)"
}

@View
struct TrieLab {
    var body: some View {
        let model = trieModel
        let playback = model.playback
        let k = playback.k
        let prefix = trieQuery(model.prefixText)
        let query = trieQuery(model.queryText)
        let answers = trieAnswers(model.history[k], prefix: prefix, text: query)
        let trie = model.tries[k], radix = model.radixes[k]

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your words and queries")) {
                label(.class("field"), .for("trie-text")) {
                    "Words to insert "
                    input(.id("trie-text"), .type(.text), .value(model.text), .custom(name: "maxlength", value: "120"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in trieModel.set(text: event.targetValue ?? "") }
                }
                label(.class("field"), .for("trie-prefix")) {
                    "Words starting with "
                    input(.id("trie-prefix"), .type(.text), .value(model.prefixText), .custom(name: "maxlength", value: "12"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in trieModel.prefixText = event.targetValue ?? "" }
                }
                label(.class("field"), .for("trie-query")) {
                    "Longest word that starts "
                    input(.id("trie-query"), .type(.text), .value(model.queryText), .custom(name: "maxlength", value: "12"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in trieModel.queryText = event.targetValue ?? "" }
                }
            }
            section(.class("lab"), .custom(name: "aria-label", value: "The trie and the radix tree")) {
                div(.class("panel stage")) {
                    span(.class("label")) { "Trie: \(trie.count) vertices" }
                    prefixTreeCanvas(trie, label: "The trie after \(k) words: \(trie.count) vertices, one letter on each edge", prefix: prefix, longest: answers.longest)
                    span(.class("label")) { "Radix tree: \(radix.count) vertices" }
                    prefixTreeCanvas(radix, label: "The radix tree after \(k) words: \(radix.count) vertices, a run of letters on each edge", prefix: prefix, longest: answers.longest)
                    div(.class("legend")) {
                        span { i(.class("dot done")) {}; "a word ends here" }
                        span { i(.class("dot match")) {}; "starts with “\(prefix)”" }
                        span { i(.class("dot current")) {}; "the longest word “\(query)” starts with" }
                    }
                }
                div(.class("side")) {
                    div(.class("panel"), .custom(name: "aria-live", value: "polite")) {
                        span(.class("label")) { k == model.words.count ? "Done after \(model.words.count) words" : "Word \(k) of \(model.words.count)" }
                        p(.class("narration")) {
                            if model.words.isEmpty {
                                "Type some words to insert."
                            } else if k > 0 {
                                describeTrieStep(model, k)
                            } else {
                                "A trie spells each word one letter per edge, so words that start the same share the start. A radix tree merges every chain of single children into one edge holding a run of letters."
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "Words starting with “\(prefix)”" }
                        p(.class("narration")) { answers.matches.isEmpty ? "None" : answers.matches.joined(separator: ", ") }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "Longest word “\(query)” starts with" }
                        p(.class("narration")) { answers.longest ?? "None" }
                    }
                }
            }
            section(.class("panel controls"), .custom(name: "aria-label", value: "Playback")) {
                div(.class("buttons")) {
                    PlaybackButtons(playback: playback)
                }
                Timeline(
                    playback: playback,
                    marbles: model.words.indices.map { i in
                        Marble(kind: "m-blue", radius: 10, letter: String(model.words[i].prefix(2)), title: describeTrieStep(model, i + 1))
                    },
                    legend: [(Marble(kind: "m-blue", radius: 6), "insert a word")])
            }
        }
    }
}

@View
struct TrieCodePanel {
    var body: some View {
        let model = trieModel
        let last = model.history.last ?? Trie()
        let prefix = trieQuery(model.prefixText), query = trieQuery(model.queryText)
        let answers = trieAnswers(last, prefix: prefix, text: query)
        let list = model.words.map { "\"\($0)\"" }.joined(separator: ", ")
        CodePanel(
            snippets: [.trieImports, Snippet(lines: ["let words = [\(list)]"]), .trieRun,
                       Snippet(lines: ["let prefix = \"\(prefix)\"", "let text = \"\(query)\""]), .trieQuery],
            results: ["\(model.tries.last?.count ?? 1)", "\(model.radixes.last?.count ?? 1)",
                      "\(answers.matches)", answers.longest.map { "\"\($0)\"" } ?? "nil"])
    }
}

enum TriePage {
    static func mount() {
        mountView(TrieLab(), in: "app")
        mountView(TrieCodePanel(), in: "code")
    }
}
