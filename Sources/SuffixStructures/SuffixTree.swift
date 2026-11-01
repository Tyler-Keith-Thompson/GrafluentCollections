/// The suffix tree of one or more texts: the compressed trie of all their suffixes, built left to
/// right in O(*n*) (Ukkonen, "On-Line Construction of Suffix Trees", 1995).
///
/// Every suffix of every text ends at a leaf, the empty suffix included, and every internal node
/// is a point where suffixes that agree so far go different ways, so the tree has at most 2*n* + 1
/// nodes. A pattern is found in O(*m*) steps down from the root, and the leaves below where it
/// ends are its occurrences.
///
/// ```swift
/// let tree = SuffixTree("banana")
/// tree.occurrences(of: "ana").map(\.range)   // [3 ..< 6, 1 ..< 4]
/// tree.longestRepeatedSubstring?.range       // 3 ..< 6, "ana"
///
/// let both = SuffixTree(texts: ["xabxac", "abcabxabcd"])
/// both.longestCommonSubstring                // text 1, 3 ..< 7: "abxa"
/// ```
///
/// Nodes are numbered in preorder from the root at 0, so a node's subtree is the nodes from it to
/// just before the next node that is not its descendant. Children come in the order of the symbol
/// that starts their edge: sorted when `Symbol` is `Comparable`, so the leaves are in the order of
/// their suffixes and match a ``SuffixArray`` of the same text; otherwise in the order the
/// symbols first occur in the texts. Each text ends in a terminator of its own that sorts before
/// every symbol and belongs to no label.
///
/// The tree converts to Grafluent's `RootedTree` with `RootedTree(_:)`, and its suffix links are
/// a directed graph, ``suffixLinksView``. Each node takes 32 bytes and each symbol 4 more, the
/// texts' codes, which the tree keeps.
@frozen
public struct SuffixTree<Symbol: Hashable> {
    /// The texts as codes, each followed by its terminator: −1 for the first text, −2 for the
    /// second, and so on.
    @usableFromInline
    let _codes: ContiguousArray<Int32>
    /// Where each text starts in the codes, and then the codes' count.
    @usableFromInline
    let _textStarts: ContiguousArray<Int>
    /// Each symbol's code: its rank among the texts' distinct symbols when `Symbol` is
    /// `Comparable`, else its order of first occurrence. Empty when `Symbol` is `UInt8`, whose
    /// code is its value.
    @usableFromInline
    let _alphabet: [Symbol: Int32]
    @usableFromInline
    let _nodes: _SuffixTreeNodes

    /// A place in one of the tree's texts: a substring, or a suffix.
    @frozen
    public struct Occurrence: Hashable, Sendable {
        /// The index of the text, in the order the texts were given.
        public var textIndex: Int
        /// The symbols' offsets in that text.
        public var range: Range<Int>

        /// The substring of the text at `textIndex` at `range`.
        @inlinable
        public init(textIndex: Int, range: Range<Int>) {
            self.textIndex = textIndex
            self.range = range
        }
    }

    /// The suffix tree of `text`.
    ///
    /// - Parameter text: The symbols, in order. Traps when it has `Int32.max / 2` or more.
    /// - Complexity: O(*n* σ) for *n* symbols of which σ are distinct, expected.
    @inlinable
    public init(_ text: some Sequence<Symbol>) {
        self.init(texts: CollectionOfOne(Array(text)))
    }

    /// The generalized suffix tree of `texts`: every suffix of every text, each text ending in a
    /// terminator of its own.
    ///
    /// - Parameter texts: The texts. Traps when they have `Int32.max / 2` or more symbols in all.
    /// - Complexity: O(*n* σ) for *n* symbols in all of which σ are distinct, expected.
    @inlinable
    public init(texts: some Sequence<some Sequence<Symbol>>) {
        let texts = texts.map { ContiguousArray($0) }
        var total = 0
        for text in texts {
            total &+= text.count &+ 1
        }
        precondition(total < Int(Int32.max) / 2, "The texts are too long for a suffix tree")
        var alphabet: [Symbol: Int32] = [:]
        var codes = ContiguousArray<Int32>()
        codes.reserveCapacity(total)
        var textStarts = ContiguousArray<Int>()
        textStarts.reserveCapacity(texts.count &+ 1)
        if Symbol.self == UInt8.self {
            for (index, text) in texts.enumerated() {
                textStarts.append(codes.count)
                for byte in unsafeBitCast(text, to: ContiguousArray<UInt8>.self) {
                    codes.append(Int32(byte))
                }
                codes.append(Int32(truncatingIfNeeded: -1 &- index))
            }
        } else {
            var distinct: [Symbol] = []
            for text in texts {
                for symbol in text where alphabet[symbol] == nil {
                    alphabet[symbol] = Int32(truncatingIfNeeded: distinct.count)
                    distinct.append(symbol)
                }
            }
            if let order = Symbol.self as? any Comparable.Type {
                for (rank, symbol) in _sorted(distinct, by: order).enumerated() {
                    alphabet[symbol] = Int32(truncatingIfNeeded: rank)
                }
            }
            for (index, text) in texts.enumerated() {
                textStarts.append(codes.count)
                for symbol in text {
                    codes.append(alphabet[symbol]!)
                }
                codes.append(Int32(truncatingIfNeeded: -1 &- index))
            }
        }
        textStarts.append(codes.count)
        let terminators = textStarts.dropFirst().map { $0 &- 1 }
        _codes = codes
        _textStarts = textStarts
        _alphabet = alphabet
        _nodes = codes.withUnsafeBufferPointer { codes in
            terminators.withUnsafeBufferPointer { _buildSuffixTree(codes, terminators: $0) }
        }
    }

    /// The number of texts.
    @inlinable
    public var textCount: Int { _textStarts.count &- 1 }

    /// The number of nodes, the root and every leaf included.
    @inlinable
    public var nodeCount: Int { _nodes.count }

    /// The root, node 0.
    @inlinable
    public var root: Int { 0 }

    /// The nodes, in preorder.
    @inlinable
    public var nodes: Range<Int> { 0 ..< _nodes.count }

    /// Whether `node` is a leaf, where a suffix ends.
    ///
    /// - Parameter node: Traps unless it is a node.
    /// - Complexity: O(1).
    @inlinable
    public func isLeaf(_ node: Int) -> Bool {
        precondition(node >= 0 && node < _nodes.count, "Node out of range")
        return _nodes.isLeaf(node)
    }

    /// The node's children, in the order of the symbols that start their edges.
    ///
    /// - Parameter node: Traps unless it is a node.
    /// - Complexity: O(*k*) for *k* children.
    @inlinable
    public func children(of node: Int) -> [Int] {
        precondition(node >= 0 && node < _nodes.count, "Node out of range")
        guard !_nodes.isLeaf(node) else { return [] }
        var children: [Int] = []
        var child = node &+ 1
        while child >= 0 {
            children.append(child)
            child = Int(_nodes.nextSiblings[child])
        }
        return children
    }

    /// The node's parent, or nil for the root.
    ///
    /// - Parameter node: Traps unless it is a node.
    /// - Complexity: O(1).
    @inlinable
    public func parent(of node: Int) -> Int? {
        precondition(node >= 0 && node < _nodes.count, "Node out of range")
        let parent = Int(_nodes.parents[node])
        return parent < 0 ? nil : parent
    }

    /// The number of symbols on the path from the root to the node, a terminator not counted.
    ///
    /// - Parameter node: Traps unless it is a node.
    /// - Complexity: O(1).
    @inlinable
    public func stringDepth(of node: Int) -> Int {
        precondition(node >= 0 && node < _nodes.count, "Node out of range")
        return Int(_nodes.depths[node]) &- (_nodes.isLeaf(node) ? 1 : 0)
    }

    /// The symbols on the edge into the node, as a place in one of the texts; a terminator is not
    /// part of it, so the edge to the leaf of an empty suffix has an empty label.
    ///
    /// - Parameter node: Traps unless it is a node other than the root.
    /// - Complexity: O(log *k*) for *k* texts.
    @inlinable
    public func edgeLabel(of node: Int) -> Occurrence {
        precondition(node > 0 && node < _nodes.count, "Node out of range, or the root")
        let start = Int(_nodes.starts[node])
        let length = Int(_nodes.ends[node]) &- start &- (_nodes.isLeaf(node) ? 1 : 0)
        let text = _textIndex(ofCode: start)
        let offset = start &- _textStarts[text]
        return Occurrence(textIndex: text, range: offset ..< offset &+ length)
    }

    /// The symbols on the path from the root to the node, as a place in one of the texts where
    /// they occur: for a leaf, its suffix; for an internal node, the occurrence at its first leaf;
    /// for the root, the empty range at the start of the first text.
    ///
    /// - Parameter node: Traps unless it is a node.
    /// - Complexity: O(log *k*) for *k* texts, and O(1) more for an internal node.
    @inlinable
    public func pathLabel(of node: Int) -> Occurrence {
        precondition(node >= 0 && node < _nodes.count, "Node out of range")
        guard node > 0 else { return Occurrence(textIndex: 0, range: 0 ..< 0) }
        // Preorder reaches a node's first leaf by first children alone.
        var leaf = node
        while !_nodes.isLeaf(leaf) {
            leaf &+= 1
        }
        let suffixStart = Int(_nodes.suffixStarts[leaf])
        let text = _textIndex(ofCode: suffixStart)
        let offset = suffixStart &- _textStarts[text]
        return Occurrence(textIndex: text, range: offset ..< offset &+ stringDepth(of: node))
    }

    /// Every occurrence of `pattern` in the texts, in the order of the suffixes they start, when
    /// `Symbol` is `Comparable`.
    ///
    /// - Parameter pattern: The symbols to find. The empty pattern occurs at every offset short of
    ///   each text's end.
    /// - Returns: One occurrence per place the pattern starts.
    /// - Complexity: O(*m* σ + *z*) for a pattern of *m* symbols and *z* occurrences.
    @inlinable
    public func occurrences(of pattern: some Sequence<Symbol>) -> [Occurrence] {
        guard let codes = _patternCodes(pattern) else { return [] }
        let node = codes.withUnsafeBufferPointer { pattern in
            _codes.withUnsafeBufferPointer { _locate(pattern, in: $0, nodes: _nodes) }
        }
        guard node >= 0 else { return [] }
        let length = codes.count
        var found: [Occurrence] = []
        for leaf in node ..< Int(_nodes.subtreeEnds[node]) where _nodes.isLeaf(leaf) {
            let suffixStart = Int(_nodes.suffixStarts[leaf])
            // The leaf of an empty suffix starts at its terminator.
            guard _codes[suffixStart] >= 0 else { continue }
            let text = _textIndex(ofCode: suffixStart)
            let offset = suffixStart &- _textStarts[text]
            found.append(Occurrence(textIndex: text, range: offset ..< offset &+ length))
        }
        return found
    }

    /// Whether `pattern` occurs in any of the texts.
    ///
    /// - Parameter pattern: The symbols to find. The empty pattern occurs in every tree.
    /// - Complexity: O(*m* σ) for a pattern of *m* symbols.
    @inlinable
    public func contains(_ pattern: some Sequence<Symbol>) -> Bool {
        guard let codes = _patternCodes(pattern) else { return false }
        return codes.withUnsafeBufferPointer { pattern in
            _codes.withUnsafeBufferPointer { _locate(pattern, in: $0, nodes: _nodes) }
        } >= 0
    }

    /// The longest substring that occurs more than once in the texts, at its first occurrence in
    /// suffix order, or nil when no symbol does. Of several such substrings, the one whose node
    /// comes first in preorder.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public var longestRepeatedSubstring: Occurrence? {
        var best = 0
        var bestNode = 0
        for node in 1 ..< _nodes.count where !_nodes.isLeaf(node) && Int(_nodes.depths[node]) > best {
            best = Int(_nodes.depths[node])
            bestNode = node
        }
        return best > 0 ? pathLabel(of: bestNode) : nil
    }

    /// The longest substring that occurs in every text, at its first occurrence in suffix order,
    /// or nil when the texts have no symbol in common. Of several such substrings, the one whose
    /// node comes first in preorder. A tree of one text has the whole text in common with itself.
    ///
    /// - Complexity: O(*n* *k* / 64) for *k* texts.
    @inlinable
    public var longestCommonSubstring: Occurrence? {
        let k = textCount
        guard k > 0 else { return nil }
        let words = (k &+ 63) / 64
        let count = _nodes.count
        // Which texts have a suffix below each node, as `words` words of bits per node,
        // gathered bottom-up: preorder puts children after their parents.
        var texts = [UInt64](repeating: 0, count: count &* words)
        var node = count &- 1
        while node >= 0 {
            if _nodes.isLeaf(node) {
                let text = _textIndex(ofCode: Int(_nodes.suffixStarts[node]))
                texts[node &* words &+ text / 64] |= 1 << UInt64(text % 64)
            }
            if node > 0 {
                let parent = Int(_nodes.parents[node])
                for word in 0 ..< words {
                    texts[parent &* words &+ word] |= texts[node &* words &+ word]
                }
            }
            node &-= 1
        }
        var all = [UInt64](repeating: .max, count: words)
        if k % 64 != 0 {
            all[words &- 1] = (1 << UInt64(k % 64)) &- 1
        }
        var best = 0
        var bestNode = -1
        for node in 1 ..< count where stringDepth(of: node) > best {
            var everyText = true
            for word in 0 ..< words where texts[node &* words &+ word] != all[word] {
                everyText = false
                break
            }
            if everyText {
                best = stringDepth(of: node)
                bestNode = node
            }
        }
        return bestNode >= 0 ? pathLabel(of: bestNode) : nil
    }

    /// The index of the text that holds the code at `position`.
    @inlinable
    func _textIndex(ofCode position: Int) -> Int {
        var low = 0
        var high = _textStarts.count &- 1
        while high &- low > 1 {
            let middle = low &+ (high &- low) >> 1
            if _textStarts[middle] <= position {
                low = middle
            } else {
                high = middle
            }
        }
        return low
    }

    /// The pattern's codes, or nil when it has a symbol no text has.
    @inlinable
    func _patternCodes(_ pattern: some Sequence<Symbol>) -> ContiguousArray<Int32>? {
        var codes = ContiguousArray<Int32>()
        if Symbol.self == UInt8.self {
            for symbol in pattern {
                codes.append(Int32(unsafeBitCast(symbol, to: UInt8.self)))
            }
            return codes
        }
        for symbol in pattern {
            guard let code = _alphabet[symbol] else { return nil }
            codes.append(code)
        }
        return codes
    }
}

extension SuffixTree: Sendable where Symbol: Sendable {}

/// `symbols` sorted, when their dynamic type is the `Comparable` type `order`.
@inlinable
func _sorted<Symbol, Order: Comparable>(_ symbols: [Symbol], by order: Order.Type) -> [Symbol] {
    let keys = unsafeBitCast(symbols, to: [Order].self)
    return unsafeBitCast(keys.sorted(), to: [Symbol].self)
}
