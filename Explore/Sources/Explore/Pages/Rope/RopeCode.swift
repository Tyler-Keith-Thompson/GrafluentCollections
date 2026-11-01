// snippet: rope-imports
import Ropes
import Trees

/// One edit of the page's text.
enum RopeOperation: Equatable {
    case insert(String, at: Int)
    case remove(Range<Int>)
    case copyToEnd(Range<Int>)
}
// snippet end

// The rope page's code. The marked regions are its code panel.

/// The operations in `text`: `+i "words"` inserts the words at offset `i`, `-a..b` removes
/// offsets `a` up to `b`, and `>a..b` copies them to the end. At most 16.
func ropeOperations(_ text: String) -> [RopeOperation] {
    let characters = Array(text)
    var at = 0
    func number() -> Int? {
        var digits = ""
        while at < characters.count, characters[at].isASCII, characters[at].isNumber, digits.count < 6 {
            digits.append(characters[at])
            at += 1
        }
        return Int(digits)
    }
    func range() -> Range<Int>? {
        guard let low = number(), at + 1 < characters.count, characters[at] == ".", characters[at + 1] == "." else { return nil }
        at += 2
        guard let high = number(), low < high else { return nil }
        return low ..< high
    }
    var operations: [RopeOperation] = []
    while at < characters.count, operations.count < 16 {
        let symbol = characters[at]
        at += 1
        switch symbol {
        case "+":
            guard let offset = number() else { continue }
            while at < characters.count, characters[at] == " " { at += 1 }
            guard at < characters.count, characters[at] == "\"" else { continue }
            at += 1
            var words = ""
            while at < characters.count, characters[at] != "\"" {
                words.append(characters[at])
                at += 1
            }
            at += 1
            if !words.isEmpty { operations.append(.insert(String(words.prefix(200)), at: offset)) }
        case "-":
            if let range = range() { operations.append(.remove(range)) }
        case ">":
            if let range = range() { operations.append(.copyToEnd(range)) }
        default:
            continue
        }
    }
    return operations
}

/// Whether `operation` fits a text of `count` characters.
func ropeFits(_ operation: RopeOperation, count: Int) -> Bool {
    switch operation {
    case .insert(_, let offset): offset <= count
    case .remove(let range), .copyToEnd(let range): range.upperBound <= count
    }
}

/// The rope after each operation, starting from `text`.
func ropeHistory(_ text: String, _ operations: [RopeOperation]) -> [Rope<Character>] {
    // snippet: rope-run
    var rope = Rope(text)
    var history = [rope]
    for operation in operations {
        switch operation {
        case .insert(let words, let offset):
            rope.insert(contentsOf: words, at: offset)
        case .remove(let range):
            rope.removeSubrange(range)
        case .copyToEnd(let range):
            rope = rope + rope.extracting(range)
        }
        history.append(rope)
    }
    let chunks = rope.chunksView.map(\.count)  // →
    // snippet end
    _ = chunks
    return history
}

/// Each chunk's parent in the rope's tree, by chunk number, and the root.
func ropeShape(_ rope: Rope<Character>) -> (parents: [Int?], depths: [Int]) {
    // snippet: rope-shape
    let shape = BinaryTree(rope)
    let root = shape?.root  // →
    // snippet end
    _ = root
    guard let shape else { return ([], []) }
    let vertices = Array(shape.inorder)
    return (vertices.map { shape.parent(of: $0) }, vertices.map { shape.depth(of: $0) })
}
