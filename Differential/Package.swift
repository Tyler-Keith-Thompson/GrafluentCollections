// swift-tools-version: 6.3
import PackageDescription

// Differential testing against Python references: this executable answers a batch of cases
// with the library, and scripts/differential.py asks the references the same questions and
// compares. In its own package so the library never depends on Foundation's JSON coding. See
// Differential/README.md.

let products: [Target.Dependency] = [
    "BinarySearchTrees", "BTrees", "SkipLists", "PersistentTrees", "Tries", "SuffixStructures",
    "DecisionDiagrams", "RangeTrees", "SpatialTrees", "Caches",
].map { .product(name: $0, package: "GrafluentCollections") }

let package = Package(
    name: "GrafluentCollectionsDifferential",
    platforms: [.macOS(.v15)],
    dependencies: [.package(name: "GrafluentCollections", path: "..")],
    targets: [.executableTarget(name: "GrafluentCollectionsDifferential", dependencies: products)]
)
