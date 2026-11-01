// snippet: persistent-imports
import PersistentTrees
import Trees

/// One edit of the page's set.
enum PersistentEdit: Equatable {
    case insert(Int)
    case remove(Int)
}
// snippet end

// The persistent tree page's code. The marked regions are its code panel.

/// The elements in `text`: whole numbers from 0 to 99, separated by spaces or commas; at most 24.
func persistentElements(_ text: String) -> [Int] {
    let numbers = text.split { $0 == " " || $0 == "," }.compactMap { Int($0) }.filter { (0 ... 99).contains($0) }
    return Array(numbers.prefix(24))
}

/// The edits in `text`: `+x` inserts x and `-x` removes it, for x from 0 to 99; at most 16.
func persistentEdits(_ text: String) -> [PersistentEdit] {
    let edits = text.split { $0 == " " || $0 == "," }.compactMap { token -> PersistentEdit? in
        guard let value = Int(token.dropFirst()), (0 ... 99).contains(value) else { return nil }
        switch token.first {
        case "+": return .insert(value)
        case "-": return .remove(value)
        default: return nil
        }
    }
    return Array(edits.prefix(16))
}

/// Every version, the first built from `elements`, and the elements each shares with the one
/// before it.
func persistentHistory(_ elements: [Int], _ edits: [PersistentEdit]) -> (versions: [PersistentTreeSet<Int>], shared: [[Int]]) {
    // snippet: persistent-run
    var versions = [PersistentTreeSet(elements)]
    var shared: [[Int]] = [[]]
    for edit in edits {
        let latest = versions[versions.count - 1]
        let next = switch edit {
        case .insert(let element): latest.inserting(element)
        case .remove(let element): latest.removing(element)
        }
        shared.append(next.elementsInSharedVertices(with: latest))
        versions.append(next)
    }
    let latest = Array(versions[versions.count - 1])  // →
    // snippet end
    _ = latest
    return (versions, shared)
}

/// Each element's depth in a version's tree, and its parent.
func persistentShape(_ version: PersistentTreeSet<Int>) -> (depths: [Int: Int], parents: [Int: Int]) {
    // snippet: persistent-shape
    let shape = BinaryTree(version)
    let height = shape?.height  // →
    // snippet end
    _ = height
    guard let shape else { return ([:], [:]) }
    var depths: [Int: Int] = [:], parents: [Int: Int] = [:]
    for element in shape.inorder {
        depths[element] = shape.depth(of: element)
        parents[element] = shape.parent(of: element)
    }
    return (depths, parents)
}
