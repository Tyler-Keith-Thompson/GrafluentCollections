// The cost of recency tracking: 10⁶ seeded reads and writes, 90% reads over 12,500 keys, on an
// LRUCache of capacity 10,000 (about 80% of reads hit) against the same operations on a plain
// Dictionary, which keeps every key and tracks no order. The cache must stay within 4× of
// the Dictionary; the gap measured on a laptop is about 1.5×, so the bound leaves room for
// a busy machine. The two sides are timed in alternating rounds, each keeping its fastest of
// five. The timing runs only in an optimized build; a debug build runs 10⁴ operations.

import Caches
import GrafluentCollectionsTestSupport
import Testing

@Suite("LRUCache against Dictionary")
struct LRUCacheRatioTests {
    @Test("LRUCache: 10⁶ mixed reads and writes stay within 4× of a Dictionary", .timeLimit(.minutes(1)))
    func overheadIsBounded() async {
        await Task {
            #if DEBUG
            let n = 10_000
            #else
            let n = 1_000_000
            #endif
            var rng = SeededRandomNumberGenerator(seed: 23)
            let keys = (0 ..< n).map { _ in Int.random(in: 0 ..< 12_500, using: &rng) }
            let isRead = (0 ..< n).map { _ in Int.random(in: 0 ..< 10, using: &rng) != 0 }

            func library() -> Int {
                var cache = LRUCache<Int, Int>(capacity: 10_000)
                var hits = 0
                for k in 0 ..< n {
                    if isRead[k] {
                        if let value = cache[keys[k]] { hits &+= value }
                    } else {
                        cache[keys[k]] = k
                    }
                }
                return hits
            }
            func dictionary() -> Int {
                var table: [Int: Int] = [:]
                var hits = 0
                for k in 0 ..< n {
                    if isRead[k] {
                        if let value = table[keys[k]] { hits &+= value }
                    } else {
                        table[keys[k]] = k
                    }
                }
                return hits
            }
            // The cache forgets some keys the Dictionary keeps, so it hits no more often.
            #expect(library() <= dictionary())

            #if !DEBUG
            let clock = ContinuousClock()
            var libraryTime = Duration.seconds(1_000), baselineTime = Duration.seconds(1_000)
            var sink = 0
            for _ in 0 ..< 5 {
                libraryTime = min(libraryTime, clock.measure { sink &+= library() })
                baselineTime = min(baselineTime, clock.measure { sink &+= dictionary() })
            }
            #expect(sink != 1)
            let slowdown = libraryTime / baselineTime
            #expect(slowdown < 4, "LRUCache was \(slowdown)× as slow as a Dictionary")
            #endif
        }.value
    }
}
