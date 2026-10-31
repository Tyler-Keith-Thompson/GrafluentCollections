// Property tests against naive references: a Set and a sorted array of distinct elements. Each
// test is self-contained; see RedBlackTreeTests.swift.

import BinarySearchTrees
import PropertyBased
import Testing

@Suite("RedBlackTree: properties")
struct RedBlackTreePropertyTests {
    @Test("After any inserts and removes, the tree holds the Set's elements in sorted order", .tags(.randomized))
    func matchesSet() async {
        let operations = zip(Gen.int(in: 0 ... 2), Gen.int(in: 0 ... 60)).array(of: 0 ... 120)
        await propertyCheck(count: 400, input: operations) { operations in
            var tree = RedBlackTree<Int>()
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
            for probe in -1 ... 61 {
                #expect(tree.contains(probe) == reference.contains(probe))
                #expect(tree.lowerBound(probe) == (sorted.firstIndex { $0 >= probe } ?? sorted.count))
            }
            #expect(tree == RedBlackTree(sorted))
        }
    }

    @Test("Removing by index removes the element of that rank in the sorted array", .tags(.randomized))
    func removeAtMatchesArray() async {
        let elements = Gen.int(in: 0 ... 1_000).array(of: 1 ... 80)
        let removals = Gen.int(in: 0 ... 1_000).array(of: 0 ... 40)
        await propertyCheck(count: 300, input: elements, removals) { elements, removals in
            var tree = RedBlackTree(elements)
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
        await propertyCheck(count: 200, input: elements, elements) { a, b in
            let left = RedBlackTree(a)
            let right = RedBlackTree(b)
            let setA = Set(a)
            let setB = Set(b)
            #expect(Array(left.union(right)) == setA.union(setB).sorted())
            #expect(Array(left.intersection(right)) == setA.intersection(setB).sorted())
            #expect(Array(left.symmetricDifference(right)) == setA.symmetricDifference(setB).sorted())
            #expect(Array(left.subtracting(right)) == setA.subtracting(setB).sorted())
        }
    }
}
