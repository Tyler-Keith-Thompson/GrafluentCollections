import ElementaryUI
import Reactivity
import Tries

/// One character of the scan: the state it starts in, the failure links it follows, the state
/// it ends in, and the matches that end with it.
struct AhoCorasickStep {
    var symbol: Character
    var position: Int
    var from: Int
    var failures: [Int]
    var to: Int
    var matches: [String]
}

@Reactive
final class AhoCorasickModel {
    var patternText = "he she his hers"
    var text = "ushers"
    var patterns: [String] = []
    var scanned = ""
    var tree = DrawnPrefixTree()
    var gotos: [[Character: Int]] = [[:]]
    var failures: [Int?] = [nil]
    var steps: [AhoCorasickStep] = []
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_200, scrubID: "scrub-ahocorasick")

    init() {
        run()
    }

    func set(patterns newText: String) {
        patternText = String(newText.prefix(80))
        run()
    }

    func set(text newText: String) {
        text = String(newText.prefix(40))
        run()
    }

    /// Builds the automaton, replays the scan state by state, and rewinds.
    func run() {
        patterns = ahoCorasickPatterns(patternText)
        scanned = ahoCorasickText(text)
        let result = ahoCorasickRun(patterns, scanned)
        let graph = ahoCorasickGraph(result.automaton)
        gotos = graph.gotos
        failures = graph.failures
        let root = failures.firstIndex { $0 == nil } ?? 0
        // Each state spells the path of goto edges from the root to it; number the drawing's
        // vertices so the root is 0.
        var order = [root], parents: [Int?] = [nil], labels = [""], prefixes = [""]
        var number = [root: 0]
        var next = 0
        while next < order.count {
            let state = order[next]
            for (symbol, child) in gotos[state].sorted(by: { $0.key < $1.key }) {
                number[child] = order.count
                order.append(child)
                parents.append(number[state]!)
                labels.append(String(symbol))
                prefixes.append(prefixes[number[state]!] + String(symbol))
            }
            next += 1
        }
        tree = DrawnPrefixTree(prefixes: prefixes, parents: parents, ends: order.map { !graph.patterns[$0].isEmpty }, labels: labels)
        // The drawing's numbering for gotos, failures and the scan.
        gotos = order.map { state in gotos[state].mapValues { number[$0]! } }
        failures = order.map { state in failures[state].map { number[$0]! } }
        var state = 0
        steps = Array(scanned).enumerated().map { position, symbol in
            let from = state
            var followed: [Int] = []
            while gotos[state][symbol] == nil, let failure = failures[state] {
                followed.append(state)
                state = failure
            }
            state = gotos[state][symbol] ?? 0
            let ending = result.matches.filter { $0.range.upperBound == position + 1 }.map { patterns[$0.patternIndex] }
            return AhoCorasickStep(symbol: symbol, position: position, from: from, failures: followed, to: state, matches: ending)
        }
        playback.reset(count: steps.count)
    }
}

let ahoCorasick = AhoCorasickModel()

/// A state as the page names it: the letters it spells, or "the root".
func stateName(_ prefix: String) -> String {
    prefix.isEmpty ? "the root" : "“\(prefix)”"
}

func describeAhoCorasick(_ step: AhoCorasickStep, _ tree: DrawnPrefixTree) -> String {
    let from = stateName(tree.prefixes[step.from]), to = stateName(tree.prefixes[step.to])
    var text: String
    if step.failures.isEmpty {
        text = step.to == 0
            ? "Read ‘\(step.symbol)’ at \(from): no pattern starts with it, so stay at the root."
            : "Read ‘\(step.symbol)’ at \(from): follow its goto edge to \(to)."
    } else {
        text = "Read ‘\(step.symbol)’ at \(from): it has no ‘\(step.symbol)’ edge, so follow the failure \(step.failures.count == 1 ? "link" : "links") to the longest end of what was read that still starts a pattern"
        text += step.to == 0 ? ", back to the root, where no pattern starts with ‘\(step.symbol)’." : ", then the ‘\(step.symbol)’ edge to \(to)."
    }
    if !step.matches.isEmpty {
        text += " Matches ending here: \(step.matches.joined(separator: ", "))."
    }
    return text
}

@View
struct AhoCorasickLab {
    var body: some View {
        let model = ahoCorasick
        let playback = model.playback
        let k = playback.k
        let steps = model.steps
        let last = k > 0 ? steps[k - 1] : nil
        let tree = model.tree
        let spots = prefixTreeSpots(tree)
        let current = last?.to ?? 0
        let walked = Set(last?.failures ?? [])
        let nodes = (0 ..< tree.count).map { vertex in
            let classes = [
                tree.ends[vertex] ? "done" : "",
                vertex == current ? "current" : walked.contains(vertex) ? "selected" : "",
            ].filter { !$0.isEmpty }.joined(separator: " ")
            return CanvasNode(x: spots.x[vertex], y: spots.y[vertex], name: "", radius: vertex == 0 ? 8 : 10, classes: classes)
        }
        let gotoEdges: [CanvasEdge] = (0 ..< tree.count).compactMap { vertex in
            guard let parent = tree.parents[vertex] else { return nil }
            let taken = last.map { $0.to == vertex && tree.parents[vertex] == ($0.failures.isEmpty ? $0.from : model.failures[$0.failures.last!]) } ?? false
            return CanvasEdge(from: parent, to: vertex, directed: true, label: tree.labels[vertex], classes: taken ? "active" : "tree")
        }
        // Failure links into the root are left out: every state without a better one has one.
        let failureEdges: [CanvasEdge] = (0 ..< tree.count).compactMap { vertex in
            guard let failure = model.failures[vertex], failure != 0 else { return nil }
            return CanvasEdge(from: vertex, to: failure, directed: true, classes: walked.contains(vertex) ? "fail active" : "fail", bend: 18)
        }

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your patterns and text")) {
                label(.class("field"), .for("aho-patterns")) {
                    "Patterns "
                    input(.id("aho-patterns"), .type(.text), .value(model.patternText), .custom(name: "maxlength", value: "80"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in ahoCorasick.set(patterns: event.targetValue ?? "") }
                }
                label(.class("field"), .for("aho-text")) {
                    "Text to scan "
                    input(.id("aho-text"), .type(.text), .value(model.text), .custom(name: "maxlength", value: "40"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in ahoCorasick.set(text: event.targetValue ?? "") }
                }
            }
            section(.class("lab"), .custom(name: "aria-label", value: "The automaton")) {
                div(.class("panel stage")) {
                    if model.patterns.isEmpty {
                        p(.class("empty")) { "Type some patterns." }
                    } else {
                        GraphCanvas(label: "The automaton: \(tree.count) states, goto edges down and failure links across", width: 680, height: spots.height, nodes: nodes, edges: gotoEdges + failureEdges)
                    }
                    div(.class("legend")) {
                        span { i(.class("dot done")) {}; "a pattern ends here" }
                        span { i(.class("dot current")) {}; "the state after this letter" }
                        span { i(.class("dot selected")) {}; "left by a failure link" }
                        span { "dashed: failure links (those to the root are left out)" }
                    }
                }
                div(.class("side")) {
                    div(.class("panel")) {
                        span(.class("label")) { "The text" }
                        p(.class("scan")) {
                            for (i, symbol) in Array(model.scanned).enumerated() {
                                span(.class(i == (last?.position ?? -1) ? "now" : i < k ? "read" : "")) { String(symbol) }
                            }
                        }
                    }
                    div(.class("panel"), .custom(name: "aria-live", value: "polite")) {
                        span(.class("label")) { k == steps.count ? "Done after \(steps.count) letters" : "Letter \(k) of \(steps.count)" }
                        p(.class("narration")) {
                            if steps.isEmpty {
                                "Type a text to scan."
                            } else if let last {
                                describeAhoCorasick(last, tree)
                            } else {
                                "The goto edges form a trie of the patterns. Each state's failure link points to the state for the longest proper end of its letters that also starts a pattern, so the scan never moves backwards in the text."
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "Matches so far" }
                        p(.class("narration")) {
                            let found = steps.prefix(k).flatMap { step in step.matches.map { "\($0) ending at \(step.position + 1)" } }
                            found.isEmpty ? "None" : found.joined(separator: "; ")
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
                        Marble(kind: !step.matches.isEmpty ? "m-green" : step.failures.isEmpty ? "m-blue" : "m-violet",
                               radius: step.matches.isEmpty ? 7 : 10, letter: String(step.symbol), title: describeAhoCorasick(step, tree))
                    },
                    legend: [
                        (Marble(kind: "m-blue", radius: 6), "a goto edge"),
                        (Marble(kind: "m-violet", radius: 6), "failure links first"),
                        (Marble(kind: "m-green", radius: 6), "a match ends here"),
                    ])
            }
        }
    }
}

@View
struct AhoCorasickCodePanel {
    var body: some View {
        let model = ahoCorasick
        let result = ahoCorasickRun(model.patterns, model.scanned)
        let found = result.matches.map { "\"\(model.patterns[$0.patternIndex]) at \($0.range)\"" }
        let links = model.failures.count { $0 != nil }
        CodePanel(
            snippets: [.ahocorasickImports,
                       Snippet(lines: ["let patterns = [\(model.patterns.map { "\"\($0)\"" }.joined(separator: ", "))]", "let text = \"\(model.scanned)\""]),
                       .ahocorasickRun, .ahocorasickStates],
            results: ["\(result.automaton.stateCount)", "[\(found.joined(separator: ", "))]", "\(links)"])
    }
}

enum AhoCorasickPage {
    static func mount() {
        mountView(AhoCorasickLab(), in: "app")
        mountView(AhoCorasickCodePanel(), in: "code")
    }
}
