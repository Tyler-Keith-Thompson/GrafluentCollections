import Benchmark
import Ropes

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.wallClock, .mallocCountTotal, .instructions]
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)

    // A seeded linear congruential generator, so every run sees the same offsets.
    var state: UInt64 = 21
    func next(_ bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound + 1))
    }
    // Offsets for the k-th insertion, each at most the length before it. The Array sides are
    // 10³ insertions so that a simulated run of the shifting stays short.
    let millionOffsets = (0 ..< 1_000).map { k in next(1_000_000 + k) }
    let tenMillionOffsets = (0 ..< 100_000).map { k in next(10_000_000 + k) }
    let textOffsets = (0 ..< 1_000).map { k in next(100_000 + k) }
    let million = Array(0 ..< 1_000_000)
    let millionRope = Rope(million)
    let tenMillionRope = Rope(0 ..< 10_000_000)
    let text = String(repeating: "lorem ipsum dolor sit amet, ", count: 100_000 / 28 + 1).prefix(100_000)
    let textRope = Rope(text)

    // The hand-written form: Array.insert, shifting the tail.
    Benchmark("Ropes: BASELINE Array.insert, 10³ random insertions into 10⁶") { benchmark in
        for _ in benchmark.scaledIterations {
            var array = million
            for (k, offset) in millionOffsets.enumerated() {
                array.insert(k, at: offset)
            }
            blackHole(array)
        }
    }

    Benchmark("Ropes: Rope.insert, 10³ random insertions into 10⁶") { benchmark in
        for _ in benchmark.scaledIterations {
            var rope = millionRope
            for (k, offset) in millionOffsets.enumerated() {
                rope.insert(k, at: offset)
            }
            blackHole(rope)
        }
    }

    Benchmark("Ropes: Rope.insert, 10⁵ random insertions into 10⁷") { benchmark in
        for _ in benchmark.scaledIterations {
            var rope = tenMillionRope
            for (k, offset) in tenMillionOffsets.enumerated() {
                rope.insert(k, at: offset)
            }
            blackHole(rope)
        }
    }

    Benchmark("Ropes: BASELINE String insertions, 10³ random insertions into 10⁵ characters") { benchmark in
        for _ in benchmark.scaledIterations {
            var string = String(text)
            for offset in textOffsets {
                string.insert("x", at: string.index(string.startIndex, offsetBy: offset))
            }
            blackHole(string)
        }
    }

    Benchmark("Ropes: Rope<Character> insertions, 10³ random insertions into 10⁵ characters") { benchmark in
        for _ in benchmark.scaledIterations {
            var rope = textRope
            for offset in textOffsets {
                rope.insert("x", at: offset)
            }
            blackHole(rope)
        }
    }

    Benchmark("Ropes: Rope.init(_:) of 10⁶ elements") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Rope(million))
        }
    }

    Benchmark("Ropes: iterating 10⁶ elements") { benchmark in
        for _ in benchmark.scaledIterations {
            var sum = 0
            for element in millionRope {
                sum &+= element
            }
            blackHole(sum)
        }
    }

    Benchmark("Ropes: BASELINE iterating an Array of 10⁶ elements") { benchmark in
        for _ in benchmark.scaledIterations {
            var sum = 0
            for element in million {
                sum &+= element
            }
            blackHole(sum)
        }
    }
}
