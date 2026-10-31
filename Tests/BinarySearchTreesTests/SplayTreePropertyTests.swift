// Property tests against naive references: a Set and a sorted array of distinct elements. Each
// test is self-contained; see SplayTreeTests.swift.

import BinarySearchTrees
import GrafluentCollectionsTestSupport
import PropertyBased
import Testing

@Suite("SplayTree: properties")
struct SplayTreePropertyTests {
    @Test("After any inserts, removes and accesses, the tree holds the Set's elements in sorted order", .tags(.randomized))
    func matchesSet() async {
        let operations = zip(Gen.int(in: 0 ... 3), Gen.int(in: 0 ... 60)).array(of: 0 ... 120)
        await propertyCheck(count: 400, input: operations) { operations in
            var tree = SplayTree<Int>()
            var reference = Set<Int>()
            for (kind, element) in operations {
                switch kind {
                case 0, 1:
                    #expect(tree.insert(element).inserted == reference.insert(element).inserted)
                case 2:
                    #expect(tree.remove(element) == reference.remove(element))
                default:
                    #expect(tree.access(element) == (reference.contains(element) ? element : nil))
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
            #expect(tree == SplayTree(sorted))
        }
    }

    @Test("Removing by index removes the element of that rank in the sorted array", .tags(.randomized))
    func removeAtMatchesArray() async {
        let elements = Gen.int(in: 0 ... 1_000).array(of: 1 ... 80)
        let removals = Gen.int(in: 0 ... 1_000).array(of: 0 ... 40)
        await propertyCheck(count: 300, input: elements, removals) { elements, removals in
            var tree = SplayTree(elements)
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
            let left = SplayTree(a)
            let right = SplayTree(b)
            let setA = Set(a)
            let setB = Set(b)
            #expect(Array(left.union(right)) == setA.union(setB).sorted())
            #expect(Array(left.intersection(right)) == setA.intersection(setB).sorted())
            #expect(Array(left.symmetricDifference(right)) == setA.symmetricDifference(setB).sorted())
            #expect(Array(left.subtracting(right)) == setA.subtracting(setB).sorted())
        }
    }

    @Test("A split matches partitioning the sorted array, and joining the parts restores it", .tags(.randomized))
    func splitMatchesPartition() async {
        let elements = Gen.int(in: 0 ... 200).array(of: 0 ... 100)
        let points = Gen.int(in: -1 ... 201).array(of: 1 ... 10)
        await propertyCheck(count: 300, input: elements, points) { elements, points in
            let sorted = Array(Set(elements)).sorted()
            var tree = SplayTree(elements)
            for point in points {
                var parts = tree.split(at: point)
                #expect(Array(parts.lower) == sorted.filter { $0 < point })
                #expect(Array(parts.upper) == sorted.filter { $0 >= point })
                #expect(parts.lower.count + parts.upper.count == sorted.count)
                let joined = (try? parts.lower.join(parts.upper)) != nil
                #expect(joined)
                tree = parts.lower
                #expect(Array(tree) == sorted)
            }
        }
    }

    @Test("Inserting into and removing from the parts of a split keeps them in order", .tags(.randomized))
    func partsStayUsable() async {
        let elements = Gen.int(in: 0 ... 200).array(of: 0 ... 100)
        let operations = zip(Gen.int(in: 0 ... 1), Gen.int(in: 0 ... 200)).array(of: 0 ... 40)
        await propertyCheck(count: 200, input: elements, operations) { elements, operations in
            var parts = SplayTree(elements).split(at: 100)
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
