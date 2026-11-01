// Property tests against a Trie built from the same keys, and a Dictionary. Each test is
// self-contained; see RadixTreeTests.swift.

import GrafluentCollectionsTestSupport
import PropertyBased
import Testing
import Tries

@Suite("RadixTree: properties")
struct RadixTreePropertyTests {
    @Test("After any inserts and removes, the radix tree answers every query as a Trie does", .tags(.randomized))
    func matchesTrie() async {
        let key = Gen.int(in: 0 ... 2).array(of: 0 ... 6)
        let operations = zip(Gen.int(in: 0 ... 2), key).array(of: 0 ... 80)
        await propertyCheck(count: 400, input: operations) { operations in
            var tree = RadixTree<Int>()
            var trie = Trie<Int>()
            for (kind, key) in operations {
                if kind == 2 {
                    #expect(tree.remove(key) == trie.remove(key))
                } else {
                    #expect(tree.insert(key).inserted == trie.insert(key).inserted)
                }
            }
            #expect(Array(tree) == Array(trie))
            #expect(tree.count == trie.count)
            for probe in [[], [0], [1], [2], [0, 1], [1, 2, 0], [0, 0, 0], [2, 2, 2, 2], [1, 0, 1, 0, 1]] as [[Int]] {
                #expect(tree.contains(probe) == trie.contains(probe))
                #expect(Array(tree.elements(withPrefix: probe)) == Array(trie.elements(withPrefix: probe)))
                #expect(tree.elements(withPrefix: probe).count == trie.elements(withPrefix: probe).count)
                #expect(tree.hasPrefix(probe) == trie.hasPrefix(probe))
                #expect(tree.longestPrefix(of: probe) == trie.longestPrefix(of: probe))
            }
            #expect(tree == RadixTree(Array(trie)))
        }
    }

    @Test("A RadixTreeDictionary stores and removes like a Dictionary keyed by arrays", .tags(.randomized))
    func dictionaryMatchesDictionary() async {
        let key = Gen.int(in: 0 ... 2).array(of: 0 ... 5)
        let operations = zip(Gen.int(in: 0 ... 3), key).array(of: 0 ... 80)
        await propertyCheck(count: 300, input: operations) { operations in
            var dictionary = RadixTreeDictionary<Int, Int>()
            var reference: [[Int]: Int] = [:]
            for (step, (kind, key)) in operations.enumerated() {
                if kind == 3 {
                    #expect(dictionary.removeValue(forKey: key) == reference.removeValue(forKey: key))
                } else {
                    #expect(dictionary.updateValue(step, forKey: key) == reference.updateValue(step, forKey: key))
                }
            }
            #expect(dictionary.count == reference.count)
            let sortedKeys = reference.keys.sorted { $0.lexicographicallyPrecedes($1) }
            #expect(dictionary.map(\.key) == sortedKeys)
            #expect(dictionary.map(\.value) == sortedKeys.map { reference[$0]! })
        }
    }
}
