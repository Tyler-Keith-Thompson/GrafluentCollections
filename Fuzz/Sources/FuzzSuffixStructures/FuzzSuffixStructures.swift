// SuffixArray, SuffixTree and SuffixAutomaton on a short text over a small alphabet, against
// sorting the suffixes and scanning every offset: the positions, LCPs, distinct-substring count
// and longest repeat; every pattern's occurrences, count, first occurrence and suffix test; the
// longest common substring's length with a second text.

import FuzzSupport
import SuffixStructures

@main
enum FuzzSuffixStructures {
    static func main() { runFuzzer(fuzz) }

    static func fuzz(_ input: inout FuzzInput) {
        let alphabet = 1 + input.int(below: 4)
        let text = (0 ..< input.int(below: 48)).map { _ in UInt8(input.int(below: alphabet)) }
        let other = (0 ..< input.int(below: 16)).map { _ in UInt8(input.int(below: alphabet)) }
        let array = SuffixArray(text)
        let tree = SuffixTree(text)
        let automaton = SuffixAutomaton(text)

        let suffixes = text.indices.map { Array(text[$0...]) }
        let order = text.indices.sorted { suffixes[$0].lexicographicallyPrecedes(suffixes[$1]) }
        check(Array(array.positions) == order, "positions \(Array(array.positions)), sorted \(order)")
        func commonPrefix(_ a: [UInt8], _ b: [UInt8]) -> Int { zip(a, b).prefix { $0 == $1 }.count }
        let lcps = order.indices.map { $0 == 0 ? 0 : commonPrefix(suffixes[order[$0 - 1]], suffixes[order[$0]]) }
        check(Array(array.longestCommonPrefixes) == lcps, "longestCommonPrefixes")
        var substrings = Set<[UInt8]>()
        for start in text.indices {
            for end in start + 1 ... text.count { substrings.insert(Array(text[start ..< end])) }
        }
        check(array.distinctSubstringCount == Int64(substrings.count), "distinctSubstringCount")
        let longestRepeat = lcps.max() ?? 0
        check((array.longestRepeatedSubstring?.count ?? 0) == longestRepeat, "longestRepeatedSubstring")

        while !input.isEmpty {
            let pattern = (0 ..< input.int(below: 5)).map { _ in UInt8(input.int(below: alphabet)) }
            let starts = (0 ... text.count).filter { $0 + pattern.count <= text.count && Array(text[$0 ..< $0 + pattern.count]) == pattern }
            check(array.contains(pattern) == !starts.isEmpty, "SuffixArray.contains(\(pattern))")
            check(array.occurrences(of: pattern).count == (pattern.isEmpty ? text.count : starts.count), "SuffixArray.occurrences(of: \(pattern))")
            check(tree.contains(pattern) == !starts.isEmpty, "SuffixTree.contains(\(pattern))")
            if !pattern.isEmpty {
                check(Set(tree.occurrences(of: pattern).map(\.range.lowerBound)) == Set(starts), "SuffixTree.occurrences(of: \(pattern))")
                check(automaton.occurrenceCount(of: pattern) == starts.count, "SuffixAutomaton.occurrenceCount(of: \(pattern))")
                check(automaton.firstOccurrence(of: pattern)?.lowerBound == starts.first, "SuffixAutomaton.firstOccurrence(of: \(pattern))")
            }
            check(automaton.contains(pattern) == (pattern.isEmpty || !starts.isEmpty), "SuffixAutomaton.contains(\(pattern))")
            check(automaton.hasSuffix(pattern) == text.reversed().starts(with: pattern.reversed()), "SuffixAutomaton.hasSuffix(\(pattern))")
        }

        var longestCommon = 0
        for start in other.indices {
            for end in start + 1 ... other.count where substrings.contains(Array(other[start ..< end])) {
                longestCommon = max(longestCommon, end - start)
            }
        }
        let common = automaton.longestCommonSubstring(with: other)
        check((common?.textRange.count ?? 0) == longestCommon, "longestCommonSubstring length")
        if let common {
            check(Array(text[common.textRange]) == Array(other[common.otherRange]), "longestCommonSubstring ranges")
        }
    }
}
