// Property tests against naive references: a Set of arrays filtered with starts(with:), and a
// Dictionary. Each test is self-contained; see TrieTests.swift.

import GrafluentCollectionsTestSupport
import PropertyBased
import Testing
import Tries

@Suite("Trie: properties")
struct TriePropertyTests {
    @Test("After any inserts and removes, the trie answers like a Set of arrays", .tags(.randomized))
    func matchesSet() async {
        let key = Gen.int(in: 0 ... 2).array(of: 0 ... 4)
        let operations = zip(Gen.int(in: 0 ... 2), key).array(of: 0 ... 80)
        await propertyCheck(count: 400, input: operations) { operations in
            var trie = Trie<Int>()
            var reference = Set<[Int]>()
            for (kind, key) in operations {
                if kind == 2 {
                    #expect(trie.remove(key) == reference.remove(key))
                } else {
                    #expect(trie.insert(key).inserted == reference.insert(key).inserted)
                }
            }
            let sorted = reference.sorted { $0.lexicographicallyPrecedes($1) }
            #expect(Array(trie) == sorted)
            #expect(trie.count == reference.count)
            for probe in [[], [0], [1], [2], [0, 1], [1, 2, 0], [2, 2, 2, 2]] as [[Int]] {
                #expect(trie.contains(probe) == reference.contains(probe))
                let withPrefix = sorted.filter { $0.starts(with: probe) }
                #expect(Array(trie.elements(withPrefix: probe)) == withPrefix)
                #expect(trie.elements(withPrefix: probe).count == withPrefix.count)
                #expect(trie.hasPrefix(probe) == !withPrefix.isEmpty)
                let longest = reference.filter { probe.starts(with: $0) }.max { $0.count < $1.count }
                #expect(trie.longestPrefix(of: probe) == longest)
            }
            #expect(trie == Trie(sorted))
        }
    }

    @Test("A byte trie with wide fan-out answers like a Set of arrays through inserts, removes and reinserts", .tags(.randomized))
    func bytesMatchSet() async {
        // Twelve byte values, so vertices pass eight children and take a row of byte links, and
        // removals drop them below eight and back.
        let key = Gen.int(in: 0 ... 11).array(of: 0 ... 3)
        let operations = zip(Gen.int(in: 0 ... 2), key).array(of: 0 ... 200)
        await propertyCheck(count: 300, input: operations) { operations in
            var trie = Trie<UInt8>()
            var reference = Set<[UInt8]>()
            for (kind, key) in operations {
                let bytes = key.map { UInt8(truncatingIfNeeded: $0 * 20) }
                if kind == 2 {
                    #expect(trie.remove(bytes) == reference.remove(bytes))
                } else {
                    #expect(trie.insert(bytes).inserted == reference.insert(bytes).inserted)
                }
            }
            let sorted = reference.sorted { $0.lexicographicallyPrecedes($1) }
            #expect(Array(trie) == sorted)
            #expect(trie.count == reference.count)
            for first in 0 ..< 13 {
                for second in 0 ..< 13 {
                    let probe = [UInt8(truncatingIfNeeded: first * 20), UInt8(truncatingIfNeeded: second * 20)]
                    #expect(trie.contains(probe) == reference.contains(probe))
                    let withPrefix = sorted.filter { $0.starts(with: probe) }
                    #expect(Array(trie.elements(withPrefix: probe)) == withPrefix)
                    let longest = reference.filter { probe.starts(with: $0) }.max { $0.count < $1.count }
                    #expect(trie.longestPrefix(of: probe) == longest)
                }
            }
            for member in sorted {
                #expect(trie.contains(member))
            }
            #expect(trie == Trie(sorted))
        }
    }

    @Test("A TrieDictionary stores and removes like a Dictionary keyed by arrays", .tags(.randomized))
    func dictionaryMatchesDictionary() async {
        let key = Gen.int(in: 0 ... 2).array(of: 0 ... 4)
        let operations = zip(Gen.int(in: 0 ... 3), key).array(of: 0 ... 80)
        await propertyCheck(count: 300, input: operations) { operations in
            var dictionary = TrieDictionary<Int, Int>()
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
