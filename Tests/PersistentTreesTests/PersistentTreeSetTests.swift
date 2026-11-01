// Tests for PersistentTreeSet and PersistentTreeDictionary. Each test builds its own versions and
// checks them against a hand-worked answer or the standard library's Set and Dictionary, so it
// can be copied into another file and still run. Nothing here is shared but the imports.

import Foundation
import GrafluentCollectionsTestSupport
import PersistentTrees
import PropertyBased
import Testing
import Trees

@Suite("PersistentTreeSet: hand-worked cases")
struct PersistentTreeSetTests {
    @Test("Every version stays readable after later versions change")
    func versions() {
        let empty = PersistentTreeSet<Int>()
        let one = empty.inserting(5)
        let two = one.inserting(3)
        let three = two.removing(5)
        let none: [Int] = [], five = [5], both = [3, 5], three3 = [3]
        #expect(Array(empty) == none)
        #expect(Array(one) == five)
        #expect(Array(two) == both)
        #expect(Array(three) == three3)
        #expect(two.contains(5))
        #expect(!three.contains(5))
        let same = two.inserting(3)
        #expect(same._root === two._root)
        let unchanged = two.removing(4)
        #expect(unchanged._root === two._root)
    }

    @Test("An insertion makes new vertices only along its path and shares the rest")
    func structuralSharing() {
        let base = PersistentTreeSet(0 ..< 1_024)
        let next = base.inserting(2_000)
        func vertices(_ set: PersistentTreeSet<Int>) -> Set<ObjectIdentifier> {
            var seen: Set<ObjectIdentifier> = []
            var stack = [set._root].compactMap { $0 }
            while let node = stack.popLast() {
                seen.insert(ObjectIdentifier(node))
                if let left = node.left { stack.append(left) }
                if let right = node.right { stack.append(right) }
            }
            return seen
        }
        let old = vertices(base), new = vertices(next)
        let fresh = new.subtracting(old).count
        let height = BinaryTree(next).map { $0.height + 1 } ?? 0
        #expect(fresh <= height + 2)
        let shared = new.intersection(old).count
        #expect(shared >= 1_024 - height)
    }

    @Test("Set operations match the standard library and keep shared subtrees whole")
    func setOperations() {
        let a = PersistentTreeSet(Swift.stride(from: 0, to: 100, by: 2))
        let b = PersistentTreeSet(Swift.stride(from: 0, to: 100, by: 3))
        let sa = Set(Swift.stride(from: 0, to: 100, by: 2)), sb = Set(Swift.stride(from: 0, to: 100, by: 3))
        #expect(Array(a.union(b)) == sa.union(sb).sorted())
        #expect(Array(a.intersection(b)) == sa.intersection(sb).sorted())
        #expect(Array(a.subtracting(b)) == sa.subtracting(sb).sorted())
        #expect(Array(a.symmetricDifference(b)) == sa.symmetricDifference(sb).sorted())
        #expect(a.union(a)._root === a._root)
        #expect(a.intersection(a)._root === a._root)
        #expect(a.subtracting(a).isEmpty)
        #expect(a.symmetricDifference(a).isEmpty)
        let grown = a.inserting(1)
        #expect(a.isSubset(of: grown))
        #expect(grown.isSuperset(of: a))
        #expect(!grown.isSubset(of: a))
        #expect(_PersistentNode.isValid(a.union(b)._root))
    }

    @Test("Ranks, bounds, ranges, min and max")
    func ranks() {
        let set: PersistentTreeSet = [10, 20, 30, 40]
        let two = 2, three = 3
        #expect(set.lowerBound(30) == two)
        #expect(set.upperBound(30) == three)
        #expect(set.lowerBound(25) == two)
        let middle = [20, 30]
        #expect(Array(set.elements(in: 15 ..< 35)) == middle)
        #expect(Array(set.elements(in: 20 ... 30)) == middle)
        let smallest: Int? = 10, largest: Int? = 40
        #expect(set.min() == smallest)
        #expect(set.max() == largest)
        let thirty = 30
        #expect(set[2] == thirty)
        let none: Int? = nil
        #expect(PersistentTreeSet<Int>().min() == none)
        #expect(PersistentTreeSet<Int>().max() == none)
    }

    @Test("SetAlgebra mutations report what they did")
    func setAlgebra() {
        var set: PersistentTreeSet = [3, 1, 2, 3]
        let three = 3
        #expect(set.count == three)
        #expect(set.insert(4).inserted)
        #expect(!set.insert(4).inserted)
        let four: Int? = 4, missing: Int? = nil
        #expect(set.update(with: 4) == four)
        #expect(set.update(with: 9) == missing)
        let nine: Int? = 9
        #expect(set.remove(9) == nine)
        #expect(set.remove(9) == missing)
        let removed = 1
        #expect(set.remove(at: 0) == removed)
        let rest = [2, 3, 4]
        #expect(Array(set) == rest)
        let description = "[2, 3, 4]"
        #expect(set.description == description)
        let copy: PersistentTreeSet = [4, 3, 2]
        #expect(set == copy)
        #expect(set.hashValue == copy.hashValue)
        #expect(BinaryTree(PersistentTreeSet<Int>()) == nil)
    }

    @Test("The checked spellings throw IndexOutOfRange and change nothing")
    func checkedSpellings() throws {
        var set: PersistentTreeSet = [1, 2]
        #expect(throws: IndexOutOfRange()) { try set[checked: 2] }
        #expect(throws: IndexOutOfRange()) { try set.remove(checkedAt: -1) }
        let two = 2
        #expect(set.count == two)
        let first = 1
        #expect(try set[checked: 0] == first)
        #expect(try set.remove(checkedAt: 0) == first)
    }

    @Test("Codable round-trips the elements")
    func codable() throws {
        let set: PersistentTreeSet = ["b", "a", "c"]
        let data = try JSONEncoder().encode(set)
        let decoded = try JSONDecoder().decode(PersistentTreeSet<String>.self, from: data)
        #expect(decoded == set)
    }

}

@Suite("PersistentTreeDictionary: hand-worked cases")
struct PersistentTreeDictionaryTests {
    @Test("Versions keep their own values")
    func versions() {
        let prices: PersistentTreeDictionary = ["pear": 4, "apple": 7]
        let sale = prices.updatingValue(5, forKey: "apple")
        let seven: Int? = 7, five: Int? = 5, none: Int? = nil
        #expect(prices["apple"] == seven)
        #expect(sale["apple"] == five)
        let keys = ["apple", "pear"]
        #expect(sale.map(\.key) == keys)
        let gone = sale.removingValue(forKey: "pear")
        #expect(gone["pear"] == none)
        let four: Int? = 4
        #expect(sale["pear"] == four)
        #expect(gone.removingValue(forKey: "fig")._root === gone._root)
    }

    @Test("Mutations, default subscripts, indices and merging")
    func mutations() throws {
        var stock: PersistentTreeDictionary<String, Int> = [:]
        stock["fig"] = 2
        stock["apple", default: 0] += 1
        stock["apple", default: 0] += 1
        let two: Int? = 2, none: Int? = nil
        #expect(stock["apple"] == two)
        #expect(stock.updateValue(3, forKey: "fig") == two)
        #expect(stock.removeValue(forKey: "kiwi") == none)
        stock["fig"] = nil
        let one = 1
        #expect(stock.count == one)
        let index = try #require(stock.index(forKey: "apple"))
        #expect(stock[index].key == "apple")
        #expect(stock.index(forKey: "fig") == nil)
        let more: PersistentTreeDictionary = ["apple": 10, "kiwi": 1]
        let merged = stock.merging(more) { $0 + $1 }
        let total: Int? = 12
        #expect(merged["apple"] == total)
        #expect(merged.description == #"["apple": 12, "kiwi": 1]"#)
        let combined = PersistentTreeDictionary([(1, "a"), (1, "b"), (0, "c")]) { $0 + $1 }
        let ab: String? = "ab"
        #expect(combined[1] == ab)
        #expect(throws: DuplicateKey()) { try PersistentTreeDictionary(checkedUniqueKeysWithValues: [(1, "a"), (1, "b")]) }
        #expect(throws: IndexOutOfRange()) { try combined[checked: combined.endIndex] }
        let range = [1]
        #expect(combined.elements(in: 1 ..< 5).map(\.key) == range)
        #expect(combined.elements(in: 1 ... 1).map(\.key) == range)
        let twoKeys: Int? = 2
        #expect(BinaryTree(combined)?.vertexCount == twoKeys)
        let data = try JSONEncoder().encode(merged)
        #expect(try JSONDecoder().decode(PersistentTreeDictionary<String, Int>.self, from: data) == merged)
    }
}

@Suite("PersistentTreeSet: properties")
struct PersistentTreeSetPropertyTests {
    @Test("A random edit history keeps every version equal to its Set snapshot and balanced", .tags(.randomized))
    func historyMatchesSnapshots() async {
        let operations = Gen.int(in: 0 ... 1_000_000).array(of: 0 ... 200)
        await propertyCheck(count: 200, input: operations) { operations in
            var versions = [PersistentTreeSet<Int>()]
            var snapshots = [Set<Int>()]
            for operation in operations {
                let source = operation % versions.count
                let value = operation / 7 % 64
                var version = versions[source], snapshot = snapshots[source]
                switch operation / 449 % 4 {
                case 0:
                    version = version.removing(value)
                    snapshot.remove(value)
                case 1:
                    let other = versions[operation / 1_801 % versions.count]
                    version = version.union(other)
                    snapshot.formUnion(snapshots[operation / 1_801 % versions.count])
                default:
                    version = version.inserting(value)
                    snapshot.insert(value)
                }
                versions.append(version)
                snapshots.append(snapshot)
            }
            for (version, snapshot) in zip(versions, snapshots) {
                #expect(Array(version) == snapshot.sorted())
                #expect(_PersistentNode.isValid(version._root))
            }
            let a = versions[versions.count / 2], b = versions[versions.count - 1]
            let sa = snapshots[versions.count / 2], sb = snapshots[versions.count - 1]
            #expect(Array(a.intersection(b)) == sa.intersection(sb).sorted())
            #expect(Array(a.subtracting(b)) == sa.subtracting(sb).sorted())
            #expect(Array(a.symmetricDifference(b)) == sa.symmetricDifference(sb).sorted())
            #expect(_PersistentNode.isValid(a.symmetricDifference(b)._root))
            #expect(a.isSubset(of: b) == sa.isSubset(of: sb))
        }
    }

    @Test("Joins of very different sizes stay balanced", .tags(.randomized))
    func unevenJoins() async {
        let sizes = Gen.int(in: 0 ... 2_000).array(of: 2 ... 2)
        await propertyCheck(count: 100, input: sizes) { sizes in
            let big = PersistentTreeSet(0 ..< sizes[0])
            let small = PersistentTreeSet((0 ..< sizes[1] / 50).map { $0 * 97 })
            for result in [big.union(small), small.union(big), big.intersection(small), big.subtracting(small), big.symmetricDifference(small)] {
                #expect(_PersistentNode.isValid(result._root))
            }
            #expect(Array(big.union(small)) == Set(big).union(Set(small)).sorted())
        }
    }
}
