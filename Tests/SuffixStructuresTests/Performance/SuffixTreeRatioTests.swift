// SuffixTree construction against inserting every suffix into an uncompressed trie, on 2,000
// seeded random bytes over a four-letter alphabet. Ukkonen's algorithm is linear and the trie
// quadratic, so construction must be at least 20× faster; the gap measured on a laptop is about
// 65×, so the bound leaves room for a busy machine. The two sides are timed in alternating
// rounds, each keeping its fastest of seven. The timing runs only in an optimized build; a debug
// build checks on 200 bytes that the trie and the tree count the same distinct substrings.

import GrafluentCollectionsTestSupport
import SuffixStructures
import Testing

@Suite("SuffixTree construction against a suffix trie")
struct SuffixTreeRatioTests {
    @Test("SuffixTree: init(_:) on 2000 bytes is at least 20× faster than inserting every suffix into a trie", .timeLimit(.minutes(1)))
    func constructionBeatsTrie() async {
        await Task {
            #if DEBUG
            let n = 200
            #else
            let n = 2_000
            #endif
            var rng = SeededRandomNumberGenerator(seed: 11)
            let letters: [UInt8] = Array("ACGT".utf8)
            let text = (0 ..< n).map { _ in letters[Int.random(in: 0 ..< 4, using: &rng)] }

            // Both sides return the number of distinct non-empty substrings: the trie's nodes but
            // the root, and the sum of the tree's edge lengths.
            func library() -> Int {
                let tree = SuffixTree(text)
                var total = 0
                for node in tree.nodes.dropFirst() {
                    total &+= tree.edgeLabel(of: node).range.count
                }
                return total
            }
            func baseline() -> Int {
                var symbols: [UInt8] = [0]
                var firstChildren: [Int32] = [-1]
                var nextSiblings: [Int32] = [-1]
                for start in text.indices {
                    var node = 0
                    for position in start ..< text.count {
                        let symbol = text[position]
                        var child = Int(firstChildren[node])
                        while child >= 0 && symbols[child] != symbol {
                            child = Int(nextSiblings[child])
                        }
                        if child < 0 {
                            child = symbols.count
                            symbols.append(symbol)
                            firstChildren.append(-1)
                            nextSiblings.append(firstChildren[node])
                            firstChildren[node] = Int32(child)
                        }
                        node = child
                    }
                }
                return symbols.count - 1
            }
            #expect(library() == baseline())

            #if !DEBUG
            let clock = ContinuousClock()
            var libraryTime = Duration.seconds(1_000), baselineTime = Duration.seconds(1_000)
            var sink = 0
            for _ in 0 ..< 7 {
                libraryTime = min(libraryTime, clock.measure { sink &+= library() })
                baselineTime = min(baselineTime, clock.measure { sink &+= baseline() })
            }
            #expect(sink != -1)
            let speedup = baselineTime / libraryTime
            #expect(speedup > 20, "init(_:) was only \(speedup)× faster than a suffix trie")
            #endif
        }.value
    }
}
