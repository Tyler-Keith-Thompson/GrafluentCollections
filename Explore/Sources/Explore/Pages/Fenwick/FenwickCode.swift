// snippet: fenwick-imports
import RangeTrees
import Trees
// snippet end

// The Fenwick tree page's code. The marked regions are its code panel.

/// One operation of the page: a prefix sum through an index, or an amount added at one.
enum FenwickOperation: Equatable {
    case prefixSum(through: Int)
    case add(Int, at: Int)

    var index: Int {
        switch self {
        case .prefixSum(let index), .add(_, let index): index
        }
    }
}

/// The values in `text`: whole numbers from −99 to 99, separated by spaces or commas; at most 16.
func fenwickValues(_ text: String) -> [Int] {
    let numbers = text.split { $0 == " " || $0 == "," }.compactMap { Int($0) }.filter { (-99 ... 99).contains($0) }
    return Array(numbers.prefix(16))
}

/// The operations in `text` over `count` values: `?i` for the sum through index `i`, `+v@i` or
/// `-v@i` to add `v` or `−v` at index `i`. Indices count from 0; others are skipped. At most 24.
func fenwickOperations(_ text: String, count: Int) -> [FenwickOperation] {
    var operations: [FenwickOperation] = []
    for token in text.split(whereSeparator: { $0 == " " || $0 == "," }) {
        if token.first == "?", let index = Int(token.dropFirst()), (0 ..< count).contains(index) {
            operations.append(.prefixSum(through: index))
        } else if let at = token.firstIndex(of: "@"), let amount = Int(token[..<at]), let index = Int(token[token.index(after: at)...]),
                  (0 ..< count).contains(index), (-99 ... 99).contains(amount), token.first == "+" || token.first == "-" {
            operations.append(.add(amount, at: index))
        }
    }
    return Array(operations.prefix(24))
}

/// The tree after each operation, and each prefix sum's answer (nil for an add).
func fenwickHistory(_ values: [Int], _ operations: [FenwickOperation]) -> (trees: [FenwickTree<Int>], answers: [Int?]) {
    // snippet: fenwick-run
    var tree = FenwickTree(values)
    var history = [tree]
    var answers: [Int?] = []
    for operation in operations {
        switch operation {
        case .prefixSum(let index):
            answers.append(tree.prefixSum(through: index))
        case .add(let amount, let index):
            tree.add(amount, at: index)
            answers.append(nil)
        }
        history.append(tree)
    }
    let total = tree.sum(in: 0 ..< tree.count)  // →
    // snippet end
    _ = total
    return (history, answers)
}

/// Each cell's parent in the update tree: the next cell an add reaches, or `count` for the end.
func fenwickParents(_ tree: FenwickTree<Int>) -> [Int: Int] {
    // snippet: fenwick-shape
    let updates = Arborescence(tree)
    var next: [Int: Int] = [:]
    for cell in 0 ..< tree.count {
        next[cell] = updates.parent(of: cell)
    }
    let root = updates.root  // →
    // snippet end
    _ = root
    return next
}
