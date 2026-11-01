// BinaryDecisionDiagram against truth tables over up to six variables, and
// ZeroSuppressedDecisionDiagram against sets of bitmasks over up to six elements. Every
// operation's result must have the reference's truth table or family, and the diagrams are
// canonical, so equal functions and families must be equal handles.

import DecisionDiagrams
import FuzzSupport

@main
enum FuzzDecisionDiagrams {
    static func main() { runFuzzer(fuzz) }

    static func fuzz(_ input: inout FuzzInput) {
        if input.int(below: 2) == 0 { binary(&input) } else { zeroSuppressed(&input) }
    }

    static func binary(_ input: inout FuzzInput) {
        let n = 1 + input.int(below: 6)
        let rows = 1 << n
        var diagram = BinaryDecisionDiagram(variableCount: n)
        // Each function beside its truth table, one bit per assignment (variable i is bit i).
        var functions: [(BinaryDecisionDiagram.Function, UInt64)] = [(diagram.constant(false), 0), (diagram.constant(true), rows == 64 ? ~0 : (1 << rows) - 1)]
        let full: UInt64 = rows == 64 ? ~0 : (1 << rows) - 1
        func table(_ predicate: (Int) -> Bool) -> UInt64 {
            (0 ..< rows).reduce(UInt64(0)) { $0 | (predicate($1) ? 1 << UInt64($1) : 0) }
        }
        while !input.isEmpty {
            let f = functions[input.int(below: functions.count)], g = functions[input.int(below: functions.count)]
            let variable = input.int(below: n)
            let result: (BinaryDecisionDiagram.Function, UInt64)
            switch input.int(below: 8) {
            case 0: result = (diagram.variable(variable), table { $0 >> variable & 1 == 1 })
            case 1: result = (diagram.and(f.0, g.0), f.1 & g.1)
            case 2: result = (diagram.or(f.0, g.0), f.1 | g.1)
            case 3: result = (diagram.xor(f.0, g.0), f.1 ^ g.1)
            case 4: result = (diagram.not(f.0), ~f.1 & full)
            case 5:
                let value = input.int(below: 2) == 1
                result = (diagram.restrict(f.0, variable: variable, to: value),
                          table { row in f.1 >> UInt64(value ? row | 1 << variable : row & ~(1 << variable)) & 1 == 1 })
            case 6:
                result = (diagram.exists([variable], in: f.0),
                          table { row in (f.1 >> UInt64(row | 1 << variable) | f.1 >> UInt64(row & ~(1 << variable))) & 1 == 1 })
            default:
                let h = functions[input.int(below: functions.count)]
                result = (diagram.ifThenElse(f.0, then: g.0, else: h.0), (f.1 & g.1) | (~f.1 & h.1 & full))
            }
            for (function, truth) in functions where truth == result.1 {
                check(function == result.0, "equal functions have different handles")
            }
            check(diagram.satisfyingAssignmentCount(of: result.0) == Double(result.1.nonzeroBitCount), "satisfyingAssignmentCount")
            for row in 0 ..< rows {
                let assignment = (0 ..< n).map { row >> $0 & 1 == 1 }
                check(diagram.evaluate(result.0, at: assignment) == (result.1 >> UInt64(row) & 1 == 1), "evaluate at \(row)")
            }
            if let witness = diagram.anySatisfyingAssignment(of: result.0) {
                check(diagram.evaluate(result.0, at: witness), "the satisfying assignment does not satisfy")
            } else {
                check(result.1 == 0, "no satisfying assignment of a satisfiable function")
            }
            functions.append(result)
        }
    }

    static func zeroSuppressed(_ input: inout FuzzInput) {
        let n = 1 + input.int(below: 6)
        var diagram = ZeroSuppressedDecisionDiagram(elementCount: n)
        func members(_ mask: Int) -> [Int] { (0 ..< n).filter { mask >> $0 & 1 == 1 } }
        var families: [(ZeroSuppressedDecisionDiagram.Family, Set<Int>)] = [(diagram.family([[Int]]()), [])]
        while !input.isEmpty {
            let f = families[input.int(below: families.count)], g = families[input.int(below: families.count)]
            let element = input.int(below: n)
            let result: (ZeroSuppressedDecisionDiagram.Family, Set<Int>)
            switch input.int(below: 10) {
            case 0:
                let masks = Set((0 ..< input.int(below: 4)).map { _ in input.int(below: 1 << n) })
                result = (diagram.family(masks.map(members)), masks)
            case 1: result = (diagram.single(element), [1 << element])
            case 2: result = (diagram.union(f.0, g.0), f.1.union(g.1))
            case 3: result = (diagram.intersection(f.0, g.0), f.1.intersection(g.1))
            case 4: result = (diagram.subtracting(g.0, from: f.0), f.1.subtracting(g.1))
            case 5: result = (diagram.join(f.0, g.0), Set(f.1.flatMap { a in g.1.map { a | $0 } }))
            case 6: result = (diagram.meet(f.0, g.0), Set(f.1.flatMap { a in g.1.map { a & $0 } }))
            case 7: result = (diagram.including(element, in: f.0), Set(f.1.filter { $0 >> element & 1 == 1 }))
            case 8: result = (diagram.minimalSets(of: f.0), f.1.filter { a in !f.1.contains { $0 != a && $0 & a == $0 } })
            default: result = (diagram.maximalSets(of: f.0), f.1.filter { a in !f.1.contains { $0 != a && $0 & a == a } })
            }
            let listed = Set(diagram.setsView(of: result.0).map { $0.reduce(0) { $0 | 1 << $1 } })
            check(listed == result.1, "family \(listed.sorted()), expected \(result.1.sorted())")
            check(diagram.count(of: result.0) == Double(result.1.count), "count")
            for mask in 0 ..< 1 << n {
                check(diagram.contains(members(mask), in: result.0) == result.1.contains(mask), "contains \(mask)")
            }
            for (family, sets) in families where sets == result.1 {
                check(family == result.0, "equal families have different handles")
            }
            families.append(result)
        }
    }
}
