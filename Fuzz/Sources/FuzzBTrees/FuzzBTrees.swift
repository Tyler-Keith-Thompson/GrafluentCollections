// BTree and BTreeDictionary against a Set and a Dictionary: after every operation the elements
// are the model's, sorted, every query agrees, and a snapshot is unaffected by later edits.

import BTrees
import FuzzSupport

@main
enum FuzzBTrees {
    static func main() { runFuzzer(fuzz) }

    static func fuzz(_ input: inout FuzzInput) {
        if input.int(below: 2) == 0 { set(&input) } else { dictionary(&input) }
    }

    static func set(_ input: inout FuzzInput) {
        var tree = BTree<Int>()
        var model = Set<Int>()
        var snapshot: (BTree<Int>, [Int])?
        while !input.isEmpty {
            // A wide key range, so the tree grows past one node.
            let key = input.byte() &* 7 &+ input.int(below: 7)
            switch input.int(below: 8) {
            case 0, 1, 2, 3:
                check(tree.insert(key).inserted == model.insert(key).inserted, "insert(\(key))")
            case 4, 5:
                check(tree.remove(key) == model.remove(key), "remove(\(key))")
            case 6:
                check(tree.contains(key) == model.contains(key), "contains(\(key))")
                check(tree.lowerBound(key) == model.filter { $0 < key }.count, "lowerBound(\(key))")
                if !model.isEmpty {
                    let rank = key % model.count
                    check(tree[rank] == model.sorted()[rank], "subscript(\(rank))")
                }
            default:
                snapshot = (tree, model.sorted())
            }
            check(tree.count == model.count, "count")
        }
        check(Array(tree) == model.sorted(), "elements")
        check(Array(tree.reversed()) == model.sorted().reversed(), "reversed")
        if let (copy, saved) = snapshot {
            check(Array(copy) == saved, "the snapshot changed")
        }
    }

    static func dictionary(_ input: inout FuzzInput) {
        var tree = BTreeDictionary<Int, Int>()
        var model: [Int: Int] = [:]
        var serial = 0
        while !input.isEmpty {
            let key = input.byte() &* 3 &+ input.int(below: 3)
            serial += 1
            switch input.int(below: 4) {
            case 0, 1:
                check(tree.updateValue(serial, forKey: key) == model.updateValue(serial, forKey: key), "updateValue(forKey: \(key))")
            case 2:
                check(tree.removeValue(forKey: key) == model.removeValue(forKey: key), "removeValue(forKey: \(key))")
            default:
                check(tree[key] == model[key], "subscript(\(key))")
            }
            check(tree.count == model.count, "count")
        }
        check(tree.map(\.key) == model.keys.sorted(), "keys")
        check(tree.map(\.value) == model.keys.sorted().map { model[$0]! }, "values")
    }
}
