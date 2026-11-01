// Trie, RadixTree and TrieDictionary against a Set and a Dictionary of keys over a three-letter
// alphabet (so keys share prefixes and nest), and AhoCorasickAutomaton against a scan of every
// pattern at every offset. After every operation the keys and every prefix query must agree.

import FuzzSupport
import Tries

@main
enum FuzzTries {
    static func main() { runFuzzer(fuzz) }

    static func key(_ input: inout FuzzInput) -> [UInt8] {
        (0 ..< input.int(below: 5)).map { _ in UInt8(input.int(below: 3)) }
    }

    static func fuzz(_ input: inout FuzzInput) {
        switch input.int(below: 3) {
        case 0: sets(&input)
        case 1: dictionary(&input)
        default: automaton(&input)
        }
    }

    static func sets(_ input: inout FuzzInput) {
        var trie = Trie<UInt8>()
        var radix = RadixTree<UInt8>()
        var model = Set<[UInt8]>()
        var snapshot: (Trie<UInt8>, RadixTree<UInt8>, Set<[UInt8]>)?
        while !input.isEmpty {
            let key = key(&input)
            switch input.int(below: 6) {
            case 0, 1, 2:
                let inserted = model.insert(key).inserted
                check(trie.insert(key).inserted == inserted, "Trie.insert(\(key))")
                check(radix.insert(key).inserted == inserted, "RadixTree.insert(\(key))")
            case 3, 4:
                let removed = model.remove(key)
                check(trie.remove(key) == removed, "Trie.remove(\(key))")
                check(radix.remove(key) == removed, "RadixTree.remove(\(key))")
            default:
                snapshot = (trie, radix, model)
            }
            let withPrefix = Set(model.filter { $0.starts(with: key) })
            check(Set(trie.elements(withPrefix: key)) == withPrefix, "Trie.elements(withPrefix: \(key))")
            check(Set(radix.elements(withPrefix: key)) == withPrefix, "RadixTree.elements(withPrefix: \(key))")
            check(trie.hasPrefix(key) == !withPrefix.isEmpty && radix.hasPrefix(key) == !withPrefix.isEmpty, "hasPrefix(\(key))")
            let longest = model.filter { key.starts(with: $0) }.max { $0.count < $1.count }
            check(trie.longestPrefix(of: key) == longest && radix.longestPrefix(of: key) == longest, "longestPrefix(of: \(key))")
            check(trie.contains(key) == model.contains(key) && radix.contains(key) == model.contains(key), "contains(\(key))")
            check(Set(trie) == model && Set(radix) == model, "keys")
            check(trie.count == model.count && radix.count == model.count, "count")
        }
        if let (trieCopy, radixCopy, saved) = snapshot {
            check(Set(trieCopy) == saved && Set(radixCopy) == saved, "the snapshot changed")
        }
    }

    static func dictionary(_ input: inout FuzzInput) {
        var trie = TrieDictionary<UInt8, Int>()
        var model: [[UInt8]: Int] = [:]
        var serial = 0
        while !input.isEmpty {
            let key = key(&input)
            serial += 1
            switch input.int(below: 4) {
            case 0, 1:
                check(trie.updateValue(serial, forKey: key) == model.updateValue(serial, forKey: key), "updateValue(forKey: \(key))")
            case 2:
                check(trie.removeValue(forKey: key) == model.removeValue(forKey: key), "removeValue(forKey: \(key))")
            default:
                check(trie[key] == model[key], "subscript(\(key))")
            }
            check(trie.count == model.count, "count")
        }
        for (key, value) in model {
            check(trie[key] == value, "subscript(\(key))")
        }
    }

    static func automaton(_ input: inout FuzzInput) {
        let patterns = (0 ..< 1 + input.int(below: 6)).map { _ in [UInt8(input.int(below: 3))] + key(&input) }
        let text = (0 ..< input.int(below: 40)).map { _ in UInt8(input.int(below: 3)) }
        let automaton = AhoCorasickAutomaton(patterns: patterns)
        var expected = Set<AhoCorasickAutomaton<UInt8>.Match>()
        for (index, pattern) in patterns.enumerated() {
            for start in 0 ... text.count where start + pattern.count <= text.count && Array(text[start ..< start + pattern.count]) == pattern {
                expected.insert(AhoCorasickAutomaton<UInt8>.Match(patternIndex: index, range: start ..< start + pattern.count))
            }
        }
        let found = Array(automaton.matches(in: text))
        check(Set(found) == expected, "matches \(found), expected \(expected.sorted { $0.range.lowerBound < $1.range.lowerBound })")
        check(found.count == expected.count, "a match reported twice")
        check(automaton.containsMatch(in: text) == !expected.isEmpty, "containsMatch")
    }
}
