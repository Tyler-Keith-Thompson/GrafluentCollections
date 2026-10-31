// Property tests against naive references: a Set, a sorted array of distinct elements and a
// Dictionary. Each test is self-contained; see AVLTreeTests.swift.

import BinarySearchTrees
import GrafluentCollectionsTestSupport
import PropertyBased
import Testing

@Suite("AVLTree and AVLDictionary: properties")
struct AVLTreePropertyTests {
    @Test("After any inserts and removes, the tree holds the Set's elements in sorted order", .tags(.randomized))
    func matchesSet() async {
        let operations = zip(Gen.int(in: 0 ... 2), Gen.int(in: 0 ... 60)).array(of: 0 ... 120)
        await propertyCheck(count: 400, input: operations) { operations in
            var tree = AVLTree<Int>()
            var reference = Set<Int>()
            for (kind, element) in operations {
                switch kind {
                case 0, 1:
                    let (inserted, member) = tree.insert(element)
                    #expect(inserted == reference.insert(element).inserted)
                    #expect(member == element)
                default:
                    #expect(tree.remove(element) == reference.remove(element))
                }
            }
            let sorted = reference.sorted()
            #expect(Array(tree) == sorted)
            #expect(tree.count == sorted.count)
            #expect(Array(tree.reversed()) == Array(sorted.reversed()))
            for (index, element) in sorted.enumerated() {
                #expect(tree[index] == element)
                #expect(tree.firstIndex(of: element) == index)
            }
            for probe in -1 ... 61 {
                #expect(tree.contains(probe) == reference.contains(probe))
                #expect(tree.lowerBound(probe) == (sorted.firstIndex { $0 >= probe } ?? sorted.count))
                #expect(tree.upperBound(probe) == (sorted.firstIndex { $0 > probe } ?? sorted.count))
            }
            #expect(tree.min() == sorted.first)
            #expect(tree.max() == sorted.last)
        }
    }

    @Test("Removing by index removes the element of that rank in the sorted array", .tags(.randomized))
    func removeAtMatchesArray() async {
        let elements = Gen.int(in: 0 ... 1_000).array(of: 1 ... 80)
        let removals = Gen.int(in: 0 ... 1_000).array(of: 0 ... 40)
        await propertyCheck(count: 300, input: elements, removals) { elements, removals in
            var tree = AVLTree(elements)
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
        let elements = Gen.int(in: 0 ... 40).array(of: 0 ... 40)
        await propertyCheck(count: 300, input: elements, elements) { a, b in
            let left = AVLTree(a)
            let right = AVLTree(b)
            let setA = Set(a)
            let setB = Set(b)
            #expect(Array(left.union(right)) == setA.union(setB).sorted())
            #expect(Array(left.intersection(right)) == setA.intersection(setB).sorted())
            #expect(Array(left.symmetricDifference(right)) == setA.symmetricDifference(setB).sorted())
            #expect(Array(left.subtracting(right)) == setA.subtracting(setB).sorted())
            #expect(left.isSubset(of: right) == setA.isSubset(of: setB))
            #expect(left.isDisjoint(with: right) == setA.isDisjoint(with: setB))
            #expect((left == right) == (setA == setB))
        }
    }

    @Test("The tree built from a sequence equals the tree built by inserting it", .tags(.randomized))
    func buildMatchesInserts() async {
        let elements = Gen.int(in: -50 ... 50).array(of: 0 ... 100)
        await propertyCheck(count: 300, input: elements) { elements in
            var inserted = AVLTree<Int>()
            for element in elements {
                inserted.insert(element)
            }
            let built = AVLTree(elements)
            #expect(built == inserted)
            #expect(built.hashValue == inserted.hashValue)
            #expect(Array(built) == Array(Set(elements)).sorted())
        }
    }

    @Test("After any stores and removals, the dictionary matches a Dictionary sorted by key", .tags(.randomized))
    func dictionaryMatchesDictionary() async {
        let operations = zip(Gen.int(in: 0 ... 2), Gen.int(in: 0 ... 40), Gen.int(in: 0 ... 1_000)).array(of: 0 ... 120)
        await propertyCheck(count: 400, input: operations) { operations in
            var dictionary = AVLDictionary<Int, Int>()
            var reference: [Int: Int] = [:]
            for (kind, key, value) in operations {
                switch kind {
                case 0:
                    #expect(dictionary.updateValue(value, forKey: key) == reference.updateValue(value, forKey: key))
                case 1:
                    dictionary[key, default: 0] += value
                    reference[key, default: 0] += value
                default:
                    #expect(dictionary.removeValue(forKey: key) == reference.removeValue(forKey: key))
                }
            }
            let keys = reference.keys.sorted()
            #expect(dictionary.map(\.key) == keys)
            #expect(dictionary.map(\.value) == keys.map { reference[$0]! })
            for probe in -1 ... 41 {
                #expect(dictionary[probe] == reference[probe])
            }
            let rebuilt = AVLDictionary(uniqueKeysWithValues: reference.map { ($0.key, $0.value) })
            #expect(rebuilt == dictionary)
        }
    }
}
