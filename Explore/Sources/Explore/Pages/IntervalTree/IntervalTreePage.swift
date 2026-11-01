import ElementaryUI
import RangeTrees
import Reactivity
import Trees

/// The largest upper bound in each vertex's subtree: what the tree records beside each interval.
func intervalSubtreeMaximums(_ shape: BinaryTree<Int>, _ tree: IntervalTree<Int, Int>) -> [Int: Int] {
    var maximums: [Int: Int] = [:]
    func walk(_ vertex: Int) -> Int {
        var largest = tree[vertex].range.upperBound
        if let left = shape.left(of: vertex) { largest = max(largest, walk(left)) }
        if let right = shape.right(of: vertex) { largest = max(largest, walk(right)) }
        maximums[vertex] = largest
        return largest
    }
    _ = walk(shape.root)
    return maximums
}

/// The vertices a search for intervals overlapping `range` visits, and the subtrees it skips:
/// one whose largest upper bound is at most the range's start ends before it, and the right
/// subtree of a vertex whose interval starts at or after the range's end starts after it.
func intervalSearch(_ range: Range<Int>, _ shape: BinaryTree<Int>, _ tree: IntervalTree<Int, Int>, _ maximums: [Int: Int]) -> (visited: [Int], pruned: [Int]) {
    var visited: [Int] = []
    var pruned: [Int] = []
    func search(_ vertex: Int?) {
        guard let vertex else { return }
        guard maximums[vertex]! > range.lowerBound else {
            pruned.append(vertex)
            return
        }
        visited.append(vertex)
        search(shape.left(of: vertex))
        if tree[vertex].range.lowerBound < range.upperBound {
            search(shape.right(of: vertex))
        } else if let right = shape.right(of: vertex) {
            pruned.append(right)
        }
    }
    search(shape.root)
    return (visited, pruned)
}

/// "[10, 30)".
func intervalText(_ range: Range<Int>) -> String { "[\(range.lowerBound), \(range.upperBound))" }

/// What one operation did: the operation, whether it changed the tree, the vertices a query
/// visited and the subtrees it skipped, and the in-order positions of the entries it found.
struct IntervalStep {
    var operation: IntervalOperation
    var changed: Bool
    var visited: [Int]
    var pruned: [Int]
    var found: [Int]
}

@Reactive
final class IntervalTreeModel {
    var text = "10-30 5-12 25-40 45-60 50-55 2-8 33-36 58-70 62-90 ?27 ?34-48 ?80 -25-40 ?27"
    var operations: [IntervalOperation] = []
    var history: [IntervalTree<Int, Int>] = [IntervalTree()]
    var shapes: [BinaryTree<Int>?] = [nil]
    var maximums: [[Int: Int]] = [[:]]
    var steps: [IntervalStep] = []
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_100, scrubID: "scrub-intervaltree")

    init() {
        set(text: text)
    }

    func set(text newText: String) {
        text = String(newText.prefix(160))
        operations = intervalOperations(text)
        let run = intervalHistory(operations)
        history = run.trees
        shapes = history.map(intervalShape)
        maximums = history.indices.map { i in shapes[i].map { intervalSubtreeMaximums($0, history[i]) } ?? [:] }
        steps = operations.indices.map { i in
            let operation = operations[i]
            let tree = history[i + 1]
            var search: (visited: [Int], pruned: [Int]) = ([], [])
            if operation.isQuery, let shape = shapes[i + 1] {
                search = intervalSearch(operation.range, shape, tree, maximums[i + 1])
            }
            let wanted = Set(run.found[i])
            let found = tree.indices.filter { wanted.contains(tree[$0].value) }
            return IntervalStep(operation: operation, changed: history[i].count != tree.count, visited: search.visited, pruned: search.pruned, found: found)
        }
        playback.reset(count: steps.count)
    }
}

let intervalTree = IntervalTreeModel()

func describeInterval(_ step: IntervalStep, _ tree: IntervalTree<Int, Int>) -> String {
    let found = step.found.map { intervalText(tree[$0].range) }
    let list = found.isEmpty ? "none" : found.joined(separator: ", ")
    let skipped = step.pruned.isEmpty ? "" : " It skipped \(step.pruned.count) \(step.pruned.count == 1 ? "subtree" : "subtrees") without looking inside: a subtree whose largest end is at or before the query’s start holds nothing that reaches it, and everything right of an interval starting at or after the query’s end starts too late."
    switch step.operation {
    case .insert(let range):
        return "Insert \(intervalText(range)). It goes where its start puts it in order, the tree rebalances like an AVL tree, and every vertex on the way up updates the largest end in its subtree."
    case .remove(let range):
        guard step.changed else { return "Remove \(intervalText(range)): it is not in the tree, so nothing changes." }
        return "Remove \(intervalText(range)). The vertices above it update the largest end in their subtrees."
    case .containing(let point):
        return "Which intervals contain \(point)? The search visited \(step.visited.count) of \(tree.count) vertices and found \(list).\(skipped)"
    case .overlapping(let range):
        return "Which intervals overlap \(intervalText(range))? The search visited \(step.visited.count) of \(tree.count) vertices and found \(list).\(skipped)"
    }
}

func intervalMarbleKind(_ operation: IntervalOperation) -> String {
    switch operation {
    case .insert: "m-blue"
    case .remove: "m-red"
    case .containing, .overlapping: "m-green"
    }
}

/// The tree's vertices, by in-order position across and depth down, each showing its interval
/// and its subtree's largest end; the links, those into a skipped subtree faint.
func intervalDrawing(_ shape: BinaryTree<Int>?, _ tree: IntervalTree<Int, Int>, _ maximums: [Int: Int], step: IntervalStep?) -> (nodes: [CanvasNode], edges: [CanvasEdge], height: Int) {
    guard let shape else { return ([], [], 120) }
    let count = tree.count
    let gap = min(60.0, 640.0 / Double(max(count, 1)))
    let visited = Set(step?.visited ?? []), found = Set(step?.found ?? [])
    // Every vertex of a skipped subtree, not only its top.
    var pruned: Set<Int> = []
    var stack = step?.pruned ?? []
    while let vertex = stack.popLast() {
        pruned.insert(vertex)
        stack += [shape.left(of: vertex), shape.right(of: vertex)].compactMap { $0 }
    }
    let inserted: Int? = if case .insert(let range) = step?.operation { tree.indices.last { tree[$0].range == range } } else { nil }
    let nodes = (0 ..< count).map { vertex in
        let state = found.contains(vertex) || vertex == inserted ? " current" : visited.contains(vertex) ? " selected" : pruned.contains(vertex) ? " dim" : ""
        let range = tree[vertex].range
        return CanvasNode(x: 340 - gap * Double(count - 1) / 2 + gap * Double(vertex), y: 34 + 72 * Double(shape.depth(of: vertex)),
                          name: "\(range.lowerBound)–\(range.upperBound)", badge: "\(maximums[vertex] ?? 0)", radius: 15, classes: state)
    }
    let edges = (0 ..< count).compactMap { vertex in
        shape.parent(of: vertex).map { parent in
            CanvasEdge(from: parent, to: vertex, classes: visited.contains(vertex) ? "active" : pruned.contains(vertex) ? "faint" : "")
        }
    }
    return (nodes, edges, 34 + 72 * shape.height + 50)
}

/// The intervals on a number line from 0 to 100, one row each in order, with the query's range
/// as a band; those found marked.
@View
struct IntervalBars {
    var tree: IntervalTree<Int, Int>
    var query: Range<Int>?
    var found: Set<Int>

    var body: some View {
        let scale = 620.0 / 100
        let rows = tree.count
        let height = 40 + 16 * rows
        SVG.svg(.class("canvas bars"), .viewBox(0, 0, 680, .init(height)), .custom(name: "role", value: "img"), .custom(name: "aria-label", value: "The intervals on a number line from 0 to 100")) {
            if let query {
                SVG.rect(.x(.init(30 + scale * Double(query.lowerBound))), .y(4), .width(.init(max(scale * Double(query.count), 3))), .height(.init(height - 30)), .class("band")) {}
            }
            for row in 0 ..< rows {
                let range = tree[row].range
                SVG.rect(.x(.init(30 + scale * Double(range.lowerBound))), .y(.init(10 + 16 * row)), .width(.init(scale * Double(range.count))), .height(10), .rx(3),
                         .class(found.contains(row) ? "bar found" : "bar")) {}
            }
            SVG.line(.x1(30), .y1(.init(height - 22)), .x2(650), .y2(.init(height - 22)), .class("axis")) {}
            for tick in stride(from: 0, through: 100, by: 10) {
                SVG.text(.x(.init(30 + scale * Double(tick))), .y(.init(height - 6)), .textAnchor("middle"), .class("tick")) { "\(tick)" }
            }
        }
    }
}

@View
struct IntervalTreeLab {
    var body: some View {
        let model = intervalTree
        let playback = model.playback
        let k = playback.k
        let steps = model.steps
        let last = k > 0 ? steps[k - 1] : nil
        let tree = model.history[k]
        let drawing = intervalDrawing(model.shapes[k], tree, model.maximums[k], step: last)
        let query = last.flatMap { $0.operation.isQuery ? $0.operation.range : nil }

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your operations")) {
                label(.class("field"), .for("intervaltree-text")) {
                    "a-b to insert, -a-b to remove, ?p for the intervals containing p, ?a-b for those overlapping "
                    input(.id("intervaltree-text"), .type(.text), .value(model.text), .custom(name: "maxlength", value: "160"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in intervalTree.set(text: event.targetValue ?? "") }
                }
            }
            section(.class("lab"), .custom(name: "aria-label", value: "The interval tree")) {
                div(.class("panel stage")) {
                    if tree.isEmpty {
                        p(.class("empty")) { k == 0 ? "The tree starts empty. Press Step to run the first operation." : "The tree is empty." }
                    } else {
                        GraphCanvas(label: "The interval tree after \(k) operations: \(tree.count) intervals", width: 680, height: drawing.height, nodes: drawing.nodes, edges: drawing.edges)
                        IntervalBars(tree: tree, query: query, found: Set(last?.found ?? []))
                    }
                    div(.class("legend")) {
                        span { i(.class("dot selected")) {}; "visited by the search" }
                        span { i(.class("dot current")) {}; "found, or just inserted" }
                    }
                    p(.class("legend")) { "In each circle the largest end in that vertex’s subtree; under it the vertex’s own interval. Below, the intervals in the same order, with the query shaded." }
                }
                div(.class("side")) {
                    div(.class("panel"), .custom(name: "aria-live", value: "polite")) {
                        span(.class("label")) { k == steps.count ? "Done after \(steps.count) operations" : "Operation \(k) of \(steps.count)" }
                        p(.class("narration")) {
                            if steps.isEmpty {
                                "Type an interval to insert, such as 10-30."
                            } else if let last {
                                describeInterval(last, tree)
                            } else {
                                "The intervals are kept in a balanced search tree ordered by where they start. Each vertex also records the largest end anywhere in its subtree, which is what lets a search skip whole subtrees."
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "The tree" }
                        div(.class("stat")) {
                            div {
                                span(.class("num")) { "\(tree.count)" }
                                "intervals"
                            }
                            div(.class("good")) {
                                span(.class("num")) { "\(last?.visited.count ?? 0)" }
                                "vertices visited"
                            }
                            div {
                                span(.class("num")) { "\(last?.found.count ?? 0)" }
                                "found"
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
                    marbles: steps.indices.map { i in
                        Marble(kind: intervalMarbleKind(steps[i].operation), radius: steps[i].operation.isQuery ? 9 : 7, letter: "\(steps[i].operation.range.lowerBound)", title: describeInterval(steps[i], model.history[i + 1]))
                    },
                    legend: [
                        (Marble(kind: "m-blue", radius: 6), "insert"),
                        (Marble(kind: "m-green", radius: 6), "query"),
                        (Marble(kind: "m-red", radius: 6), "remove"),
                    ])
            }
        }
    }
}

/// Swift source for an operation, as the code panel's `operations` binding spells it.
func intervalOperationCode(_ operation: IntervalOperation) -> String {
    switch operation {
    case .insert(let range): ".insert(\(range.lowerBound) ..< \(range.upperBound))"
    case .remove(let range): ".remove(\(range.lowerBound) ..< \(range.upperBound))"
    case .containing(let point): ".containing(\(point))"
    case .overlapping(let range): ".overlapping(\(range.lowerBound) ..< \(range.upperBound))"
    }
}

@View
struct IntervalTreeCodePanel {
    var body: some View {
        let model = intervalTree
        let height = model.shapes.last.flatMap { $0?.height }.map { "\($0)" } ?? "nil"
        CodePanel(
            snippets: [
                .intervaltreeImports,
                Snippet(lines: ["let operations: [IntervalOperation] = [\(model.operations.map(intervalOperationCode).joined(separator: ", "))]"]),
                .intervaltreeRun, .intervaltreeShape,
            ],
            results: ["\(model.history.last?.count ?? 0)", height])
    }
}

enum IntervalTreePage {
    static func mount() {
        mountView(IntervalTreeLab(), in: "app")
        mountView(IntervalTreeCodePanel(), in: "code")
    }
}
