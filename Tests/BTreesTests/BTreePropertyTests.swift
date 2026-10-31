// Property tests against naive references: a Set and a sorted array of distinct elements. Each
// test is self-contained; see BTreeTests.swift. The inputs run to hundreds of elements, so the
// trees span several levels.

import BTrees
import GrafluentCollectionsTestSupport
import PropertyBased
import Testing

@Suite("BTree: properties")
struct BTreePropertyTests {
    @Test("After any inserts and removes, the tree holds the Set's elements in sorted order", .tags(.randomized))
    func matchesSet() async {
        let operations = zip(Gen.int(in: 0 ... 2), Gen.int(in: 0 ... 600)).array(of: 0 ... 1_200)
        await propertyCheck(count: 150, input: operations) { operations in
            var tree = BTree<Int>()
            var reference = Set<Int>()
            for (kind, element) in operations {
                switch kind {
                case 0, 1:
                    #expect(tree.insert(element).inserted == reference.insert(element).inserted)
                default:
                    #expect(tree.remove(element) == reference.remove(element))
                }
            }
            let sorted = reference.sorted()
            #expect(Array(tree) == sorted)
            #expect(Array(tree.reversed()) == Array(sorted.reversed()))
            for (index, element) in sorted.enumerated() {
                #expect(tree[index] == element)
                #expect(tree.firstIndex(of: element) == index)
            }
            for probe in -1 ... 601 {
                #expect(tree.contains(probe) == reference.contains(probe))
                #expect(tree.lowerBound(probe) == (sorted.firstIndex { $0 >= probe } ?? sorted.count))
            }
            #expect(tree == BTree(sorted))
        }
    }

    @Test("Removing by index removes the element of that rank in the sorted array", .tags(.randomized))
    func removeAtMatchesArray() async {
        let elements = Gen.int(in: 0 ... 1_000).array(of: 1 ... 800)
        let removals = Gen.int(in: 0 ... 1_000).array(of: 0 ... 400)
        await propertyCheck(count: 300, input: elements, removals) { elements, removals in
            var tree = BTree(elements)
            var reference = Array(Set(elements)).sorted()
            for removal in removals where !reference.isEmpty {
                let index = removal % reference.count
                #expect(tree.remove(at: index) == reference.remove(at: index))
            }
            #expect(Array(tree) == reference)
        }
    }

    @Test("Set algebra matches Set's on any two trees", .tags(.randomized))
    func setAlgebraMatchesSet() async {
        let elements = Gen.int(in: 0 ... 400).array(of: 0 ... 400)
        await propertyCheck(count: 200, input: elements, elements) { a, b in
            let left = BTree(a)
            let right = BTree(b)
            let setA = Set(a)
            let setB = Set(b)
            #expect(Array(left.union(right)) == setA.union(setB).sorted())
            #expect(Array(left.intersection(right)) == setA.intersection(setB).sorted())
            #expect(Array(left.symmetricDifference(right)) == setA.symmetricDifference(setB).sorted())
            #expect(Array(left.subtracting(right)) == setA.subtracting(setB).sorted())
        }
    }

    @Test("A split matches partitioning the sorted array", .tags(.randomized))
    func splitMatchesPartition() async {
        let elements = Gen.int(in: 0 ... 2_000).array(of: 0 ... 600)
        let points = Gen.int(in: -1 ... 2_001).array(of: 1 ... 5)
        await propertyCheck(count: 200, input: elements, points) { elements, points in
            let sorted = Array(Set(elements)).sorted()
            let tree = BTree(elements)
            for point in points {
                let parts = tree.split(at: point)
                #expect(Array(parts.lower) == sorted.filter { $0 < point })
                #expect(Array(parts.upper) == sorted.filter { $0 >= point })
            }
        }
    }

    @Test("After any inserts and removes on hundreds of elements, the dictionary matches Dictionary", .tags(.randomized))
    func dictionaryMatchesDictionary() async {
        let operations = zip(Gen.int(in: 0 ... 2), Gen.int(in: 0 ... 800)).array(of: 0 ... 1_500)
        await propertyCheck(count: 100, input: operations) { operations in
            var dictionary = BTreeDictionary<Int, Int>()
            var reference: [Int: Int] = [:]
            for (step, (kind, key)) in operations.enumerated() {
                if kind < 2 {
                    #expect(dictionary.updateValue(step, forKey: key) == reference.updateValue(step, forKey: key))
                } else {
                    #expect(dictionary.removeValue(forKey: key) == reference.removeValue(forKey: key))
                }
            }
            let keys = reference.keys.sorted()
            #expect(dictionary.map(\.key) == keys)
            #expect(dictionary.map(\.value) == keys.map { reference[$0]! })
            for probe in stride(from: -1, through: 801, by: 7) {
                #expect(dictionary[probe] == reference[probe])
            }
        }
    }

    @Test("Inserting into and removing from the parts of a split keeps them in order", .tags(.randomized))
    func partsStayUsable() async {
        let elements = Gen.int(in: 0 ... 200).array(of: 0 ... 100)
        let operations = zip(Gen.int(in: 0 ... 1), Gen.int(in: 0 ... 200)).array(of: 0 ... 40)
        await propertyCheck(count: 200, input: elements, operations) { elements, operations in
            var parts = BTree(elements).split(at: 100)
            var lower = Set(elements.filter { $0 < 100 })
            var upper = Set(elements.filter { $0 >= 100 })
            for (kind, element) in operations {
                if element < 100 {
                    if kind == 0 {
                        #expect(parts.lower.insert(element).inserted == lower.insert(element).inserted)
                    } else {
                        #expect(parts.lower.remove(element) == lower.remove(element))
                    }
                } else if kind == 0 {
                    #expect(parts.upper.insert(element).inserted == upper.insert(element).inserted)
                } else {
                    #expect(parts.upper.remove(element) == upper.remove(element))
                }
            }
            #expect(Array(parts.lower) == lower.sorted())
            #expect(Array(parts.upper) == upper.sorted())
        }
    }
}
