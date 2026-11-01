// Each test is self-contained: it builds its own automata and states its own expectations, so it
// can be copied into another file and still run. Nothing here is shared but the imports.

import GrafluentCollectionsTestSupport
import GraphProtocols
import PropertyBased
import SuffixStructures
import Testing
import Trees

@Suite("SuffixAutomaton: hand-worked cases")
struct SuffixAutomatonTests {
    @Test("abcbc has 8 states, two of them clones, and 9 transitions")
    func abcbc() {
        let automaton = SuffixAutomaton("abcbc")
        // States as built: 0 start, 1 a, 2 ab, 3 abc, 4 abcb, 5 b (a clone of 2), 6 abcbc,
        // 7 bc (a clone of 3).
        #expect(automaton.stateCount == 8)
        #expect(automaton.transitionCount == 9)
        let graph = automaton.transitionsView
        let lengths: [Int] = [0, 1, 2, 3, 4, 1, 5, 2]
        #expect(graph.vertices.map { graph.length(of: $0) } == lengths)
        let fromStart: [Int] = [1, 5, 7]
        #expect(graph.successors(of: 0) == fromStart)
        let startSymbols: [Character] = ["a", "b", "c"]
        #expect(graph.outEdges(of: 0).map { graph.symbol(ofEdgeAt: $0) } == startSymbols)
        let terminal: [Int] = [0, 6, 7]
        #expect(graph.vertices.filter { graph.isTerminal($0) } == terminal)

        let links = Arborescence(automaton)
        #expect(links.parent(of: 4) == 5)
        #expect(links.parent(of: 6) == 7)
        #expect(links.parent(of: 3) == 7)
        #expect(links.parent(of: 0) == nil)

        let distinct: Int64 = 12
        #expect(automaton.distinctSubstringCount == distinct)
        #expect(automaton.contains("cbc"))
        #expect(!automaton.contains("ca"))
        #expect(automaton.occurrenceCount(of: "bc") == 2)
        #expect(automaton.occurrenceCount(of: "abc") == 1)
        #expect(automaton.occurrenceCount(of: "x") == 0)
        let cb: Range<Int>? = 2 ..< 4
        #expect(automaton.firstOccurrence(of: "cb") == cb)
        #expect(automaton.hasSuffix("bc"))
        #expect(automaton.hasSuffix("cbc"))
        #expect(!automaton.hasSuffix("b"))
    }

    @Test("The longest common substring of abcbc and xbcbz is bcb, where it first ends in each")
    func longestCommonSubstring() {
        let automaton = SuffixAutomaton("abcbc")
        let expected = SuffixAutomaton<Character>.CommonSubstring(textRange: 1 ..< 4, otherRange: 1 ..< 4)
        #expect(automaton.longestCommonSubstring(with: "xbcbz") == expected)
        #expect(automaton.longestCommonSubstring(with: "xyz") == nil)
        #expect(automaton.longestCommonSubstring(with: "") == nil)
        let whole = SuffixAutomaton<Character>.CommonSubstring(textRange: 0 ..< 5, otherRange: 2 ..< 7)
        #expect(automaton.longestCommonSubstring(with: "zzabcbczz") == whole)
    }

    @Test("The empty text has only the start state and the empty substring")
    func emptyText() {
        let automaton = SuffixAutomaton<UInt8>([UInt8]())
        #expect(automaton.stateCount == 1)
        #expect(automaton.transitionCount == 0)
        #expect(automaton.contains([UInt8]()))
        #expect(automaton.hasSuffix([UInt8]()))
        #expect(!automaton.contains([UInt8(1)]))
        #expect(automaton.occurrenceCount(of: [UInt8]()) == 0)
        let start: Range<Int>? = 0 ..< 0
        #expect(automaton.firstOccurrence(of: [UInt8]()) == start)
        let zero: Int64 = 0
        #expect(automaton.distinctSubstringCount == zero)
    }

    @Test("A one-symbol text has two states and one transition")
    func oneSymbol() {
        let automaton = SuffixAutomaton("x")
        #expect(automaton.stateCount == 2)
        #expect(automaton.transitionCount == 1)
        #expect(automaton.hasSuffix("x"))
        #expect(automaton.occurrenceCount(of: "") == 1)
        let one: Int64 = 1
        #expect(automaton.distinctSubstringCount == one)
    }

    @Test("A text of one repeated symbol is a chain of states, one per length")
    func allEqual() {
        let n = 50
        let automaton = SuffixAutomaton([UInt8](repeating: 9, count: n))
        #expect(automaton.stateCount == n + 1)
        #expect(automaton.transitionCount == n)
        #expect(automaton.occurrenceCount(of: [9, 9, 9]) == n - 2)
        let distinct = Int64(n)
        #expect(automaton.distinctSubstringCount == distinct)
    }

    @Test("Symbols that are only Hashable are found, with transitions in the order symbols first occur")
    func hashableSymbols() {
        struct Token: Hashable {
            let name: String
        }
        let text = ["to", "be", "or", "not", "to", "be"].map(Token.init)
        let automaton = SuffixAutomaton(text)
        let toBe = [Token(name: "to"), Token(name: "be")]
        #expect(automaton.occurrenceCount(of: toBe) == 2)
        #expect(automaton.hasSuffix(toBe))
        #expect(!automaton.contains([Token(name: "question")]))
        let graph = automaton.transitionsView
        let firstSymbols = graph.outEdges(of: 0).map { graph.symbol(ofEdgeAt: $0).name }
        let expected: [String] = ["to", "be", "or", "not"]
        #expect(firstSymbols == expected)
    }

}

@Suite("SuffixAutomaton: properties")
struct SuffixAutomatonPropertyTests {
    @Test("Membership, counts and first places match a naive set of substrings, within the size bounds", .tags(.randomized))
    func matchesNaive() async {
        let text = Gen.int(in: 0 ... 3).array(of: 0 ... 50)
        let pattern = Gen.int(in: 0 ... 4).array(of: 0 ... 5)
        await propertyCheck(count: 300, input: text, pattern) { text, pattern in
            let automaton = SuffixAutomaton(text)
            let n = text.count
            if n >= 2 {
                #expect(automaton.stateCount <= 2 * n - 1)
            }
            if n >= 3 {
                #expect(automaton.transitionCount <= 3 * n - 4)
            }
            var substrings = Set<[Int]>()
            for start in 0 ..< n {
                for end in start + 1 ... n {
                    substrings.insert(Array(text[start ..< end]))
                }
            }
            #expect(automaton.distinctSubstringCount == Int64(substrings.count))
            #expect(automaton.distinctSubstringCount == SuffixArray(text).distinctSubstringCount)

            let starts = (0 ..< n).filter { $0 + pattern.count <= n && Array(text[$0 ..< $0 + pattern.count]) == pattern }
            #expect(automaton.contains(pattern) == (pattern.isEmpty || !starts.isEmpty))
            #expect(automaton.occurrenceCount(of: pattern) == starts.count)
            #expect(automaton.occurrenceCount(of: pattern) == SuffixArray(text).occurrences(of: pattern).count)
            if !pattern.isEmpty {
                #expect(automaton.firstOccurrence(of: pattern) == starts.first.map { $0 ..< $0 + pattern.count })
            }
            let isSuffix = pattern.count <= n && Array(text.suffix(pattern.count)) == pattern
            #expect(automaton.hasSuffix(pattern) == isSuffix)

            // The transitions spell exactly the substrings: paths from the start state, counted by
            // dynamic programming over the graph in order of length, number the distinct
            // substrings plus the empty one.
            let graph = automaton.transitionsView
            let order = graph.vertices.sorted { graph.length(of: $0) < graph.length(of: $1) }
            var paths = [Int64](repeating: 0, count: graph.vertexCount)
            paths[0] = 1
            for state in order {
                for edge in graph.outEdges(of: state) {
                    paths[graph.target(ofEdgeAt: edge)] += paths[state]
                }
            }
            #expect(paths.reduce(0, +) == Int64(substrings.count) + 1)
        }
    }

    @Test("The longest common substring with another text matches a direct search", .tags(.randomized))
    func longestCommonSubstringMatchesNaive() async {
        let text = Gen.int(in: 0 ... 2).array(of: 0 ... 30)
        await propertyCheck(count: 300, input: text, text) { first, second in
            let automaton = SuffixAutomaton(first)
            var longest = 0
            for start in second.indices {
                for end in start + 1 ... second.count {
                    let piece = Array(second[start ..< end])
                    let inFirst = first.count >= piece.count
                        && (0 ... first.count - piece.count).contains { Array(first[$0 ..< $0 + piece.count]) == piece }
                    if inFirst {
                        longest = max(longest, piece.count)
                    }
                }
            }
            let common = automaton.longestCommonSubstring(with: second)
            #expect((common?.textRange.count ?? 0) == longest)
            if let common {
                #expect(Array(first[common.textRange]) == Array(second[common.otherRange]))
            }
        }
    }
}
