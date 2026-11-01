// Each test is self-contained: it builds its own dictionaries and states its own expectations, so
// it can be copied into another file and still run. Nothing here is shared but the imports.

import Foundation
import GrafluentCollectionsTestSupport
import Testing
import Tries
import Trees

@Suite("TrieDictionary: hand-worked cases")
struct TrieDictionaryTests {
    @Test("A value stored for the empty key of an empty dictionary is its root's, and read back")
    func emptyKeyOfEmptyDictionary() {
        // From FuzzTries: the first store into a fresh dictionary copies its storage, which once
        // started from a static literal that AddressSanitizer reported read past its end.
        var empty = TrieDictionary<UInt8, Int>()
        let none: Int? = nil
        #expect(empty.updateValue(1, forKey: [UInt8]()) == none)
        let one: Int? = 1
        #expect(empty[[UInt8]()] == one)
        let count = 1
        #expect(empty.count == count)
        var radix = RadixTreeDictionary<UInt8, Int>()
        #expect(radix.updateValue(1, forKey: [UInt8]()) == none)
        #expect(radix[[UInt8]()] == one)
    }

    @Test("The subscript reads, stores and removes values by key")
    func subscriptReadsAndWrites() {
        var routes = TrieDictionary<Character, String>()
        routes["/"] = "home"
        routes["/users"] = "users"
        let home: String? = "home"
        let users: String? = "users"
        #expect(routes["/"] == home)
        #expect(routes["/users"] == users)
        #expect(routes["/user"] == nil)
        #expect(routes.count == 2)
        routes["/users"] = "people"
        let people: String? = "people"
        #expect(routes["/users"] == people)
        #expect(routes.count == 2)
        routes["/users"] = nil
        #expect(routes["/users"] == nil)
        #expect(routes.count == 1)
        #expect(routes._core.vertexCount == 2)
    }

    @Test("The default subscript reads a default and stores through it")
    func defaultSubscript() {
        var counts = TrieDictionary<Character, Int>()
        for word in ["a", "b", "a", "ab", "a"] {
            counts[word, default: 0] += 1
        }
        let three: Int? = 3
        let one: Int? = 1
        #expect(counts["a"] == three)
        #expect(counts["ab"] == one)
        #expect(counts["c", default: 7] == 7)
        #expect(counts["c"] == nil)
    }

    @Test("updateValue and removeValue report the value they replaced or removed")
    func updateAndRemove() {
        var dictionary = TrieDictionary<Character, Int>()
        #expect(dictionary.updateValue(1, forKey: "x") == nil)
        let one: Int? = 1
        #expect(dictionary.updateValue(2, forKey: "x") == one)
        let two: Int? = 2
        #expect(dictionary.removeValue(forKey: "x") == two)
        #expect(dictionary.removeValue(forKey: "x") == nil)
        #expect(dictionary.isEmpty)
    }

    @Test("Entries come in lexicographic order of their keys, each with its value")
    func iteration() {
        let dictionary = TrieDictionary(uniqueKeysWithValues: [("pear", 3), ("apple", 1), ("app", 0)])
        let keys: [String] = ["app", "apple", "pear"]
        let values: [Int] = [0, 1, 3]
        #expect(dictionary.map { String($0.key) } == keys)
        #expect(dictionary.map(\.value) == values)
    }

    @Test("Prefix queries return the entries under a prefix and the longest key starting a query")
    func prefixQueries() {
        var routes = TrieDictionary<Character, String>()
        routes["/"] = "home"
        routes["/users"] = "user list"
        routes["/users/new"] = "new user"
        let underUsers: [String] = ["/users", "/users/new"]
        #expect(routes.elements(withPrefix: "/users").map { String($0.key) } == underUsers)
        #expect(routes.elements(withPrefix: "/u").count == 2)
        #expect(routes.hasPrefix("/us"))
        #expect(!routes.hasPrefix("/x"))
        let longest = routes.longestPrefix(of: "/users/42")
        #expect(longest.map { String($0.key) } == "/users")
        #expect(longest?.value == "user list")
        #expect(routes.longestPrefix(of: "nothing") == nil)
    }

    @Test("init(uniquingKeysWith:) combines the values of repeated keys")
    func uniquing() {
        let dictionary = TrieDictionary([("a", 1), ("b", 2), ("a", 10)], uniquingKeysWith: +)
        let eleven: Int? = 11
        #expect(dictionary["a"] == eleven)
        #expect(dictionary.count == 2)
    }

    @Test("The checked spelling throws DuplicateKey on a repeated key")
    func checkedThrows() throws {
        #expect(throws: DuplicateKey()) {
            try TrieDictionary(checkedUniqueKeysWithValues: [("a", 1), ("a", 2)])
        }
        let dictionary = try TrieDictionary(checkedUniqueKeysWithValues: [("a", 1), ("b", 2)])
        #expect(dictionary.count == 2)
    }

    @Test("Mutating a copy leaves the original alone", .tags(.copyOnWrite))
    func copyOnWrite() {
        let original = TrieDictionary(uniqueKeysWithValues: [("a", 1)])
        var copy = original
        copy["a"] = 2
        copy["b"] = 3
        let one: Int? = 1
        #expect(original["a"] == one)
        #expect(original.count == 1)
        #expect(copy.count == 2)
    }

    @Test("Dictionaries are equal when their entries are, and hash alike", .tags(.conformance))
    func equality() {
        let one = TrieDictionary(uniqueKeysWithValues: [("a", 1), ("b", 2)])
        let other = TrieDictionary(uniqueKeysWithValues: [("b", 2), ("a", 1)])
        #expect(one == other)
        #expect(one.hashValue == other.hashValue)
        #expect(one != TrieDictionary(uniqueKeysWithValues: [("a", 1), ("b", 3)]))
        let literal: TrieDictionary<Int, String> = [[1, 2]: "x", [1]: "y"]
        #expect(literal.count == 2)
    }

    @Test("Codable round-trips the entries as alternating keys and values", .tags(.conformance))
    func codable() throws {
        let dictionary: TrieDictionary<Int, String> = [[1, 2]: "x", [1]: "y"]
        let data = try JSONEncoder().encode(dictionary)
        let decoded = try JSONDecoder().decode(TrieDictionary<Int, String>.self, from: data)
        #expect(decoded == dictionary)
        let repeated = Data(#"[[1], "a", [1], "b"]"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TrieDictionary<Int, String>.self, from: repeated)
        }
    }

    @Test("PrefixTree(_:) of a dictionary is the prefix tree of its keys", .tags(.fixture))
    func prefixTreeShape() {
        let dictionary = TrieDictionary(uniqueKeysWithValues: [("ab", 1), ("a", 2)])
        let shape = PrefixTree(dictionary)
        #expect(shape.arborescence.vertexCount == 3)
        #expect(shape.sequenceEnds.count == 2)
    }
}
