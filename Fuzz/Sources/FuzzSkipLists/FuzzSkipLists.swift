// SkipList against a Set: after every operation the elements are the model's, sorted, every
// query agrees, and a snapshot is unaffected by later edits.

import FuzzSupport
import SkipLists

@main
enum FuzzSkipLists {
    static func main() { runFuzzer(fuzz) }

    static func fuzz(_ input: inout FuzzInput) {
        var list = SkipList<Int>()
        var model = Set<Int>()
        var snapshot: (SkipList<Int>, [Int])?
        while !input.isEmpty {
            let key = input.int(below: 64)
            switch input.int(below: 8) {
            case 0, 1, 2:
                check(list.insert(key).inserted == model.insert(key).inserted, "insert(\(key))")
            case 3, 4:
                check(list.remove(key) == model.remove(key), "remove(\(key))")
            case 5:
                check(list.contains(key) == model.contains(key), "contains(\(key))")
                check(list.lowerBound(key) == model.filter { $0 < key }.count, "lowerBound(\(key))")
                check(list.upperBound(key) == model.filter { $0 <= key }.count, "upperBound(\(key))")
                check(list.min() == model.min() && list.max() == model.max(), "min and max")
            case 6:
                if !model.isEmpty {
                    let rank = key % model.count
                    let removed = list.remove(at: rank)
                    check(removed == model.sorted()[rank], "remove(at: \(rank))")
                    model.remove(removed)
                }
            default:
                snapshot = (list, model.sorted())
            }
            check(Array(list) == model.sorted(), "elements \(Array(list)), model \(model.sorted())")
        }
        if let (copy, saved) = snapshot {
            check(Array(copy) == saved, "the snapshot changed")
        }
    }
}
