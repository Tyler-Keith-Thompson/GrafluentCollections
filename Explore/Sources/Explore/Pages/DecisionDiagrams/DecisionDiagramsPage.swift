import DecisionDiagrams
import ElementaryUI
import Reactivity

/// The formula as the reader would type it, with the fewest parentheses.
func formulaText(_ formula: Formula, _ outer: Int = 0) -> String {
    func wrap(_ text: String, _ level: Int) -> String { level < outer ? "(\(text))" : text }
    switch formula {
    case .variable(let index): return String(decisionVariables[index])
    case .not(let f): return "!" + formulaText(f, 4)
    case .and(let f, let g): return wrap(formulaText(f, 3) + " & " + formulaText(g, 3), 3)
    case .xor(let f, let g): return wrap(formulaText(f, 2) + " ^ " + formulaText(g, 2), 2)
    case .or(let f, let g): return wrap(formulaText(f, 1) + " | " + formulaText(g, 1), 1)
    }
}

/// The assignment in `text`: the letters of the variables that are true, such as "ac".
func decisionAssignment(_ text: String) -> [Bool] {
    decisionVariables.map { text.lowercased().contains($0) }
}

/// One edge of a drawn function: from a test to the vertex it goes to when its variable is
/// false (low) or true (high).
struct DecisionEdge {
    var source: Int
    var target: Int
    var isHigh: Bool
}

/// The function rooted at `root`, read from `graphView`: its vertices in breadth-first order,
/// the variable each tests (nil for a constant), and its edges.
func decisionGraph(_ diagram: BinaryDecisionDiagram, root: Int) -> (vertices: [Int], variables: [Int: Int], edges: [DecisionEdge]) {
    let view = diagram.graphView
    var seen: Set<Int> = [root], order = [root], variables: [Int: Int] = [:], edges: [DecisionEdge] = []
    var cursor = 0
    while cursor < order.count {
        let vertex = order[cursor]
        cursor += 1
        variables[vertex] = view.variable(of: vertex)
        for position in view.outEdges(of: vertex) {
            let target = view.target(ofEdgeAt: position)
            edges.append(DecisionEdge(source: vertex, target: target, isHigh: view.isHighEdge(at: position)))
            if seen.insert(target).inserted { order.append(target) }
        }
    }
    return (order, variables, edges)
}

/// The vertices an evaluation passes: from the root, high where the tested variable is true and
/// low otherwise, down to a constant.
func decisionPath(root: Int, variables: [Int: Int], edges: [DecisionEdge], assignment: [Bool]) -> [Int] {
    var path = [root]
    while let variable = variables[path.last!] {
        let edge = edges.first { $0.source == path.last! && $0.isHigh == assignment[variable] }!
        path.append(edge.target)
    }
    return path
}

/// What one formula built: its function's vertices, variables and edges, which of them the
/// table held already, the path the assignment takes, and the function's truth count and value.
struct DecisionStep {
    var formula: Formula
    var vertices: [Int]
    var variables: [Int: Int]
    var edges: [DecisionEdge]
    var reused: Set<Int>
    var path: [Int]
    var satisfying: Int
    var value: Bool
}

@Reactive
final class DecisionDiagramsModel {
    var text = "a & b; c | d; a & b | c & d; (a ^ b) & (c ^ d); a ^ b ^ c ^ d ^ e; !(a & b) | e"
    var assignmentText = "ad"
    var formulas: [Formula] = []
    var assignment: [Bool] = []
    var tableCounts: [Int] = [2]
    var steps: [DecisionStep] = []
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_600, scrubID: "scrub-decisiondiagrams")

    init() {
        run()
    }

    func set(text newText: String) {
        text = String(newText.prefix(200))
        run()
    }

    func set(assignment newText: String) {
        assignmentText = String(newText.prefix(10))
        run()
    }

    func run() {
        formulas = Array(text.split(separator: ";").compactMap { parseFormula(String($0)) }.prefix(10))
        assignment = decisionAssignment(assignmentText)
        let history = decisionHistory(formulas)
        tableCounts = history.tableBefore.dropFirst() + [history.diagram.tableVertexCount]
        steps = formulas.indices.map { i in
            let function = history.functions[i]
            let graph = decisionGraph(history.diagram, root: function.vertex)
            return DecisionStep(formula: formulas[i], vertices: graph.vertices, variables: graph.variables, edges: graph.edges,
                                reused: Set(graph.vertices.filter { $0 >= 2 && $0 < history.tableBefore[i] }),
                                path: decisionPath(root: function.vertex, variables: graph.variables, edges: graph.edges, assignment: assignment),
                                satisfying: Int(history.diagram.satisfyingAssignmentCount(of: function)),
                                value: history.diagram.evaluate(function, at: assignment))
        }
        tableCounts = [2] + tableCounts
        playback.reset(count: steps.count)
    }
}

let decisionDiagrams = DecisionDiagramsModel()

func describeDecision(_ step: DecisionStep, assignment: [Bool]) -> String {
    let tests = step.vertices.filter { step.variables[$0] != nil }.count
    let reused = step.reused.isEmpty
        ? "None of its tests were in the table before."
        : step.reused.count == 1
            ? "1 of its tests was already in the table from an earlier formula, and building it reused that vertex rather than making a copy."
            : "\(step.reused.count) of its tests were already in the table from earlier formulas, and building it reused them rather than making copies."
    let named = decisionVariables.indices.filter { assignment[$0] }.map { String(decisionVariables[$0]) }
    let truth = named.isEmpty ? "every variable false" : named.joined(separator: " and ") + " true and the rest false"
    return "\(formulaText(step.formula)): \(tests) \(tests == 1 ? "test" : "tests") above the constants. \(reused) It is true for \(step.satisfying) of the 32 assignments. With \(truth), the path from the root reaches \(step.value ? "true" : "false")."
}

/// The function's tests in rows by the variable they test, a at the top, the constants at the
/// bottom; low edges dashed, high edges solid; the assignment's path lit, reused tests tinted.
func decisionDrawing(_ step: DecisionStep?) -> (nodes: [CanvasNode], edges: [CanvasEdge], height: Int) {
    guard let step else { return ([], [], 120) }
    let bottom = decisionVariables.count
    var rows: [Int: [Int]] = [:]
    for vertex in step.vertices { rows[step.variables[vertex] ?? bottom, default: []].append(vertex) }
    let usedRows = rows.keys.sorted()
    var spot: [Int: (x: Double, y: Double)] = [:]
    for (rank, row) in usedRows.enumerated() {
        let vertices = row == bottom ? rows[row]!.sorted() : rows[row]!
        let gap = min(110.0, 600.0 / Double(vertices.count))
        for (i, vertex) in vertices.enumerated() {
            spot[vertex] = (340 - gap * Double(vertices.count - 1) / 2 + gap * Double(i), 34 + 70 * Double(rank))
        }
    }
    let path = Set(step.path)
    let walked = Set(zip(step.path, step.path.dropFirst()).map { [$0, $1] })
    let offset = Dictionary(uniqueKeysWithValues: step.vertices.enumerated().map { ($1, $0) })
    let nodes = step.vertices.map { vertex in
        let isConstant = step.variables[vertex] == nil
        let state = vertex == step.path.last ? " current" : path.contains(vertex) ? " selected" : step.reused.contains(vertex) ? " done" : ""
        let label = isConstant ? (vertex == 1 ? "T" : "F") : String(decisionVariables[step.variables[vertex]!])
        return CanvasNode(x: spot[vertex]!.x, y: spot[vertex]!.y, name: "", badge: label, radius: isConstant ? 13 : 16, classes: state)
    }
    let edges = step.edges.map { edge in
        let lit = walked.contains([edge.source, edge.target])
        // A test whose two edges reach the same row would draw them on top of each other.
        return CanvasEdge(from: offset[edge.source]!, to: offset[edge.target]!, directed: true,
                          classes: (edge.isHigh ? "high" : "low") + (lit ? " active" : ""), bend: edge.isHigh ? -10 : 10)
    }
    return (nodes, edges, 34 + 70 * (usedRows.count - 1) + 40)
}

@View
struct DecisionDiagramsLab {
    var body: some View {
        let model = decisionDiagrams
        let playback = model.playback
        let k = playback.k
        let steps = model.steps
        let last = k > 0 ? steps[k - 1] : nil
        let drawing = decisionDrawing(last)

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your formulas and assignment")) {
                label(.class("field"), .for("decisiondiagrams-text")) {
                    "Formulas over a to e, separated by ; (! not, & and, ^ xor, | or) "
                    input(.id("decisiondiagrams-text"), .type(.text), .value(model.text), .custom(name: "maxlength", value: "200"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in decisionDiagrams.set(text: event.targetValue ?? "") }
                }
                label(.class("field"), .for("decisiondiagrams-assignment")) {
                    "The variables that are true "
                    input(.id("decisiondiagrams-assignment"), .type(.text), .value(model.assignmentText), .custom(name: "maxlength", value: "10"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in decisionDiagrams.set(assignment: event.targetValue ?? "") }
                }
            }
            section(.class("lab"), .custom(name: "aria-label", value: "The decision diagram")) {
                div(.class("panel stage")) {
                    if let last {
                        GraphCanvas(label: "The decision diagram of \(formulaText(last.formula))", width: 680, height: drawing.height, nodes: drawing.nodes, edges: drawing.edges)
                    } else {
                        p(.class("empty")) { steps.isEmpty ? "Type a formula, such as a & b | c." : "The table starts with only the two constants. Press Step to build the first formula." }
                    }
                    div(.class("legend")) {
                        span { i(.class("dot selected")) {}; "the assignment’s path" }
                        span { i(.class("dot done")) {}; "reused from an earlier formula" }
                    }
                    p(.class("legend")) { "Each circle tests a variable: the dashed edge is taken when it is false, the solid one when it is true. T and F are the constants." }
                }
                div(.class("side")) {
                    div(.class("panel"), .custom(name: "aria-live", value: "polite")) {
                        span(.class("label")) { k == steps.count ? "Done after \(steps.count) formulas" : "Formula \(k) of \(steps.count)" }
                        p(.class("narration")) {
                            if let last {
                                describeDecision(last, assignment: model.assignment)
                            } else {
                                "A decision diagram is a Boolean function drawn as a graph of tests, each asking one variable, in a fixed order. It merges any two tests that ask the same thing and lead the same way, and drops any test whose answer doesn’t matter. That leaves exactly one diagram per function."
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "The table" }
                        div(.class("stat")) {
                            div {
                                span(.class("num")) { "\(last.map { $0.vertices.count - 2 } ?? 0)" }
                                "tests in this formula"
                            }
                            div(.class("good")) {
                                span(.class("num")) { "\(model.tableCounts[min(k, model.tableCounts.count - 1)])" }
                                "vertices in the shared table"
                            }
                            div {
                                span(.class("num")) { last.map { "\($0.satisfying)" } ?? "–" }
                                "of 32 assignments true"
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
                    marbles: steps.enumerated().map { i, step in
                        Marble(kind: step.value ? "m-green" : "m-red", radius: 9, letter: "\(i + 1)", title: describeDecision(step, assignment: model.assignment))
                    },
                    legend: [
                        (Marble(kind: "m-green", radius: 6), "true for the assignment"),
                        (Marble(kind: "m-red", radius: 6), "false for it"),
                    ])
            }
        }
    }
}

/// Swift source for a formula, as the code panel's `formulas` binding spells it.
func formulaCode(_ formula: Formula) -> String {
    switch formula {
    case .variable(let index): ".variable(\(index))"
    case .not(let f): ".not(\(formulaCode(f)))"
    case .and(let f, let g): ".and(\(formulaCode(f)), \(formulaCode(g)))"
    case .xor(let f, let g): ".xor(\(formulaCode(f)), \(formulaCode(g)))"
    case .or(let f, let g): ".or(\(formulaCode(f)), \(formulaCode(g)))"
    }
}

@View
struct DecisionDiagramsCodePanel {
    var body: some View {
        let model = decisionDiagrams
        CodePanel(
            snippets: [
                .decisiondiagramsImports,
                Snippet(lines: ["let formulas: [Formula] = [\(model.formulas.map(formulaCode).joined(separator: ", "))]"]),
                .decisiondiagramsRun,
            ],
            results: ["\(model.tableCounts.last ?? 2)"])
    }
}

enum DecisionDiagramsPage {
    static func mount() {
        mountView(DecisionDiagramsLab(), in: "app")
        mountView(DecisionDiagramsCodePanel(), in: "code")
    }
}
