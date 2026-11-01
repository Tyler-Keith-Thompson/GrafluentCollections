// Each test is self-contained: it builds its own suffix arrays and states its own expectations,
// so it can be copied into another file and still run. Nothing here is shared but the imports.

import GrafluentCollectionsTestSupport
import PropertyBased
import SuffixStructures
import Testing

@Suite("SuffixArray: hand-worked cases")
struct SuffixArrayTests {
    @Test("banana's suffixes sort to positions 5 3 1 0 4 2 with prefix lengths 0 1 3 0 0 2")
    func banana() {
        let banana = SuffixArray("banana")
        let positions: [Int] = [5, 3, 1, 0, 4, 2]
        let prefixes: [Int] = [0, 1, 3, 0, 0, 2]
        #expect(Array(banana.positions) == positions)
        #expect(Array(banana.longestCommonPrefixes) == prefixes)
        #expect(banana.count == 6)
        let ana: Range<Int> = 1 ..< 3
        #expect(banana.occurrences(of: "ana") == ana)
        let repeated: Range<Int>? = 1 ..< 4
        #expect(banana.longestRepeatedSubstring == repeated)
        let distinct: Int64 = 15
        #expect(banana.distinctSubstringCount == distinct)
        #expect(banana.contains("nan"))
        #expect(!banana.contains("nab"))
    }

    @Test("Bytes and Characters sort ASCII text the same way")
    func bytesAndCharacters() {
        let text = "mississippi"
        let bytes = SuffixArray(text.utf8)
        let characters = SuffixArray(text)
        let positions: [Int] = [10, 7, 4, 1, 0, 9, 8, 6, 3, 5, 2]
        let prefixes: [Int] = [0, 1, 1, 4, 0, 0, 1, 0, 2, 1, 3]
        #expect(Array(bytes.positions) == positions)
        #expect(Array(characters.positions) == positions)
        #expect(Array(bytes.longestCommonPrefixes) == prefixes)
        #expect(Array(characters.longestCommonPrefixes) == prefixes)
        let issi: Range<Int> = 2 ..< 4
        #expect(bytes.occurrences(of: "issi".utf8) == issi)
        #expect(characters.occurrences(of: "issi") == issi)
    }

    @Test("The empty text has no suffixes, and only the empty pattern occurs in it")
    func emptyText() {
        let empty = SuffixArray<UInt8>([UInt8]())
        #expect(empty.positions.isEmpty)
        #expect(empty.longestCommonPrefixes.isEmpty)
        let none: Range<Int> = 0 ..< 0
        #expect(empty.occurrences(of: [UInt8]()) == none)
        #expect(empty.occurrences(of: [UInt8(1)]) == none)
        #expect(empty.contains([UInt8]()))
        #expect(!empty.contains([UInt8(1)]))
        #expect(empty.longestRepeatedSubstring == nil)
        let zero: Int64 = 0
        #expect(empty.distinctSubstringCount == zero)
    }

    @Test("A one-symbol text has one suffix and repeats nothing")
    func oneSymbol() {
        let one = SuffixArray([7])
        let positions: [Int] = [0]
        let prefixes: [Int] = [0]
        #expect(Array(one.positions) == positions)
        #expect(Array(one.longestCommonPrefixes) == prefixes)
        let all: Range<Int> = 0 ..< 1
        #expect(one.occurrences(of: [Int]()) == all)
        #expect(one.occurrences(of: [7]) == all)
        #expect(one.occurrences(of: [7, 7]).isEmpty)
        #expect(one.longestRepeatedSubstring == nil)
        let distinct: Int64 = 1
        #expect(one.distinctSubstringCount == distinct)
    }

    @Test("A text of one repeated symbol sorts its suffixes shortest first, each sharing all but one symbol with the next")
    func allEqual() {
        let n = 1_000
        let text = SuffixArray([UInt8](repeating: 65, count: n))
        #expect(Array(text.positions) == Array((0 ..< n).reversed()))
        #expect(Array(text.longestCommonPrefixes) == Array(0 ..< n))
        let repeated: Range<Int>? = 0 ..< n - 1
        #expect(text.longestRepeatedSubstring == repeated)
        let distinct = Int64(n)
        #expect(text.distinctSubstringCount == distinct)
        let threes = text.occurrences(of: [UInt8](repeating: 65, count: 3))
        #expect(threes.count == n - 2)
    }

    @Test("A Fibonacci word, whose LMS substrings repeat at every level of the recursion, sorts like a direct comparison")
    func fibonacciWord() {
        var previous: [UInt8] = [1]
        var word: [UInt8] = [0]
        while word.count < 3_000 {
            (previous, word) = (word, word + previous)
        }
        let suffixes = SuffixArray(word)
        let n = word.count
        func precedes(_ a: Int, _ b: Int) -> Bool {
            word[a...].lexicographicallyPrecedes(word[b...])
        }
        let sorted = (0 ..< n).sorted(by: precedes)
        #expect(Array(suffixes.positions) == sorted)
        var prefixes = [0]
        for k in 1 ..< n {
            prefixes.append(zip(word[sorted[k - 1]...], word[sorted[k]...]).prefix { $0 == $1 }.count)
        }
        #expect(Array(suffixes.longestCommonPrefixes) == prefixes)
    }

    @Test("Of several longest repeated substrings, the one that sorts first is reported, at its later-sorting occurrence")
    func longestRepeatedTie() {
        // "ab" (at 0 and 6) and "cd" (at 3 and 9) each occur twice, and nothing longer repeats.
        // "ab" sorts first; its suffix "abzcd" at 6 follows "abxcdyabzcd" at 0, sharing 2.
        let text = SuffixArray("abxcdyabzcd")
        let expected: Range<Int>? = 6 ..< 8
        #expect(text.longestRepeatedSubstring == expected)
    }

    @Test("Symbols that are only Comparable, such as Doubles, are ranked and sorted")
    func comparableSymbols() {
        let text = SuffixArray([2.5, -1.0, 2.5, -1.0, 0.0])
        // Suffixes: [2.5,-1,2.5,-1,0] [-1,2.5,-1,0] [2.5,-1,0] [-1,0] [0]
        let positions: [Int] = [3, 1, 4, 2, 0]
        let prefixes: [Int] = [0, 1, 0, 0, 2]
        #expect(Array(text.positions) == positions)
        #expect(Array(text.longestCommonPrefixes) == prefixes)
    }

    @Test("Reading a position or prefix length outside the arrays traps", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            let text = SuffixArray("ab")
            _ = text.positions[2]
        }
        await #expect(processExitsWith: .failure) {
            let text = SuffixArray("ab")
            _ = text.longestCommonPrefixes[-1]
        }
    }
}

@Suite("SuffixArray: properties")
struct SuffixArrayPropertyTests {
    @Test("Positions sort the suffixes, prefix lengths match a direct comparison, and every query matches a naive scan", .tags(.randomized))
    func matchesNaive() async {
        let text = Gen.int(in: 0 ... 3).array(of: 0 ... 200)
        let pattern = Gen.int(in: 0 ... 3).array(of: 0 ... 4)
        await propertyCheck(count: 300, input: text, pattern) { text, pattern in
            let suffixes = SuffixArray(text)
            let n = text.count
            func precedes(_ a: Int, _ b: Int) -> Bool {
                text[a...].lexicographicallyPrecedes(text[b...])
            }
            let sorted = (0 ..< n).sorted(by: precedes)
            #expect(Array(suffixes.positions) == sorted)
            var prefixes: [Int] = []
            for k in 0 ..< n {
                prefixes.append(k == 0 ? 0 : zip(text[sorted[k - 1]...], text[sorted[k]...]).prefix { $0 == $1 }.count)
            }
            #expect(Array(suffixes.longestCommonPrefixes) == prefixes)

            let starts = (0 ..< n).filter { $0 + pattern.count <= n && Array(text[$0 ..< $0 + pattern.count]) == pattern }
            let found = suffixes.occurrences(of: pattern).map { suffixes.positions[$0] }.sorted()
            #expect(found == starts)
            #expect(suffixes.contains(pattern) == (pattern.isEmpty || !starts.isEmpty))

            var substrings = Set<[Int]>()
            var longest = 0
            for start in 0 ..< n {
                for end in start + 1 ... n {
                    let substring = Array(text[start ..< end])
                    if !substrings.insert(substring).inserted {
                        longest = max(longest, substring.count)
                    }
                }
            }
            #expect(suffixes.distinctSubstringCount == Int64(substrings.count))
            #expect((suffixes.longestRepeatedSubstring?.count ?? 0) == longest)
            if let repeated = suffixes.longestRepeatedSubstring {
                let symbols = Array(text[repeated])
                #expect(suffixes.occurrences(of: symbols).count >= 2)
            }
        }
    }

    @Test("A byte text and the same values as Ints sort alike", .tags(.randomized))
    func bytesMatchRanks() async {
        let text = Gen.int(in: 0 ... 255).array(of: 0 ... 500)
        await propertyCheck(count: 200, input: text) { text in
            let bytes = SuffixArray(text.map { UInt8($0) })
            let ints = SuffixArray(text)
            #expect(Array(bytes.positions) == Array(ints.positions))
            #expect(Array(bytes.longestCommonPrefixes) == Array(ints.longestCommonPrefixes))
        }
    }
}
