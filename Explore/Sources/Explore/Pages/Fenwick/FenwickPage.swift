import ElementaryUI
import RangeTrees
import Reactivity

/// The first index cell `cell` covers: its range is that index through `cell`.
func fenwickLow(_ cell: Int) -> Int { cell & (cell + 1) }

/// How many times the cell's range has doubled: it covers 2^level indices.
func fenwickLevel(_ cell: Int) -> Int { (cell + 1).trailingZeroBitCount }

/// The cells an operation visits: a prefix sum reads its index's cell and then the cell just
/// below each range read; an add writes its index's cell and then each next cell up the update
/// tree, every one of which covers the index.
func fenwickVisits(_ operation: FenwickOperation, count: Int) -> [Int] {
    var cells: [Int] = []
    switch operation {
    case .prefixSum(let index):
        var cell = index
        while cell >= 0 {
            cells.append(cell)
            cell = fenwickLow(cell) - 1
        }
    case .add(_, let index):
        var cell = index
        while cell < count {
            cells.append(cell)
            cell = cell | (cell + 1)
        }
    }
    return cells
}

/// "4–7", or "5" for a range of one.
func fenwickRange(_ cell: Int) -> String {
    fenwickLow(cell) == cell ? "\(cell)" : "\(fenwickLow(cell))–\(cell)"
}

/// What one operation did: the operation, the cells it visited, and a prefix sum's answer.
struct FenwickStep {
    var operation: FenwickOperation
    var cells: [Int]
    var answer: Int?
}

@Reactive
final class FenwickModel {
    var valuesText = "3 1 4 1 5 9 2 6 5 3 5 8"
    var text = "?6 ?11 +4@2 ?6 ?3 -5@8 ?11"
    var values: [Int] = []
    var operations: [FenwickOperation] = []
    var history: [FenwickTree<Int>] = [FenwickTree()]
    var parents: [Int: Int] = [:]
    var steps: [FenwickStep] = []
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_100, scrubID: "scrub-fenwick")

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
        operations = fenwickOperations(text, count: values.count)
        let run = fenwickHistory(values, operations)
        history = run.trees
        parents = fenwickParents(history[0])
        steps = operations.indices.map { i in
            FenwickStep(operation: operations[i], cells: fenwickVisits(operations[i], count: values.count), answer: run.answers[i])
        }
        playback.reset(count: steps.count)
    }
}

let fenwick = FenwickModel()

func describeFenwick(_ step: FenwickStep) -> String {
    let cells = step.cells.map { "cell \($0) (\(fenwickRange($0)))" }
    let list = cells.count == 1 ? cells[0] : cells.dropLast().joined(separator: ", ") + " and " + cells.last!
    switch step.operation {
    case .prefixSum(let index):
        let count = step.cells.count == 1 ? "1 cell" : "\(step.cells.count) cells"
        return "Sum through index \(index): read \(list). Their ranges meet end to end and cover 0 to \(index), so \(count) give \(step.answer ?? 0). Each hop goes to the cell just below the range it read."
    case .add(let amount, let index):
        let verb = amount < 0 ? "Subtract \(-amount) at" : "Add \(amount) at"
        return "\(verb) index \(index): \(list) all cover index \(index), so each changes by \(amount). Each hop follows the update tree to the next cell whose longer range still covers it, until the walk passes the end."
    }
}

/// The cells in a row by index, each raised by its level, with the end as a small vertex top
/// right; the update tree's links, those an add walked `active`; and a prefix sum's hops, bent
/// so they don't cover the update links.
func fenwickDrawing(_ tree: FenwickTree<Int>, parents: [Int: Int], step: FenwickStep?) -> (nodes: [CanvasNode], edges: [CanvasEdge], height: Int) {
    let count = tree.count
    let levels = (0 ..< count).map(fenwickLevel).max() ?? 0
    let gap = min(46.0, 610.0 / Double(max(count, 1)))
    let rise = 62.0
    let top = 34.0
    let bottom = top + rise * Double(levels + 1)
    let visited = step?.cells ?? []
    let target = step?.operation.index
    var nodes = (0 ..< count).map { cell in
        let state = cell == target ? " current" : visited.contains(cell) ? " selected" : ""
        return CanvasNode(x: 30 + gap * Double(cell), y: bottom - rise * Double(fenwickLevel(cell)), name: "\(cell)",
                          badge: "\(tree.sum(in: fenwickLow(cell) ..< cell + 1))", note: fenwickRange(cell), radius: 15, classes: state)
    }
    nodes.append(CanvasNode(x: 30 + gap * Double(count), y: top, name: "end", radius: 7, classes: "head"))
    var adds: Set<Int> = []
    var hops: [(Int, Int)] = []
    switch step?.operation {
    case .add: adds = Set(visited)
    case .prefixSum: hops = Array(zip(visited, visited.dropFirst()))
    case nil: break
    }
    var edges = (0 ..< count).map { cell in
        CanvasEdge(from: cell, to: parents[cell] ?? count, directed: true, classes: adds.contains(cell) ? "active" : "faint")
    }
    edges += hops.map { CanvasEdge(from: $0.0, to: $0.1, directed: true, classes: "active", bend: 18) }
    return (nodes, edges, Int(bottom) + 50)
}

func fenwickMarbleKind(_ operation: FenwickOperation) -> String {
    switch operation {
    case .prefixSum: "m-green"
    case .add(let amount, _): amount < 0 ? "m-red" : "m-blue"
    }
}

@View
struct FenwickLab {
    var body: some View {
        let model = fenwick
        let playback = model.playback
        let k = playback.k
        let steps = model.steps
        let last = k > 0 ? steps[k - 1] : nil
        let tree = model.history[k]
        let count = tree.count
        let visited = last?.cells ?? []
        let drawing = fenwickDrawing(tree, parents: model.parents, step: last)

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your values and operations")) {
                label(.class("field"), .for("fenwick-values")) {
                    "Values "
                    input(.id("fenwick-values"), .type(.text), .value(model.valuesText), .custom(name: "maxlength", value: "80"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in fenwick.set(values: event.targetValue ?? "") }
                }
                label(.class("field"), .for("fenwick-text")) {
                    "?i for the sum through index i, +v@i to add v at index i "
                    input(.id("fenwick-text"), .type(.text), .value(model.text), .custom(name: "maxlength", value: "120"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in fenwick.set(text: event.targetValue ?? "") }
                }
            }
            section(.class("lab"), .custom(name: "aria-label", value: "The Fenwick tree")) {
                div(.class("panel stage")) {
                    if count == 0 {
                        p(.class("empty")) { "Type some values to build a tree over." }
                    } else {
                        GraphCanvas(label: "The Fenwick tree's \(count) cells after \(k) operations, each raised by the length of its range", width: 680, height: drawing.height, nodes: drawing.nodes, edges: drawing.edges)
                    }
                    div(.class("legend")) {
                        span { i(.class("dot selected")) {}; "a cell this step reads or changes" }
                        span { i(.class("dot current")) {}; "the step's index" }
                    }
                    p(.class("legend")) { "In each circle the cell's sum; under it its index, then the indices it covers. Arrows: the update tree, each cell to the next cell an add reaches." }
                }
                div(.class("side")) {
                    div(.class("panel"), .custom(name: "aria-live", value: "polite")) {
                        span(.class("label")) { k == steps.count ? "Done after \(steps.count) operations" : "Operation \(k) of \(steps.count)" }
                        p(.class("narration")) {
                            if steps.isEmpty {
                                "Type an operation, such as ?5 or +2@3."
                            } else if let last {
                                describeFenwick(last)
                            } else {
                                "Cell i holds the sum of a run of values ending at index i, as long as the run of 1 bits at the bottom of i + 1 allows: 1, 2, 4 or 8 values. Higher cells cover longer runs."
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "The tree" }
                        div(.class("stat")) {
                            div {
                                span(.class("num")) { "\(count)" }
                                "values"
                            }
                            div(.class("good")) {
                                span(.class("num")) { "\(visited.count)" }
                                "cells this step"
                            }
                            div {
                                span(.class("num")) { last?.answer.map { "\($0)" } ?? "–" }
                                "the sum"
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
                        Marble(kind: fenwickMarbleKind(step.operation), radius: 9, letter: "\(step.operation.index)", title: describeFenwick(step))
                    },
                    legend: [
                        (Marble(kind: "m-green", radius: 6), "prefix sum"),
                        (Marble(kind: "m-blue", radius: 6), "add"),
                        (Marble(kind: "m-red", radius: 6), "subtract"),
                    ])
            }
        }
    }
}

/// Swift source for an operation, as the code panel's `operations` binding spells it.
func fenwickOperationCode(_ operation: FenwickOperation) -> String {
    switch operation {
    case .prefixSum(let index): ".prefixSum(through: \(index))"
    case .add(let amount, let index): ".add(\(amount), at: \(index))"
    }
}

@View
struct FenwickCodePanel {
    var body: some View {
        let model = fenwick
        let tree = model.history.last ?? FenwickTree()
        CodePanel(
            snippets: [
                .fenwickImports,
                Snippet(lines: [
                    "let values = [\(model.values.map(String.init).joined(separator: ", "))]",
                    "let operations: [FenwickOperation] = [\(model.operations.map(fenwickOperationCode).joined(separator: ", "))]",
                ]),
                .fenwickRun, .fenwickShape,
            ],
            results: ["\(tree.sum(in: 0 ..< tree.count))", "\(tree.count)"])
    }
}

enum FenwickPage {
    static func mount() {
        mountView(FenwickLab(), in: "app")
        mountView(FenwickCodePanel(), in: "code")
    }
}
