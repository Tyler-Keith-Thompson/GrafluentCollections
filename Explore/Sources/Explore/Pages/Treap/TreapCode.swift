// snippet: treap-imports
import BinarySearchTrees
import Trees
// snippet end

// The treap page's code. The marked regions are its code panel.

/// SplitMix64 from a fixed seed, so the page draws the same priorities every time it loads.
struct PageRandom: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// The operations in `text`, as for the red–black page: insertions, and removals as negative
/// numbers, from 1 to 999; at most 24.
func treapOperations(_ text: String) -> [Int] {
    redBlackOperations(text)
}

/// The treap after each operation, starting from an empty one seeded with `seed`.
func treapHistory(_ operations: [Int], seed: UInt64) -> [Treap<Int>] {
    // snippet: treap-run
    var random = PageRandom(state: seed)  // any RandomNumberGenerator
    var treap = Treap<Int>(using: &random)
    var history = [treap]
    for key in operations {
        if key < 0 {
            treap.remove(-key)
        } else {
            treap.insert(key)
        }
        history.append(treap)
    }
    let height = treap.height  // →
    // snippet end
    _ = height
    return history
}

/// The shape of `treap` and each key's priority.
func treapShape(_ treap: Treap<Int>) -> (shape: BinaryTree<Int>?, priorities: [Int: Int]) {
    // snippet: treap-shape
    let shape = BinaryTree(treap)
    let top = shape.map { treap.priority(of: $0.root) }  // →
    // snippet end
    _ = top
    var priorities: [Int: Int] = [:]
    for key in treap {
        priorities[key] = treap.priority(of: key)
    }
    return (shape, priorities)
}

/// A priority from −2³¹ to 2³¹ − 1 as a whole number from 0 to 99, for the drawing.
func percentile(_ priority: Int) -> Int {
    Int(((Int64(priority) + (1 << 31)) * 100) >> 32)
}
