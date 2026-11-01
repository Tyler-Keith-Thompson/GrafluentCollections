// snippet: btree-imports
import BTrees
import Trees
// snippet end

// The B-tree page's code. The marked regions are its code panel.

// snippet: btree-row
/// A row of 64 bytes. A B-tree sizes its nodes in bytes, so with rows this large a node holds
/// at most 7 keys, and a few dozen keys already make several levels.
struct Row {
    var fields: (Int64, Int64, Int64, Int64, Int64, Int64, Int64, Int64) = (0, 0, 0, 0, 0, 0, 0, 0)
}
// snippet end

/// The operations in `text`, as for the red–black page: insertions, and removals as negative
/// numbers, from 1 to 999; at most 24.
func bTreeOperations(_ text: String) -> [Int] {
    redBlackOperations(text)
}

/// The table after each operation, starting from an empty one.
func bTreeHistory(_ operations: [Int]) -> [BTreeDictionary<Int, Row>] {
    // snippet: btree-run
    var table = BTreeDictionary<Int, Row>()
    var history = [table]
    for key in operations {
        if key < 0 {
            table.removeValue(forKey: -key)
        } else {
            table[key] = Row()
        }
        history.append(table)
    }
    let height = table.height  // →
    // snippet end
    _ = height
    return history
}

/// The shape of `table`: one vertex per node, holding the node's keys in ascending order.
func bTreeShape(_ table: BTreeDictionary<Int, Row>) -> RootedTree<[Int]>? {
    // snippet: btree-shape
    let shape = RootedTree(table)
    let root = shape?.root  // →
    // snippet end
    _ = root
    return shape
}
