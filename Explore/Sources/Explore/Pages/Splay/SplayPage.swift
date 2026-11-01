import BinarySearchTrees
import ElementaryUI
import Reactivity
import Trees

/// What one operation did to the tree: the operation, whether it found or changed anything, the
/// keys now at the roots, and the depth the key was at before.
struct SplayStep {
    var operation: KeyOperation
    var found: Bool
    var roots: [Int]
    var depthBefore: Int?
    var moved: Set<Int>
    var wasEmpty: Bool
    var lowerCount: Int
    var upperCount: Int
}

/// Each key's parent (nil for a root) across one or two trees.
func splayParents(_ shapes: [BinaryTree<Int>]) -> [Int: Int?] {
    var out: [Int: Int?] = [:]
    for shape in shapes {
        for key in shape.inorder { out[key] = shape.parent(of: key) }
    }
    return out
}

/// Where each key is drawn: across by rank, with a gap between two trees, and down by depth.
func splaySpots(_ shapes: [BinaryTree<Int>]) -> (spots: [Int: (x: Double, y: Double)], height: Int) {
    let count = shapes.reduce(0) { $0 + $1.inorder.count } + (shapes.count > 1 ? 1 : 0)
    guard count > 0 else { return ([:], 120) }
    let gap = min(56.0, 640.0 / Double(max(count, 1)))
    var spots: [Int: (x: Double, y: Double)] = [:]
    var rank = 0
    for shape in shapes {
        for key in shape.inorder {
            spots[key] = (340 - gap * Double(count - 1) / 2 + gap * Double(rank), 34 + 70 * Double(shape.depth(of: key)))
            rank += 1
        }
        rank += 1
    }
    return (spots, 34 + 70 * (shapes.map(\.height).max() ?? 0) + 40)
}

@Reactive
final class SplayModel {
    var text = "10 20 30 40 50 60 70 ?10 ?40 ?10 /35 -50 80"
    var operations: [KeyOperation] = []
    var history: [[SplayTree<Int>]] = [[SplayTree()]]
    var shapes: [[BinaryTree<Int>]] = [[]]
    var steps: [SplayStep] = []
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_000, scrubID: "scrub-splay")

    init() {
        set(text: text)
    }

    func set(text newText: String) {
        text = String(newText.prefix(120))
        operations = keyOperations(text, splits: true)
        history = splayHistory(operations)
        shapes = history.map { trees in trees.compactMap(splayShape) }
        steps = operations.indices.map { i in
            let before = splayParents(shapes[i]), after = splayParents(shapes[i + 1])
            let operation = operations[i]
            let key = operation.key
            let moved = Set(after.keys.filter { $0 != key && before[$0] != nil && before[$0]! != after[$0]! })
            let countBefore = history[i].reduce(0) { $0 + $1.count }, countAfter = history[i + 1].reduce(0) { $0 + $1.count }
            let found: Bool
            switch operation {
            case .insert, .remove: found = countBefore != countAfter
            case .access, .split, .join: found = history[i][0].contains(key)
            }
            let depthBefore = shapes[i].first.flatMap { shape in shape.inorder.contains(key) ? shape.depth(of: key) : nil }
            return SplayStep(operation: operation, found: found, roots: shapes[i + 1].map(\.root), depthBefore: depthBefore, moved: moved,
                             wasEmpty: countBefore == 0, lowerCount: history[i + 1][0].count, upperCount: history[i + 1].count > 1 ? history[i + 1][1].count : 0)
        }
        playback.reset(count: steps.count)
    }
}

let splay = SplayModel()

func describeSplayStep(_ step: SplayStep) -> String {
    let key = step.operation.key
    let root = step.roots.first.map { "\($0)" } ?? "nothing"
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
    case .split:
        return "Split at \(key): splay \(step.found ? "\(key)" : "the key nearest \(key)") to the root, so the keys below \(key) form one subtree, which is cut off as a tree of its own: \(step.lowerCount) keys on the left, \(step.upperCount) on the right."
    case .join:
        return "Join the two trees again: splay the left tree's largest key to its root, where it has no right child, and hang the right tree there. \(root) is the root now."
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
        let trees = model.history[k]
        let shapes = model.shapes[k]
        let drawing = splaySpots(shapes)
        let keys = shapes.flatMap(\.inorder)
        let index = Dictionary(uniqueKeysWithValues: keys.enumerated().map { ($1, $0) })
        let parents = splayParents(shapes)
        let nodes = keys.map { key in
            let spot = drawing.spots[key]!
            let touched = last.map { $0.operation.key == key } ?? false
            return CanvasNode(
                x: spot.x, y: spot.y, name: "", badge: "\(key)", radius: 16,
                classes: touched ? "current" : (last?.moved.contains(key) ?? false) ? "selected" : "")
        }
        let edges: [CanvasEdge] = keys.compactMap { key in
            guard let parent = parents[key] ?? nil else { return nil }
            return CanvasEdge(from: index[parent]!, to: index[key]!, classes: (last?.moved.contains(key) ?? false) ? "active" : "tree")
        }
        let height = trees.map(\.height).max() ?? 0

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your operations")) {
                label(.class("field"), .for("splay-text")) {
                    "Keys to insert, ? to look up, a minus sign to remove, / to split and join "
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
                        GraphCanvas(label: "The splay \(trees.count > 1 ? "trees" : "tree") after \(k) operations: \(keys.count) keys, \(height) levels", width: 680, height: drawing.height, nodes: nodes, edges: edges)
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
                                span(.class("num")) { "\(keys.count)" }
                                "keys"
                            }
                            div(.class("good")) {
                                span(.class("num")) { "\(height)" }
                                "levels"
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { shapes.count > 1 ? "At the roots" : "At the root" }
                        p(.class("narration")) { shapes.isEmpty ? "—" : shapes.map { "\($0.root)" }.joined(separator: " and ") }
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
                        Marble(kind: splayMarbleKind(step.operation), radius: step.found ? 10 : 7, letter: "\(step.operation.key)", title: describeSplayStep(step))
                    },
                    legend: [
                        (Marble(kind: "m-blue", radius: 6), "insert"),
                        (Marble(kind: "m-green", radius: 6), "look up"),
                        (Marble(kind: "m-red", radius: 6), "remove"),
                        (Marble(kind: "m-violet", radius: 6), "split, then join"),
                    ])
            }
        }
    }
}

func splayMarbleKind(_ operation: KeyOperation) -> String {
    switch operation {
    case .insert: "m-blue"
    case .access: "m-green"
    case .remove: "m-red"
    case .split, .join: "m-violet"
    }
}

/// An operation as the code panel writes it.
func operationCode(_ operation: KeyOperation) -> String {
    switch operation {
    case .insert(let key): ".insert(\(key))"
    case .remove(let key): ".remove(\(key))"
    case .access(let key): ".access(\(key))"
    case .split(let key): ".split(\(key))"
    case .join(let key): ".join(\(key))"
    }
}

@View
struct SplayCodePanel {
    var body: some View {
        let model = splay
        let list = model.operations.map(operationCode).joined(separator: ", ")
        let root = model.shapes.last?.first.map { "\($0.root)" } ?? "nil"
        CodePanel(
            snippets: [.splayImports, Snippet(lines: ["let operations: [KeyOperation] = [\(list)]"]), .splayRun, .splayShape],
            results: ["\(model.history.last?.first?.height ?? 0)", root])
    }
}

enum SplayPage {
    static func mount() {
        mountView(SplayLab(), in: "app")
        mountView(SplayCodePanel(), in: "code")
    }
}
