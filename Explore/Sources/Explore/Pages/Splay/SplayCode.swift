// snippet: splay-imports
import BinarySearchTrees
import Trees
// snippet end

// The splay tree page's code. The marked regions are its code panel.

/// One operation on the splay tree page.
enum SplayOperation: Equatable {
    case insert(Int)
    case remove(Int)
    case access(Int)

    var key: Int {
        switch self {
        case .insert(let key), .remove(let key), .access(let key): key
        }
    }

    /// The operation as typed: the key, `-` before it for a removal, `?` for a lookup.
    var written: String {
        switch self {
        case .insert(let key): "\(key)"
        case .remove(let key): "-\(key)"
        case .access(let key): "?\(key)"
        }
    }
}

/// The operations in `text`: whole numbers from 1 to 999 separated by spaces or commas, each
/// an insertion, with a leading minus sign a removal, or with a leading question mark a lookup.
/// Anything else is skipped; at most 24.
func splayOperations(_ text: String) -> [SplayOperation] {
    var operations: [SplayOperation] = []
    for word in text.split(whereSeparator: { $0 == " " || $0 == "," }) {
        let removes = word.hasPrefix("-") || word.hasPrefix("−")
        let looksUp = word.hasPrefix("?")
        guard let key = Int(removes || looksUp ? String(word.dropFirst()) : String(word)), key >= 1, key <= 999 else { continue }
        operations.append(removes ? .remove(key) : looksUp ? .access(key) : .insert(key))
        if operations.count == 24 { break }
    }
    return operations
}

/// The tree after each operation, starting from the empty tree.
func splayHistory(_ operations: [SplayOperation]) -> [SplayTree<Int>] {
    // snippet: splay-run
    var tree = SplayTree<Int>()
    var history = [tree]
    for operation in operations {
        switch operation {
        case .insert(let key): tree.insert(key)
        case .remove(let key): tree.remove(key)
        case .access(let key): tree.access(key)
        }
        history.append(tree)
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
