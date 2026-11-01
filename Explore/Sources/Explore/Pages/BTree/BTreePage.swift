import BTrees
import ElementaryUI
import Reactivity
import Trees

/// What one operation did to the table: the key it touched, whether it found it, how the node
/// count and height changed, whether the key sat in an inner node, and the keys that moved up
/// or down a level.
struct BTreeStep {
    var key: Int
    var removes: Bool
    var changed: Bool
    var nodesBefore: Int
    var nodesAfter: Int
    var heightBefore: Int
    var heightAfter: Int
    var wasInner: Bool
    var movedUp: Set<Int>
    var movedDown: Set<Int>
}

/// One node of the drawing: its keys and where its box goes.
struct BTreeBox {
    var keys: [Int]
    var x: Double
    var y: Double
    var width: Double
}

/// One line of the drawing, from a gap in a parent's box down to the top of a child's.
struct BTreeLink {
    var x1: Double
    var y1: Double
    var x2: Double
    var y2: Double
}

/// The width of one key's cell in a node's box, and the box's padding at each end.
let bTreeCell = 30.0
let bTreePad = 6.0

/// The depth of each key: 0 for a key in the root.
func bTreeLevels(_ shape: RootedTree<[Int]>?) -> [Int: Int] {
    guard let shape else { return [:] }
    var levels: [Int: Int] = [:]
    for node in shape.preorder {
        for key in node { levels[key] = shape.depth(of: node) }
    }
    return levels
}

/// Where every node goes: leaves left to right in key order, each parent centred over its
/// children, one row per level.
func bTreeLayout(_ shape: RootedTree<[Int]>?) -> (boxes: [BTreeBox], links: [BTreeLink], width: Double, height: Double) {
    guard let shape else { return ([], [], 680, 120) }
    var centres: [[Int]: Double] = [:]
    var next = 10.0
    for node in shape.postorder {
        let width = Double(node.count) * bTreeCell + 2 * bTreePad
        let children = shape.children(of: node)
        if children.isEmpty {
            centres[node] = next + width / 2
            next += width + 16
        } else {
            centres[node] = (centres[children.first!]! + centres[children.last!]!) / 2
        }
    }
    let total = max(680, next - 6)
    let shift = (total - (next - 6)) / 2
    var boxes: [BTreeBox] = []
    var links: [BTreeLink] = []
    for node in shape.preorder {
        let width = Double(node.count) * bTreeCell + 2 * bTreePad
        let x = centres[node]! + shift - width / 2
        let y = 20 + 80 * Double(shape.depth(of: node))
        boxes.append(BTreeBox(keys: node, x: x, y: y, width: width))
        for (j, child) in shape.children(of: node).enumerated() {
            links.append(BTreeLink(x1: x + bTreePad + bTreeCell * Double(j), y1: y + 30, x2: centres[child]! + shift, y2: y + 80))
        }
    }
    return (boxes, links, total, 20 + 80 * Double(shape.height) + 50)
}

@Reactive
final class BTreeModel {
    var text = "10 20 30 40 50 60 70 25 35 45 55 65 5 15 75 80 -40 -45 -50 -35 -30 -25 -20"
    var operations: [Int] = []
    var history: [BTreeDictionary<Int, Row>] = [BTreeDictionary()]
    var shapes: [RootedTree<[Int]>?] = [nil]
    var steps: [BTreeStep] = []
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_000, scrubID: "scrub-btree")

    init() {
        set(text: text)
    }

    /// Runs the operations in `newText` on a fresh table and rewinds.
    func set(text newText: String) {
        text = String(newText.prefix(120))
        operations = bTreeOperations(text)
        history = bTreeHistory(operations)
        shapes = history.map(bTreeShape)
        steps = operations.indices.map { i in
            let before = bTreeLevels(shapes[i]), after = bTreeLevels(shapes[i + 1])
            let key = abs(operations[i])
            let kept = Set(before.keys).intersection(after.keys).subtracting([key])
            // A key whose depth fell while the tree kept its height moved up; one whose depth grew
            // while the height kept moved down. When the height changes every key shifts by one,
            // so compare against that shift.
            let shift = (shapes[i + 1]?.height ?? 0) - (shapes[i]?.height ?? 0)
            let up = kept.filter { after[$0]! < before[$0]! + shift }
            let down = kept.filter { after[$0]! > before[$0]! + shift }
            let height = shapes[i]?.height ?? 0
            return BTreeStep(
                key: key, removes: operations[i] < 0, changed: history[i].count != history[i + 1].count,
                nodesBefore: shapes[i]?.vertexCount ?? 0, nodesAfter: shapes[i + 1]?.vertexCount ?? 0,
                heightBefore: shapes[i]?.height ?? 0, heightAfter: shapes[i + 1]?.height ?? 0,
                wasInner: before[key].map { $0 < height } ?? false, movedUp: Set(up), movedDown: Set(down))
        }
        playback.reset(count: steps.count)
    }
}

let bTree = BTreeModel()

func describeBTree(_ step: BTreeStep) -> String {
    let key = step.key
    if step.removes {
        guard step.changed else { return "Remove \(key): it is not in the table, so nothing changes." }
        let neighbour = step.movedUp.contains { $0 > key } ? "the key just after it" : "the key just before it"
        var text = step.wasInner
            ? "Remove \(key). It sits in an inner node, so \(step.movedUp.isEmpty ? neighbour : "\(keyList(step.movedUp)), \(neighbour),") comes up from a leaf to take its place."
            : "Remove \(key) from its leaf."
        let merges = step.nodesBefore - step.nodesAfter
        if merges > 0 {
            text += " That leaves a node under 3 keys with no sibling to spare one, so it merges with a sibling and the key between them comes down from the parent"
            text += step.heightAfter < step.heightBefore ? ". The root is left empty, so the tree loses a level." : "."
        } else if !step.movedDown.isEmpty {
            text += " That leaves a node under 3 keys, so it borrows through the parent: \(keyList(step.movedDown)) comes down and \(keyList(step.movedUp)) goes up."
        } else if !step.wasInner {
            text += " The leaf still holds at least 3 keys, so nothing else moves."
        }
        return text
    }
    guard step.changed else { return "Insert \(key): it is already there, so its row is replaced and nothing moves." }
    if step.nodesBefore == 0 { return "Insert \(key) into the empty table: one node, the root, holding one key." }
    let splits = step.nodesAfter - step.nodesBefore
    guard splits > 0 else { return "Insert \(key) into its leaf, which has room: a node holds up to 7 keys." }
    let promoted = step.movedUp.isEmpty ? "" : " \(keyList(step.movedUp)) moves up into the parent."
    if step.heightBefore == 0 {
        return "Insert \(key). The root is the only node and it is full at 7 keys, so it splits into two nodes of 3 around its middle key, \(keyList(step.movedUp)), which becomes a new root above them: the tree gains a level."
    }
    if step.heightAfter > step.heightBefore {
        return "Insert \(key). Its leaf is full, so it splits in two around its middle key, and the splits run up to the root, which splits too: the tree gains a level at the top." + promoted
    }
    let cascade = splits > 1 ? " Its parent was full too, so the parent splits as well." : ""
    return "Insert \(key). Its leaf is full at 7 keys, so it splits into two nodes of 3 around its middle key." + cascade + promoted
}

@View
struct BTreeCanvas {
    var label: String
    var boxes: [BTreeBox]
    var links: [BTreeLink]
    var width: Double
    var height: Double
    var current: Int?
    var moved: Set<Int>

    var body: some View {
        SVG.svg(.class("canvas btree"), .viewBox(0, 0, .init(width), .init(height)), .custom(name: "role", value: "img"), .custom(name: "aria-label", value: label)) {
            for link in links {
                SVG.line(.x1(.init(link.x1)), .y1(.init(link.y1)), .x2(.init(link.x2)), .y2(.init(link.y2)), .class("blink")) {}
            }
            for box in boxes {
                SVG.g(.class("bnode")) {
                    SVG.rect(.x(.init(box.x)), .y(.init(box.y)), .width(.init(box.width)), .height(30), .rx(6), .class("box")) {}
                    for (i, key) in box.keys.enumerated() {
                        let x = box.x + bTreePad + bTreeCell * (Double(i) + 0.5)
                        if i > 0 {
                            SVG.line(.x1(.init(x - bTreeCell / 2)), .y1(.init(box.y + 6)), .x2(.init(x - bTreeCell / 2)), .y2(.init(box.y + 24)), .class("divider")) {}
                        }
                        SVG.text(.x(.init(x)), .y(.init(box.y + 20)), .textAnchor("middle"),
                                 .class(key == current ? "bkey current" : moved.contains(key) ? "bkey selected" : "bkey")) { "\(key)" }
                    }
                }
            }
        }
    }
}

@View
struct BTreeLab {
    var body: some View {
        let model = bTree
        let playback = model.playback
        let k = playback.k
        let steps = model.steps
        let last = k > 0 ? steps[k - 1] : nil
        let table = model.history[k]
        let shape = model.shapes[k]
        let drawing = bTreeLayout(shape)
        let current = last.flatMap { $0.removes ? nil : $0.key }
        let moved = (last?.movedUp ?? []).union(last?.movedDown ?? [])

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your operations")) {
                label(.class("field"), .for("btree-text")) {
                    "Keys to insert, a minus sign to remove "
                    input(.id("btree-text"), .type(.text), .value(model.text), .custom(name: "maxlength", value: "120"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in bTree.set(text: event.targetValue ?? "") }
                }
            }
            section(.class("lab"), .custom(name: "aria-label", value: "The B-tree")) {
                div(.class("panel stage")) {
                    if shape == nil {
                        p(.class("empty")) { k == 0 ? "The table starts empty. Press Step to run the first operation." : "The table is empty." }
                    } else {
                        BTreeCanvas(label: "The B-tree after \(k) operations: \(table.count) keys in \(shape?.vertexCount ?? 0) nodes, \(table.height) levels",
                                    boxes: drawing.boxes, links: drawing.links, width: drawing.width, height: drawing.height, current: current, moved: moved)
                    }
                    div(.class("legend")) {
                        span { i(.class("dot current")) {}; "just inserted" }
                        span { i(.class("dot selected")) {}; "moved up or down a level by this step" }
                    }
                }
                div(.class("side")) {
                    div(.class("panel"), .custom(name: "aria-live", value: "polite")) {
                        span(.class("label")) { k == steps.count ? "Done after \(steps.count) operations" : "Operation \(k) of \(steps.count)" }
                        p(.class("narration")) {
                            if steps.isEmpty {
                                "Type some keys to insert."
                            } else if let last {
                                describeBTree(last)
                            } else {
                                "Every node holds 3 to 7 keys in order (the root may hold fewer), and every leaf is at the same depth. A node with k keys has k + 1 children, one for each gap between its keys."
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "The table" }
                        div(.class("stat")) {
                            div {
                                span(.class("num")) { "\(table.count)" }
                                "keys"
                            }
                            div {
                                span(.class("num")) { "\(shape?.vertexCount ?? 0)" }
                                "nodes"
                            }
                            div(.class("good")) {
                                span(.class("num")) { "\(table.height)" }
                                "levels"
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
                        Marble(kind: step.removes ? "m-red" : step.nodesAfter > step.nodesBefore && step.nodesBefore > 0 ? "m-violet" : "m-blue",
                               radius: step.changed ? 10 : 7, letter: "\(step.key)", title: describeBTree(step))
                    },
                    legend: [
                        (Marble(kind: "m-blue", radius: 6), "insert"),
                        (Marble(kind: "m-violet", radius: 6), "insert with a split"),
                        (Marble(kind: "m-red", radius: 6), "remove"),
                    ])
            }
        }
    }
}

@View
struct BTreeCodePanel {
    var body: some View {
        let model = bTree
        let list = model.operations.map(String.init).joined(separator: ", ")
        let root = model.shapes.last.flatMap { $0 }.map { "\($0.root)" } ?? "nil"
        CodePanel(
            snippets: [.btreeImports, .btreeRow, Snippet(lines: ["let operations = [\(list)]  // negative: remove"]), .btreeRun, .btreeShape],
            results: ["\(model.history.last?.height ?? 0)", root])
    }
}

enum BTreePage {
    static func mount() {
        mountView(BTreeLab(), in: "app")
        mountView(BTreeCodePanel(), in: "code")
    }
}
