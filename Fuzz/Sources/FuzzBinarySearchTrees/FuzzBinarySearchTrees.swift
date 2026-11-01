// The four binary search trees and AVLDictionary against a Set and a Dictionary. After every
// operation the tree's elements must be the model's, sorted, every query must agree, and the
// height must stay within the tree's bound (AVL 1.4405 log₂(n + 2), red–black 2 log₂(n + 1)); a
// snapshot taken earlier must be unaffected by later edits.

import BinarySearchTrees
import FuzzSupport

@main
enum FuzzBinarySearchTrees {
    static func main() { runFuzzer(fuzz) }

    static func fuzz(_ input: inout FuzzInput) {
        switch input.int(below: 5) {
        case 0: exercise(AVLTree<Int>(), &input, height: \.height, isBalanced: avlBalanced)
        case 1: exercise(RedBlackTree<Int>(), &input, height: \.height, isBalanced: { height, n in 1 << (height / 2) <= n + 1 })
        case 2: exercise(Treap<Int>(), &input, height: \.height, isBalanced: { height, n in height <= n })
        case 3: exercise(SplayTree<Int>(), &input, height: \.height, isBalanced: { height, n in height <= n })
        default: dictionary(&input)
        }
    }

    /// Whether an AVL tree of `n` elements may have `height`: the smallest such tree of height h
    /// holds N(h) = N(h − 1) + N(h − 2) + 1 elements.
    static func avlBalanced(_ height: Int, _ n: Int) -> Bool {
        var smaller = 0, smallest = 1
        if height == 0 { return n == 0 }
        for _ in 1 ..< height { (smaller, smallest) = (smallest, smallest + smaller + 1) }
        return n >= smallest
    }

    static func exercise<T: SetAlgebra & RandomAccessCollection>(
        _ empty: T, _ input: inout FuzzInput, height: (T) -> Int, isBalanced: (Int, Int) -> Bool
    ) where T.Element == Int, T.Index == Int {
        var tree = empty
        var model = Set<Int>()
        var snapshot: (T, [Int])?
        while !input.isEmpty {
            let key = input.int(below: 32)
            switch input.int(below: 8) {
            case 0, 1, 2:
                let inserted = tree.insert(key).inserted
                check(inserted == model.insert(key).inserted, "insert(\(key))")
            case 3, 4:
                check(tree.remove(key) == model.remove(key), "remove(\(key))")
            case 5:
                check(tree.contains(key) == model.contains(key), "contains(\(key))")
                if !model.isEmpty {
                    let rank = key % model.count
                    check(tree[rank] == model.sorted()[rank], "subscript(\(rank))")
                }
            case 6:
                snapshot = (tree, model.sorted())
            default:
                var other = empty
                for _ in 0 ..< input.int(below: 6) { other.insert(input.int(below: 32)) }
                let otherModel = Set(other)
                switch input.int(below: 4) {
                case 0: tree.formUnion(other); model.formUnion(otherModel)
                case 1: tree.formIntersection(other); model.formIntersection(otherModel)
                case 2: tree.subtract(other); model.subtract(otherModel)
                default: tree.formSymmetricDifference(other); model.formSymmetricDifference(otherModel)
                }
            }
            check(Array(tree) == model.sorted(), "elements \(Array(tree)), model \(model.sorted())")
            check(tree.count == model.count, "count")
            check(isBalanced(height(tree), model.count), "height \(height(tree)) for \(model.count) elements")
        }
        if let (copy, saved) = snapshot {
            check(Array(copy) == saved, "the snapshot changed")
        }
    }

    static func dictionary(_ input: inout FuzzInput) {
        var tree = AVLDictionary<Int, Int>()
        var model: [Int: Int] = [:]
        var serial = 0
        while !input.isEmpty {
            let key = input.int(below: 32)
            serial += 1
            switch input.int(below: 4) {
            case 0, 1:
                check(tree.updateValue(serial, forKey: key) == model.updateValue(serial, forKey: key), "updateValue(forKey: \(key))")
            case 2:
                check(tree.removeValue(forKey: key) == model.removeValue(forKey: key), "removeValue(forKey: \(key))")
            default:
                check(tree[key] == model[key], "subscript(\(key))")
            }
            check(tree.map(\.key) == model.keys.sorted(), "keys")
            check(tree.map(\.value) == model.keys.sorted().map { model[$0]! }, "values")
            check(avlBalanced(tree.height, model.count), "height")
        }
    }
}
