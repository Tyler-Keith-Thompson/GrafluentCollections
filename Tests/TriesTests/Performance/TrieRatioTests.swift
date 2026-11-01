// Lookups in a Trie against the standard library's Set<String>: 10⁵ seeded random lowercase
// words of 3 to 10 letters and 10⁵ probes, half of them present. A Set hashes each probe once;
// the trie walks one vertex per UTF-8 byte, so it must stay within 15× of the Set. The gap
// measured on a laptop is about 6×, so the bound leaves room for a busy machine. The two
// sides are timed in alternating rounds, each keeping its fastest of seven. The timing runs only
// in an optimized build; a debug build checks on 10³ words that both sides agree.

import GrafluentCollectionsTestSupport
import Testing
import Tries

@Suite("Trie lookups against Set<String>")
struct TrieRatioTests {
    @Test("Trie<UInt8>: contains(_:) over UTF-8 stays within 15× of Set<String>", .timeLimit(.minutes(1)))
    func lookupsKeepPaceWithSet() async {
        await Task {
            #if DEBUG
            let n = 1_000
            #else
            let n = 100_000
            #endif
            var rng = SeededRandomNumberGenerator(seed: 24)
            func word() -> String {
                let length = Int.random(in: 3 ... 10, using: &rng)
                return String((0 ..< length).map { _ in Character(Unicode.Scalar(UInt8.random(in: 97 ... 122, using: &rng))) })
            }
            let words = (0 ..< n).map { _ in word() }
            let probes = (0 ..< n).map { k in k % 2 == 0 ? words[Int.random(in: 0 ..< n, using: &rng)] : word() }
            let trie = Trie(words.map(\.utf8))
            let set = Set(words)

            func library() -> Int {
                var found = 0
                for probe in probes where trie.contains(probe.utf8) {
                    found &+= 1
                }
                return found
            }
            func baseline() -> Int {
                var found = 0
                for probe in probes where set.contains(probe) {
                    found &+= 1
                }
                return found
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
            #expect(sink != 1)
            let slowdown = libraryTime / baselineTime
            #expect(slowdown < 15, "Trie lookups were \(slowdown)× as slow as Set<String>'s")
            #endif
        }.value
    }
}
