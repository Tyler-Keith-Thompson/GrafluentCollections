// snippet: decisiondiagrams-imports
import DecisionDiagrams

/// A Boolean formula over variables numbered from 0.
indirect enum Formula: Equatable {
    case variable(Int)
    case not(Formula)
    case and(Formula, Formula)
    case xor(Formula, Formula)
    case or(Formula, Formula)
}
// snippet end

// The decision diagram page's code. The marked regions are its code panel.

/// The variables' names, in the order the diagram tests them.
let decisionVariables: [Character] = ["a", "b", "c", "d", "e"]

/// The formula in `text`, or nil when it doesn't parse: the variables a to e, `!` for not, then
/// `&`, `^` and `|` from tightest to loosest, and parentheses.
func parseFormula(_ text: String) -> Formula? {
    let tokens = Array(text.filter { !$0.isWhitespace })
    var at = 0
    func primary() -> Formula? {
        guard at < tokens.count else { return nil }
        let token = tokens[at]
        at += 1
        if token == "!" { return primary().map(Formula.not) }
        if token == "(" {
            guard let inside = loosest(), at < tokens.count, tokens[at] == ")" else { return nil }
            at += 1
            return inside
        }
        return decisionVariables.firstIndex(of: token).map(Formula.variable)
    }
    func chain(_ symbol: Character, _ next: () -> Formula?, _ make: (Formula, Formula) -> Formula) -> Formula? {
        guard var left = next() else { return nil }
        while at < tokens.count, tokens[at] == symbol {
            at += 1
            guard let right = next() else { return nil }
            left = make(left, right)
        }
        return left
    }
    func conjunction() -> Formula? { chain("&", primary, Formula.and) }
    func exclusive() -> Formula? { chain("^", conjunction, Formula.xor) }
    func loosest() -> Formula? { chain("|", exclusive, Formula.or) }
    guard let formula = loosest(), at == tokens.count else { return nil }
    return formula
}

/// Each formula built in one shared table, and how many vertices the table held before it.
func decisionHistory(_ formulas: [Formula]) -> (diagram: BinaryDecisionDiagram, functions: [BinaryDecisionDiagram.Function], tableBefore: [Int]) {
    // snippet: decisiondiagrams-run
    var diagram = BinaryDecisionDiagram(variableCount: 5)
    func build(_ formula: Formula) -> BinaryDecisionDiagram.Function {
        switch formula {
        case .variable(let index): diagram.variable(index)
        case .not(let f): diagram.not(build(f))
        case .and(let f, let g): diagram.and(build(f), build(g))
        case .xor(let f, let g): diagram.xor(build(f), build(g))
        case .or(let f, let g): diagram.or(build(f), build(g))
        }
    }
    var functions: [BinaryDecisionDiagram.Function] = []
    var tableBefore: [Int] = []
    for formula in formulas {
        tableBefore.append(diagram.tableVertexCount)
        functions.append(build(formula))
    }
    let vertices = diagram.tableVertexCount  // →
    // snippet end
    _ = vertices
    return (diagram, functions, tableBefore)
}
