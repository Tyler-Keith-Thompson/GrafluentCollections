import BinarySearchTrees
import ElementaryUI
import Reactivity
import Trees

/// What one operation did to the tree: the operation, whether it found or changed anything, the
/// key now at the root, and the depth the key was at before.
struct SplayStep {
    var operation: SplayOperation
    var found: Bool
    var root: Int?
    var depthBefore: Int?
    var moved: Set<Int>
    var wasEmpty: Bool
}

@Reactive
final class SplayModel {
    var text = "10 20 30 40 50 60 70 ?10 ?40 ?10 -50 80"
    var operations: [SplayOperation] = []
    var history: [SplayTree<Int>] = [SplayTree()]
    var shapes: [BinaryTree<Int>?] = [nil]
    var steps: [SplayStep] = []
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_000, scrubID: "scrub-splay")

    init() {
        set(text: text)
    }

    func set(text newText: String) {
        text = String(newText.prefix(120))
        operations = splayOperations(text)
        history = splayHistory(operations)
        shapes = history.map(splayShape)
        steps = operations.indices.map { i in
            let before = parents(shapes[i]), after = parents(shapes[i + 1])
            let operation = operations[i]
            let key = operation.key
            let moved = Set(after.keys.filter { $0 != key && before[$0] != nil && before[$0]! != after[$0]! })
            let found: Bool
            switch operation {
            case .insert: found = history[i].count != history[i + 1].count
            case .remove: found = history[i].count != history[i + 1].count
            case .access: found = history[i].contains(key)
            }
            let depthBefore = shapes[i].flatMap { shape in shape.inorder.contains(key) ? shape.depth(of: key) : nil }
            return SplayStep(operation: operation, found: found, root: shapes[i + 1]?.root, depthBefore: depthBefore, moved: moved,
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
        return (spots, 34 + 70 * shape.height + 40)
    }
}

let splay = SplayModel()

func describeSplayStep(_ step: SplayStep) -> String {
    let key = step.operation.key
    let root = step.root.map { "\($0)" } ?? "nothing"
    switch step.operation {
    case .access:
        guard step.found else { return "Look up \(key): it is not there. The last key the search reached, \(root), is splayed to the root instead." }
        guard let depth = step.depthBefore, depth > 0 else { return "Look up \(key): it is already at the root, so nothing moves." }
        return "Look up \(key), \(depth) \(depth == 1 ? "level" : "levels") down. Rotations in pairs bring it to the root, and roughly halve the depth of every key on the way."
    case .insert:
        guard step.found else { return "Insert \(key): it is already there, so it is splayed to the root." }
        if step.wasEmpty { return "Insert \(key) into the empty tree. It is the root." }
        return "Insert \(key) as a leaf, then splay it to the root, so the newest key is the quickest to find again."
    case .remove:
        guard step.found else { return "Remove \(key): it is not there. The search's last key, \(root), is splayed to the root." }
        return "Remove \(key): splay it to the root, take it off, and join its two subtrees under the largest key on the left. \(root) is the root now."
    }
}

@View
struct SplayLab {
    var body: some View {
        let model = splay
        let playback = model.playback
        let k = playback.k
        let steps = model.steps
        let last = k > 0 ? steps[k - 1] : nil
        let tree = model.history[k]
        let shape = model.shapes[k]
        let drawing = model.spots(k)
        let keys = shape?.inorder ?? []
        let index = Dictionary(uniqueKeysWithValues: keys.enumerated().map { ($1, $0) })
        let nodes = keys.map { key in
            let spot = drawing.spots[key]!
            let touched = last.map { $0.operation.key == key } ?? false
            return CanvasNode(
                x: spot.x, y: spot.y, name: "", badge: "\(key)", radius: 16,
                classes: touched ? "current" : (last?.moved.contains(key) ?? false) ? "selected" : "")
        }
        let edges: [CanvasEdge] = keys.compactMap { key in
            guard let parent = shape?.parent(of: key) else { return nil }
            return CanvasEdge(from: index[parent]!, to: index[key]!, classes: (last?.moved.contains(key) ?? false) ? "active" : "tree")
        }

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your operations")) {
                label(.class("field"), .for("splay-text")) {
                    "Keys to insert, ? to look up, a minus sign to remove "
                    input(.id("splay-text"), .type(.text), .value(model.text), .custom(name: "maxlength", value: "120"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in splay.set(text: event.targetValue ?? "") }
                }
            }
            section(.class("lab"), .custom(name: "aria-label", value: "The splay tree")) {
                div(.class("panel stage")) {
                    if keys.isEmpty {
                        p(.class("empty")) { k == 0 ? "The tree starts empty. Press Step to run the first operation." : "The tree is empty." }
                    } else {
                        GraphCanvas(label: "The splay tree after \(k) operations: \(keys.count) keys, \(tree.height) levels", width: 680, height: drawing.height, nodes: nodes, edges: edges)
                    }
                    div(.class("legend")) {
                        span { i(.class("dot current")) {}; "the key this step used" }
                        span { i(.class("dot selected")) {}; "moved by the splay" }
                    }
                }
                div(.class("side")) {
                    div(.class("panel"), .custom(name: "aria-live", value: "polite")) {
                        span(.class("label")) { k == steps.count ? "Done after \(steps.count) operations" : "Operation \(k) of \(steps.count)" }
                        p(.class("narration")) {
                            if steps.isEmpty {
                                "Type some keys to insert."
                            } else if let last {
                                describeSplayStep(last)
                            } else {
                                "A splay tree keeps no balance information at all. Every operation moves the key it used to the root, with rotations in pairs that also shorten the path it came along."
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "The tree" }
                        div(.class("stat")) {
                            div {
                                span(.class("num")) { "\(tree.count)" }
                                "keys"
                            }
                            div(.class("good")) {
                                span(.class("num")) { "\(tree.height)" }
                                "levels"
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "At the root" }
                        p(.class("narration")) { shape.map { "\($0.root)" } ?? "—" }
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
                        let kind: String
                        switch step.operation {
                        case .insert: kind = "m-blue"
                        case .access: kind = "m-green"
                        case .remove: kind = "m-red"
                        }
                        return Marble(kind: kind, radius: step.found ? 10 : 7, letter: "\(step.operation.key)", title: describeSplayStep(step))
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
struct SplayCodePanel {
    var body: some View {
        let model = splay
        let list = model.operations.map { operation -> String in
            switch operation {
            case .insert(let key): ".insert(\(key))"
            case .remove(let key): ".remove(\(key))"
            case .access(let key): ".access(\(key))"
            }
        }.joined(separator: ", ")
        let root = model.shapes.last.flatMap { $0 }.map { "\($0.root)" } ?? "nil"
        CodePanel(
            snippets: [.splayImports, Snippet(lines: ["let operations: [SplayOperation] = [\(list)]"]), .splayRun, .splayShape],
            results: ["\(model.history.last?.height ?? 0)", root])
    }
}

enum SplayPage {
    static func mount() {
        mountView(SplayLab(), in: "app")
        mountView(SplayCodePanel(), in: "code")
    }
}
