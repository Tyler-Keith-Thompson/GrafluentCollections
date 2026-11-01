// LRUCache against a list kept from most to least recent: reads, peeks, writes, removals and
// evictions. After every operation the entries must be the list's, in order.

import Caches
import FuzzSupport

@main
enum FuzzCaches {
    static func main() { runFuzzer(fuzz) }

    static func fuzz(_ input: inout FuzzInput) {
        let capacity = input.int(below: 6)
        var cache = LRUCache<Int, Int>(capacity: capacity)
        var model: [(key: Int, value: Int)] = []
        var snapshot: (LRUCache<Int, Int>, [Int])?
        var serial = 0
        while !input.isEmpty {
            let key = input.int(below: 10)
            serial += 1
            switch input.int(below: 6) {
            case 0:
                let found = cache[key]
                if let index = model.firstIndex(where: { $0.key == key }) {
                    let entry = model.remove(at: index)
                    model.insert(entry, at: 0)
                    check(found == entry.value, "subscript(\(key))")
                } else {
                    check(found == nil, "subscript(\(key)) of an absent key")
                }
            case 1:
                check(cache.peek(key) == model.first { $0.key == key }?.value, "peek(\(key))")
            case 2:
                let removed = cache.removeValue(forKey: key)
                let index = model.firstIndex { $0.key == key }
                check(removed == index.map { model.remove(at: $0).value }, "removeValue(forKey: \(key))")
            case 3:
                let evicted = cache.removeLeastRecentlyUsed()
                let last = model.popLast()
                check(evicted?.key == last?.key && evicted?.value == last?.value, "removeLeastRecentlyUsed")
            case 4:
                snapshot = (cache, model.map(\.key))
            default:
                let evicted = cache.insert(serial, forKey: key)
                if let index = model.firstIndex(where: { $0.key == key }) {
                    model.remove(at: index)
                    model.insert((key, serial), at: 0)
                    check(evicted == nil, "insert over a present key evicted")
                } else if capacity == 0 {
                    check(evicted?.key == key, "capacity 0 keeps nothing")
                } else {
                    let expected = model.count == capacity ? model.removeLast() : nil
                    model.insert((key, serial), at: 0)
                    check(evicted?.key == expected?.key && evicted?.value == expected?.value, "insert(forKey: \(key)) evicted the wrong entry")
                }
            }
            check(cache.map(\.key) == model.map(\.key), "order \(cache.map(\.key)), model \(model.map(\.key))")
            check(cache.map(\.value) == model.map(\.value), "values")
        }
        if let (copy, saved) = snapshot {
            check(copy.map(\.key) == saved, "the snapshot changed")
        }
    }
}
