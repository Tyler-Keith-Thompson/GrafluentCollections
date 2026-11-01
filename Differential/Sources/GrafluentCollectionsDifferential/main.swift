// Reads {"section": name, "cases": [...]} as JSON on standard input and writes one answer per
// case as a JSON array on standard output. scripts/differential.py writes the cases and checks
// the answers against Python references; Differential/README.md lists what each section asks.

import BinarySearchTrees
import BTrees
import Caches
import DecisionDiagrams
import Foundation
import PersistentTrees
import RangeTrees
import SkipLists
import SpatialTrees
import SuffixStructures
import Tries

typealias JSON = [String: Any]

let request = try JSONSerialization.jsonObject(with: FileHandle.standardInput.readDataToEndOfFile()) as! JSON
let cases = request["cases"] as! [JSON]
let answers: [Any]
switch request["section"] as! String {
case "sortedsets": answers = cases.map(sortedSet)
case "sorteddicts": answers = cases.map(sortedDictionary)
case "tries": answers = cases.map(trie)
case "ahocorasick": answers = cases.map(ahoCorasick)
case "suffix": answers = cases.map(suffix)
case "bdd": answers = cases.map(binaryDecisionDiagram)
case "intervals": answers = cases.map(intervals)
case "spatial": answers = cases.map(spatial)
case "lru": answers = cases.map(leastRecentlyUsed)
case let section: fatalError("No section \(section)")
}
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: answers))

// MARK: - Sorted sets and dictionaries

/// A sorted set's operations, so one loop drives every kind.
struct SortedSetOperations {
    var insert: (Int) -> Bool
    var remove: (Int) -> Bool
    var contains: (Int) -> Bool
    var lowerBound: (Int) -> Int
    var element: (Int) -> Int
    var count: () -> Int
    var elements: () -> [Int]
}

func operations<S: SetAlgebra & RandomAccessCollection>(_ set: S, lowerBound: @escaping (S, Int) -> Int) -> SortedSetOperations where S.Element == Int, S.Index == Int {
    var set = set
    return SortedSetOperations(
        insert: { set.insert($0).inserted },
        remove: { set.remove($0) != nil },
        contains: { set.contains($0) },
        lowerBound: { lowerBound(set, $0) },
        element: { set[$0] },
        count: { set.count },
        elements: { Array(set) })
}

func sortedSet(_ testCase: JSON) -> Any {
    let set: SortedSetOperations
    switch testCase["structure"] as! String {
    case "AVLTree": set = operations(AVLTree<Int>()) { $0.lowerBound($1) }
    case "RedBlackTree": set = operations(RedBlackTree<Int>()) { $0.lowerBound($1) }
    case "Treap": set = operations(Treap<Int>()) { $0.lowerBound($1) }
    case "SplayTree": set = operations(SplayTree<Int>()) { $0.lowerBound($1) }
    case "BTree": set = operations(BTree<Int>()) { $0.lowerBound($1) }
    case "SkipList": set = operations(SkipList<Int>()) { $0.lowerBound($1) }
    case "PersistentTreeSet": set = operations(PersistentTreeSet<Int>()) { $0.lowerBound($1) }
    case let structure: fatalError("No structure \(structure)")
    }
    var results: [Any] = []
    for operation in testCase["ops"] as! [[Any]] {
        let argument = operation[1] as! Int
        switch operation[0] as! String {
        case "insert": results.append(set.insert(argument))
        case "remove": results.append(set.remove(argument))
        case "contains": results.append(set.contains(argument))
        case "lowerBound": results.append(set.lowerBound(argument))
        default: results.append(set.count() == 0 ? NSNull() : set.element(argument % set.count()))
        }
    }
    return ["answers": results, "elements": set.elements()]
}

/// A sorted dictionary's operations, so one loop drives every kind.
struct SortedDictionaryOperations {
    var update: (Int, Int) -> Int?
    var remove: (Int) -> Int?
    var value: (Int) -> Int?
    var pairs: () -> [[Int]]
}

func sortedDictionary(_ testCase: JSON) -> Any {
    let dictionary: SortedDictionaryOperations
    switch testCase["structure"] as! String {
    case "AVLDictionary":
        var d = AVLDictionary<Int, Int>()
        dictionary = SortedDictionaryOperations(update: { d.updateValue($1, forKey: $0) }, remove: { d.removeValue(forKey: $0) }, value: { d[$0] }, pairs: { d.map { [$0.key, $0.value] } })
    case "BTreeDictionary":
        var d = BTreeDictionary<Int, Int>()
        dictionary = SortedDictionaryOperations(update: { d.updateValue($1, forKey: $0) }, remove: { d.removeValue(forKey: $0) }, value: { d[$0] }, pairs: { d.map { [$0.key, $0.value] } })
    case "PersistentTreeDictionary":
        var d = PersistentTreeDictionary<Int, Int>()
        dictionary = SortedDictionaryOperations(update: { d.updateValue($1, forKey: $0) }, remove: { d.removeValue(forKey: $0) }, value: { d[$0] }, pairs: { d.map { [$0.key, $0.value] } })
    case let structure: fatalError("No structure \(structure)")
    }
    var results: [Any] = []
    for operation in testCase["ops"] as! [[Any]] {
        let key = operation[1] as! Int
        let answer: Int?
        switch operation[0] as! String {
        case "set": answer = dictionary.update(key, operation[2] as! Int)
        case "remove": answer = dictionary.remove(key)
        default: answer = dictionary.value(key)
        }
        results.append(answer.map { $0 as Any } ?? NSNull())
    }
    return ["answers": results, "pairs": dictionary.pairs()]
}

// MARK: - Tries

func trie(_ testCase: JSON) -> Any {
    var trie = Trie<Character>()
    var radix = RadixTree<Character>()
    var trieAnswers: [Any] = [], radixAnswers: [Any] = []
    func string(_ key: [Character]?) -> Any { key.map { String($0) as Any } ?? NSNull() }
    for operation in testCase["ops"] as! [[String]] {
        let key = operation[1]
        switch operation[0] {
        case "insert":
            trieAnswers.append(trie.insert(key).inserted)
            radixAnswers.append(radix.insert(key).inserted)
        case "remove":
            trieAnswers.append(trie.remove(key) != nil)
            radixAnswers.append(radix.remove(key) != nil)
        case "contains":
            trieAnswers.append(trie.contains(key))
            radixAnswers.append(radix.contains(key))
        case "prefix":
            trieAnswers.append(trie.elements(withPrefix: key).map { String($0) }.sorted())
            radixAnswers.append(radix.elements(withPrefix: key).map { String($0) }.sorted())
        default:
            trieAnswers.append(string(trie.longestPrefix(of: key)))
            radixAnswers.append(string(radix.longestPrefix(of: key)))
        }
    }
    return ["Trie": trieAnswers, "RadixTree": radixAnswers]
}

func ahoCorasick(_ testCase: JSON) -> Any {
    let patterns = (testCase["patterns"] as! [String]).map(Array.init)
    let automaton = AhoCorasickAutomaton(patterns: patterns)
    let text = Array(testCase["text"] as! String)
    return automaton.matches(in: text)
        .map { [$0.patternIndex, $0.range.lowerBound, $0.range.upperBound] }
        .sorted { $0.lexicographicallyPrecedes($1) }
}

// MARK: - Suffix structures

func suffix(_ testCase: JSON) -> Any {
    let text = Array((testCase["text"] as! String).utf8)
    let array = SuffixArray(text)
    let tree = SuffixTree(text)
    let automaton = SuffixAutomaton(text)
    let patterns = (testCase["patterns"] as! [String]).map { Array($0.utf8) }
    return [
        "positions": Array(array.positions),
        "distinct": array.distinctSubstringCount,
        "longestRepeat": array.longestRepeatedSubstring?.count ?? 0,
        "arrayCounts": patterns.map { array.occurrences(of: $0).count },
        "treeCounts": patterns.map { tree.occurrences(of: $0).count },
        "automatonCounts": patterns.map { automaton.occurrenceCount(of: $0) },
    ]
}

// MARK: - Decision diagrams

/// Builds functions by a program of steps, each referring to earlier ones by index, and
/// answers each step's satisfying-assignment count.
func binaryDecisionDiagram(_ testCase: JSON) -> Any {
    let n = testCase["variables"] as! Int
    var diagram = BinaryDecisionDiagram(variableCount: n)
    var functions: [BinaryDecisionDiagram.Function] = []
    var counts: [Double] = []
    for step in testCase["steps"] as! [[Any]] {
        let arguments = step.dropFirst().map { $0 as! Int }
        let f: BinaryDecisionDiagram.Function
        switch step[0] as! String {
        case "var": f = diagram.variable(arguments[0])
        case "and": f = diagram.and(functions[arguments[0]], functions[arguments[1]])
        case "or": f = diagram.or(functions[arguments[0]], functions[arguments[1]])
        case "xor": f = diagram.xor(functions[arguments[0]], functions[arguments[1]])
        case "not": f = diagram.not(functions[arguments[0]])
        case "ite": f = diagram.ifThenElse(functions[arguments[0]], then: functions[arguments[1]], else: functions[arguments[2]])
        default: f = diagram.exists([arguments[1]], in: functions[arguments[0]])
        }
        functions.append(f)
        counts.append(diagram.satisfyingAssignmentCount(of: f))
    }
    return counts
}

// MARK: - Interval trees

func intervals(_ testCase: JSON) -> Any {
    var tree = IntervalTree<Int, Int>()
    var results: [Any] = []
    for operation in testCase["ops"] as! [[Any]] {
        let lower = operation[1] as! Int, upper = operation[2] as! Int
        switch operation[0] as! String {
        case "insert":
            tree.insert(lower ..< upper, value: operation[3] as! Int)
            results.append(NSNull())
        case "remove": results.append(tree.remove(lower ..< upper).map { $0 as Any } ?? NSNull())
        case "overlap": results.append(tree.overlapping(lower ..< upper).map(\.value).sorted())
        case "at": results.append(tree.containing(lower).map(\.value).sorted())
        default: results.append(tree.contained(in: lower ..< upper).map(\.value).sorted())
        }
    }
    return results
}

// MARK: - Spatial trees

func spatial(_ testCase: JSON) -> Any {
    let points = (testCase["points"] as! [[Double]]).map { SIMD2($0[0], $0[1]) }
    let tree = KDTree(points)
    var quadtree = Quadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [1, 1]), bucketCapacity: 4)
    for (k, point) in points.enumerated() {
        quadtree.insert(k, at: point)
    }
    func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { ((a - b) * (a - b)).sum().squareRoot() }
    var kd: [Any] = [], quad: [Any] = []
    for query in testCase["queries"] as! [JSON] {
        let point = (query["point"] as! [Double])
        let center = SIMD2(point[0], point[1])
        let k = query["k"] as! Int, radius = query["radius"] as! Double
        kd.append([
            "nearest": tree.nearestIndices(to: center, count: k).map { distance(points[$0], center) },
            "within": tree.indices(within: radius, of: center).sorted(),
        ])
        quad.append([
            "nearest": quadtree.nearest(to: center, count: k).map { distance($0.point, center) },
            "within": quadtree.items(within: radius, of: center).map(\.element).sorted(),
        ])
    }
    return ["KDTree": kd, "Quadtree": quad]
}

// MARK: - Caches

func leastRecentlyUsed(_ testCase: JSON) -> Any {
    var cache = LRUCache<Int, Int>(capacity: testCase["capacity"] as! Int)
    var results: [Any] = []
    for operation in testCase["ops"] as! [[Int]] {
        switch operation[0] {
        case 0: results.append(cache[operation[1]].map { $0 as Any } ?? NSNull())
        case 1:
            cache[operation[1]] = operation[2]
            results.append(NSNull())
        case 2: results.append(cache.removeValue(forKey: operation[1]).map { $0 as Any } ?? NSNull())
        default: results.append(cache.contains(operation[1]))
        }
    }
    return ["answers": results, "keys": cache.map(\.key).sorted()]
}
