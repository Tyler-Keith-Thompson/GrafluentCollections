// snippet: skiplist-imports
import SkipLists
// snippet end

// The skip list page's code. The marked regions are its code panel.

/// The operations in `text`, as for the splay tree page: insertions, removals with a leading
/// minus sign and lookups with a leading question mark, from 1 to 999; at most 24.
func skipListOperations(_ text: String) -> [KeyOperation] {
    keyOperations(text, splits: false)
}

/// The list after each operation, starting from an empty one seeded with `seed`.
func skipListHistory(_ operations: [KeyOperation], seed: UInt64) -> [SkipList<Int>] {
    // snippet: skiplist-run
    var random = PageRandom(state: seed)  // any RandomNumberGenerator
    var list = SkipList<Int>(using: &random)
    var history = [list]
    for operation in operations {
        switch operation {
        case .insert(let key): list.insert(key)
        case .remove(let key): list.remove(key)
        case .access(let key): _ = list.contains(key)
        case .split, .join: break  // the splay page's alone
        }
        history.append(list)
    }
    let count = list.count  // →
    // snippet end
    _ = count
    return history
}

/// How many levels each element's tower has.
func skipListTowers(_ list: SkipList<Int>) -> [Int: Int] {
    // snippet: skiplist-towers
    let layers = list.layersView
    var towers: [Int: Int] = [:]
    for vertex in layers.vertices {
        towers[vertex.element, default: 0] += 1
    }
    let tallest = towers.values.max()  // →
    // snippet end
    _ = tallest
    return towers
}
