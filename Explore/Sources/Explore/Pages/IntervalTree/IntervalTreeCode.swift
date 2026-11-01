// snippet: intervaltree-imports
import RangeTrees
import Trees
// snippet end

// The interval tree page's code. The marked regions are its code panel.

/// One operation of the page: an interval inserted or removed, the intervals containing a
/// point, or those overlapping a range.
enum IntervalOperation: Equatable {
    case insert(Range<Int>)
    case remove(Range<Int>)
    case containing(Int)
    case overlapping(Range<Int>)

    /// The range a search looks at: a point `p` as `p ..< p + 1`.
    var range: Range<Int> {
        switch self {
        case .insert(let range), .remove(let range), .overlapping(let range): range
        case .containing(let point): point ..< point + 1
        }
    }

    var isQuery: Bool {
        switch self {
        case .containing, .overlapping: true
        case .insert, .remove: false
        }
    }
}

/// The operations in `text`: `a-b` inserts the interval from `a` up to `b`, `-a-b` removes it,
/// `?p` finds the intervals containing `p`, and `?a-b` those overlapping `a` up to `b`. Bounds run
/// from 0 to 100 with `a < b`; others are skipped. At most 24.
func intervalOperations(_ text: String) -> [IntervalOperation] {
    func range(_ part: Substring) -> Range<Int>? {
        let ends = part.split(separator: "-", omittingEmptySubsequences: false)
        guard ends.count == 2, let a = Int(ends[0]), let b = Int(ends[1]), 0 <= a, a < b, b <= 100 else { return nil }
        return a ..< b
    }
    var operations: [IntervalOperation] = []
    for token in text.split(whereSeparator: { $0 == " " || $0 == "," }) {
        if token.first == "?" {
            if let range = range(token.dropFirst()) {
                operations.append(.overlapping(range))
            } else if let point = Int(token.dropFirst()), (0 ... 100).contains(point) {
                operations.append(.containing(point))
            }
        } else if token.first == "-", let range = range(token.dropFirst()) {
            operations.append(.remove(range))
        } else if let range = range(token) {
            operations.append(.insert(range))
        }
    }
    return Array(operations.prefix(24))
}

/// The tree after each operation, its values numbering the intervals in insertion order, and the
/// values each query found (empty for an insert or remove).
func intervalHistory(_ operations: [IntervalOperation]) -> (trees: [IntervalTree<Int, Int>], found: [[Int]]) {
    // snippet: intervaltree-run
    var tree = IntervalTree<Int, Int>()
    var history = [tree]
    var found: [[Int]] = []
    for (number, operation) in operations.enumerated() {
        switch operation {
        case .insert(let range):
            tree.insert(range, value: number)
            found.append([])
        case .remove(let range):
            _ = tree.remove(range)
            found.append([])
        case .containing(let point):
            found.append(tree.containing(point).map(\.value))
        case .overlapping(let range):
            found.append(tree.overlapping(range).map(\.value))
        }
        history.append(tree)
    }
    let count = tree.count  // →
    // snippet end
    _ = count
    return (history, found)
}

/// The tree's shape: each in-order position's depth and children.
func intervalShape(_ tree: IntervalTree<Int, Int>) -> BinaryTree<Int>? {
    // snippet: intervaltree-shape
    let shape = BinaryTree(tree)  // vertex i is the entry tree[i]
    let height = shape?.height  // →
    // snippet end
    _ = height
    return shape
}
