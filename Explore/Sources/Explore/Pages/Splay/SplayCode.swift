// snippet: splay-imports
import BinarySearchTrees
import Trees
// snippet end

// The splay tree page's code. The marked regions are its code panel.

/// One operation on the splay tree and skip list pages. A split and the join after it are the
/// splay page's alone.
enum KeyOperation: Equatable {
    case insert(Int)
    case remove(Int)
    case access(Int)
    case split(Int)
    case join(Int)

    var key: Int {
        switch self {
        case .insert(let key), .remove(let key), .access(let key), .split(let key), .join(let key): key
        }
    }
}

/// The operations in `text`: whole numbers from 1 to 999 separated by spaces or commas, each
/// an insertion, with a leading minus sign a removal, or with a leading question mark a lookup.
/// With `splits`, a leading slash splits the tree at the number and then joins the two parts
/// again, as two operations. Anything else is skipped; at most 24.
func keyOperations(_ text: String, splits: Bool) -> [KeyOperation] {
    var operations: [KeyOperation] = []
    for word in text.split(whereSeparator: { $0 == " " || $0 == "," }) {
        let removes = word.hasPrefix("-") || word.hasPrefix("−")
        let looksUp = word.hasPrefix("?")
        let splitsHere = splits && word.hasPrefix("/")
        guard let key = Int(removes || looksUp || splitsHere ? String(word.dropFirst()) : String(word)), key >= 1, key <= 999 else { continue }
        if splitsHere {
            guard operations.count <= 22 else { break }
            operations += [.split(key), .join(key)]
        } else {
            operations.append(removes ? .remove(key) : looksUp ? .access(key) : .insert(key))
        }
        if operations.count >= 24 { break }
    }
    return operations
}

/// The trees after each operation, starting from the empty tree: one tree, or the two parts
/// between a split and its join.
func splayHistory(_ operations: [KeyOperation]) -> [[SplayTree<Int>]] {
    // snippet: splay-run
    var tree = SplayTree<Int>()
    var upper = SplayTree<Int>()  // the upper part between a split and its join
    var history = [[tree]]
    for operation in operations {
        switch operation {
        case .insert(let key): tree.insert(key)
        case .remove(let key): tree.remove(key)
        case .access(let key): tree.access(key)
        case .split(let key):
            let parts = tree.split(at: key)
            tree = parts.lower
            upper = parts.upper
        case .join:
            try? tree.join(upper)  // every lower key is below every upper key, so it can't throw
            upper = SplayTree()
        }
        history.append(operation == .split(operation.key) ? [tree, upper] : [tree])
    }
    let height = tree.height  // →
    // snippet end
    _ = height
    return history
}

/// The shape of `tree`, as Grafluent's binary tree over its keys.
func splayShape(_ tree: SplayTree<Int>) -> BinaryTree<Int>? {
    // snippet: splay-shape
    let shape = BinaryTree(tree)
    let root = shape?.root  // →
    // snippet end
    _ = root
    return shape
}
