// Each test is self-contained: it builds its own radix trees and states its own expectations, so it can
// be copied into another file and still run. Nothing here is shared but the imports. The
// invariant tests read the vertices from `package` storage.

import Foundation
import GrafluentCollectionsTestSupport
import Testing
import Tries
import Trees

@Suite("RadixTree: hand-worked cases")
struct RadixTreeTests {
    @Test("Inserting words makes them members, and reports what was inserted")
    func insert() {
        var words = RadixTree<Character>()
        #expect(words.insert("cat").inserted)
        #expect(words.insert("car").inserted)
        #expect(!words.insert("cat").inserted)
        let memberAfterInsert: [Character] = ["c", "a", "t"]
        #expect(words.insert("cat").memberAfterInsert == memberAfterInsert)
        #expect(words.count == 2)
        #expect(words.contains("cat"))
        #expect(words.contains("car"))
        #expect(!words.contains("ca"))
        #expect(!words.contains("cats"))
        #expect(!words.contains("dog"))
    }

    @Test("Keys come in lexicographic order when the symbols are Comparable")
    func lexicographicOrder() {
        let words = RadixTree(["pear", "apple", "fig", "app", "banana", "apricot"])
        let expected: [String] = ["app", "apple", "apricot", "banana", "fig", "pear"]
        #expect(words.map { String($0) } == expected)
    }

    @Test("Keys come in the order their branches were added when the symbols are not Comparable")
    func insertionOrder() {
        struct Color: Hashable {
            var name: String
        }
        let red = Color(name: "red"), green = Color(name: "green"), blue = Color(name: "blue")
        let paths = RadixTree([[green, red], [red], [green, blue], [blue]])
        let expected: [[Color]] = [[green, red], [green, blue], [red], [blue]]
        #expect(Array(paths) == expected)
    }

    @Test("A key that is a prefix of another comes before it, and both are members")
    func prefixKeys() {
        let words = RadixTree(["cart", "car", "ca"])
        let expected: [String] = ["ca", "car", "cart"]
        #expect(words.map { String($0) } == expected)
        #expect(words.contains("car"))
        #expect(words.contains("ca"))
        #expect(!words.contains("c"))
    }

    @Test("The empty key is a member like any other, at the root")
    func emptyKey() {
        var words = RadixTree<Character>()
        #expect(!words.contains(""))
        #expect(words.insert("").inserted)
        #expect(words.contains(""))
        #expect(words.count == 1)
        words.insert("a")
        let expected: [String] = ["", "a"]
        #expect(words.map { String($0) } == expected)
        let longest: [Character]? = []
        #expect(words.longestPrefix(of: "zebra") == longest)
        let removed: [Character]? = []
        #expect(words.remove("") == removed)
        #expect(!words.contains(""))
        #expect(words.count == 1)
    }

    @Test("elements(withPrefix:) is every key with the prefix, the prefix itself included")
    func elementsWithPrefix() {
        let words = RadixTree(["car", "cart", "carbon", "cat", "dog", "ca"])
        let withCar: [String] = ["car", "carbon", "cart"]
        let withCa: [String] = ["ca", "car", "carbon", "cart", "cat"]
        let none: [String] = []
        #expect(words.elements(withPrefix: "car").map { String($0) } == withCar)
        #expect(words.elements(withPrefix: "car").count == 3)
        #expect(words.elements(withPrefix: "ca").map { String($0) } == withCa)
        #expect(words.elements(withPrefix: "cow").map { String($0) } == none)
        #expect(words.elements(withPrefix: "cow").isEmpty)
        #expect(words.elements(withPrefix: "carts").isEmpty)
        #expect(words.elements(withPrefix: "").count == words.count)
    }

    @Test("hasPrefix(_:) is whether some key starts with the prefix")
    func hasPrefix() {
        let words = RadixTree(["car", "dog"])
        #expect(words.hasPrefix("ca"))
        #expect(words.hasPrefix("car"))
        #expect(words.hasPrefix(""))
        #expect(!words.hasPrefix("cars"))
        #expect(!words.hasPrefix("x"))
        #expect(!RadixTree<Character>().hasPrefix(""))
    }

    @Test("longestPrefix(of:) is the longest key that starts the query, the query included")
    func longestPrefix() {
        let words = RadixTree(["a", "car", "cart", "carton"])
        let cart: [Character]? = Array("cart")
        let carton: [Character]? = Array("carton")
        let car: [Character]? = Array("car")
        let a: [Character]? = ["a"]
        #expect(words.longestPrefix(of: "cartoon") == cart)
        #expect(words.longestPrefix(of: "carton") == carton)
        #expect(words.longestPrefix(of: "carp") == car)
        #expect(words.longestPrefix(of: "apple") == a)
        #expect(words.longestPrefix(of: "ca") == nil)
        #expect(words.longestPrefix(of: "") == nil)
        #expect(RadixTree<Character>().longestPrefix(of: "car") == nil)
    }

    @Test("Set algebra agrees with Set on two overlapping tries")
    func setAlgebra() {
        let a = RadixTree(["car", "cart", "cat", "dog"])
        let b = RadixTree(["cat", "dog", "cow"])
        let setA: Set<[Character]> = Set(["car", "cart", "cat", "dog"].map(Array.init))
        let setB: Set<[Character]> = Set(["cat", "dog", "cow"].map(Array.init))
        #expect(Set(a.union(b)) == setA.union(setB))
        #expect(Set(a.intersection(b)) == setA.intersection(setB))
        #expect(Set(a.symmetricDifference(b)) == setA.symmetricDifference(setB))
        #expect(Set(a.subtracting(b)) == setA.subtracting(setB))
        var c = a
        c.formUnion(b)
        #expect(Set(c) == setA.union(setB))
        c = a
        c.subtract(b)
        #expect(Set(c) == setA.subtracting(setB))
        c = a
        c.formIntersection(b)
        #expect(Set(c) == setA.intersection(setB))
        c = a
        c.formSymmetricDifference(b)
        #expect(Set(c) == setA.symmetricDifference(setB))
        #expect(a.intersection(b).isSubset(of: a))
        #expect(a.isDisjoint(with: RadixTree(["x"])))
    }

    @Test("Mutating a copy leaves the original alone", .tags(.copyOnWrite))
    func copyOnWrite() {
        let original = RadixTree(["car", "cat"])
        var copy = original
        copy.insert("cow")
        copy.remove("car")
        let originalKeys: [String] = ["car", "cat"]
        let copyKeys: [String] = ["cat", "cow"]
        #expect(original.map { String($0) } == originalKeys)
        #expect(copy.map { String($0) } == copyKeys)
    }

    @Test("A unique owner mutates its storage in place", .tags(.copyOnWrite))
    func uniqueMutatesInPlace() {
        var words = RadixTree((0 ..< 100).map { String($0) })
        let before = words._core.parents.withUnsafeBufferPointer { $0.baseAddress }
        words.remove("50")
        words.insert("50")
        let after = words._core.parents.withUnsafeBufferPointer { $0.baseAddress }
        #expect(before == after)
    }

    @Test("Tries are equal when their keys are, whatever order the branches were added in", .tags(.conformance))
    func equality() {
        struct Color: Hashable {
            var name: String
        }
        let red = Color(name: "red"), blue = Color(name: "blue")
        let one = RadixTree([[red], [blue, red]])
        let other = RadixTree([[blue, red], [red]])
        #expect(Array(one) != Array(other))
        #expect(one == other)
        #expect(one.hashValue == other.hashValue)
        #expect(one != RadixTree([[red]]))
        #expect(RadixTree(["ab"]) != RadixTree(["ba"]))
    }

    @Test("Codable round-trips the keys as arrays of symbols", .tags(.conformance))
    func codable() throws {
        let words = RadixTree([[1, 2], [1], [3]])
        let data = try JSONEncoder().encode(words)
        let asArrays = try JSONDecoder().decode([[Int]].self, from: data)
        let expected: [[Int]] = [[1], [1, 2], [3]]
        #expect(asArrays == expected)
        let decoded = try JSONDecoder().decode(RadixTree<Int>.self, from: data)
        #expect(decoded == words)
    }

    @Test("The description is the keys written as arrays", .tags(.conformance))
    func description() {
        let words: RadixTree<Int> = [[2], [1, 2]]
        let expected = "[[1, 2], [2]]"
        #expect(words.description == expected)
    }

    @Test("A key that leaves a label partway splits it, and a key ending inside one splits it there")
    func splits() {
        var paths = RadixTree<Character>()
        paths.insert("/usr/bin")
        // The root and one leaf labelled with the whole key.
        #expect(paths._core.vertexCount == 2)
        paths.insert("/usr/lib")
        // "/usr/" splits off, with "bin" and "lib" below it.
        #expect(paths._core.vertexCount == 4)
        paths.insert("/usr")
        // "/usr/" splits again into "/usr" and "/".
        #expect(paths._core.vertexCount == 5)
        let expected: [String] = ["/usr", "/usr/bin", "/usr/lib"]
        #expect(paths.map { String($0) } == expected)
        #expect(paths.contains("/usr"))
        #expect(!paths.contains("/usr/"))
        #expect(paths.hasPrefix("/usr/"))
        #expect(paths.elements(withPrefix: "/usr/").count == 2)
        #expect(paths.elements(withPrefix: "/us").count == 3)
    }

    @Test("Removing a key merges a vertex left with one child and no key, and deletes a bare leaf")
    func merges() {
        var paths = RadixTree(["/usr", "/usr/bin", "/usr/lib"])
        #expect(paths._core.vertexCount == 5)
        let usr: [Character]? = Array("/usr")
        #expect(paths.remove("/usr") == usr)
        // "/usr" had one child, "/", so they merge back into "/usr/".
        #expect(paths._core.vertexCount == 4)
        paths.remove("/usr/lib")
        // The leaf goes, and "/usr/" merges with "bin".
        #expect(paths._core.vertexCount == 2)
        let rest: [String] = ["/usr/bin"]
        #expect(paths.map { String($0) } == rest)
        paths.remove("/usr/bin")
        #expect(paths._core.vertexCount == 1)
        #expect(paths.isEmpty)
    }

    @Test("Removing an absent key, or a prefix that is not a key, changes nothing")
    func removeAbsent() {
        var words = RadixTree(["cart"])
        #expect(words.remove("car") == nil)
        #expect(words.remove("carts") == nil)
        #expect(words.remove("dog") == nil)
        #expect(words.remove("") == nil)
        #expect(words.count == 1)
        #expect(words.contains("cart"))
        #expect(words._core.vertexCount == 2)
    }

    @Test("Unicode.Scalar keys split what Character keys hold whole")
    func scalarsAndCharacters() {
        let decomposed = "e\u{301}"
        let characters = RadixTree([decomposed, "e"])
        let scalars = RadixTree([decomposed.unicodeScalars, "e".unicodeScalars])
        #expect(characters.count == 2)
        #expect(scalars.count == 2)
        // As Characters, "é" and "e" are siblings; as scalars, "e" is a prefix of "é".
        #expect(characters.elements(withPrefix: "e").count == 1)
        #expect(scalars.elements(withPrefix: "e".unicodeScalars).count == 2)
        let precomposed = "\u{E9}"
        #expect(characters.contains(precomposed))
        #expect(!scalars.contains(precomposed.unicodeScalars))
    }

    @Test("Arborescence(_:) has a vertex per prefix the tree stands for, rooted at the empty one", .tags(.fixture))
    func arborescenceShape() {
        let paths = RadixTree(["/usr/bin", "/usr/lib", "/var"])
        let shape = Arborescence(paths)
        let empty: [Character] = []
        #expect(shape.root == empty)
        #expect(shape.vertexCount == paths._core.vertexCount)
        let usr: [Character] = Array("/usr/")
        let bin: [Character] = Array("/usr/bin")
        let slash: [Character] = ["/"]
        #expect(shape.parent(of: bin) == usr)
        #expect(shape.parent(of: usr) == slash)
        #expect(shape.parent(of: slash) == empty)
        #expect(Arborescence(RadixTree<Character>()).vertexCount == 1)
    }

    @Test("Compression, counts, chains, parents and labels hold after every seeded operation", .tags(.randomized))
    func invariantsUnderRandomOperations() {
        var rng = SeededRandomNumberGenerator(seed: 8)
        var tree = RadixTree<UInt8>()
        var reference = Set<[UInt8]>()
        for step in 0 ..< 2_000 {
            let length = Int.random(in: 0 ... 6, using: &rng)
            let key = (0 ..< length).map { _ in UInt8.random(in: 0 ..< 3, using: &rng) }
            if step >= 300 && Bool.random(using: &rng) {
                #expect(tree.remove(key) == reference.remove(key))
            } else {
                #expect(tree.insert(key).inserted == reference.insert(key).inserted)
            }
            let core = tree._core
            var reached = 0
            var countMismatches = 0
            var parentMismatches = 0
            var unsortedChains = 0
            var uncompressed = 0
            var emptyLabels = 0
            var keysFound = Set<[UInt8]>()
            var stack: [(vertex: Int32, prefix: [UInt8])] = [(0, [])]
            while let (vertex, prefix) = stack.popLast() {
                reached += 1
                if core.values[Int(vertex)] != nil { keysFound.insert(prefix) }
                var keysBelow = core.values[Int(vertex)] == nil ? 0 : 1
                var children = 0
                var child = core.firstChildren[Int(vertex)]
                var previous: UInt8?
                while child >= 0 {
                    children += 1
                    if core.parents[Int(child)] != vertex { parentMismatches += 1 }
                    let start = Int(core.labelStarts[Int(child)])
                    let length = Int(core.labelLengths[Int(child)])
                    if length == 0 { emptyLabels += 1 }
                    let label = Array(core.labels[start ..< start + length])
                    if let first = label.first {
                        if let previous, !(previous < first) { unsortedChains += 1 }
                        previous = first
                    }
                    keysBelow += Int(core.counts[Int(child)])
                    stack.append((child, prefix + label))
                    child = core.nextSiblings[Int(child)]
                }
                if vertex != 0 && core.values[Int(vertex)] == nil && children < 2 { uncompressed += 1 }
                if keysBelow != Int(core.counts[Int(vertex)]) { countMismatches += 1 }
            }
            #expect(reached == core.vertexCount, "unreachable vertices at step \(step)")
            #expect(countMismatches == 0, "a count is wrong at step \(step)")
            #expect(parentMismatches == 0, "a parent link is wrong at step \(step)")
            #expect(unsortedChains == 0, "children out of order at step \(step)")
            #expect(uncompressed == 0, "a vertex with no key and fewer than two children at step \(step)")
            #expect(emptyLabels == 0, "an empty label below the root at step \(step)")
            #expect(keysFound == reference, "the labels spell other keys at step \(step)")
            #expect(core.labels.count <= max(64, 2 * core.liveSymbols) + 64, "the label buffer grew unbounded at step \(step)")
        }
        let sorted = reference.sorted { $0.lexicographicallyPrecedes($1) }
        #expect(Array(tree) == sorted)
    }
}
