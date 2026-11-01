// snippet: lru-imports
import Caches
import Trees

/// One operation of the page: store a value for a key, or look a key up.
enum CacheOperation: Equatable {
    case insert(String, value: Int)
    case lookup(String)
}

/// What an operation found or pushed out.
enum CacheOutcome {
    case stored(evicted: LRUCache<String, Int>.Entry?)
    case found(Int?)
}
// snippet end

// The LRU cache page's code. The marked regions are its code panel.

/// The operations in `text`: `key=value` stores a whole number from −999 to 999, `key?` looks the
/// key up. Keys are up to 8 letters or digits; at most 24 operations.
func cacheOperations(_ text: String) -> [CacheOperation] {
    func isKey(_ key: Substring) -> Bool { !key.isEmpty && key.count <= 8 && key.allSatisfy { $0.isLetter || $0.isNumber } }
    let operations = text.split { $0 == " " || $0 == "," }.compactMap { token -> CacheOperation? in
        if token.last == "?", isKey(token.dropLast()) { return .lookup(String(token.dropLast())) }
        let parts = token.split(separator: "=", omittingEmptySubsequences: false)
        guard parts.count == 2, isKey(parts[0]), let value = Int(parts[1]), (-999 ... 999).contains(value) else { return nil }
        return .insert(String(parts[0]), value: value)
    }
    return Array(operations.prefix(24))
}

/// The cache after each operation, and what each one found or evicted.
func cacheHistory(capacity: Int, _ operations: [CacheOperation]) -> (caches: [LRUCache<String, Int>], outcomes: [CacheOutcome]) {
    // snippet: lru-run
    var cache = LRUCache<String, Int>(capacity: capacity)
    var history = [cache]
    var outcomes: [CacheOutcome] = []
    for operation in operations {
        switch operation {
        case .insert(let key, let value):
            outcomes.append(.stored(evicted: cache.insert(value, forKey: key)))
        case .lookup(let key):
            outcomes.append(.found(cache[key]))
        }
        history.append(cache)
    }
    let recency = cache.map(\.key)  // →
    // snippet end
    _ = recency
    return (history, outcomes)
}

/// The recency list's links, each entry to the next less recent one.
func cacheLinks(_ cache: LRUCache<String, Int>) -> [(from: Int, to: Int)] {
    // snippet: lru-shape
    let path = RootedTree(cache)
    let depth = path.map { $0.height }  // →
    // snippet end
    _ = depth
    guard let path else { return [] }
    return (1 ..< cache.count).compactMap { entry in path.parent(of: entry).map { ($0, entry) } }
}
