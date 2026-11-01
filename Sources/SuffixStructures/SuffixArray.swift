/// A text's suffix array and longest-common-prefix array: the starting positions of its
/// suffixes in sorted order, and the length of the prefix each suffix shares with the one before
/// it (Manber and Myers, "Suffix Arrays: A New Method for On-Line String Searches", 1990).
///
/// Together the two arrays answer what a suffix tree answers, in a fraction of the space:
/// where a pattern occurs, in O(*m* log *n*) for a pattern of *m* symbols; the longest substring
/// that occurs twice; the number of distinct substrings.
///
/// ```swift
/// let banana = SuffixArray("banana")
/// Array(banana.positions)              // [5, 3, 1, 0, 4, 2]
/// Array(banana.longestCommonPrefixes)  // [0, 1, 3, 0, 0, 2]
/// banana.occurrences(of: "ana")        // 1 ..< 3, so positions 3 and 1
/// banana.longestRepeatedSubstring      // 1 ..< 4, "ana"
/// banana.distinctSubstringCount        // 15
/// ```
///
/// A suffix array is immutable: it holds a copy of its text and is built once, in O(*n*) for a
/// byte text and O(*n* log σ) for a text of σ distinct symbols of any other type, which are first
/// replaced by their ranks. Positions and prefix lengths are stored in 32 bits when the text has
/// at most `Int32.max` symbols.
@frozen
public struct SuffixArray<Symbol: Comparable> {
    /// The text.
    @usableFromInline
    let _text: ContiguousArray<Symbol>
    /// The positions and prefix lengths when the text has at most `Int32.max` symbols, else empty.
    @usableFromInline
    let _narrow: _SuffixArrayParts<Int32>
    /// The positions and prefix lengths when the text has more than `Int32.max` symbols, else
    /// empty.
    @usableFromInline
    let _wide: _SuffixArrayParts<Int>

    /// The suffix array of `text`.
    ///
    /// - Parameter text: The symbols, in order.
    /// - Complexity: O(*n*) for `UInt8` symbols, O(*n* log σ) otherwise, for *n* symbols of which
    ///   σ are distinct.
    @inlinable
    public init(_ text: some Sequence<Symbol>) {
        let text = ContiguousArray(text)
        _text = text
        let empty = _SuffixArrayParts<Int32>(positions: [], longestCommonPrefixes: [])
        let emptyWide = _SuffixArrayParts<Int>(positions: [], longestCommonPrefixes: [])
        let isWide = Int64(text.count) > Int64(Int32.max)
        if Symbol.self == UInt8.self {
            let bytes = unsafeBitCast(text, to: ContiguousArray<UInt8>.self)
            if isWide {
                _narrow = empty
                _wide = bytes.withUnsafeBufferPointer { _wideSuffixArray(bytes: $0) }
            } else {
                _narrow = bytes.withUnsafeBufferPointer { _narrowSuffixArray(bytes: $0) }
                _wide = emptyWide
            }
            return
        }
        // The distinct symbols, sorted, so a symbol's rank is its index here.
        var alphabet = Array(text)
        alphabet.sort()
        var distinct = 0
        for symbol in alphabet where distinct == 0 || alphabet[distinct &- 1] != symbol {
            alphabet[distinct] = symbol
            distinct &+= 1
        }
        alphabet.removeSubrange(distinct...)
        let upper = Swift.max(distinct &- 1, 0)
        func rank(_ symbol: Symbol) -> Int {
            var low = 0
            var high = alphabet.count
            while low < high {
                let middle = low &+ (high &- low) >> 1
                if alphabet[middle] < symbol {
                    low = middle &+ 1
                } else {
                    high = middle
                }
            }
            return low
        }
        if isWide {
            let ranks = ContiguousArray(text.lazy.map { rank($0) })
            _narrow = empty
            _wide = ranks.withUnsafeBufferPointer { _wideSuffixArray(ranks: $0, upper: upper) }
        } else {
            let ranks = ContiguousArray(text.lazy.map { Int32(truncatingIfNeeded: rank($0)) })
            _narrow = ranks.withUnsafeBufferPointer { _narrowSuffixArray(ranks: $0, upper: upper) }
            _wide = emptyWide
        }
    }

    /// The number of symbols in the text, which is the number of its non-empty suffixes.
    @inlinable
    public var count: Int { _text.count }

    /// The text's symbols.
    @inlinable
    public var text: ContiguousArray<Symbol> { _text }

    /// The starting positions of the text's suffixes, in the suffixes' sorted order.
    ///
    /// A suffix sorts before every suffix it is a proper prefix of.
    @inlinable
    public var positions: Positions { Positions(narrow: _narrow.positions, wide: _wide.positions) }

    /// For each suffix in sorted order, the length of the longest prefix it shares with the
    /// suffix before it; 0 for the first.
    @inlinable
    public var longestCommonPrefixes: LongestCommonPrefixes {
        LongestCommonPrefixes(narrow: _narrow.longestCommonPrefixes, wide: _wide.longestCommonPrefixes)
    }

    /// The range of ``positions`` whose suffixes begin with `pattern`: one entry per occurrence
    /// of the pattern in the text, at that entry's position.
    ///
    /// - Parameter pattern: The symbols to find. The empty pattern occurs at every position.
    /// - Returns: A range of indices into ``positions``, empty when the pattern does not occur.
    /// - Complexity: O(*m* log *n*) for a pattern of *m* symbols.
    @inlinable
    public func occurrences(of pattern: some Sequence<Symbol>) -> Range<Int> {
        let pattern = ContiguousArray(pattern)
        let isWide = !_wide.positions.isEmpty
        return _text.withUnsafeBufferPointer { text in
            pattern.withUnsafeBufferPointer { pattern in
                if isWide {
                    _wide.positions.withUnsafeBufferPointer { _occurrences(of: pattern, in: text, positions: $0) }
                } else {
                    _narrow.positions.withUnsafeBufferPointer { _occurrences(of: pattern, in: text, positions: $0) }
                }
            }
        }
    }

    /// Whether `pattern` occurs in the text.
    ///
    /// - Parameter pattern: The symbols to find. The empty pattern occurs in every text, the empty
    ///   text included.
    /// - Complexity: O(*m* log *n*) for a pattern of *m* symbols.
    @inlinable
    public func contains(_ pattern: some Sequence<Symbol>) -> Bool {
        let pattern = ContiguousArray(pattern)
        return pattern.isEmpty || !occurrences(of: pattern).isEmpty
    }

    /// The positions in the text of the longest substring that occurs more than once, or nil when
    /// no symbol does. Of several such substrings, the one that sorts first.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public var longestRepeatedSubstring: Range<Int>? {
        let prefixes = longestCommonPrefixes
        var best = 0
        var bestIndex = 0
        for k in prefixes.indices where prefixes[k] > best {
            best = prefixes[k]
            bestIndex = k
        }
        guard best > 0 else { return nil }
        let start = positions[bestIndex]
        return start ..< start &+ best
    }

    /// The number of distinct non-empty substrings of the text.
    ///
    /// Counted in `Int64`, since a text of *n* symbols can have *n*(*n* + 1)/2 of them.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public var distinctSubstringCount: Int64 {
        let n = Int64(count)
        var shared: Int64 = 0
        for length in longestCommonPrefixes {
            shared &+= Int64(length)
        }
        return n * (n + 1) / 2 - shared
    }
}

extension SuffixArray: Sendable where Symbol: Sendable {}

extension SuffixArray {
    /// The starting positions of a text's suffixes in sorted order; see
    /// ``SuffixArray/positions``.
    @frozen
    public struct Positions: RandomAccessCollection, Sendable {
        @usableFromInline let _narrow: ContiguousArray<Int32>
        @usableFromInline let _wide: ContiguousArray<Int>

        @inlinable
        init(narrow: ContiguousArray<Int32>, wide: ContiguousArray<Int>) {
            _narrow = narrow
            _wide = wide
        }

        @inlinable public var startIndex: Int { 0 }
        @inlinable public var endIndex: Int { _wide.isEmpty ? _narrow.count : _wide.count }

        /// The starting position of the suffix at `index` in sorted order.
        ///
        /// - Parameter index: Traps unless it is a valid index.
        /// - Complexity: O(1).
        @inlinable
        public subscript(index: Int) -> Int {
            _wide.isEmpty ? Int(_narrow[index]) : _wide[index]
        }
    }

    /// The longest-common-prefix lengths of a text's sorted suffixes; see
    /// ``SuffixArray/longestCommonPrefixes``.
    @frozen
    public struct LongestCommonPrefixes: RandomAccessCollection, Sendable {
        @usableFromInline let _narrow: ContiguousArray<Int32>
        @usableFromInline let _wide: ContiguousArray<Int>

        @inlinable
        init(narrow: ContiguousArray<Int32>, wide: ContiguousArray<Int>) {
            _narrow = narrow
            _wide = wide
        }

        @inlinable public var startIndex: Int { 0 }
        @inlinable public var endIndex: Int { _wide.isEmpty ? _narrow.count : _wide.count }

        /// The length of the prefix the suffix at `index` in sorted order shares with the one
        /// before it.
        ///
        /// - Parameter index: Traps unless it is a valid index.
        /// - Complexity: O(1).
        @inlinable
        public subscript(index: Int) -> Int {
            _wide.isEmpty ? Int(_narrow[index]) : _wide[index]
        }
    }
}

/// The range of `positions` whose suffixes of `text` begin with `pattern`, by two binary searches.
@inlinable
func _occurrences<Symbol: Comparable, Index: FixedWidthInteger>(
    of pattern: UnsafeBufferPointer<Symbol>, in text: UnsafeBufferPointer<Symbol>, positions: UnsafeBufferPointer<Index>
) -> Range<Int> {
    let n = text.count
    let m = pattern.count
    // −1 when the suffix at `start` sorts before every text that begins with the pattern, 0 when
    // it begins with the pattern, 1 when it sorts after.
    func compare(_ start: Int) -> Int {
        var k = 0
        while k < m {
            if start &+ k == n { return -1 }
            let symbol = text[start &+ k]
            let wanted = pattern[k]
            if symbol < wanted { return -1 }
            if wanted < symbol { return 1 }
            k &+= 1
        }
        return 0
    }
    var low = 0
    var high = positions.count
    while low < high {
        let middle = low &+ (high &- low) >> 1
        if compare(Int(positions[middle])) < 0 {
            low = middle &+ 1
        } else {
            high = middle
        }
    }
    let lower = low
    high = positions.count
    while low < high {
        let middle = low &+ (high &- low) >> 1
        if compare(Int(positions[middle])) <= 0 {
            low = middle &+ 1
        } else {
            high = middle
        }
    }
    return lower ..< low
}
