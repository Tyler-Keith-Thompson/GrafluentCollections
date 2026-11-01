import ElementaryUI
import Reactivity
import SuffixStructures

/// The rows of the suffix array a binary search for `pattern` probes: one search for the first
/// suffix that starts with the pattern or sorts after it, one for the first that sorts after
/// every suffix starting with it.
func suffixProbes(_ pattern: String, _ text: [Character], _ positions: [Int]) -> [Int] {
    let wanted = Array(pattern)
    func prefix(_ row: Int) -> [Character] { Array(text[positions[row]...].prefix(wanted.count)) }
    var probes: [Int] = []
    for strict in [false, true] {
        var low = 0, high = positions.count
        while low < high {
            let middle = (low + high) / 2
            probes.append(middle)
            let probe = prefix(middle)
            let before = probe.lexicographicallyPrecedes(wanted) || (strict && probe == wanted)
            if before { low = middle + 1 } else { high = middle }
        }
    }
    return probes
}

/// The nodes a search for `pattern` passes on its way down the suffix tree, the last being the
/// one at or below which the pattern ends; empty past the root when the pattern isn't there.
func suffixPath(_ pattern: String, _ tree: SuffixTree<Character>, _ text: [Character]) -> (path: [Int], found: Bool) {
    let wanted = Array(pattern)
    var node = tree.root, matched = 0
    var path = [node]
    while matched < wanted.count {
        let next = tree.children(of: node).first { child in
            let label = tree.edgeLabel(of: child).range
            return !label.isEmpty && text[label.lowerBound] == wanted[matched]
        }
        guard let next else { return (path, false) }
        let label = tree.edgeLabel(of: next).range
        for offset in 0 ..< label.count where matched < wanted.count {
            guard text[label.lowerBound + offset] == wanted[matched] else { return (path + [next], false) }
            matched += 1
        }
        node = next
        path.append(node)
    }
    return (path, true)
}

/// The nodes below `node`, itself included.
func suffixSubtree(_ node: Int, _ tree: SuffixTree<Character>) -> [Int] {
    var nodes: [Int] = [], stack = [node]
    while let next = stack.popLast() {
        nodes.append(next)
        stack += tree.children(of: next)
    }
    return nodes
}

/// What one search did in each structure.
struct SuffixStep {
    var pattern: String
    var range: Range<Int>
    var probes: [Int]
    var path: [Int]
    var found: Bool
    var starts: [Int]
}

@Reactive
final class SuffixModel {
    var textInput = "banana"
    var patternsInput = "ana na b nab a"
    var text = ""
    var patterns: [String] = []
    var array = SuffixArray<Character>("")
    var tree = SuffixTree<Character>("")
    var steps: [SuffixStep] = []
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_400, scrubID: "scrub-suffix")

    init() {
        run()
    }

    func set(text newText: String) {
        textInput = String(newText.prefix(40))
        run()
    }

    func set(patterns newText: String) {
        patternsInput = String(newText.prefix(80))
        run()
    }

    func run() {
        text = suffixText(textInput)
        patterns = suffixPatterns(patternsInput)
        let run = suffixRun(text, patterns)
        array = run.array
        tree = run.tree
        let characters = Array(text)
        let positions = Array(array.positions)
        steps = patterns.indices.map { i in
            let path = suffixPath(patterns[i], tree, characters)
            return SuffixStep(pattern: patterns[i], range: run.ranges[i], probes: suffixProbes(patterns[i], characters, positions),
                              path: path.path, found: path.found, starts: run.starts[i].sorted())
        }
        playback.reset(count: steps.count)
    }
}

let suffix = SuffixModel()

func describeSuffix(_ step: SuffixStep) -> String {
    let count = step.starts.count
    let probes = "The suffix array’s two binary searches probed \(step.probes.count) rows"
    guard count > 0 else {
        return "Find “\(step.pattern)”: it does not occur. \(probes) and found no suffix starting with it. The suffix tree walk falls off after \(max(step.path.count - 1, 0)) \(step.path.count == 2 ? "edge" : "edges")."
    }
    let starts = step.starts.map(String.init).joined(separator: ", ")
    return "Find “\(step.pattern)”: \(count) \(count == 1 ? "occurrence" : "occurrences"), starting at \(starts). \(probes) and found rows \(step.range.lowerBound) to \(step.range.upperBound - 1), every suffix starting with it, side by side because they sort together. The suffix tree walks \(step.path.count - 1) \(step.path.count == 2 ? "edge" : "edges") down from the root, and the leaves below where the pattern ends are its occurrences."
}

/// The suffix tree: leaves left to right in the order of their suffixes, each internal node
/// above the middle of its children, edges labelled with their symbols (a leaf's edge ends in
/// $, the terminator), and each leaf showing where its suffix starts.
func suffixDrawing(_ tree: SuffixTree<Character>, _ text: [Character], step: SuffixStep?) -> (nodes: [CanvasNode], edges: [CanvasEdge], height: Int) {
    var order: [Int] = [], depth: [Int: Int] = [:], stack = [(tree.root, 0)]
    while let (node, level) = stack.popLast() {
        order.append(node)
        depth[node] = level
        stack += tree.children(of: node).reversed().map { ($0, level + 1) }
    }
    let leaves = order.filter { tree.isLeaf($0) }
    let gap = min(84.0, 640.0 / Double(max(leaves.count, 1)))
    var x: [Int: Double] = [:]
    for (rank, leaf) in leaves.enumerated() { x[leaf] = 340 - gap * Double(leaves.count - 1) / 2 + gap * Double(rank) }
    for node in order.reversed() where !tree.isLeaf(node) {
        let children = tree.children(of: node)
        x[node] = (x[children.first!]! + x[children.last!]!) / 2
    }
    let path = Set(step?.path ?? [])
    let below = step.flatMap { $0.found ? Set(suffixSubtree($0.path.last!, tree)) : nil } ?? []
    let offset = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
    let nodes = order.map { node in
        let state = below.contains(node) && tree.isLeaf(node) ? " current" : path.contains(node) || below.contains(node) ? " selected" : ""
        let start = tree.isLeaf(node) ? "\(tree.pathLabel(of: node).range.lowerBound)" : ""
        return CanvasNode(x: x[node]!, y: 30 + 70 * Double(depth[node]!), name: "", badge: start, radius: tree.isLeaf(node) ? 13 : 7, classes: state)
    }
    let edges = order.dropFirst().map { node in
        let range = tree.edgeLabel(of: node).range
        var label = String(text[range])
        if label.count > 4 { label = String(label.prefix(3)) + "…" }
        if tree.isLeaf(node) { label += "$" }
        let walked = path.contains(node) || below.contains(node)
        return CanvasEdge(from: offset[tree.parent(of: node)!]!, to: offset[node]!, label: label, classes: walked ? "active" : "")
    }
    return (nodes, edges, 30 + 70 * (depth.values.max() ?? 0) + 40)
}

@View
struct SuffixLab {
    var body: some View {
        let model = suffix
        let playback = model.playback
        let k = playback.k
        let steps = model.steps
        let last = k > 0 ? steps[k - 1] : nil
        let text = Array(model.text)
        let drawing = suffixDrawing(model.tree, text, step: last)
        let positions = Array(model.array.positions)
        let prefixes = Array(model.array.longestCommonPrefixes)
        let probes = Set(last?.probes ?? [])

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your text and patterns")) {
                label(.class("field"), .for("suffix-text")) {
                    "Text "
                    input(.id("suffix-text"), .type(.text), .value(model.textInput), .custom(name: "maxlength", value: "40"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in suffix.set(text: event.targetValue ?? "") }
                }
                label(.class("field"), .for("suffix-patterns")) {
                    "Patterns to find "
                    input(.id("suffix-patterns"), .type(.text), .value(model.patternsInput), .custom(name: "maxlength", value: "80"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in suffix.set(patterns: event.targetValue ?? "") }
                }
            }
            section(.class("lab"), .custom(name: "aria-label", value: "The suffix tree and suffix array")) {
                div(.class("panel stage")) {
                    span(.class("label")) { "The suffix tree" }
                    GraphCanvas(label: "The suffix tree of “\(model.text)”: \(model.tree.nodeCount) nodes", width: 680, height: drawing.height, nodes: drawing.nodes, edges: drawing.edges)
                    div(.class("legend")) {
                        span { i(.class("dot selected")) {}; "the search’s path" }
                        span { i(.class("dot current")) {}; "an occurrence" }
                    }
                    span(.class("label")) { "The suffix array" }
                    table(.class("suffixes")) {
                        thead {
                            tr {
                                th { "row" }
                                th { "starts at" }
                                th { "suffix" }
                                th { "shared with the row above" }
                            }
                        }
                        tbody {
                            for row in positions.indices {
                                let found = last?.range.contains(row) ?? false
                                tr(.class(found ? "found" : probes.contains(row) ? "probe" : "")) {
                                    td { "\(row)" }
                                    td { "\(positions[row])" }
                                    td(.class("suffix")) { positions[row] == text.count ? "$" : String(text[positions[row]...]) + "$" }
                                    td { "\(prefixes[row])" }
                                }
                            }
                        }
                    }
                    p(.class("legend")) { "Rows the binary searches probed are outlined; the rows of every suffix starting with the pattern are filled. $ is the end of the text, sorted before every letter." }
                }
                div(.class("side")) {
                    div(.class("panel"), .custom(name: "aria-live", value: "polite")) {
                        span(.class("label")) { k == steps.count ? "Done after \(steps.count) searches" : "Search \(k) of \(steps.count)" }
                        p(.class("narration")) {
                            if steps.isEmpty {
                                "Type a pattern to find, such as ana."
                            } else if let last {
                                describeSuffix(last)
                            } else {
                                "Every substring of the text is the start of some suffix. The suffix array lists the suffixes in sorted order, so the ones starting with a pattern sit together; the suffix tree spells them out from a shared root, so they lie below one point."
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "This search" }
                        div(.class("stat")) {
                            div(.class("good")) {
                                span(.class("num")) { "\(last?.starts.count ?? 0)" }
                                "occurrences"
                            }
                            div {
                                span(.class("num")) { "\(last?.probes.count ?? 0)" }
                                "rows probed"
                            }
                            div {
                                span(.class("num")) { "\(max((last?.path.count ?? 1) - 1, 0))" }
                                "edges walked"
                            }
                        }
                    }
                }
            }
            section(.class("panel controls"), .custom(name: "aria-label", value: "Playback")) {
                div(.class("buttons")) {
                    PlaybackButtons(playback: playback)
                }
                Timeline(
                    playback: playback,
                    marbles: steps.map { step in
                        Marble(kind: step.starts.isEmpty ? "m-red" : "m-green", radius: 9, letter: String(step.pattern.prefix(1)), title: describeSuffix(step))
                    },
                    legend: [
                        (Marble(kind: "m-green", radius: 6), "found"),
                        (Marble(kind: "m-red", radius: 6), "not there"),
                    ])
            }
        }
    }
}

@View
struct SuffixCodePanel {
    var body: some View {
        let model = suffix
        let repeated = model.tree.longestRepeatedSubstring.map { "\($0.range.lowerBound)..<\($0.range.upperBound)" } ?? "nil"
        CodePanel(
            snippets: [
                .suffixImports,
                Snippet(lines: [
                    "let text = \"\(model.text)\"",
                    "let patterns = [\(model.patterns.map { "\"\($0)\"" }.joined(separator: ", "))]",
                ]),
                .suffixRun,
            ],
            results: [repeated])
    }
}

enum SuffixPage {
    static func mount() {
        mountView(SuffixLab(), in: "app")
        mountView(SuffixCodePanel(), in: "code")
    }
}
