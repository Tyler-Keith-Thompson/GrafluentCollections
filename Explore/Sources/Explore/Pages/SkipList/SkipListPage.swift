import ElementaryUI
import Reactivity
import SkipLists

/// One stop of a search: an element's rank in the list, or −1 for the head, and the level.
struct SkipListStop: Hashable {
    var index: Int
    var level: Int
}

/// The stops a search for `target` makes: from the head's top level, right while the next
/// element on the level is smaller, down a level otherwise, until it meets `target` or leaves
/// the bottom level.
func skipListSearch(_ keys: [Int], _ towers: [Int: Int], _ target: Int) -> (stops: [SkipListStop], found: Bool) {
    let levels = towers.values.max() ?? 0
    guard levels > 0 else { return ([], false) }
    var position = -1, level = levels - 1
    var stops = [SkipListStop(index: -1, level: level)]
    while level >= 0 {
        let next = keys.indices.first { $0 > position && towers[keys[$0]]! > level }
        if let next, keys[next] < target {
            position = next
            stops.append(SkipListStop(index: next, level: level))
        } else if let next, keys[next] == target {
            stops.append(SkipListStop(index: next, level: level))
            return (stops, true)
        } else {
            level -= 1
            if level >= 0 { stops.append(SkipListStop(index: position, level: level)) }
        }
    }
    return (stops, false)
}

/// What one operation did: the operation, whether it found or changed anything, the height of
/// the key's tower, and how many stops the search made.
struct SkipListStep {
    var operation: KeyOperation
    var found: Bool
    var tower: Int
    var stops: Int
}

@Reactive
final class SkipListModel {
    var text = "30 10 50 20 40 70 60 80 90 15 35 ?60 ?65 -50 ?60"
    var seed: UInt64 = 3
    var operations: [KeyOperation] = []
    var history: [SkipList<Int>] = []
    var towers: [[Int: Int]] = [[:]]
    var steps: [SkipListStep] = []
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_000, scrubID: "scrub-skiplist")

    init() {
        set(text: text)
    }

    /// Runs the operations in `newText` on a fresh list and rewinds.
    func set(text newText: String) {
        text = String(newText.prefix(120))
        run()
    }

    /// The same operations with the next seed: other tower heights.
    func reroll() {
        seed &+= 1
        run()
    }

    func run() {
        operations = skipListOperations(text)
        history = skipListHistory(operations, seed: seed)
        towers = history.map(skipListTowers)
        steps = operations.indices.map { i in
            let operation = operations[i]
            let key = operation.key
            let found: Bool
            switch operation {
            case .insert, .remove: found = history[i].count != history[i + 1].count
            case .access, .split, .join: found = history[i].contains(key)
            }
            // A removal's tower is the one it took out; the search is drawn on the list after it.
            let tower = operation == .remove(key) ? towers[i][key] ?? 0 : towers[i + 1][key] ?? 0
            let keys = Array(history[i + 1])
            let stops = skipListSearch(keys, towers[i + 1], key).stops.count
            return SkipListStep(operation: operation, found: found, tower: tower, stops: stops)
        }
        playback.reset(count: steps.count)
    }
}

let skipList = SkipListModel()

func describeSkipList(_ step: SkipListStep) -> String {
    let key = step.operation.key
    let moves = step.stops <= 1 ? "" : " The search made \(step.stops - 1) \(step.stops == 2 ? "move" : "moves")."
    switch step.operation {
    case .insert:
        guard step.found else { return "Insert \(key): it is already there, so nothing changes." }
        let tower = step.tower == 1 ? "1 level" : "\(step.tower) levels"
        return "Insert \(key) with a tower of \(tower): each level above the bottom is added with probability 1/4, by a coin toss at insertion. It is linked in on every level it reaches." + moves
    case .remove:
        guard step.found else { return "Remove \(key): it is not in the list, so nothing changes." }
        return "Remove \(key). Its tower of \(step.tower == 1 ? "1 level" : "\(step.tower) levels") comes out, and each link that led to it now skips past it."
    case .access, .split, .join:
        guard step.found else {
            return "Look up \(key): not there. The search goes right while the next key is smaller and down otherwise, and drops off the bottom level next to where \(key) would be." + moves
        }
        return "Look up \(key): found. The search starts on the top level, goes right while the next key is smaller, and drops a level otherwise, skipping most of the list." + moves
    }
}

/// The links of the drawing: along each level from the head, and down each tower. Those the
/// search walked are `active`.
func skipListEdges(_ stops: [SkipListStop], _ offset: [SkipListStop: Int], _ levels: Int, _ walked: Set<[Int]>) -> [CanvasEdge] {
    var edges: [CanvasEdge] = []
    for level in 0 ..< levels {
        let row = stops.filter { $0.level == level }
        for (a, b) in zip(row, row.dropFirst()) {
            let pair = [offset[a]!, offset[b]!]
            edges.append(CanvasEdge(from: pair[0], to: pair[1], directed: true, classes: walked.contains(pair) ? "active" : ""))
        }
        guard level > 0 else { continue }
        for stop in row {
            let pair = [offset[stop]!, offset[SkipListStop(index: stop.index, level: level - 1)]!]
            edges.append(CanvasEdge(from: pair[0], to: pair[1], directed: true, classes: walked.contains(pair) ? "active" : "tree"))
        }
    }
    return edges
}

@View
struct SkipListLab {
    var body: some View {
        let model = skipList
        let playback = model.playback
        let k = playback.k
        let steps = model.steps
        let last = k > 0 ? steps[k - 1] : nil
        let list = model.history[k]
        let towers = model.towers[k]
        let keys = Array(list)
        let levels = towers.values.max() ?? 0
        let search = last.map { skipListSearch(keys, towers, $0.operation.key) }
        let visited = Set(search?.stops ?? [])
        let gap = min(56.0, 610.0 / Double(max(keys.count, 1)))
        let bottom = 30.0 + 52 * Double(max(levels - 1, 0))
        let stops: [SkipListStop] = (0 ..< levels).flatMap { level in
            [SkipListStop(index: -1, level: level)] + keys.indices.filter { towers[keys[$0]]! > level }.map { SkipListStop(index: $0, level: level) }
        }
        let offset = Dictionary(uniqueKeysWithValues: stops.enumerated().map { ($1, $0) })
        let nodes = stops.map { stop in
            let x = stop.index < 0 ? 30 : 30 + gap * Double(stop.index + 1)
            let y = bottom - 52 * Double(stop.level)
            let isTarget = stop.index >= 0 && last?.operation.key == keys[stop.index]
            let state = visited.contains(stop) ? (isTarget ? " current" : " selected") : ""
            return stop.index < 0
                ? CanvasNode(x: x, y: y, name: "", radius: 7, classes: "head" + state)
                : CanvasNode(x: x, y: y, name: "", badge: "\(keys[stop.index])", radius: 15, classes: state)
        }
        let path = search?.stops ?? []
        let walked = Set(zip(path, path.dropFirst()).map { [offset[$0]!, offset[$1]!] })
        let edges = skipListEdges(stops, offset, levels, walked)

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your operations")) {
                label(.class("field"), .for("skiplist-text")) {
                    "Keys to insert, ? to look up, a minus sign to remove "
                    input(.id("skiplist-text"), .type(.text), .value(model.text), .custom(name: "maxlength", value: "120"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in skipList.set(text: event.targetValue ?? "") }
                }
                div(.class("buttons")) {
                    button(.type(.button)) { "New towers" }
                        .onClick { skipList.reroll() }
                }
            }
            section(.class("lab"), .custom(name: "aria-label", value: "The skip list")) {
                div(.class("panel stage")) {
                    if keys.isEmpty {
                        p(.class("empty")) { k == 0 ? "The list starts empty. Press Step to run the first operation." : "The list is empty." }
                    } else {
                        GraphCanvas(label: "The skip list after \(k) operations: \(keys.count) keys on \(levels) levels", width: 680, height: Int(bottom) + 40, nodes: nodes, edges: edges)
                    }
                    div(.class("legend")) {
                        span { i(.class("dot head")) {}; "the head" }
                        span { i(.class("dot selected")) {}; "where this step's search went" }
                        span { i(.class("dot current")) {}; "the key it found" }
                    }
                }
                div(.class("side")) {
                    div(.class("panel"), .custom(name: "aria-live", value: "polite")) {
                        span(.class("label")) { k == steps.count ? "Done after \(steps.count) operations" : "Operation \(k) of \(steps.count)" }
                        p(.class("narration")) {
                            if steps.isEmpty {
                                "Type some keys to insert."
                            } else if let last {
                                describeSkipList(last)
                            } else {
                                "The bottom level is a sorted linked list of every key. Each level above links only the keys whose towers reach it, about a quarter of the level below, so a search can take long strides first."
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "The list" }
                        div(.class("stat")) {
                            div {
                                span(.class("num")) { "\(keys.count)" }
                                "keys"
                            }
                            div(.class("good")) {
                                span(.class("num")) { "\(levels)" }
                                "levels"
                            }
                            div {
                                span(.class("num")) { "\(max((search?.stops.count ?? 1) - 1, 0))" }
                                "moves in this search"
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
                        Marble(kind: splayMarbleKind(step.operation), radius: step.found ? 10 : 7, letter: "\(step.operation.key)", title: describeSkipList(step))
                    },
                    legend: [
                        (Marble(kind: "m-blue", radius: 6), "insert"),
                        (Marble(kind: "m-green", radius: 6), "look up"),
                        (Marble(kind: "m-red", radius: 6), "remove"),
                    ])
            }
        }
    }
}

@View
struct SkipListCodePanel {
    var body: some View {
        let model = skipList
        let list = model.operations.map(operationCode).joined(separator: ", ")
        let tallest = model.towers.last?.values.max().map { "\($0)" } ?? "nil"
        CodePanel(
            snippets: [.skiplistImports, Snippet(lines: ["let operations: [KeyOperation] = [\(list)]", "let seed: UInt64 = \(model.seed)"]), .skiplistRun, .skiplistTowers],
            results: ["\(model.history.last?.count ?? 0)", tallest])
    }
}

enum SkipListPage {
    static func mount() {
        mountView(SkipListLab(), in: "app")
        mountView(SkipListCodePanel(), in: "code")
    }
}
