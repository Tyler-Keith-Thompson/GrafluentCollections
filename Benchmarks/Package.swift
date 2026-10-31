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
            name: "RangeTreesBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "benchmark"),
                .product(name: "RangeTrees", package: "GrafluentCollections"),
            ],
            path: "Benchmarks/RangeTreesBenchmarks",
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]
        ),
    ]
)
