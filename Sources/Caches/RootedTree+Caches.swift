import Trees

extension RootedTree where Vertex == Int {
    /// The recency list of a cache as a path: vertex *k* is the *k*-th most recently used entry,
    /// the most recent at the root and each entry the parent of the next less recent one; nil
    /// when the cache is empty.
    ///
    /// - Parameter cache: The cache whose order is converted. Its keys and values are not read.
    /// - Complexity: O(*n*).
    @inlinable
    public init?<Key, Value>(_ cache: LRUCache<Key, Value>) {
        guard !cache.isEmpty else { return nil }
        let parents: [Int?] = (0 ..< cache.count).map { $0 == 0 ? nil : $0 - 1 }
        guard let tree = RootedTree(parents: parents) else {
            preconditionFailure("A recency list is a path")
        }
        self = tree
    }
}
