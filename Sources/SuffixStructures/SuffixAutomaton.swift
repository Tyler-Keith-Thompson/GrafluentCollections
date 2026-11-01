/// The suffix automaton of a text: the smallest deterministic automaton that accepts every suffix
/// of it, whose paths from the start state spell exactly the text's substrings (Blumer et al.,
/// "The Smallest Automaton Recognizing the Subwords of a Text", 1985).
///
/// It is built one symbol at a time in O(*n*) expected steps, with at most 2*n* − 1 states and
/// 3*n* − 4 transitions. Each state stands for the substrings that end at the same set of places
/// in the text; its suffix link leads to the state of the longest of their suffixes that ends at
/// more places. A pattern is checked in O(*m*) transitions.
///
/// ```swift
/// let automaton = SuffixAutomaton("abcbc")
/// automaton.contains("cbc")              // true
/// automaton.occurrenceCount(of: "bc")    // 2
/// automaton.firstOccurrence(of: "cb")    // 2 ..< 4
/// automaton.distinctSubstringCount       // 12
/// automaton.longestCommonSubstring(with: "xbcbz")?.textRange  // 1 ..< 4, "bcb"
/// ```
///
/// Transitions from a state come in the order of their symbols: sorted when `Symbol` is
/// `Comparable`, otherwise in the order the symbols first occur in the text. The automaton is a
/// directed graph, ``transitionsView``, and its suffix links are a tree that converts to
/// Grafluent's `Arborescence` with `Arborescence(_:)`.
@frozen
public struct SuffixAutomaton<Symbol: Hashable> {
    /// Each symbol's code: its rank among the text's distinct symbols when `Symbol` is
    /// `Comparable`, else its order of first occurrence. Empty when `Symbol` is `UInt8`, whose
    /// code is its value.
    @usableFromInline
    let _alphabet: [Symbol: Int32]
    /// The text's distinct symbols by code; empty when `Symbol` is `UInt8`.
    @usableFromInline
    let _symbols: [Symbol]
    /// The text's length.
    @usableFromInline
    let _count: Int
    @usableFromInline
    let _states: _SuffixAutomatonStates

    /// A substring this text has in common with another, at its first place in each.
    @frozen
    public struct CommonSubstring: Hashable, Sendable {
        /// The substring's offsets in the automaton's text, where it first ends.
        public var textRange: Range<Int>
        /// The substring's offsets in the other text, where it first ends.
        public var otherRange: Range<Int>

        /// The substring at `textRange` in the automaton's text and `otherRange` in the other.
        @inlinable
        public init(textRange: Range<Int>, otherRange: Range<Int>) {
            self.textRange = textRange
            self.otherRange = otherRange
        }
    }

    /// The suffix automaton of `text`.
    ///
    /// - Parameter text: The symbols, in order. Traps when it has `Int32.max / 2` or more.
    /// - Complexity: O(*n* σ) for *n* symbols of which σ are distinct, expected.
    @inlinable
    public init(_ text: some Sequence<Symbol>) {
        let text = ContiguousArray(text)
        precondition(text.count < Int(Int32.max) / 2, "The text is too long for a suffix automaton")
        var codes = ContiguousArray<Int32>()
        codes.reserveCapacity(text.count)
        var alphabet: [Symbol: Int32] = [:]
        var symbols: [Symbol] = []
        if Symbol.self == UInt8.self {
            for byte in unsafeBitCast(text, to: ContiguousArray<UInt8>.self) {
                codes.append(Int32(byte))
            }
        } else {
            for symbol in text where alphabet[symbol] == nil {
                alphabet[symbol] = Int32(truncatingIfNeeded: symbols.count)
                symbols.append(symbol)
            }
            if let order = Symbol.self as? any Comparable.Type {
                symbols = _sorted(symbols, by: order)
                for (rank, symbol) in symbols.enumerated() {
                    alphabet[symbol] = Int32(truncatingIfNeeded: rank)
                }
            }
            for symbol in text {
                codes.append(alphabet[symbol]!)
            }
        }
        _alphabet = alphabet
        _symbols = symbols
        _count = text.count
        _states = codes.withUnsafeBufferPointer { _buildSuffixAutomaton($0) }
    }

    /// The number of symbols in the text.
    @inlinable
    public var count: Int { _count }

    /// The number of states, the start state included.
    @inlinable
    public var stateCount: Int { _states.count }

    /// The number of transitions.
    @inlinable
    public var transitionCount: Int { _states.codes.count }

    /// Whether `pattern` is a substring of the text.
    ///
    /// - Parameter pattern: The symbols to find. The empty pattern is a substring of every text.
    /// - Complexity: O(*m* log σ) for a pattern of *m* symbols.
    @inlinable
    public func contains(_ pattern: some Sequence<Symbol>) -> Bool {
        _state(of: pattern) >= 0
    }

    /// Whether `pattern` is a suffix of the text.
    ///
    /// - Parameter pattern: The symbols to check. The empty pattern is a suffix of every text.
    /// - Complexity: O(*m* log σ) for a pattern of *m* symbols.
    @inlinable
    public func hasSuffix(_ pattern: some Sequence<Symbol>) -> Bool {
        let state = _state(of: pattern)
        return state >= 0 && _states.isTerminal[state]
    }

    /// The number of places `pattern` occurs in the text, overlapping places included.
    ///
    /// - Parameter pattern: The symbols to count. The empty pattern occurs at every offset short of
    ///   the text's end.
    /// - Complexity: O(*m* log σ) for a pattern of *m* symbols.
    @inlinable
    public func occurrenceCount(of pattern: some Sequence<Symbol>) -> Int {
        let state = _state(of: pattern)
        return state < 0 ? 0 : Int(_states.occurrenceCounts[state])
    }

    /// The offsets of the first place `pattern` occurs in the text, or nil when it does not.
    ///
    /// - Parameter pattern: The symbols to find. The empty pattern occurs first at 0.
    /// - Complexity: O(*m* log σ) for a pattern of *m* symbols.
    @inlinable
    public func firstOccurrence(of pattern: some Sequence<Symbol>) -> Range<Int>? {
        let pattern = ContiguousArray(pattern)
        let state = _state(of: pattern)
        guard state >= 0 else { return nil }
        guard !pattern.isEmpty else { return 0 ..< 0 }
        let end = Int(_states.firstEnds[state])
        return end &- pattern.count ..< end
    }

    /// The number of distinct non-empty substrings of the text.
    ///
    /// Counted in `Int64`, since a text of *n* symbols can have *n*(*n* + 1)/2 of them.
    ///
    /// - Complexity: O(*n*).
    @inlinable
    public var distinctSubstringCount: Int64 {
        var total: Int64 = 0
        for state in 1 ..< Swift.max(_states.count, 1) {
            total &+= Int64(_states.lengths[state]) &- Int64(_states.lengths[Int(_states.links[state])])
        }
        return total
    }

    /// The longest substring of the text that `other` has too, or nil when they share no symbol.
    /// Of several, the one that ends first in `other`.
    ///
    /// Walks `other` over the automaton, following suffix links where a transition is missing.
    ///
    /// - Parameter other: The text to compare with.
    /// - Returns: Where the substring first ends in each text.
    /// - Complexity: O(*k* log σ) for *k* symbols in `other`.
    @inlinable
    public func longestCommonSubstring(with other: some Sequence<Symbol>) -> CommonSubstring? {
        var state = 0
        var length = 0
        var best = 0
        var bestState = 0
        var bestEnd = 0
        var offset = 0
        for symbol in other {
            offset &+= 1
            guard let code = _code(of: symbol) else {
                state = 0
                length = 0
                continue
            }
            var next = _states.transition(from: state, on: code)
            while next < 0 && state > 0 {
                state = Int(_states.links[state])
                length = Int(_states.lengths[state])
                next = _states.transition(from: state, on: code)
            }
            if next >= 0 {
                state = next
                length &+= 1
            } else {
                state = 0
                length = 0
            }
            if length > best {
                best = length
                bestState = state
                bestEnd = offset
            }
        }
        guard best > 0 else { return nil }
        let end = Int(_states.firstEnds[bestState])
        return CommonSubstring(textRange: end &- best ..< end, otherRange: bestEnd &- best ..< bestEnd)
    }

    /// The symbol's code, or nil when the text does not have it.
    @inlinable
    func _code(of symbol: Symbol) -> Int32? {
        if Symbol.self == UInt8.self {
            return Int32(unsafeBitCast(symbol, to: UInt8.self))
        }
        return _alphabet[symbol]
    }

    /// The symbol a code stands for.
    @inlinable
    func _symbol(ofCode code: Int32) -> Symbol {
        if Symbol.self == UInt8.self {
            return unsafeBitCast(UInt8(truncatingIfNeeded: code), to: Symbol.self)
        }
        return _symbols[Int(code)]
    }

    /// The state the pattern leads to from the start state, or −1.
    @inlinable
    func _state(of pattern: some Sequence<Symbol>) -> Int {
        var state = 0
        for symbol in pattern {
            guard let code = _code(of: symbol) else { return -1 }
            state = _states.transition(from: state, on: code)
            if state < 0 { return -1 }
        }
        return state
    }
}

extension SuffixAutomaton: Sendable where Symbol: Sendable {}
