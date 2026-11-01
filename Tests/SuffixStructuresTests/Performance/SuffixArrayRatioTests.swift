// SuffixArray construction against sorting the suffix positions with a comparison of the
// suffixes, on 10⁶ seeded random bytes over a four-letter alphabet. Induced sorting is linear and
// the comparison sort makes about twenty comparisons per suffix, so construction must be at least
// 2× faster; the gap measured on a laptop is about 5×, so the bound leaves room for a busy
// machine. The two sides are timed in alternating rounds, each keeping its fastest of five. The
// timing runs only in an optimized build; a debug build checks on 10³ bytes that both sides agree.

import GrafluentCollectionsTestSupport
import SuffixStructures
import Testing

@Suite("SuffixArray construction against a comparison sort")
struct SuffixArrayRatioTests {
    @Test("SuffixArray: init(_:) on 10⁶ bytes is at least 2× faster than sorting the suffixes by comparison", .timeLimit(.minutes(1)))
    func constructionBeatsSort() async {
        await Task {
            #if DEBUG
            let n = 1_000
            #else
            let n = 1_000_000
            #endif
            var rng = SeededRandomNumberGenerator(seed: 10)
            let letters: [UInt8] = Array("ACGT".utf8)
            let text = (0 ..< n).map { _ in letters[Int.random(in: 0 ..< 4, using: &rng)] }

            func library() -> [Int] {
                Array(SuffixArray(text).positions)
            }
            func baseline() -> [Int] {
                text.withUnsafeBufferPointer { text in
                    var order = Array(0 ..< text.count)
                    order.sort { a, b in
                        var a = a, b = b
                        while a < text.count && b < text.count {
                            if text[a] != text[b] { return text[a] < text[b] }
                            a &+= 1
                            b &+= 1
                        }
                        return a == text.count
                    }
                    return order
                }
            }
            #expect(library() == baseline())

            #if !DEBUG
            let clock = ContinuousClock()
            var libraryTime = Duration.seconds(1_000), baselineTime = Duration.seconds(1_000)
            var sink = 0
            for _ in 0 ..< 5 {
                libraryTime = min(libraryTime, clock.measure { sink &+= library()[n / 2] })
                baselineTime = min(baselineTime, clock.measure { sink &+= baseline()[n / 2] })
            }
            #expect(sink != -1)
            let speedup = baselineTime / libraryTime
            #expect(speedup > 2, "init(_:) was only \(speedup)× faster than a comparison sort")
            #endif
        }.value
    }
}
