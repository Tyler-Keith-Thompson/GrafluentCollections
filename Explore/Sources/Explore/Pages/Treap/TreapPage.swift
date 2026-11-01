import BinarySearchTrees
import ElementaryUI
import Reactivity
import Trees

/// What one operation did to the treap: the key it touched, whether it found it, and the keys
/// whose parent changed.
struct TreapStep {
    var key: Int
    var removes: Bool
    var changed: Bool
    var moved: Set<Int>
    var wasEmpty: Bool
}

@Reactive
final class TreapModel {
    var text = "1 2 3 4 5 6 7 8 -4 -1"
    var seed: UInt64 = 7
    var operations: [Int] = []
    var history: [Treap<Int>] = []
    var shapes: [BinaryTree<Int>?] = [nil]
    var priorities: [[Int: Int]] = [[:]]
    var steps: [TreapStep] = []
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_000, scrubID: "scrub-treap")

    init() {
        set(text: text)
    }

    /// Runs the operations in `newText` on a fresh treap and rewinds.
    func set(text newText: String) {
        text = String(newText.prefix(120))
        run()
    }

    /// The same operations with the next seed: other priorities, so another shape.
    func reroll() {
        seed &+= 1
        run()
    }

    func run() {
        operations = treapOperations(text)
        history = treapHistory(operations, seed: seed)
        let drawn = history.map(treapShape)
        shapes = drawn.map(\.shape)
        priorities = drawn.map(\.priorities)
        steps = operations.indices.map { i in
            let before = parents(shapes[i]), after = parents(shapes[i + 1])
            let key = abs(operations[i])
            let moved = Set(after.keys.filter { $0 != key && before[$0] != nil && before[$0]! != after[$0]! })
            return TreapStep(key: key, removes: operations[i] < 0, changed: history[i].count != history[i + 1].count, moved: moved,
                             wasEmpty: history[i].isEmpty)
        }
        playback.reset(count: steps.count)
    }

    func parents(_ shape: BinaryTree<Int>?) -> [Int: Int?] {
        guard let shape else { return [:] }
        var out: [Int: Int?] = [:]
        for key in shape.inorder { out[key] = shape.parent(of: key) }
        return out
    }

    func spots(_ k: Int) -> (spots: [Int: (x: Double, y: Double)], height: Int) {
        guard let shape = shapes[k] else { return ([:], 120) }
        let keys = shape.inorder
        let gap = min(56.0, 640.0 / Double(max(keys.count, 1)))
        var spots: [Int: (x: Double, y: Double)] = [:]
        for (rank, key) in keys.enumerated() {
            spots[key] = (340 - gap * Double(keys.count - 1) / 2 + gap * Double(rank), 34 + 70 * Double(shape.depth(of: key)))
        }
        return (spots, 34 + 70 * shape.height + 60)
    }
}

let treap = TreapModel()

func describeTreap(_ step: TreapStep, _ priorities: [Int: Int]) -> String {
    let key = step.key
    if step.removes {
        guard step.changed else { return "Remove \(key): it is not in the treap, so nothing changes." }
        return step.moved.isEmpty
            ? "Remove \(key). It had at most one child, which takes its place."
            : "Remove \(key). Its two subtrees join: of the two roots, the higher priority goes on top, all the way down, which moves \(keyList(step.moved))."
    }
    guard step.changed else { return "Insert \(key): it is already there, so nothing changes." }
    let priority = priorities[key].map(percentile) ?? 0
    if step.wasEmpty { return "Insert \(key) with priority \(priority). The treap was empty, so it is the root." }
    return step.moved.isEmpty
        ? "Insert \(key) with priority \(priority). It goes in as a leaf, and its parent's priority is higher, so it stays."
        : "Insert \(key) with priority \(priority). It goes in where its priority puts it above \(keyList(step.moved)), splitting them to either side."
}

@View
struct TreapLab {
    var body: some View {
        let model = treap
        let playback = model.playback
        let k = playback.k
        let steps = model.steps
        let last = k > 0 ? steps[k - 1] : nil
        let current = model.history[k]
        let shape = model.shapes[k]
        let priorities = model.priorities[k]
        let drawing = model.spots(k)
        let keys = shape?.inorder ?? []
        let index = Dictionary(uniqueKeysWithValues: keys.enumerated().map { ($1, $0) })
        let nodes = keys.map { key in
            let spot = drawing.spots[key]!
            let touched = last.map { !$0.removes && $0.key == key } ?? false
            return CanvasNode(
                x: spot.x, y: spot.y, name: "", badge: "\(key)", note: "p \(priorities[key].map(percentile) ?? 0)", radius: 16,
                classes: touched ? "current" : (last?.moved.contains(key) ?? false) ? "selected" : "")
        }
        let edges: [CanvasEdge] = keys.compactMap { key in
            guard let parent = shape?.parent(of: key) else { return nil }
            return CanvasEdge(from: index[parent]!, to: index[key]!, classes: (last?.moved.contains(key) ?? false) ? "active" : "tree")
        }

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your operations")) {
                label(.class("field"), .for("treap-text")) {
                    "Keys to insert, a minus sign to remove "
                    input(.id("treap-text"), .type(.text), .value(model.text), .custom(name: "maxlength", value: "120"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in treap.set(text: event.targetValue ?? "") }
                }
                div(.class("buttons")) {
                    button(.type(.button)) { "New priorities" }
                        .onClick { treap.reroll() }
                }
            }
            section(.class("lab"), .custom(name: "aria-label", value: "The treap")) {
                div(.class("panel stage")) {
                    if keys.isEmpty {
                        p(.class("empty")) { k == 0 ? "The treap starts empty. Press Step to run the first operation." : "The treap is empty." }
                    } else {
                        GraphCanvas(label: "The treap after \(k) operations: \(keys.count) keys, \(current.height) levels", width: 680, height: drawing.height, nodes: nodes, edges: edges)
                    }
                    div(.class("legend")) {
                        span { i(.class("dot current")) {}; "just inserted" }
                        span { i(.class("dot selected")) {}; "moved by this step" }
                        span { "under each key: its priority, 0 to 99" }
                    }
                }
                div(.class("side")) {
                    div(.class("panel"), .custom(name: "aria-live", value: "polite")) {
                        span(.class("label")) { k == steps.count ? "Done after \(steps.count) operations" : "Operation \(k) of \(steps.count)" }
                        p(.class("narration")) {
                            if steps.isEmpty {
                                "Type some keys to insert."
                            } else if let last {
                                describeTreap(last, model.priorities[k])
                            } else {
                                "Every key draws a random priority as it goes in. The keys are in search-tree order left to right, and no key has a higher priority than the one above it."
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "The treap" }
                        div(.class("stat")) {
                            div {
                                span(.class("num")) { "\(current.count)" }
                                "keys"
                            }
                            div(.class("good")) {
                                span(.class("num")) { "\(current.height)" }
                                "levels"
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "By priority, highest first" }
                        p(.class("narration")) {
                            keys.isEmpty ? "—" : keys.sorted { (priorities[$0] ?? 0) > (priorities[$1] ?? 0) }.map(String.init).joined(separator: " ")
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
                    marbles: steps.enumerated().map { i, step in
                        Marble(kind: step.removes ? "m-red" : step.moved.isEmpty ? "m-blue" : "m-violet",
                               radius: step.changed ? 10 : 7, letter: "\(step.key)", title: describeTreap(step, model.priorities[i + 1]))
                    },
                    legend: [
                        (Marble(kind: "m-blue", radius: 6), "insert as a leaf"),
                        (Marble(kind: "m-violet", radius: 6), "insert above other keys"),
                        (Marble(kind: "m-red", radius: 6), "remove"),
                    ])
            }
        }
    }
}

@View
struct TreapCodePanel {
    var body: some View {
        let model = treap
        let list = model.operations.map(String.init).joined(separator: ", ")
        let last = model.history.last
        let top = model.shapes.last.flatMap { $0 }.flatMap { last?.priority(of: $0.root) }
        CodePanel(
            snippets: [.treapImports, Snippet(lines: ["let operations = [\(list)]  // negative: remove", "let seed: UInt64 = \(model.seed)"]), .treapRun, .treapShape],
            results: ["\(last?.height ?? 0)", top.map { "\($0)" } ?? "nil"])
    }
}

enum TreapPage {
    static func mount() {
        mountView(TreapLab(), in: "app")
        mountView(TreapCodePanel(), in: "code")
    }
}
