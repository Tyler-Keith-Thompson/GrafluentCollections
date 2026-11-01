import BinarySearchTrees
import ElementaryUI
import Reactivity
import Trees

/// What one operation did to the tree: the key it touched, whether it found it, and the keys
/// whose parent changed, which a rotation (or, for a removal, the successor taking the removed
/// key's place) moved.
struct AVLStep {
    /// The key inserted or removed.
    var key: Int
    var removes: Bool
    var changed: Bool
    var moved: Set<Int>
}

/// Where each key of a shape is drawn: across by its rank in key order, down by its depth.
struct AVLDrawing {
    var spots: [Int: (x: Double, y: Double)] = [:]
    var height = 120
}

@Reactive
final class AVLModel {
    var text = "30 20 10 40 50 25 27 5 -40 -50"
    var operations: [Int] = []
    var history: [AVLTree<Int>] = [AVLTree()]
    var shapes: [BinaryTree<Int>?] = [nil]
    var steps: [AVLStep] = []
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_000, scrubID: "scrub-avl")

    init() {
        set(text: text)
    }

    /// Runs the operations in `newText` on a fresh tree and rewinds.
    func set(text newText: String) {
        text = String(newText.prefix(120))
        operations = avlOperations(text)
        history = avlHistory(operations)
        shapes = history.map(avlShape)
        steps = operations.indices.map { i in
            let before = parents(shapes[i]), after = parents(shapes[i + 1])
            let key = abs(operations[i])
            let moved = Set(after.keys.filter { $0 != key && before[$0] != nil && before[$0]! != after[$0]! })
            return AVLStep(key: key, removes: operations[i] < 0, changed: history[i].count != history[i + 1].count, moved: moved)
        }
        playback.reset(count: steps.count)
    }

    /// Each key's parent (nil for the root), or nothing for an empty tree.
    func parents(_ shape: BinaryTree<Int>?) -> [Int: Int?] {
        guard let shape else { return [:] }
        var out: [Int: Int?] = [:]
        for key in shape.inorder { out[key] = shape.parent(of: key) }
        return out
    }

    /// The drawing of the tree after `k` operations.
    func drawing(_ k: Int) -> AVLDrawing {
        guard let shape = shapes[k] else { return AVLDrawing() }
        let keys = shape.inorder
        let gap = min(56.0, 640.0 / Double(max(keys.count, 1)))
        var drawing = AVLDrawing()
        for (rank, key) in keys.enumerated() {
            drawing.spots[key] = (340 - gap * Double(keys.count - 1) / 2 + gap * Double(rank), 34 + 70 * Double(shape.depth(of: key)))
        }
        drawing.height = 34 + 70 * shape.height + 60
        return drawing
    }
}

let avl = AVLModel()

/// The height of `key`'s subtree in `shape`, in vertices: 0 for no subtree.
func subtreeHeight(_ key: Int?, _ shape: BinaryTree<Int>) -> Int {
    guard let key else { return 0 }
    return 1 + max(subtreeHeight(shape.left(of: key), shape), subtreeHeight(shape.right(of: key), shape))
}

/// `+1`, `0` or `−1`: the right subtree's height less the left's.
func balanceText(_ key: Int, _ shape: BinaryTree<Int>) -> String {
    let balance = subtreeHeight(shape.right(of: key), shape) - subtreeHeight(shape.left(of: key), shape)
    return balance > 0 ? "+\(balance)" : balance < 0 ? "−\(-balance)" : "0"
}

func describeAVL(_ step: AVLStep) -> String {
    let key = step.key
    if step.removes {
        guard step.changed else { return "Remove \(key): it is not in the tree, so nothing changes." }
        return step.moved.isEmpty
            ? "Remove \(key). Every subtree on the way back up is still balanced, so nothing rotates."
            : "Remove \(key). On the way back up a subtree leans by two, so it rotates; \(movedList(step)) move."
    }
    guard step.changed else { return "Insert \(key): it is already there, so nothing changes." }
    return step.moved.isEmpty
        ? "Insert \(key) as a new leaf. Every subtree on the way back up still differs by at most one."
        : "Insert \(key) as a new leaf. A subtree above it now leans by two, so it rotates; \(movedList(step)) move."
}

func movedList(_ step: AVLStep) -> String {
    let keys = step.moved.sorted().map(String.init)
    return keys.count <= 1 ? keys.joined() : keys.dropLast().joined(separator: ", ") + " and " + keys.last!
}

@View
struct AVLLab {
    var body: some View {
        let model = avl
        let playback = model.playback
        let k = playback.k
        let steps = model.steps
        let last = k > 0 ? steps[k - 1] : nil
        let tree = model.history[k]
        let shape = model.shapes[k]
        let drawing = model.drawing(k)
        let keys = shape?.inorder ?? []
        let index = Dictionary(uniqueKeysWithValues: keys.enumerated().map { ($1, $0) })
        let nodes = keys.map { key in
            let spot = drawing.spots[key]!
            let touched = last.map { !$0.removes && $0.key == key } ?? false
            return CanvasNode(
                x: spot.x, y: spot.y, name: "", badge: "\(key)", note: balanceText(key, shape!), radius: 16,
                classes: touched ? "current" : (last?.moved.contains(key) ?? false) ? "selected" : "")
        }
        let edges: [CanvasEdge] = keys.compactMap { key in
            guard let parent = shape?.parent(of: key) else { return nil }
            return CanvasEdge(from: index[parent]!, to: index[key]!, classes: (last?.moved.contains(key) ?? false) ? "active" : "tree")
        }

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your operations")) {
                label(.class("field"), .for("avl-text")) {
                    "Keys to insert, a minus sign to remove "
                    input(.id("avl-text"), .type(.text), .value(model.text), .custom(name: "maxlength", value: "120"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in avl.set(text: event.targetValue ?? "") }
                }
            }
            section(.class("lab"), .custom(name: "aria-label", value: "The AVL tree")) {
                div(.class("panel stage")) {
                    if keys.isEmpty {
                        p(.class("empty")) { k == 0 ? "The tree starts empty. Press Step to run the first operation." : "The tree is empty." }
                    } else {
                        GraphCanvas(label: "The AVL tree after \(k) operations: \(keys.count) keys, \(tree.height) levels", width: 680, height: drawing.height, nodes: nodes, edges: edges)
                    }
                    div(.class("legend")) {
                        span { i(.class("dot current")) {}; "just inserted" }
                        span { i(.class("dot selected")) {}; "moved by this step" }
                        span { "under each key: right height − left height" }
                    }
                }
                div(.class("side")) {
                    div(.class("panel"), .custom(name: "aria-live", value: "polite")) {
                        span(.class("label")) { k == steps.count ? "Done after \(steps.count) operations" : "Operation \(k) of \(steps.count)" }
                        p(.class("narration")) {
                            if steps.isEmpty {
                                "Type some keys to insert."
                            } else if let last {
                                describeAVL(last)
                            } else {
                                "Each insert walks down to a leaf as in any search tree. On the way back up, each vertex checks that its two subtrees differ in height by at most one, and rotates when they differ by two."
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
                        span(.class("label")) { "In order" }
                        p(.class("narration")) { keys.isEmpty ? "—" : keys.map(String.init).joined(separator: " ") }
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
                        Marble(kind: step.removes ? "m-red" : step.moved.isEmpty ? "m-blue" : "m-violet",
                               radius: step.changed ? 10 : 7, letter: "\(step.key)", title: describeAVL(step))
                    },
                    legend: [
                        (Marble(kind: "m-blue", radius: 6), "insert"),
                        (Marble(kind: "m-violet", radius: 6), "insert with a rotation"),
                        (Marble(kind: "m-red", radius: 6), "remove"),
                    ])
            }
        }
    }
}

@View
struct AVLCodePanel {
    var body: some View {
        let model = avl
        let shape = model.shapes.last ?? nil
        let list = model.operations.map(String.init).joined(separator: ", ")
        CodePanel(
            snippets: [.avlImports, Snippet(lines: ["let operations = [\(list)]  // negative: remove"]), .avlRun, .avlShape],
            results: ["\(model.history.last?.height ?? 0)", shape.map { "\($0.inorder)" } ?? "nil"])
    }
}

enum AVLPage {
    static func mount() {
        mountView(AVLLab(), in: "app")
        mountView(AVLCodePanel(), in: "code")
    }
}
