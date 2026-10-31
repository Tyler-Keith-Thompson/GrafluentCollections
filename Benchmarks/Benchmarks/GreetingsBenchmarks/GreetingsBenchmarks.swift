import Benchmark
import Greetings

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.wallClock, .mallocCountTotal]
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)

    let names = (0 ..< 10_000).map { "name\($0)" }

    // The hand-written form the library must keep pace with.
    Benchmark("Greetings: BASELINE string interpolation") { benchmark in
        for _ in benchmark.scaledIterations {
            for name in names {
                blackHole("Good day, \(name)!")
            }
        }
    }

    Benchmark("Greetings: Greeting(name:).formal().punctuated(with:).text") { benchmark in
        for _ in benchmark.scaledIterations {
            for name in names {
                blackHole(Greeting(name: name).formal().punctuated(with: "!").text)
            }
        }
    }
}
