import ElementaryUI
import RangeTrees
import Reactivity

/// Cell `cell`'s depth, its place along its level, and the values it spans, in a perfect tree
/// over `leaves` leaves numbered in level order from the root, cell 0.
func segmentCell(_ cell: Int, leaves: Int) -> (depth: Int, column: Int, range: Range<Int>) {
    let depth = Int.bitWidth - 1 - (cell + 1).leadingZeroBitCount
    let column = cell + 1 - (1 << depth)
    let width = leaves >> depth
    return (depth, column, column * width ..< (column + 1) * width)
}

/// The cells a range operation splits `range` into, those wholly inside it, and the cells it
/// passes through on the way down to them, those that straddle an end.
func segmentCover(_ range: Range<Int>, children: [Int: (left: Int?, right: Int?)], leaves: Int) -> (covered: [Int], passed: [Int]) {
    var covered: [Int] = []
    var passed: [Int] = []
    var stack = children.isEmpty ? [] : [0]
    while let cell = stack.popLast() {
        let span = segmentCell(cell, leaves: leaves).range
        guard span.overlaps(range) else { continue }
        if range.lowerBound <= span.lowerBound && span.upperBound <= range.upperBound {
            covered.append(cell)
        } else {
            passed.append(cell)
            if let right = children[cell]?.right { stack.append(right) }
            if let left = children[cell]?.left { stack.append(left) }
        }
    }
    return (covered, passed)
}

/// "4–7", or "5" for one value.
func segmentRangeText(_ range: Range<Int>) -> String {
    range.count == 1 ? "\(range.lowerBound)" : "\(range.lowerBound)–\(range.upperBound - 1)"
}

/// What one operation did: the operation, the cells it covered and passed, and a query's
/// answers.
struct SegmentStep {
    var operation: SegmentOperation
    var covered: [Int]
    var passed: [Int]
    var answer: (sum: Int, minimum: Int)?
}

@Reactive
final class SegmentTreeModel {
    var valuesText = "5 2 8 6 3 7 1 4 9 2 6 5"
    var text = "?2-9 ?0-11 +3@4-7 ?2-9 ?6 -6@1-10 ?0-11"
    var values: [Int] = []
    var operations: [SegmentOperation] = []
    var sums: [LazySegmentTree<AddToSum>] = [LazySegmentTree()]
    var minimums: [LazySegmentTree<AddToMinimum>] = [LazySegmentTree()]
    var children: [Int: (left: Int?, right: Int?)] = [:]
    var leaves = 0
    var steps: [SegmentStep] = []
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_200, scrubID: "scrub-segmenttree")

    init() {
        run()
    }

    func set(values newText: String) {
        valuesText = String(newText.prefix(80))
        run()
    }

    func set(text newText: String) {
        text = String(newText.prefix(120))
        run()
    }

    func run() {
        values = fenwickValues(valuesText)
        operations = segmentOperations(text, count: values.count)
        let run = segmentHistory(values, operations)
        sums = run.sums
        minimums = run.minimums
        children = segmentShape(sums[0])
        leaves = (children.count + 1) / 2
        steps = operations.indices.map { i in
            let cover = segmentCover(operations[i].range, children: children, leaves: leaves)
            return SegmentStep(operation: operations[i], covered: cover.covered, passed: cover.passed, answer: run.answers[i])
        }
        playback.reset(count: steps.count)
    }
}

let segmentTree = SegmentTreeModel()

func describeSegment(_ step: SegmentStep, leaves: Int) -> String {
    let range = step.operation.range
    let pieces = step.covered.map { segmentRangeText(segmentCell($0, leaves: leaves).range) }
    let list = pieces.count == 1 ? pieces[0] : pieces.dropLast().joined(separator: ", ") + " and " + pieces.last!
    let cells = step.covered.count == 1 ? "1 cell whose span fits inside it" : "\(step.covered.count) cells whose spans fit inside it"
    let their = step.covered.count == 1 ? "its total" : "their totals"
    guard let amount = step.operation.amount else {
        let answer = step.answer.map { "sum \($0.sum), smallest \($0.minimum)" } ?? ""
        return "Query \(segmentRangeText(range)): it splits into \(cells), \(list), and reads \(their): \(answer). The \(step.passed.count) cells it passed through straddle an end of the range, so it looks below them."
    }
    let verb = amount < 0 ? "Subtract \(-amount) from" : "Add \(amount) to"
    return "\(verb) every value in \(segmentRangeText(range)): the range splits into \(cells), \(list). Each takes the change in its total at once and keeps it pending for the cells below it, which catch up only when a later operation passes through. A sum changes by \(amount) per value it spans, a minimum by \(amount)."
}

/// The tree's cells, level by level, each with its sum and its smallest value as the current
/// trees give them (padding past the values dimmed); the links, those walked `active`.
func segmentDrawing(_ model: SegmentTreeModel, k: Int, step: SegmentStep?) -> (nodes: [CanvasNode], edges: [CanvasEdge], height: Int) {
    let leaves = model.leaves
    let count = model.values.count
    let sums = model.sums[k], minimums = model.minimums[k]
    let cells = model.children.keys.sorted()
    let covered = Set(step?.covered ?? []), passed = Set(step?.passed ?? [])
    var deepest = 0
    let nodes = cells.map { cell in
        let place = segmentCell(cell, leaves: leaves)
        deepest = max(deepest, place.depth)
        let span = place.range.clamped(to: 0 ..< count)
        let state = covered.contains(cell) ? " selected" : passed.contains(cell) ? " current" : ""
        let x = 20 + (Double(place.column) + 0.5) * 640 / Double(1 << place.depth)
        let y = 34 + 86 * Double(place.depth)
        guard !span.isEmpty else { return CanvasNode(x: x, y: y, name: "", radius: 8, classes: "dim") }
        let leaf = place.range.count == 1
        return CanvasNode(x: x, y: y, name: segmentRangeText(place.range), badge: "\(sums.combined(in: span))",
                          note: leaf ? "" : "min \(minimums.combined(in: span))", radius: 15, classes: state)
    }
    let edges = cells.flatMap { cell in
        [model.children[cell]?.left, model.children[cell]?.right].compactMap { $0 }.map { child in
            CanvasEdge(from: cell, to: child, classes: passed.contains(cell) && (covered.contains(child) || passed.contains(child)) ? "active" : "")
        }
    }
    return (nodes, edges, 34 + 86 * deepest + 50)
}

func segmentMarbleKind(_ operation: SegmentOperation) -> String {
    switch operation.amount {
    case nil: "m-green"
    case let amount?: amount < 0 ? "m-red" : "m-blue"
    }
}

@View
struct SegmentTreeLab {
    var body: some View {
        let model = segmentTree
        let playback = model.playback
        let k = playback.k
        let steps = model.steps
        let last = k > 0 ? steps[k - 1] : nil
        let drawing = segmentDrawing(model, k: k, step: last)
        let count = model.values.count

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your values and operations")) {
                label(.class("field"), .for("segmenttree-values")) {
                    "Values "
                    input(.id("segmenttree-values"), .type(.text), .value(model.valuesText), .custom(name: "maxlength", value: "80"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in segmentTree.set(values: event.targetValue ?? "") }
                }
                label(.class("field"), .for("segmenttree-text")) {
                    "?a-b to query, +v@a-b to add v to each of a through b "
                    input(.id("segmenttree-text"), .type(.text), .value(model.text), .custom(name: "maxlength", value: "120"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in segmentTree.set(text: event.targetValue ?? "") }
                }
            }
            section(.class("lab"), .custom(name: "aria-label", value: "The segment tree")) {
                div(.class("panel stage")) {
                    if count == 0 {
                        p(.class("empty")) { "Type some values to build a tree over." }
                    } else {
                        GraphCanvas(label: "The segment tree over \(count) values after \(k) operations", width: 680, height: drawing.height, nodes: drawing.nodes, edges: drawing.edges)
                    }
                    div(.class("legend")) {
                        span { i(.class("dot selected")) {}; "a cell wholly inside the range" }
                        span { i(.class("dot current")) {}; "a cell the walk passed through" }
                    }
                    p(.class("legend")) { "In each circle the sum of the values the cell spans; under it the span, then the smallest value in it." }
                }
                div(.class("side")) {
                    div(.class("panel"), .custom(name: "aria-live", value: "polite")) {
                        span(.class("label")) { k == steps.count ? "Done after \(steps.count) operations" : "Operation \(k) of \(steps.count)" }
                        p(.class("narration")) {
                            if steps.isEmpty {
                                "Type an operation, such as ?2-5 or +3@0-4."
                            } else if let last {
                                describeSegment(last, leaves: model.leaves)
                            } else {
                                "Each cell holds the total of the values it spans: a leaf one value, its parent two, then four, and so on up to the root, which spans them all. The values are padded to a power of two."
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "The tree" }
                        div(.class("stat")) {
                            div(.class("good")) {
                                span(.class("num")) { "\(last?.covered.count ?? 0)" }
                                "cells covering it"
                            }
                            div {
                                span(.class("num")) { last?.answer.map { "\($0.sum)" } ?? "–" }
                                "the sum"
                            }
                            div {
                                span(.class("num")) { last?.answer.map { "\($0.minimum)" } ?? "–" }
                                "the smallest"
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
                        Marble(kind: segmentMarbleKind(step.operation), radius: 9, letter: "\(step.operation.range.lowerBound)", title: describeSegment(step, leaves: model.leaves))
                    },
                    legend: [
                        (Marble(kind: "m-green", radius: 6), "query"),
                        (Marble(kind: "m-blue", radius: 6), "add"),
                        (Marble(kind: "m-red", radius: 6), "subtract"),
                    ])
            }
        }
    }
}

/// Swift source for an operation, as the code panel's `operations` binding spells it.
func segmentOperationCode(_ operation: SegmentOperation) -> String {
    let range = "\(operation.range.lowerBound) ..< \(operation.range.upperBound)"
    return operation.amount.map { "SegmentOperation(range: \(range), amount: \($0))" } ?? "SegmentOperation(range: \(range))"
}

@View
struct SegmentTreeCodePanel {
    var body: some View {
        let model = segmentTree
        let minimums = model.minimums.last ?? LazySegmentTree()
        CodePanel(
            snippets: [
                .segmenttreeImports,
                Snippet(lines: [
                    "let values = [\(model.values.map(String.init).joined(separator: ", "))]",
                    "let operations = [\(model.operations.map(segmentOperationCode).joined(separator: ", "))]",
                ]),
                .segmenttreeRun, .segmenttreeShape,
            ],
            results: [minimums.isEmpty ? "\(Int.max)" : "\(minimums.combined(in: 0 ..< minimums.count))", "\(model.children.count)"])
    }
}

enum SegmentTreePage {
    static func mount() {
        mountView(SegmentTreeLab(), in: "app")
        mountView(SegmentTreeCodePanel(), in: "code")
    }
}
