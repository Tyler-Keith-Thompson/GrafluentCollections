// Property tests against naive references: a Set and a sorted array of distinct elements. Each
// test is self-contained; see TreapTests.swift.

import BinarySearchTrees
import GrafluentCollectionsTestSupport
import PropertyBased
import Testing

@Suite("Treap: properties")
struct TreapPropertyTests {
    @Test("After any inserts and removes, the treap holds the Set's elements in sorted order", .tags(.randomized))
    func matchesSet() async {
        let operations = zip(Gen.int(in: 0 ... 2), Gen.int(in: 0 ... 60)).array(of: 0 ... 120)
        await propertyCheck(count: 400, input: operations) { operations in
            var treap = Treap<Int>()
            var reference = Set<Int>()
            for (kind, element) in operations {
                switch kind {
                case 0, 1:
                    #expect(treap.insert(element).inserted == reference.insert(element).inserted)
                default:
                    #expect(treap.remove(element) == reference.remove(element))
                }
            }
            let sorted = reference.sorted()
            #expect(Array(treap) == sorted)
            #expect(Array(treap.reversed()) == Array(sorted.reversed()))
            for (index, element) in sorted.enumerated() {
                #expect(treap[index] == element)
                #expect(treap.firstIndex(of: element) == index)
            }
            for probe in -1 ... 61 {
                #expect(treap.contains(probe) == reference.contains(probe))
                #expect(treap.lowerBound(probe) == (sorted.firstIndex { $0 >= probe } ?? sorted.count))
            }
            #expect(treap == Treap(sorted))
        }
    }

    @Test("Removing by index removes the element of that rank in the sorted array", .tags(.randomized))
    func removeAtMatchesArray() async {
        let elements = Gen.int(in: 0 ... 1_000).array(of: 1 ... 80)
        let removals = Gen.int(in: 0 ... 1_000).array(of: 0 ... 40)
        await propertyCheck(count: 300, input: elements, removals) { elements, removals in
            var treap = Treap(elements)
            var reference = Array(Set(elements)).sorted()
            for removal in removals where !reference.isEmpty {
                let index = removal % reference.count
                #expect(treap.remove(at: index) == reference.remove(at: index))
            }
            #expect(Array(treap) == reference)
        }
    }

    @Test("Set algebra matches Set's on any two treaps", .tags(.randomized))
    func setAlgebraMatchesSet() async {
        let elements = Gen.int(in: 0 ... 40).array(of: 0 ... 40)
        await propertyCheck(count: 200, input: elements, elements) { a, b in
            let left = Treap(a)
            let right = Treap(b)
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
            var treap = Treap(elements)
            for point in points {
                var parts = treap.split(at: point)
                #expect(Array(parts.lower) == sorted.filter { $0 < point })
                #expect(Array(parts.upper) == sorted.filter { $0 >= point })
                #expect(parts.lower.count + parts.upper.count == sorted.count)
                let joined = (try? parts.lower.join(parts.upper)) != nil
                #expect(joined)
                treap = parts.lower
                #expect(Array(treap) == sorted)
            }
        }
    }

    @Test("Inserting into and removing from the parts of a split keeps them in order", .tags(.randomized))
    func partsStayUsable() async {
        let elements = Gen.int(in: 0 ... 200).array(of: 0 ... 100)
        let operations = zip(Gen.int(in: 0 ... 1), Gen.int(in: 0 ... 200)).array(of: 0 ... 40)
        await propertyCheck(count: 200, input: elements, operations) { elements, operations in
            var parts = Treap(elements).split(at: 100)
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
