// snippet: redblack-imports
import BinarySearchTrees
import Trees
// snippet end

// The red–black tree page's code. The marked regions are its code panel.

/// The operations in `text`: whole numbers from 1 to 999 separated by spaces or commas, each
/// an insertion, or with a leading minus sign a removal, as a negative number. Anything else is
/// skipped; at most 24.
func redBlackOperations(_ text: String) -> [Int] {
    var operations: [Int] = []
    for word in text.split(whereSeparator: { $0 == " " || $0 == "," }) {
        let removes = word.hasPrefix("-") || word.hasPrefix("−")
        guard let key = Int(removes ? String(word.dropFirst()) : String(word)), key >= 1, key <= 999 else { continue }
        operations.append(removes ? -key : key)
        if operations.count == 24 { break }
    }
    return operations
}

/// The tree after each operation, starting from the empty tree.
func redBlackHistory(_ operations: [Int]) -> [RedBlackTree<Int>] {
    // snippet: redblack-run
    var tree = RedBlackTree<Int>()
    var history = [tree]
    for key in operations {
        if key < 0 {
            tree.remove(-key)
        } else {
            tree.insert(key)
        }
        history.append(tree)
    }
    let height = tree.height  // →
    // snippet end
    _ = height
    return history
}

/// The shape of `tree` and each key's colour.
func redBlackShape(_ tree: RedBlackTree<Int>) -> (shape: BinaryTree<Int>?, red: Set<Int>) {
    // snippet: redblack-shape
    let shape = BinaryTree(tree)
    let red = tree.filter { tree.color(of: $0) == .red }  // →
    // snippet end
    return (shape, Set(red))
}
