// swift-tools-version: 6.3
import PackageDescription

// Benchmarks live in their own package so the library and its tests never depend on the
// benchmark framework. Run them with `just bench`; see Benchmarks/README.md.

let package = Package(
    name: "GrafluentCollectionsBenchmarks",
    platforms: [.macOS(.v15)],
    dependencies: [
        // Named, so the identity does not depend on the checkout directory's name.
        .package(name: "GrafluentCollections", path: ".."),
        .package(url: "https://github.com/ordo-one/benchmark", from: "1.27.0"),
    ],
    targets: [
        .executableTarget(
            name: "BinarySearchTreesBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "BinarySearchTrees", package: "GrafluentCollections"),
            ],
            path: "Benchmarks/BinarySearchTreesBenchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]
        ),
        .executableTarget(
            name: "BTreesBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "BTrees", package: "GrafluentCollections"),
                .product(name: "BinarySearchTrees", package: "GrafluentCollections"),
            ],
            path: "Benchmarks/BTreesBenchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]
        ),
        .executableTarget(
            name: "SkipListsBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "SkipLists", package: "GrafluentCollections"),
                .product(name: "BinarySearchTrees", package: "GrafluentCollections"),
            ],
            path: "Benchmarks/SkipListsBenchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]
        ),
        .executableTarget(
            name: "TriesBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "Tries", package: "GrafluentCollections"),
            ],
            path: "Benchmarks/TriesBenchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]
        ),
        .executableTarget(
            name: "SuffixStructuresBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "SuffixStructures", package: "GrafluentCollections"),
            ],
            path: "Benchmarks/SuffixStructuresBenchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]
        ),
        .executableTarget(
            name: "DecisionDiagramsBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "DecisionDiagrams", package: "GrafluentCollections"),
            ],
            path: "Benchmarks/DecisionDiagramsBenchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]
        ),
        .executableTarget(
            name: "RangeTreesBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "RangeTrees", package: "GrafluentCollections"),
            ],
            path: "Benchmarks/RangeTreesBenchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]
        ),
        .executableTarget(
            name: "SpatialTreesBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "SpatialTrees", package: "GrafluentCollections"),
            ],
            path: "Benchmarks/SpatialTreesBenchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]
        ),
        .executableTarget(
            name: "RopesBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "Ropes", package: "GrafluentCollections"),
            ],
            path: "Benchmarks/RopesBenchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]
        ),
        .executableTarget(
            name: "PersistentTreesBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "BinarySearchTrees", package: "GrafluentCollections"),
                .product(name: "PersistentTrees", package: "GrafluentCollections"),
            ],
            path: "Benchmarks/PersistentTreesBenchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]
        ),
    ]
)
