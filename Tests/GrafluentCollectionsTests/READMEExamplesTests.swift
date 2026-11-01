// The README's examples, verbatim, so the README cannot drift from the code.

import GrafluentCollections
import Testing
import Trees

@Suite("README examples")
struct READMEExamplesTests {
    @Test("Usage: prefix sums, range sums, an add and a lower bound")
    func usage() {
        var scores: FenwickTree = [3, 1, 4, 1, 5, 9, 2, 6]
        let first: Int = 9
        let range: Int = 19
        let afterAdd: Int = 19
        let lowerBound: Int = 2
        #expect(scores.prefixSum(through: 3) == first)
        #expect(scores.sum(in: 2 ..< 6) == range)
        scores.add(10, at: 1)
        #expect(scores.prefixSum(through: 3) == afterAdd)
        #expect(scores.lowerBound(ofPrefixSum: 15) == lowerBound)
    }

    @Test("Usage: the update tree as an Arborescence")
    func arborescence() {
        let updates = Arborescence(FenwickTree([1, 2, 3, 4, 5, 6, 7, 8]))
        let root: Int = 8
        let parent: Int = 3
        #expect(updates.root == root)
        #expect(updates.parent(of: 2)! == parent)
    }

    @Test("Usage: a sorted set and a sorted dictionary")
    func sortedSetAndDictionary() {
        var primes: AVLTree = [7, 2, 11, 3, 5]
        primes.insert(13)
        let sortedPrimes: [Int] = [2, 3, 5, 7, 11, 13]
        let indexOfSeven: Int = 3
        #expect(!primes.contains(4))
        #expect(Array(primes) == sortedPrimes)
        #expect(primes.lowerBound(6) == indexOfSeven)

        var stock: AVLDictionary = ["pear": 4, "apple": 7]
        stock["fig"] = 2
        stock["apple", default: 0] += 1
        let keys: [String] = ["apple", "fig", "pear"]
        let apples: Int? = 8
        #expect(stock.map(\.key) == keys)
        #expect(stock["apple"] == apples)
    }

    @Test("Usage: a B-tree sorted set")
    func bTree() {
        var readings: BTree = [40, 10, 30, 20]
        readings.insert(25)
        let sortedReadings: [Int] = [10, 20, 25, 30, 40]
        let third: Int = 25
        let first: Int? = 10
        #expect(Array(readings) == sortedReadings)
        #expect(readings[2] == third)
        #expect(readings.popFirst() == first)
    }

    @Test("Usage: a trie's prefix queries")
    func trie() {
        let words = Trie(["car", "cart", "cat", "dog"])
        let withCar: [String] = ["car", "cart"]
        let longest: String = "cart"
        #expect(words.elements(withPrefix: "car").map { String($0) } == withCar)
        #expect(words.longestPrefix(of: "carton").map { String($0) } == longest)
        #expect(words.hasPrefix("do"))

        let paths = RadixTree(["/usr/bin", "/usr/lib", "/var/log"])
        let underUsr: Int = 2
        #expect(paths.elements(withPrefix: "/usr/").count == underUsr)
    }

    @Test("Usage: a skip list and its levels")
    func skipList() {
        var queue: SkipList = [30, 10, 20]
        queue.insert(15)
        let sorted: [Int] = [10, 15, 20, 30]
        let indexOfTwenty: Int = 2
        #expect(Array(queue) == sorted)
        #expect(queue.lowerBound(20) == indexOfTwenty)
        #expect(queue.layersView.vertices.filter { $0.level == 0 }.map(\.element) == sorted)
    }
}
