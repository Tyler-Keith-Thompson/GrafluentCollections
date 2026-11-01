// SuffixAutomaton construction against a hash set of every substring, on 500 seeded random bytes
// over a four-letter alphabet. The automaton is built in linear time and the set holds a
// quadratic number of substrings, hashing each, so construction must be at least 200× faster; the
// gap measured on a laptop is about 5000×, so the bound leaves room for a busy machine. The two
// sides are timed in alternating rounds, each keeping its fastest of five. The timing runs only in
// an optimized build; a debug build checks on 60 bytes that both count the same substrings.

import GrafluentCollectionsTestSupport
import SuffixStructures
import Testing

@Suite("SuffixAutomaton construction against a set of substrings")
struct SuffixAutomatonRatioTests {
    @Test("SuffixAutomaton: init(_:) on 500 bytes is at least 200× faster than a Set of every substring", .timeLimit(.minutes(1)))
    func constructionBeatsSet() async {
        await Task {
            #if DEBUG
            let n = 60
            #else
            let n = 500
            #endif
            var rng = SeededRandomNumberGenerator(seed: 12)
            let letters: [UInt8] = Array("ACGT".utf8)
            let text = (0 ..< n).map { _ in letters[Int.random(in: 0 ..< 4, using: &rng)] }

            func library() -> Int64 {
                SuffixAutomaton(text).distinctSubstringCount
            }
            func baseline() -> Int64 {
                var substrings = Set<ArraySlice<UInt8>>()
                for start in text.indices {
                    for end in start + 1 ... text.count {
                        substrings.insert(text[start ..< end])
                    }
                }
                return Int64(substrings.count)
            }
            #expect(library() == baseline())

            #if !DEBUG
            let clock = ContinuousClock()
            var libraryTime = Duration.seconds(1_000), baselineTime = Duration.seconds(1_000)
            var sink: Int64 = 0
            for _ in 0 ..< 5 {
                libraryTime = min(libraryTime, clock.measure { sink &+= library() })
                baselineTime = min(baselineTime, clock.measure { sink &+= baseline() })
            }
            #expect(sink != -1)
            let speedup = baselineTime / libraryTime
            #expect(speedup > 200, "init(_:) was only \(speedup)× faster than a Set of every substring")
            #endif
        }.value
    }
}
