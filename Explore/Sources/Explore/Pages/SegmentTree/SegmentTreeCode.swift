// snippet: segmenttree-imports
import RangeTrees
import Trees

/// Adding to every value in a range, over sums: the sum of `count` values each raised by `update`
/// rises by `update × count`.
enum AddToSum: MonoidAction {
    typealias Values = Sum<Int>
    static var identity: Int { 0 }
    static func compose(_ outer: Int, _ inner: Int) -> Int { outer + inner }
    static func apply(_ update: Int, to sum: Int, count: Int) -> Int { sum + update * count }
}

/// Adding to every value in a range, over minimums: the smallest rises by the same amount.
enum AddToMinimum: MonoidAction {
    typealias Values = Minimum<Int>
    static var identity: Int { 0 }
    static func compose(_ outer: Int, _ inner: Int) -> Int { outer + inner }
    static func apply(_ update: Int, to minimum: Int, count: Int) -> Int {
        minimum == .max ? minimum : minimum + update
    }
}
// snippet end

// The segment tree page's code. The marked regions are its code panel.

/// One operation of the page over the values `lower ..< upper`: a query of their sum and
/// minimum, or an amount added to each of them.
struct SegmentOperation: Equatable {
    var range: Range<Int>
    var amount: Int?  // nil for a query
}

/// The operations in `text` over `count` values: `?a-b` for the sum and minimum of indices `a`
/// through `b`, `+v@a-b` or `-v@a-b` to add `v` or `−v` to each of them; `?a` and `+v@a` for one
/// index. Indices count from 0; others are skipped. At most 24.
func segmentOperations(_ text: String, count: Int) -> [SegmentOperation] {
    func range(_ part: Substring) -> Range<Int>? {
        let ends = part.split(separator: "-", omittingEmptySubsequences: false)
        guard ends.count <= 2, let a = Int(ends[0]), let b = ends.count == 2 ? Int(ends[1]) : a,
              a <= b, a >= 0, b < count else { return nil }
        return a ..< b + 1
    }
    var operations: [SegmentOperation] = []
    for token in text.split(whereSeparator: { $0 == " " || $0 == "," }) {
        if token.first == "?", let range = range(token.dropFirst()) {
            operations.append(SegmentOperation(range: range))
        } else if token.first == "+" || token.first == "-", let at = token.firstIndex(of: "@"),
                  let amount = Int(token[..<at]), (-99 ... 99).contains(amount), let range = range(token[token.index(after: at)...]) {
            operations.append(SegmentOperation(range: range, amount: amount))
        }
    }
    return Array(operations.prefix(24))
}

/// The sum and minimum trees after each operation, and each query's answers.
func segmentHistory(_ values: [Int], _ operations: [SegmentOperation]) -> (sums: [LazySegmentTree<AddToSum>], minimums: [LazySegmentTree<AddToMinimum>], answers: [(sum: Int, minimum: Int)?]) {
    // snippet: segmenttree-run
    var sums = LazySegmentTree<AddToSum>(values)
    var minimums = LazySegmentTree<AddToMinimum>(values)
    var history = [(sums, minimums)]
    var answers: [(sum: Int, minimum: Int)?] = []
    for operation in operations {
        if let amount = operation.amount {
            sums.apply(amount, in: operation.range)
            minimums.apply(amount, in: operation.range)
            answers.append(nil)
        } else {
            answers.append((sums.combined(in: operation.range), minimums.combined(in: operation.range)))
        }
        history.append((sums, minimums))
    }
    let smallest = minimums.combined(in: 0 ..< minimums.count)  // →
    // snippet end
    _ = smallest
    return (history.map(\.0), history.map(\.1), answers)
}

/// The tree's shape: each cell's children, in level order from the root, cell 0.
func segmentShape(_ tree: LazySegmentTree<AddToSum>) -> [Int: (left: Int?, right: Int?)] {
    // snippet: segmenttree-shape
    guard let shape = BinaryTree(tree) else { return [:] }
    var children: [Int: (left: Int?, right: Int?)] = [:]
    for cell in shape.preorder {
        children[cell] = (shape.left(of: cell), shape.right(of: cell))
    }
    let cells = shape.vertexCount  // →
    // snippet end
    _ = cells
    return children
}
