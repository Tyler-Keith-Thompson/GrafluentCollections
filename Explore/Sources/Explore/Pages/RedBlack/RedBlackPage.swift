import BinarySearchTrees
import ElementaryUI
import Reactivity
import Trees

/// What one operation did to the tree: the key it touched, whether it found it, the keys whose
/// parent changed (a rotation moved them) and the keys whose colour changed.
struct RedBlackStep {
    var key: Int
    var removes: Bool
    var changed: Bool
    var moved: Set<Int>
    var recoloured: Set<Int>
    var wasEmpty: Bool
}

@Reactive
final class RedBlackModel {
    var text = "10 20 30 15 25 5 1 40 50 -20 -30"
    var operations: [Int] = []
    var history: [RedBlackTree<Int>] = [RedBlackTree()]
    var shapes: [BinaryTree<Int>?] = [nil]
    var reds: [Set<Int>] = [[]]
    var steps: [RedBlackStep] = []
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_000, scrubID: "scrub-redblack")

    init() {
        set(text: text)
    }

    /// Runs the operations in `newText` on a fresh tree and rewinds.
    func set(text newText: String) {
        text = String(newText.prefix(120))
        operations = redBlackOperations(text)
        history = redBlackHistory(operations)
        let drawn = history.map(redBlackShape)
        shapes = drawn.map(\.shape)
        reds = drawn.map(\.red)
        steps = operations.indices.map { i in
            let before = parents(shapes[i]), after = parents(shapes[i + 1])
            let key = abs(operations[i])
            let moved = Set(after.keys.filter { $0 != key && before[$0] != nil && before[$0]! != after[$0]! })
            let kept = Set(before.keys).intersection(after.keys).subtracting([key])
            let recoloured = kept.filter { reds[i].contains($0) != reds[i + 1].contains($0) }
            return RedBlackStep(key: key, removes: operations[i] < 0, changed: history[i].count != history[i + 1].count,
                                moved: moved, recoloured: Set(recoloured), wasEmpty: history[i].isEmpty)
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

    /// Where each key is drawn after `k` operations: across by rank, down by depth.
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

let redBlack = RedBlackModel()

/// The number of black keys on the way down from the root to an empty link: the same on every
/// path, which is what keeps the tree shallow.
func blackHeight(_ shape: BinaryTree<Int>, _ red: Set<Int>) -> Int {
    var count = 0
    var key: Int? = shape.root
    while let current = key {
        if !red.contains(current) { count += 1 }
        key = shape.left(of: current)
    }
    return count
}

func keyList(_ keys: Set<Int>) -> String {
    let sorted = keys.sorted().map(String.init)
    return sorted.count <= 1 ? sorted.joined() : sorted.dropLast().joined(separator: ", ") + " and " + sorted.last!
}

func describeRedBlack(_ step: RedBlackStep) -> String {
    let key = step.key
    var repairs: [String] = []
    if !step.recoloured.isEmpty { repairs.append("\(keyList(step.recoloured)) change colour") }
    if !step.moved.isEmpty { repairs.append("a rotation moves \(keyList(step.moved))") }
    let repair = repairs.isEmpty ? "" : " To repair it, " + repairs.joined(separator: " and ") + "."
    if step.removes {
        guard step.changed else { return "Remove \(key): it is not in the tree, so nothing changes." }
        return repairs.isEmpty
            ? "Remove \(key). Every path still passes the same number of black keys, so nothing else changes."
            : "Remove \(key). Taking it out would leave a path with a black key too few, or a red key under a red one." + repair
    }
    guard step.changed else { return "Insert \(key): it is already there, so nothing changes." }
    if step.wasEmpty { return "Insert \(key) into the empty tree. It becomes the root, and the root is always black." }
    return repairs.isEmpty
        ? "Insert \(key) as a red leaf. Its parent is black, so every rule still holds."
        : "Insert \(key) as a red leaf under a red parent, which breaks the no-two-reds rule." + repair
}

@View
struct RedBlackLab {
    var body: some View {
        let model = redBlack
        let playback = model.playback
        let k = playback.k
        let steps = model.steps
        let last = k > 0 ? steps[k - 1] : nil
        let tree = model.history[k]
        let shape = model.shapes[k]
        let red = model.reds[k]
        let drawing = model.spots(k)
        let keys = shape?.inorder ?? []
        let index = Dictionary(uniqueKeysWithValues: keys.enumerated().map { ($1, $0) })
        let nodes = keys.map { key in
            let spot = drawing.spots[key]!
            let touched = last.map { !$0.removes && $0.key == key } ?? false
            let changed = (last?.moved.contains(key) ?? false) || (last?.recoloured.contains(key) ?? false)
            let colour = red.contains(key) ? "red" : "black"
            return CanvasNode(
                x: spot.x, y: spot.y, name: "", badge: "\(key)", radius: 16,
                classes: colour + (touched || changed ? " selected" : ""))
        }
        let edges: [CanvasEdge] = keys.compactMap { key in
            guard let parent = shape?.parent(of: key) else { return nil }
            return CanvasEdge(from: index[parent]!, to: index[key]!, classes: (last?.moved.contains(key) ?? false) ? "active" : "")
        }

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your operations")) {
                label(.class("field"), .for("redblack-text")) {
                    "Keys to insert, a minus sign to remove "
                    input(.id("redblack-text"), .type(.text), .value(model.text), .custom(name: "maxlength", value: "120"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in redBlack.set(text: event.targetValue ?? "") }
                }
            }
            section(.class("lab"), .custom(name: "aria-label", value: "The red–black tree")) {
                div(.class("panel stage")) {
                    if keys.isEmpty {
                        p(.class("empty")) { k == 0 ? "The tree starts empty. Press Step to run the first operation." : "The tree is empty." }
                    } else {
                        GraphCanvas(label: "The red–black tree after \(k) operations: \(keys.count) keys, \(tree.height) levels", width: 680, height: drawing.height, nodes: nodes, edges: edges)
                    }
                    div(.class("legend")) {
                        span { i(.class("dot red")) {}; "red" }
                        span { i(.class("dot black")) {}; "black" }
                        span { i(.class("dot selected")) {}; "inserted, recoloured or moved by this step" }
                    }
                }
                div(.class("side")) {
                    div(.class("panel"), .custom(name: "aria-live", value: "polite")) {
                        span(.class("label")) { k == steps.count ? "Done after \(steps.count) operations" : "Operation \(k) of \(steps.count)" }
                        p(.class("narration")) {
                            if steps.isEmpty {
                                "Type some keys to insert."
                            } else if let last {
                                describeRedBlack(last)
                            } else {
                                "Every key is red or black. The root is black, a red key never has a red child, and every path down passes the same number of black keys."
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
                            div {
                                span(.class("num")) { "\(shape.map { blackHeight($0, red) } ?? 0)" }
                                "black on each path"
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "Red keys" }
                        p(.class("narration")) { red.isEmpty ? "—" : red.sorted().map(String.init).joined(separator: " ") }
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
                               radius: step.changed ? 10 : 7, letter: "\(step.key)", title: describeRedBlack(step))
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
struct RedBlackCodePanel {
    var body: some View {
        let model = redBlack
        let list = model.operations.map(String.init).joined(separator: ", ")
        let red = model.reds.last ?? []
        CodePanel(
            snippets: [.redblackImports, Snippet(lines: ["let operations = [\(list)]  // negative: remove"]), .redblackRun, .redblackShape],
            results: ["\(model.history.last?.height ?? 0)", "\(red.sorted())"])
    }
}

enum RedBlackPage {
    static func mount() {
        mountView(RedBlackLab(), in: "app")
        mountView(RedBlackCodePanel(), in: "code")
    }
}
