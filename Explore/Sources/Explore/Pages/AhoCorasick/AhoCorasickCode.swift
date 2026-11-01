// snippet: ahocorasick-imports
import Tries
// snippet end

// The Aho–Corasick page's code. The marked regions are its code panel.

/// The patterns in `text`: runs of the letters a to z, at most 8 letters each and at most 8
/// patterns, without repeats. Anything else separates patterns.
func ahoCorasickPatterns(_ text: String) -> [String] {
    var patterns: [String] = []
    for word in text.lowercased().split(whereSeparator: { !("a" ... "z").contains($0) }) {
        let pattern = String(word.prefix(8))
        if !patterns.contains(pattern) { patterns.append(pattern) }
        if patterns.count == 8 { break }
    }
    return patterns
}

/// The text to scan: the letters a to z in `text`, at most 24.
func ahoCorasickText(_ text: String) -> String {
    String(text.lowercased().filter { ("a" ... "z").contains($0) }.prefix(24))
}

/// The automaton over `patterns`, and every match in `text`.
func ahoCorasickRun(_ patterns: [String], _ text: String) -> (automaton: AhoCorasickAutomaton<Character>, matches: [AhoCorasickAutomaton<Character>.Match]) {
    // snippet: ahocorasick-run
    let automaton = AhoCorasickAutomaton<Character>(patterns: patterns)
    let states = automaton.stateCount  // →
    let matches = Array(automaton.matches(in: text))
    let found = matches.map { "\(patterns[$0.patternIndex]) at \($0.range)" }  // →
    // snippet end
    _ = (states, found)
    return (automaton, matches)
}

/// The automaton's states as a graph: for each state, the symbol and state of each goto edge,
/// and its failure link (nil for the root).
func ahoCorasickGraph(_ automaton: AhoCorasickAutomaton<Character>) -> (gotos: [[Character: Int]], failures: [Int?], patterns: [[Int]]) {
    // snippet: ahocorasick-states
    let states = automaton.statesView
    var gotos = Array(repeating: [Character: Int](), count: states.vertexCount)
    var failures = Array(repeating: Int?.none, count: states.vertexCount)
    for edge in 0 ..< states.edgeCount {
        let source = states.source(ofEdgeAt: edge), target = states.target(ofEdgeAt: edge)
        if let symbol = states.symbol(ofEdgeAt: edge) {
            gotos[source][symbol] = target  // a goto edge
        } else {
            failures[source] = target  // a failure link
        }
    }
    let links = failures.count { $0 != nil }  // →
    // snippet end
    _ = links
    return (gotos, failures, states.vertices.map { states.patternIndices(endingAt: $0) })
}
