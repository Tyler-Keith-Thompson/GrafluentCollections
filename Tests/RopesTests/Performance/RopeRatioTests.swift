// Random insertions into a Rope against Array.insert: 10⁴ seeded single-element insertions at
// random offsets into a sequence of 10⁶ Ints. Each Array insertion shifts half the array on
// average and each rope insertion one chunk, so the rope must be at least 50× faster; the gap
// measured on a laptop is about 150×, so the bound leaves room for a busy machine. The two
// sides are timed in alternating rounds, each keeping its fastest of five. The timing runs only
// in an optimized build; a debug build checks on 10⁴ elements that both sides agree.

import GrafluentCollectionsTestSupport
import Ropes
import Testing

@Suite("Rope insertions against Array.insert")
struct RopeRatioTests {
    @Test("Rope: random insertions into 10⁶ elements are at least 50× faster than Array's", .timeLimit(.minutes(1)))
    func insertionsBeatArray() async {
        await Task {
            #if DEBUG
            let n = 10_000
            let insertions = 1_000
            #else
            let n = 1_000_000
            let insertions = 10_000
            #endif
            var rng = SeededRandomNumberGenerator(seed: 21)
            let offsets = (0 ..< insertions).map { k in Int.random(in: 0 ... n + k, using: &rng) }
            let initialRope = Rope(0 ..< n)
            let initialArray = Array(0 ..< n)

            func library() -> Rope<Int> {
                var rope = initialRope
                for (k, offset) in offsets.enumerated() {
                    rope.insert(-k, at: offset)
                }
                return rope
            }
            func array() -> [Int] {
                var array = initialArray
                for (k, offset) in offsets.enumerated() {
                    array.insert(-k, at: offset)
                }
                return array
            }
            #expect(Array(library()) == array())

            #if !DEBUG
            let clock = ContinuousClock()
            var libraryTime = Duration.seconds(1_000), baselineTime = Duration.seconds(1_000)
            var sink = 0
            for _ in 0 ..< 5 {
                libraryTime = min(libraryTime, clock.measure { sink &+= library().count })
                baselineTime = min(baselineTime, clock.measure { sink &+= array().count })
            }
            #expect(sink != 1)
            let speedup = baselineTime / libraryTime
            #expect(speedup > 50, "Rope insertions were only \(speedup)× faster than Array's")
            #endif
        }.value
    }
}
