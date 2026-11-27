// swift-tools-version: 6.4
import PackageDescription

// libFuzzer targets, in their own package so the library never depends on the fuzzer runtime.
// Xcode's toolchain does not ship libFuzzer; `just fuzz` builds these with a swift.org toolchain
// installed by swiftly. See Fuzz/README.md.

// SwiftPM names a package at a path by its directory, whatever the checkout is called.
let library = String(#filePath.split(separator: "/").dropLast(2).last!)

func target(_ name: String, _ modules: [String]) -> Target {
    .executableTarget(
        name: name,
        dependencies: ["FuzzSupport"] + modules.map { .product(name: $0, package: library) }
    )
}

let package = Package(
    name: "GrafluentCollectionsFuzz",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: "..")],
    targets: [
        // libFuzzer's driver, declared in a C header (it is defined by the runtime -sanitize=fuzzer links).
        .systemLibrary(name: "CLibFuzzer", path: "Sources/CLibFuzzer"),
        .target(name: "FuzzSupport", dependencies: ["CLibFuzzer"]),
        target("FuzzBinarySearchTrees", ["BinarySearchTrees"]),
        target("FuzzBTrees", ["BTrees"]),
        target("FuzzSkipLists", ["SkipLists"]),
        target("FuzzPersistentTrees", ["PersistentTrees"]),
        target("FuzzTries", ["Tries"]),
        target("FuzzSuffixStructures", ["SuffixStructures"]),
        target("FuzzDecisionDiagrams", ["DecisionDiagrams"]),
        target("FuzzRangeTrees", ["RangeTrees"]),
        target("FuzzSpatialTrees", ["SpatialTrees"]),
        target("FuzzRopes", ["Ropes"]),
        target("FuzzCaches", ["Caches"]),
    ]
)
