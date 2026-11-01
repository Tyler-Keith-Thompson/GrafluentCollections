import Benchmark
import Tries

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.wallClock, .mallocCountTotal, .instructions]
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)

    // A seeded linear congruential generator, so every run sees the same words: 10⁵ of three to
    // ten lowercase letters, 10⁴ probes of which about half are words, and 10³ two-letter
    // prefixes.
    var state: UInt64 = 1
    func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int(truncatingIfNeeded: state >> 33) % bound
    }
    func word() -> String {
        let letters = (0 ..< 3 + next(below: 8)).map { _ in Character(Unicode.Scalar(UInt8(97 + next(below: 26)))) }
        return String(letters)
    }
    let words = (0 ..< 100_000).map { _ in word() }
    let probes = (0 ..< 10_000).map { k in k % 2 == 0 ? words[next(below: words.count)] : word() }
    let prefixes = (0 ..< 1_000).map { _ in String(word().prefix(2)) }
    let sorted = Array(Set(words)).sorted()
    let set = Set(words)

    // The hand-written forms the library must keep pace with.
    Benchmark("Tries: BASELINE Set<String>.contains(_:)") { benchmark in
        for _ in benchmark.scaledIterations {
            var found = 0
            for probe in probes where set.contains(probe) {
                found &+= 1
            }
            blackHole(found)
        }
    }

    Benchmark("Tries: BASELINE prefix range by binary search in a sorted array") { benchmark in
        for _ in benchmark.scaledIterations {
            var total = 0
            for prefix in prefixes {
                var low = 0
                var high = sorted.count
                while low < high {
                    let middle = low &+ (high &- low) / 2
                    if sorted[middle] < prefix {
                        low = middle &+ 1
                    } else {
                        high = middle
                    }
                }
                while low < sorted.count && sorted[low].hasPrefix(prefix) {
                    total &+= sorted[low].utf8.count
                    low &+= 1
                }
            }
            blackHole(total)
        }
    }

    Benchmark("Tries: Trie<Character>.init(_:)") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Trie(words))
        }
    }

    Benchmark("Tries: Trie<Character>.contains(_:)") { benchmark in
        let trie = Trie(words)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var found = 0
            for probe in probes where trie.contains(probe) {
                found &+= 1
            }
            blackHole(found)
        }
        benchmark.stopMeasurement()
    }

    Benchmark("Tries: Trie<UInt8>.contains(_:) over UTF-8") { benchmark in
        let trie = Trie(words.map(\.utf8))
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var found = 0
            for probe in probes where trie.contains(probe.utf8) {
                found &+= 1
            }
            blackHole(found)
        }
        benchmark.stopMeasurement()
    }

    Benchmark("Tries: Trie<Character>.elements(withPrefix:)") { benchmark in
        let trie = Trie(words)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var total = 0
            for prefix in prefixes {
                for key in trie.elements(withPrefix: prefix) {
                    total &+= key.count
                }
            }
            blackHole(total)
        }
        benchmark.stopMeasurement()
    }

    Benchmark("Tries: Trie<Character>.elements(withPrefix:).count") { benchmark in
        let trie = Trie(words)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var total = 0
            for prefix in prefixes {
                total &+= trie.elements(withPrefix: prefix).count
            }
            blackHole(total)
        }
        benchmark.stopMeasurement()
    }

    Benchmark("Tries: Trie<Character>.remove(_:) then insert(_:)") { benchmark in
        var trie = Trie(words)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for probe in probes {
                if trie.remove(probe) != nil {
                    trie.insert(probe)
                } else {
                    trie.insert(probe)
                    trie.remove(probe)
                }
            }
        }
        benchmark.stopMeasurement()
        blackHole(trie)
    }

    Benchmark("Tries: TrieDictionary<Character, Int> subscript stores") { benchmark in
        for _ in benchmark.scaledIterations {
            var counts = TrieDictionary<Character, Int>()
            for word in words {
                counts[word, default: 0] += 1
            }
            blackHole(counts)
        }
    }

    // 10⁵ file paths with long shared prefixes: four to seven components, each drawn from a few
    // dozen names, under a handful of roots.
    let roots = ["/usr/local/lib/", "/Users/someone/Library/Caches/", "/var/folders/xy/"]
    let components = (0 ..< 40).map { "component\($0)" }
    func path() -> String {
        var path = roots[next(below: roots.count)]
        for k in 0 ..< 3 + next(below: 4) {
            if k > 0 { path += "/" }
            path += components[next(below: components.count)]
        }
        return path
    }
    let paths = (0 ..< 100_000).map { _ in path() }
    let pathProbes = (0 ..< 10_000).map { k in k % 2 == 0 ? paths[next(below: paths.count)] : path() }
    let pathSet = Set(paths)

    Benchmark("Tries: BASELINE Set<String>.contains(_:) on paths") { benchmark in
        for _ in benchmark.scaledIterations {
            var found = 0
            for probe in pathProbes where pathSet.contains(probe) {
                found &+= 1
            }
            blackHole(found)
        }
    }

    Benchmark("Tries: Trie<UInt8>.contains(_:) on paths over UTF-8") { benchmark in
        let trie = Trie(paths.map(\.utf8))
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var found = 0
            for probe in pathProbes where trie.contains(probe.utf8) {
                found &+= 1
            }
            blackHole(found)
        }
        benchmark.stopMeasurement()
    }

    Benchmark("Tries: RadixTree<UInt8>.contains(_:) on paths over UTF-8") { benchmark in
        let tree = RadixTree(paths.map(\.utf8))
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var found = 0
            for probe in pathProbes where tree.contains(probe.utf8) {
                found &+= 1
            }
            blackHole(found)
        }
        benchmark.stopMeasurement()
    }

    Benchmark("Tries: Trie<UInt8>.init(_:) on paths over UTF-8") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Trie(paths.map(\.utf8)))
        }
    }

    Benchmark("Tries: RadixTree<UInt8>.init(_:) on paths over UTF-8") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(RadixTree(paths.map(\.utf8)))
        }
    }

    Benchmark("Tries: RadixTree<UInt8>.remove(_:) then insert(_:) on paths") { benchmark in
        var tree = RadixTree(paths.map(\.utf8))
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            for probe in pathProbes {
                if tree.remove(probe.utf8) != nil {
                    tree.insert(probe.utf8)
                } else {
                    tree.insert(probe.utf8)
                    tree.remove(probe.utf8)
                }
            }
        }
        benchmark.stopMeasurement()
        blackHole(tree)
    }

    Benchmark("Tries: RadixTree<Character>.elements(withPrefix:)") { benchmark in
        let tree = RadixTree(words)
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            var total = 0
            for prefix in prefixes {
                for key in tree.elements(withPrefix: prefix) {
                    total &+= key.count
                }
            }
            blackHole(total)
        }
        benchmark.stopMeasurement()
    }
}
