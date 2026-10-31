// Each test is self-contained: it builds its own dictionaries and states its own expectations, so
// it can be copied into another file and still run. Nothing here is shared but the imports.

import BinarySearchTrees
import Foundation
import GrafluentCollectionsTestSupport
import Testing
import Trees

@Suite("AVLDictionary: hand-worked cases")
struct AVLDictionaryTests {
    @Test("The subscript reads, stores, replaces and, given nil, removes a value")
    func subscriptByKey() {
        var stock: AVLDictionary = ["pear": 4, "apple": 7]
        let apples: Int? = 7
        #expect(stock["apple"] == apples)
        #expect(stock["fig"] == nil)
        stock["fig"] = 2
        stock["apple"] = 8
        stock["pear"] = nil
        let keys: [String] = ["apple", "fig"]
        let values: [Int] = [8, 2]
        #expect(stock.map(\.key) == keys)
        #expect(stock.map(\.value) == values)
        stock["absent"] = nil
        #expect(stock.count == 2)
    }

    @Test("The default subscript reads the default for an absent key and stores through it")
    func defaultSubscript() {
        var counts = AVLDictionary<Character, Int>()
        for letter in "abracadabra" {
            counts[letter, default: 0] += 1
        }
        let keys: [Character] = ["a", "b", "c", "d", "r"]
        let values: [Int] = [5, 2, 1, 1, 2]
        #expect(counts.map(\.key) == keys)
        #expect(counts.map(\.value) == values)
        let zero: Int = 0
        #expect(counts["z", default: 0] == zero)
        #expect(counts["z"] == nil)
    }

    @Test("updateValue and removeValue return the value they replace or remove")
    func updateAndRemove() {
        var dictionary: AVLDictionary = [1: "one", 2: "two"]
        #expect(dictionary.updateValue("uno", forKey: 1) == "one")
        #expect(dictionary.updateValue("three", forKey: 3) == nil)
        #expect(dictionary.removeValue(forKey: 2) == "two")
        #expect(dictionary.removeValue(forKey: 2) == nil)
        let keys: [Int] = [1, 3]
        let values: [String] = ["uno", "three"]
        #expect(dictionary.map(\.key) == keys)
        #expect(dictionary.map(\.value) == values)
    }

    @Test("Indices are ranks by key, and the bounds and ranges follow the keys")
    func ranksAndBounds() {
        let dictionary: AVLDictionary = [30: "c", 10: "a", 20: "b", 40: "d"]
        let start = dictionary.startIndex
        #expect(dictionary[start].key == 10)
        #expect(dictionary[dictionary.index(start, offsetBy: 3)].value == "d")
        let third = dictionary.index(start, offsetBy: 2)
        #expect(dictionary.index(forKey: 30) == third)
        #expect(dictionary.index(forKey: 35) == nil)
        #expect(dictionary.lowerBound(25) == third)
        #expect(dictionary.upperBound(30) == dictionary.index(start, offsetBy: 3))
        #expect(dictionary.lowerBound(45) == dictionary.endIndex)
        #expect(dictionary.distance(from: start, to: third) == 2)
        let halfOpen: [String] = ["b", "c"]
        let closed: [String] = ["b", "c", "d"]
        #expect(dictionary.elements(in: 20 ..< 40).map(\.value) == halfOpen)
        #expect(dictionary.elements(in: 20 ... 40).map(\.value) == closed)
        #expect(dictionary.first?.key == 10)
        #expect(dictionary.last?.key == 40)
    }

    @Test("remove(at:) removes the pair of that rank")
    func removeAtIndex() {
        var dictionary: AVLDictionary = [1: "a", 2: "b", 3: "c"]
        let removed = dictionary.remove(at: dictionary.index(after: dictionary.startIndex))
        #expect(removed.key == 2)
        #expect(removed.value == "b")
        let keys: [Int] = [1, 3]
        #expect(dictionary.map(\.key) == keys)
    }

    @Test("init(_:uniquingKeysWith:) merges equal keys in the order the pairs appear")
    func uniquingKeys() {
        let pairs: [(String, Int)] = [("b", 1), ("a", 2), ("b", 3), ("a", 4), ("b", 5)]
        let merged = AVLDictionary(pairs) { old, new in old * 10 + new }
        let keys: [String] = ["a", "b"]
        let values: [Int] = [24, 135]
        #expect(merged.map(\.key) == keys)
        #expect(merged.map(\.value) == values)
        let kept = AVLDictionary(pairs) { first, _ in first }
        let firstValues: [Int] = [2, 1]
        #expect(kept.map(\.value) == firstValues)
    }

    @Test("init(_:uniquingKeysWith:) passes on the error its closure throws")
    func uniquingKeysThrows() {
        struct Clash: Error, Equatable {}
        let pairs: [(Int, Int)] = [(1, 1), (1, 2)]
        #expect(throws: Clash()) {
            try AVLDictionary(pairs) { (_: Int, _: Int) throws(Clash) -> Int in throw Clash() }
        }
    }

    @Test("init(uniqueKeysWithValues:) takes pairs in any order")
    func uniqueKeys() {
        let dictionary = AVLDictionary(uniqueKeysWithValues: [(3, "c"), (1, "a"), (2, "b")])
        let values: [String] = ["a", "b", "c"]
        #expect(dictionary.map(\.value) == values)
        let ascending = AVLDictionary(uniqueKeysWithValues: (0 ..< 50).map { ($0, $0 * 2) })
        let last: Int? = 98
        #expect(ascending.count == 50)
        #expect(ascending[49] == last)
        #expect(ascending[ascending.index(before: ascending.endIndex)].value == 98)
    }

    @Test("The checked spellings throw DuplicateKey and IndexOutOfRange")
    func checkedThrows() {
        #expect(throws: DuplicateKey()) {
            try AVLDictionary(checkedUniqueKeysWithValues: [(1, "a"), (2, "b"), (1, "c")])
        }
        var dictionary: AVLDictionary = [1: "a"]
        let end = dictionary.endIndex
        let beforeStart = dictionary.startIndex.advanced(by: -1)
        #expect(throws: IndexOutOfRange()) { try dictionary[checked: end] }
        #expect(throws: IndexOutOfRange()) { try dictionary.remove(checkedAt: end) }
        #expect(throws: IndexOutOfRange()) { try dictionary.remove(checkedAt: beforeStart) }
        #expect(dictionary.count == 1)
    }

    @Test("The checked spellings agree with the plain ones on valid input")
    func checkedAgrees() throws {
        let checked = try AVLDictionary(checkedUniqueKeysWithValues: [(2, "b"), (1, "a")])
        let plain = AVLDictionary(uniqueKeysWithValues: [(2, "b"), (1, "a")])
        #expect(checked == plain)
        let checkedFirst = try checked[checked: checked.startIndex]
        let plainFirst = plain[plain.startIndex]
        #expect(checkedFirst.key == plainFirst.key)
        #expect(checkedFirst.value == plainFirst.value)
        var removing = checked
        let removed = try removing.remove(checkedAt: removing.startIndex)
        #expect(removed.key == 1)
    }

    @Test("An empty dictionary has no pairs, height 0 and no shape")
    func empty() {
        let dictionary = AVLDictionary<Int, String>()
        #expect(dictionary.isEmpty)
        #expect(dictionary.height == 0)
        #expect(dictionary[1] == nil)
        #expect(BinaryTree(dictionary) == nil)
        #expect(dictionary.description == "[:]")
        #expect(dictionary == [:])
    }

    @Test("Mutating a copy leaves the original alone", .tags(.copyOnWrite))
    func copyOnWrite() {
        let original: AVLDictionary = [1: "a", 2: "b"]
        var copy = original
        copy[3] = "c"
        copy[1] = "z"
        copy[2] = nil
        let originalValues: [String] = ["a", "b"]
        let copyValues: [String] = ["z", "c"]
        #expect(original.map(\.value) == originalValues)
        #expect(copy.map(\.value) == copyValues)
    }

    @Test("Dictionaries are equal when their pairs are, whatever their shapes", .tags(.conformance))
    func equality() {
        var inserted = AVLDictionary<Int, String>()
        for key in [4, 2, 6, 1, 3, 5, 7] {
            inserted[key] = "\(key)"
        }
        let built = AVLDictionary(uniqueKeysWithValues: (1 ... 7).map { ($0, "\($0)") })
        #expect(inserted == built)
        #expect(inserted.hashValue == built.hashValue)
        var changed = built
        changed[4] = "four"
        #expect(changed != built)
    }

    @Test("Codable round-trips the pairs as alternating keys and values", .tags(.conformance))
    func codable() throws {
        let dictionary: AVLDictionary = [2: "b", 1: "a"]
        let data = try JSONEncoder().encode(dictionary)
        let text = String(decoding: data, as: UTF8.self)
        let expected = #"[1,"a",2,"b"]"#
        #expect(text == expected)
        let decoded = try JSONDecoder().decode(AVLDictionary<Int, String>.self, from: data)
        #expect(decoded == dictionary)
    }

    @Test("Decoding throws on a duplicate key or a key without a value", .tags(.conformance))
    func codableErrors() {
        let duplicate = Data(#"[1,"a",1,"b"]"#.utf8)
        let dangling = Data(#"[1,"a",2]"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AVLDictionary<Int, String>.self, from: duplicate)
        }
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AVLDictionary<Int, String>.self, from: dangling)
        }
    }

    @Test("The description is the pairs written as a dictionary literal", .tags(.conformance))
    func description() {
        let dictionary: AVLDictionary = [2: "b", 1: "a"]
        let expected = #"[1: "a", 2: "b"]"#
        #expect(dictionary.description == expected)
    }

    @Test("The plain spellings trap on duplicate keys and invalid indices", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = AVLDictionary(uniqueKeysWithValues: [(1, "a"), (1, "b")])
        }
        await #expect(processExitsWith: .failure) {
            let dictionary: AVLDictionary = [1: "a", 1: "b"]
            _ = dictionary.count
        }
        await #expect(processExitsWith: .failure) {
            let dictionary: AVLDictionary = [1: "a"]
            _ = dictionary[dictionary.endIndex]
        }
        await #expect(processExitsWith: .failure) {
            var dictionary: AVLDictionary = [1: "a"]
            dictionary.remove(at: dictionary.endIndex)
        }
    }
}
