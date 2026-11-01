// snippet: avl-imports
import BinarySearchTrees
import Trees
// snippet end

// The AVL tree page's code. The marked regions are its code panel.

/// The operations in `text`: whole numbers from 1 to 999 separated by spaces or commas, each
/// an insertion, or with a leading minus sign a removal, as a negative number. Anything else is
/// skipped; at most 24.
func avlOperations(_ text: String) -> [Int] {
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
func avlHistory(_ operations: [Int]) -> [AVLTree<Int>] {
    // snippet: avl-run
    var tree = AVLTree<Int>()
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

/// The shape of `tree`, as Grafluent's binary tree over its keys.
func avlShape(_ tree: AVLTree<Int>) -> BinaryTree<Int>? {
    // snippet: avl-shape
    let shape = BinaryTree(tree)
    let order = shape?.inorder  // →
    // snippet end
    _ = order
    return shape
}
