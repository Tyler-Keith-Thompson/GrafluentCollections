// Tests for LRUCache. Each test builds its own cache and checks it against a hand-worked answer
// or a naive model that keeps the entries in an array from most to least recent, so it can be
// copied into another file and still run. Nothing here is shared but the imports.

import Caches
import GrafluentCollectionsTestSupport
import PropertyBased
import Testing
import Trees

@Suite("LRUCache: hand-worked cases")
struct LRUCacheTests {
    @Test("The least recently used entry is evicted, and a read promotes")
    func evictionOrder() {
        var cache = LRUCache<String, Int>(capacity: 2)
        cache["a"] = 1
        cache["b"] = 2
        let one: Int? = 1
        #expect(cache["a"] == one)
        cache["c"] = 3
        let order = ["c", "a"]
        #expect(cache.map(\.key) == order)
        #expect(!cache.contains("b"))
        let evicted = cache.insert(4, forKey: "d")
        let a = LRUCache<String, Int>.Entry(key: "a", value: 1)
        #expect(evicted == a)
    }

    @Test("peek and contains leave the order alone; an update promotes and returns the old value")
    func peekAndUpdate() {
        var cache = LRUCache<Int, String>(capacity: 3)
        cache[1] = "one"
        cache[2] = "two"
        cache[3] = "three"
        let two: String? = "two"
        #expect(cache.peek(2) == two)
        #expect(cache.contains(1))
        let unchanged = [3, 2, 1]
        #expect(cache.map(\.key) == unchanged)
        let old: String? = "one"
        #expect(cache.updateValue("uno", forKey: 1) == old)
        let promoted = [1, 3, 2]
        #expect(cache.map(\.key) == promoted)
        #expect(cache.insert("dos", forKey: 2) == nil)
        let afterInsert = [2, 1, 3]
        #expect(cache.map(\.key) == afterInsert)
        #expect(cache.description == #"[2: "dos", 1: "uno", 3: "three"]"#)
    }

    @Test("Removing, removing the least recent and reinserting")
    func removal() {
        var cache = LRUCache<Int, Int>(capacity: 4)
        for k in 0 ..< 4 {
            cache[k] = k * 10
        }
        let twenty: Int? = 20, none: Int? = nil
        #expect(cache.removeValue(forKey: 2) == twenty)
        #expect(cache.removeValue(forKey: 2) == none)
        let rest = [3, 1, 0]
        #expect(cache.map(\.key) == rest)
        let oldest = LRUCache<Int, Int>.Entry(key: 0, value: 0)
        #expect(cache.removeLeastRecentlyUsed() == oldest)
        cache[2] = 21
        cache[0] = 1
        let reinserted = [0, 2, 3, 1]
        #expect(cache.map(\.key) == reinserted)
        cache[3] = nil
        let withoutThree = [0, 2, 1]
        #expect(cache.map(\.key) == withoutThree)
        let three = 3
        #expect(cache.count == three)
        cache.removeAll()
        #expect(cache.isEmpty)
        #expect(cache.removeLeastRecentlyUsed() == nil)
        #expect(cache.description == "[:]")
    }

    @Test("Capacity 0 holds nothing and evicts each new entry at once; capacity 1 keeps the last")
    func smallCapacities() {
        var none = LRUCache<Int, Int>(capacity: 0)
        let itself = LRUCache<Int, Int>.Entry(key: 1, value: 1)
        #expect(none.insert(1, forKey: 1) == itself)
        none[2] = 2
        #expect(none.isEmpty)
        var one = LRUCache<Int, Int>(capacity: 1)
        #expect(one.insert(1, forKey: 1) == nil)
        let first = LRUCache<Int, Int>.Entry(key: 1, value: 1)
        #expect(one.insert(2, forKey: 2) == first)
        let last = [2]
        #expect(one.map(\.key) == last)
        let capacity = 1
        #expect(one.capacity == capacity)
    }

    @Test("A copy's recency order is independent")
    func copyOnWrite() {
        var cache = LRUCache<Int, Int>(capacity: 3)
        for k in 0 ..< 3 {
            cache[k] = k
        }
        let snapshot = cache
        _ = cache[0]
        cache[9] = 9
        let original = [2, 1, 0], changed = [9, 0, 2]
        #expect(snapshot.map(\.key) == original)
        #expect(cache.map(\.key) == changed)
    }

    @Test("The recency list converts to a path")
    func rootedTree() {
        var cache = LRUCache<Int, Int>(capacity: 5)
        for k in 0 ..< 4 {
            cache[k] = k
        }
        let four = 4
        #expect(RootedTree(cache)?.vertexCount == four)
        #expect(RootedTree(LRUCache<Int, Int>(capacity: 1)) == nil)
    }

    @Test("The checked spelling throws NegativeCapacity")
    func checkedSpelling() throws {
        #expect(throws: NegativeCapacity()) { try LRUCache<Int, Int>(checkedCapacity: -1) }
        let cache = try LRUCache<Int, Int>(checkedCapacity: 0)
        let zero = 0
        #expect(cache.capacity == zero)
    }

    @Test("A negative capacity traps", .tags(.precondition))
    func plainTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = LRUCache<Int, Int>(capacity: -1)
        }
    }
}

@Suite("LRUCache: properties")
struct LRUCachePropertyTests {
    @Test("Random reads, writes, peeks and removals match a naive recency list", .tags(.randomized))
    func matchesModel() async {
        let operations = Gen.int(in: 0 ... 1_000_000).array(of: 0 ... 300)
        await propertyCheck(count: 200, input: operations) { operations in
            let capacity = operations.first.map { $0 % 6 } ?? 3
            var cache = LRUCache<Int, Int>(capacity: capacity)
            // Most recent first.
            var model: [(key: Int, value: Int)] = []
            for (serial, operation) in operations.enumerated() {
                let key = operation / 5 % 10
                switch operation % 5 {
                case 0:
                    let found = cache[key]
                    var expected: Int?
                    if let index = model.firstIndex(where: { $0.key == key }) {
                        let entry = model.remove(at: index)
                        model.insert(entry, at: 0)
                        expected = entry.value
                    }
                    #expect(found == expected)
                case 1:
                    #expect(cache.peek(key) == model.first(where: { $0.key == key })?.value)
                case 2:
                    let removed = cache.removeValue(forKey: key)
                    var expected: Int?
                    if let index = model.firstIndex(where: { $0.key == key }) {
                        expected = model.remove(at: index).value
                    }
                    #expect(removed == expected)
                case 3:
                    let evicted = cache.removeLeastRecentlyUsed()
                    let expected = model.popLast()
                    #expect(evicted?.key == expected?.key)
                    #expect(evicted?.value == expected?.value)
                default:
                    let evicted = cache.insert(serial, forKey: key)
                    var expectedEvicted: (key: Int, value: Int)?
                    if let index = model.firstIndex(where: { $0.key == key }) {
                        model.remove(at: index)
                        model.insert((key, serial), at: 0)
                    } else if capacity == 0 {
                        expectedEvicted = (key, serial)
                    } else {
                        if model.count == capacity {
                            expectedEvicted = model.removeLast()
                        }
                        model.insert((key, serial), at: 0)
                    }
                    #expect(evicted?.key == expectedEvicted?.key)
                    #expect(evicted?.value == expectedEvicted?.value)
                }
                #expect(cache.map(\.key) == model.map(\.key))
                #expect(cache.map(\.value) == model.map(\.value))
                #expect(cache.count == model.count)
            }
        }
    }
}
