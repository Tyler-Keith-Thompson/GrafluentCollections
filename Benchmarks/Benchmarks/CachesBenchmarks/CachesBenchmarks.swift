import Benchmark
import Caches

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.wallClock, .mallocCountTotal, .instructions]
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)

    // A seeded linear congruential generator, so every run sees the same operations.
    var state: UInt64 = 23
    func next(_ bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
    // 10⁶ operations, 90% reads, over 12,500 keys: about 80% of reads hit a cache of 10⁴.
    let keys = (0 ..< 1_000_000).map { _ in next(12_500) }
    let isRead = (0 ..< 1_000_000).map { _ in next(10) != 0 }

    // The hand-written form: a Dictionary with no bound and no recency.
    Benchmark("Caches: BASELINE Dictionary, 10⁶ mixed reads and writes") { benchmark in
        for _ in benchmark.scaledIterations {
            var table: [Int: Int] = [:]
            var hits = 0
            for k in keys.indices {
                if isRead[k] {
                    if let value = table[keys[k]] { hits &+= value }
                } else {
                    table[keys[k]] = k
                }
            }
            blackHole(hits)
        }
    }

    Benchmark("Caches: LRUCache, 10⁶ mixed reads and writes at capacity 10⁴") { benchmark in
        for _ in benchmark.scaledIterations {
            var cache = LRUCache<Int, Int>(capacity: 10_000)
            var hits = 0
            for k in keys.indices {
                if isRead[k] {
                    if let value = cache[keys[k]] { hits &+= value }
                } else {
                    cache[keys[k]] = k
                }
            }
            blackHole(hits)
        }
    }

    Benchmark("Caches: LRUCache, 10⁶ writes evicting at capacity 10³") { benchmark in
        for _ in benchmark.scaledIterations {
            var cache = LRUCache<Int, Int>(capacity: 1_000)
            for k in keys.indices {
                cache[keys[k]] = k
            }
            blackHole(cache.count)
        }
    }
}
