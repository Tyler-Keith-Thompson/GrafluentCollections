// Each test is self-contained: it builds its own automata and states its own expectations, so it
// can be copied into another file and still run. Nothing here is shared but the imports.

import GrafluentCollectionsTestSupport
import GraphProtocols
import PropertyBased
import Testing
import Tries

@Suite("AhoCorasickAutomaton: hand-worked cases")
struct AhoCorasickAutomatonTests {
    typealias Match = AhoCorasickAutomaton<Character>.Match

    @Test("The paper's example: he, she, his and hers in \"ushers\"")
    func papersExample() {
        let automaton = AhoCorasickAutomaton(patterns: ["he", "she", "his", "hers"])
        let expected: [Match] = [
            Match(patternIndex: 1, range: 1 ..< 4),
            Match(patternIndex: 0, range: 2 ..< 4),
            Match(patternIndex: 3, range: 2 ..< 6),
        ]
        #expect(Array(automaton.matches(in: "ushers")) == expected)
        // The prefixes: "", h, he, her, hers, s, sh, she, hi, his.
        #expect(automaton.stateCount == 10)
        #expect(automaton.patternCount == 4)
    }

    @Test("Overlapping occurrences of one pattern are all reported")
    func overlapping() {
        let automaton = AhoCorasickAutomaton(patterns: ["aa"])
        let expected: [Match] = [
            Match(patternIndex: 0, range: 0 ..< 2),
            Match(patternIndex: 0, range: 1 ..< 3),
            Match(patternIndex: 0, range: 2 ..< 4),
        ]
        #expect(Array(automaton.matches(in: "aaaa")) == expected)
    }

    @Test("A pattern that is a suffix of another is reported where the longer one ends, after it")
    func suffixPatterns() {
        let automaton = AhoCorasickAutomaton(patterns: ["c", "abc", "bc"])
        let expected: [Match] = [
            Match(patternIndex: 1, range: 1 ..< 4),
            Match(patternIndex: 2, range: 2 ..< 4),
            Match(patternIndex: 0, range: 3 ..< 4),
        ]
        #expect(Array(automaton.matches(in: "xabc")) == expected)
    }

    @Test("A repeated pattern is reported once per index")
    func repeatedPatterns() {
        let automaton = AhoCorasickAutomaton(patterns: ["ab", "ab"])
        let expected: [Match] = [
            Match(patternIndex: 0, range: 0 ..< 2),
            Match(patternIndex: 1, range: 0 ..< 2),
        ]
        #expect(Array(automaton.matches(in: "ab")) == expected)
    }

    @Test("No patterns match nothing, and an empty text matches nothing but the empty pattern")
    func emptyInputs() {
        let none = AhoCorasickAutomaton<Character>(patterns: [String]())
        #expect(none.stateCount == 1)
        #expect(Array(none.matches(in: "abc")).isEmpty)
        #expect(!none.containsMatch(in: "abc"))
        let some = AhoCorasickAutomaton(patterns: ["a"])
        #expect(Array(some.matches(in: "")).isEmpty)
        #expect(some.firstMatch(in: "") == nil)
    }

    @Test("The empty pattern matches at every offset, the end included")
    func emptyPattern() {
        let automaton = AhoCorasickAutomaton(patterns: ["", "b"])
        let expected: [Match] = [
            Match(patternIndex: 0, range: 0 ..< 0),
            Match(patternIndex: 0, range: 1 ..< 1),
            Match(patternIndex: 1, range: 1 ..< 2),
            Match(patternIndex: 0, range: 2 ..< 2),
        ]
        #expect(Array(automaton.matches(in: "ab")) == expected)
        let onEmptyText: [Match] = [Match(patternIndex: 0, range: 0 ..< 0)]
        #expect(Array(automaton.matches(in: "")) == onEmptyText)
    }

    @Test("firstMatch is the match that ends first, longest of those, and containsMatch whether any does")
    func firstMatch() {
        let automaton = AhoCorasickAutomaton(patterns: ["cat", "at", "dog"])
        let first: Match? = Match(patternIndex: 0, range: 1 ..< 4)
        #expect(automaton.firstMatch(in: "scatdog") == first)
        #expect(automaton.containsMatch(in: "hotdog"))
        #expect(!automaton.containsMatch(in: "cow"))
    }

    @Test("Symbols no pattern has send the scan back to the root")
    func unknownSymbols() {
        let automaton = AhoCorasickAutomaton(patterns: ["ab"])
        let expected: [Match] = [Match(patternIndex: 0, range: 3 ..< 5)]
        #expect(Array(automaton.matches(in: "azbab")) == expected)
    }

    @Test("Bytes and Characters find the same matches in ASCII text")
    func bytesAndCharacters() {
        let patterns = ["needle", "eed", "le", "hay"]
        let text = "haystack with a needle and more hay, needles"
        let characters = AhoCorasickAutomaton(patterns: patterns)
        let bytes = AhoCorasickAutomaton(patterns: patterns.map(\.utf8))
        let fromCharacters = characters.matches(in: text).map { [$0.patternIndex, $0.range.lowerBound, $0.range.upperBound] }
        let fromBytes = bytes.matches(in: text.utf8).map { [$0.patternIndex, $0.range.lowerBound, $0.range.upperBound] }
        #expect(fromCharacters == fromBytes)
        #expect(fromBytes.count == 8)
    }

    @Test("Without a transition table, following failure links finds the same matches")
    func sparseTransitions() {
        // 3000 one-symbol patterns make 3001 states over 3000 symbols, too many for the table.
        let patterns = (0 ..< 3_000).map { [$0] } + [[1, 2, 3], [2, 3, 1], [3, 1, 2]]
        let sparse = AhoCorasickAutomaton(patterns: patterns)
        let text = [1, 2, 3, 1, 2, 3, 2_999, 4_000, 3, 1, 2]
        var expected: [AhoCorasickAutomaton<Int>.Match] = []
        for end in 1 ... text.count {
            for (index, pattern) in patterns.enumerated().reversed().sorted(by: { $0.element.count > $1.element.count })
            where pattern.count <= end && Array(text[end - pattern.count ..< end]) == pattern {
                expected.append(.init(patternIndex: index, range: end - pattern.count ..< end))
            }
        }
        let found = Array(sparse.matches(in: text))
        #expect(found.count == expected.count)
        #expect(Set(found) == Set(expected))
        #expect(found.map(\.range.upperBound) == expected.map(\.range.upperBound))
    }

    @Test("The states view has a goto edge per non-root state and a failure edge from each", .tags(.fixture))
    func statesView() {
        let automaton = AhoCorasickAutomaton(patterns: ["he", "she", "his", "hers"])
        let graph = automaton.statesView
        #expect(graph.vertexCount == 10)
        #expect(graph.edgeCount == 18)
        #expect(Array(graph.edges).count == graph.edgeCount)
        let gotoEdges = (0 ..< graph.edgeCount).filter { graph.symbol(ofEdgeAt: $0) != nil }
        let failureEdges = (0 ..< graph.edgeCount).filter { graph.symbol(ofEdgeAt: $0) == nil }
        #expect(gotoEdges.count == 9)
        #expect(failureEdges.count == 9)
        // Every out-edge of every state is listed once, from that state.
        var listed: [Int] = []
        for vertex in graph.vertices {
            for position in graph.outEdges(of: vertex) {
                #expect(graph.source(ofEdgeAt: position) == vertex)
                #expect(graph.edges[position].source == vertex)
                listed.append(position)
            }
        }
        #expect(listed.sorted() == Array(0 ..< graph.edgeCount))
        // The state for "she" fails to the state for "he", where pattern 0 ends.
        func state(_ prefix: String) -> Int {
            var vertex = 0
            for symbol in prefix {
                vertex = graph.outEdges(of: vertex).first { graph.symbol(ofEdgeAt: $0) == symbol }.map { graph.target(ofEdgeAt: $0) }!
            }
            return vertex
        }
        let she = state("she")
        let he = state("he")
        let failure = graph.outEdges(of: she).first { graph.symbol(ofEdgeAt: $0) == nil }.map { graph.target(ofEdgeAt: $0) }
        #expect(failure == he)
        let heEnds: [Int] = [0]
        let sheEnds: [Int] = [1]
        #expect(graph.patternIndices(endingAt: he) == heEnds)
        #expect(graph.patternIndices(endingAt: she) == sheEnds)
        #expect(graph.patternIndices(endingAt: 0).isEmpty)
        #expect(!graph.contains(10))
        #expect(graph.successors(of: 0).count == 2)
    }

    @Test("The checked spelling throws IndexOutOfRange for a pattern index out of range")
    func checkedThrows() throws {
        let automaton = AhoCorasickAutomaton(patterns: ["ab", "c"])
        #expect(try automaton.patternLength(checkedAt: 0) == automaton.patternLength(at: 0))
        let two: Int = 2
        #expect(automaton.patternLength(at: 0) == two)
        #expect(throws: IndexOutOfRange()) { try automaton.patternLength(checkedAt: 2) }
        #expect(throws: IndexOutOfRange()) { try automaton.patternLength(checkedAt: -1) }
    }

    @Test("Every match is an occurrence a naive scan finds, and the naive scan finds no others", .tags(.randomized))
    func matchesNaiveScan() async {
        let pattern = Gen.int(in: 0 ... 2).array(of: 0 ... 4)
        let patterns = pattern.array(of: 0 ... 8)
        let text = Gen.int(in: 0 ... 3).array(of: 0 ... 40)
        await propertyCheck(count: 400, input: patterns, text) { patterns, text in
            let automaton = AhoCorasickAutomaton(patterns: patterns)
            var naive: [AhoCorasickAutomaton<Int>.Match] = []
            for end in 0 ... text.count {
                for (index, pattern) in patterns.enumerated()
                where pattern.count <= end && Array(text[end - pattern.count ..< end]) == pattern {
                    naive.append(.init(patternIndex: index, range: end - pattern.count ..< end))
                }
            }
            let found = Array(automaton.matches(in: text))
            #expect(found.count == naive.count)
            #expect(Set(found) == Set(naive))
            // In order of where they end, and of those ending together, longest first.
            let ordered = found.indices.dropFirst().allSatisfy { k in
                let (a, b) = (found[k - 1], found[k])
                return a.range.upperBound < b.range.upperBound
                    || (a.range.upperBound == b.range.upperBound && a.range.count >= b.range.count)
            }
            #expect(ordered)
            #expect(automaton.firstMatch(in: text) == found.first)
            #expect(automaton.containsMatch(in: text) == !naive.isEmpty)
        }
    }
}
