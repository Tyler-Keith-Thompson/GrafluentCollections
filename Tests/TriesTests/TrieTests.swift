// Each test is self-contained: it builds its own tries and states its own expectations, so it can
// be copied into another file and still run. Nothing here is shared but the imports. The
// invariant tests read the vertices from `package` storage.

import Foundation
import GrafluentCollectionsTestSupport
import Testing
import Tries
import Trees

@Suite("Trie: hand-worked cases")
struct TrieTests {
    @Test("Inserting words makes them members, and reports what was inserted")
    func insert() {
        var words = Trie<Character>()
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
        let words = Trie(["pear", "apple", "fig", "app", "banana", "apricot"])
        let expected: [String] = ["app", "apple", "apricot", "banana", "fig", "pear"]
        #expect(words.map { String($0) } == expected)
    }

    @Test("Keys come in the order their branches were added when the symbols are not Comparable")
    func insertionOrder() {
        struct Color: Hashable {
            var name: String
        }
        let red = Color(name: "red"), green = Color(name: "green"), blue = Color(name: "blue")
        let paths = Trie([[green, red], [red], [green, blue], [blue]])
        let expected: [[Color]] = [[green, red], [green, blue], [red], [blue]]
        #expect(Array(paths) == expected)
    }

    @Test("A key that is a prefix of another comes before it, and both are members")
    func prefixKeys() {
        let words = Trie(["cart", "car", "ca"])
        let expected: [String] = ["ca", "car", "cart"]
        #expect(words.map { String($0) } == expected)
        #expect(words.contains("car"))
        #expect(words.contains("ca"))
        #expect(!words.contains("c"))
    }

    @Test("The empty key is a member like any other, at the root")
    func emptyKey() {
        var words = Trie<Character>()
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
        let words = Trie(["car", "cart", "carbon", "cat", "dog", "ca"])
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
        let words = Trie(["car", "dog"])
        #expect(words.hasPrefix("ca"))
        #expect(words.hasPrefix("car"))
        #expect(words.hasPrefix(""))
        #expect(!words.hasPrefix("cars"))
        #expect(!words.hasPrefix("x"))
        #expect(!Trie<Character>().hasPrefix(""))
    }

    @Test("longestPrefix(of:) is the longest key that starts the query, the query included")
    func longestPrefix() {
        let words = Trie(["a", "car", "cart", "carton"])
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
        #expect(Trie<Character>().longestPrefix(of: "car") == nil)
    }

    @Test("Removing a key prunes the branch no other key needs, and keeps the rest")
    func removePrunes() {
        var words = Trie(["car", "cart", "cat"])
        let verticesBefore = words._core.vertexCount
        let removed: [Character]? = Array("cart")
        #expect(words.remove("cart") == removed)
        #expect(words._core.vertexCount == verticesBefore - 1)
        #expect(words.remove("car") == Array("car"))
        // "car" ends where "cat" branches off, so only its last vertex goes.
        #expect(words._core.vertexCount == verticesBefore - 2)
        #expect(words.remove("cat") == Array("cat"))
        #expect(words._core.vertexCount == 1)
        #expect(words.isEmpty)
        #expect(words.remove("cat") == nil)
    }

    @Test("Removing an absent key, or a prefix that is not a key, changes nothing")
    func removeAbsent() {
        var words = Trie(["cart"])
        #expect(words.remove("car") == nil)
        #expect(words.remove("carts") == nil)
        #expect(words.remove("dog") == nil)
        #expect(words.count == 1)
        #expect(words.contains("cart"))
        #expect(words._core.vertexCount == 5)
    }

    @Test("Unicode.Scalar keys split what Character keys hold whole")
    func scalarsAndCharacters() {
        let decomposed = "e\u{301}"
        let characters = Trie([decomposed, "e"])
        let scalars = Trie([decomposed.unicodeScalars, "e".unicodeScalars])
        #expect(characters.count == 2)
        #expect(scalars.count == 2)
        // As Characters, "é" and "e" are siblings; as scalars, "e" is a prefix of "é".
        #expect(characters.elements(withPrefix: "e").count == 1)
        #expect(scalars.elements(withPrefix: "e".unicodeScalars).count == 2)
        #expect(characters._core.vertexCount == 3)
        #expect(scalars._core.vertexCount == 3)
        let precomposed = "\u{E9}"
        #expect(characters.contains(precomposed))
        #expect(!scalars.contains(precomposed.unicodeScalars))
    }

    @Test("Set algebra agrees with Set on two overlapping tries")
    func setAlgebra() {
        let a = Trie(["car", "cart", "cat", "dog"])
        let b = Trie(["cat", "dog", "cow"])
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
        #expect(a.isDisjoint(with: Trie(["x"])))
    }

    @Test("Mutating a copy leaves the original alone", .tags(.copyOnWrite))
    func copyOnWrite() {
        let original = Trie(["car", "cat"])
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
        var words = Trie((0 ..< 100).map { String($0) })
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
        let one = Trie([[red], [blue, red]])
        let other = Trie([[blue, red], [red]])
        #expect(Array(one) != Array(other))
        #expect(one == other)
        #expect(one.hashValue == other.hashValue)
        #expect(one != Trie([[red]]))
        #expect(Trie(["ab"]) != Trie(["ba"]))
    }

    @Test("Codable round-trips the keys as arrays of symbols", .tags(.conformance))
    func codable() throws {
        let words = Trie([[1, 2], [1], [3]])
        let data = try JSONEncoder().encode(words)
        let asArrays = try JSONDecoder().decode([[Int]].self, from: data)
        let expected: [[Int]] = [[1], [1, 2], [3]]
        #expect(asArrays == expected)
        let decoded = try JSONDecoder().decode(Trie<Int>.self, from: data)
        #expect(decoded == words)
    }

    @Test("The description is the keys written as arrays", .tags(.conformance))
    func description() {
        let words: Trie<Int> = [[2], [1, 2]]
        let expected = "[[1, 2], [2]]"
        #expect(words.description == expected)
    }

    @Test("PrefixTree(_:) has a vertex per prefix, an edge per symbol, and the keys' ends", .tags(.fixture))
    func prefixTreeShape() {
        let words = Trie(["car", "cart", "cat"])
        let shape = PrefixTree(words)
        // The prefixes: "", c, ca, car, cart, cat.
        #expect(shape.arborescence.vertexCount == 6)
        #expect(shape.arborescence.vertexCount == words._core.vertexCount)
        #expect(shape.sequenceEnds.count == 3)
        let ends = shape.sequenceEnds.map { end in
            var symbols: [Character] = []
            var vertex = end
            while vertex != 0 {
                symbols.append(shape.symbol(ofEdgeAt: vertex - 1))
                vertex = shape.arborescence.parent(of: vertex)!
            }
            return String(symbols.reversed())
        }
        let expected: [String] = ["car", "cart", "cat"]
        #expect(ends == expected)
        #expect(shape.sequenceEnds.allSatisfy { shape.isSequenceEnd($0) })
        #expect(!shape.isSequenceEnd(0))
        #expect(PrefixTree(Trie<Character>()).arborescence.vertexCount == 1)
    }

    @Test("Counts, chains, parents and sorted children hold after every seeded operation", .tags(.randomized))
    func invariantsUnderRandomOperations() {
        var rng = SeededRandomNumberGenerator(seed: 7)
        var trie = Trie<UInt8>()
        var reference = Set<[UInt8]>()
        for step in 0 ..< 2_000 {
            let length = Int.random(in: 0 ... 5, using: &rng)
            let key = (0 ..< length).map { _ in UInt8.random(in: 0 ..< 4, using: &rng) }
            if step >= 300 && Bool.random(using: &rng) {
                #expect(trie.remove(key) == reference.remove(key))
            } else {
                #expect(trie.insert(key).inserted == reference.insert(key).inserted)
            }
            let core = trie._core
            var reached = 0
            var countMismatches = 0
            var parentMismatches = 0
            var unsortedChains = 0
            var deadLeaves = 0
            var stack: [Int32] = [0]
            while let vertex = stack.popLast() {
                reached += 1
                var keysBelow = core.values[Int(vertex)] == nil ? 0 : 1
                var child = core.firstChildren[Int(vertex)]
                var previous: UInt8?
                if child < 0 && vertex != 0 && core.values[Int(vertex)] == nil { deadLeaves += 1 }
                while child >= 0 {
                    if core.parents[Int(child)] != vertex { parentMismatches += 1 }
                    let symbol = core.symbols[Int(child) - 1]
                    if let previous, !(previous < symbol) { unsortedChains += 1 }
                    previous = symbol
                    keysBelow += Int(core.counts[Int(child)])
                    stack.append(child)
                    child = core.nextSiblings[Int(child)]
                }
                if keysBelow != Int(core.counts[Int(vertex)]) { countMismatches += 1 }
            }
            #expect(reached == core.vertexCount, "unreachable vertices at step \(step)")
            #expect(countMismatches == 0, "a count is wrong at step \(step)")
            #expect(parentMismatches == 0, "a parent link is wrong at step \(step)")
            #expect(unsortedChains == 0, "children out of order at step \(step)")
            #expect(deadLeaves == 0, "a leaf with no key at step \(step)")
            #expect(trie.count == reference.count)
        }
        let sorted = reference.sorted { $0.lexicographicallyPrecedes($1) }
        #expect(Array(trie) == sorted)
    }
}
