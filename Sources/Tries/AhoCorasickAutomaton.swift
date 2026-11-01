/// An automaton that finds every occurrence of every pattern of a set in one pass over a text
/// (Aho and Corasick, 1975).
///
/// It is the trie of the patterns with two more links per state: the failure link, to the state
/// of the longest proper suffix of the state's prefix that is also a prefix of some pattern, and
/// the output link, to the nearest state along the failure links at which a pattern ends. A scan
/// follows the trie while the text matches and the failure links where it stops matching, so it
/// reads each symbol of the text once and reports all the matches in O(*t* + *k*) for a text of
/// *t* symbols with *k* matches.
///
/// ```swift
/// let automaton = AhoCorasickAutomaton(patterns: ["he", "she", "his", "hers"])
/// for match in automaton.matches(in: "ushers") {
///     print(match.patternIndex, match.range)
/// }
/// // 1 1..<4   ("she")
/// // 0 2..<4   ("he")
/// // 3 2..<6   ("hers")
/// ```
///
/// Matches come in order of where they end, and of those ending at one place, longest first.
/// Ranges count the text's symbols from 0. The automaton is built once and is immutable.
///
/// Symbols are mapped to dense indices at construction, through a 256-entry table when they are
/// `UInt8` and a dictionary otherwise, so a scan over bytes, such as a string's `utf8`, does no
/// hashing. When the states times the distinct symbols are few enough, every transition is
/// precomputed into a table, and a scan takes one load per symbol.
@frozen
public struct AhoCorasickAutomaton<Symbol: Hashable> {
    /// The distinct symbols of the patterns, by index.
    @usableFromInline let _alphabet: ContiguousArray<Symbol>
    /// The index of each symbol in `_alphabet`.
    @usableFromInline let _alphabetIndices: [Symbol: Int32]
    /// When `Symbol` is `UInt8`, the alphabet index of every byte, the alphabet's count for one
    /// no pattern has; empty otherwise.
    @usableFromInline let _byteIndices: ContiguousArray<Int32>
    /// Each state's goto transitions: row `s` is `_gotoOffsets[s] ..< _gotoOffsets[s + 1]` of
    /// `_gotoSymbols` (alphabet indices, ascending) and `_gotoTargets`.
    @usableFromInline let _gotoOffsets: ContiguousArray<Int32>
    @usableFromInline let _gotoSymbols: ContiguousArray<Int32>
    @usableFromInline let _gotoTargets: ContiguousArray<Int32>
    /// Each state's failure link; the root's is itself.
    @usableFromInline let _failures: ContiguousArray<Int32>
    /// Each state's output link: the nearest state along its failure links, other than itself,
    /// at which a pattern ends, or −1.
    @usableFromInline let _outputLinks: ContiguousArray<Int32>
    /// The first state to report from after reaching each state: the state itself when a pattern
    /// ends there, its output link otherwise.
    @usableFromInline let _reportStates: ContiguousArray<Int32>
    /// The patterns ending at each state, ascending: `_outputOffsets[s] ..< _outputOffsets[s + 1]`
    /// of `_outputPatterns`.
    @usableFromInline let _outputOffsets: ContiguousArray<Int32>
    @usableFromInline let _outputPatterns: ContiguousArray<Int32>
    /// The length of each pattern, by index.
    @usableFromInline let _patternLengths: ContiguousArray<Int>
    /// Every transition, `state × (alphabet count + 1) + symbol index`, when precomputed; empty
    /// otherwise. The last column, for a symbol no pattern has, leads to the root.
    @usableFromInline let _transitions: ContiguousArray<Int32>

    /// The most entries a precomputed transition table has: 2²², 16 MiB of `Int32`.
    @inlinable
    static var _maximumTableEntries: Int { 1 << 22 }

    /// The automaton for `patterns`.
    ///
    /// Repeated patterns are kept, each with its own index, and an empty pattern matches at every
    /// offset of a text, its end included.
    ///
    /// - Parameter patterns: The patterns, read once, in order; a pattern's index is its position.
    /// - Complexity: O(*L* log *σ*) expected for *L* symbols in all and *σ* distinct symbols, plus
    ///   O(*S*·*σ*) for *S* states when the transitions are precomputed.
    @inlinable
    public init<Patterns: Sequence>(patterns: Patterns) where Patterns.Element: Sequence, Patterns.Element.Element == Symbol {
        // Map the symbols to dense indices and build the trie, numbering states as they are met.
        var alphabet = ContiguousArray<Symbol>()
        var alphabetIndices: [Symbol: Int32] = [:]
        var children: [Int: Int32] = [:]
        var edges = ContiguousArray<(parent: Int32, symbol: Int32, child: Int32)>()
        var stateCount: Int32 = 1
        var ends = ContiguousArray<(state: Int32, pattern: Int32)>()
        var lengths = ContiguousArray<Int>()
        for pattern in patterns {
            var state: Int32 = 0
            var length = 0
            for symbol in pattern {
                let index: Int32
                if let known = alphabetIndices[symbol] {
                    index = known
                } else {
                    index = Int32(truncatingIfNeeded: alphabet.count)
                    alphabet.append(symbol)
                    alphabetIndices[symbol] = index
                }
                // A key unique for (state, symbol): states and symbols are below 2³¹.
                let key = Int(state) << 32 | Int(index)
                if let child = children[key] {
                    state = child
                } else {
                    precondition(stateCount < Int32.max, "An automaton has fewer than 2³¹ − 1 states")
                    children[key] = stateCount
                    edges.append((state, index, stateCount))
                    state = stateCount
                    stateCount &+= 1
                }
                length &+= 1
            }
            precondition(lengths.count < Int(Int32.max), "An automaton has fewer than 2³¹ − 1 patterns")
            ends.append((state, Int32(truncatingIfNeeded: lengths.count)))
            lengths.append(length)
        }
        let states = Int(stateCount)
        let sigma = alphabet.count

        // Goto rows, sorted by parent and then symbol.
        edges.sort { a, b in a.parent < b.parent || (a.parent == b.parent && a.symbol < b.symbol) }
        var gotoOffsets = ContiguousArray<Int32>(repeating: 0, count: states &+ 1)
        for edge in edges {
            gotoOffsets[Int(edge.parent) &+ 1] &+= 1
        }
        for s in 0 ..< states {
            gotoOffsets[s &+ 1] &+= gotoOffsets[s]
        }
        let gotoSymbols = ContiguousArray(edges.lazy.map(\.symbol))
        let gotoTargets = ContiguousArray(edges.lazy.map(\.child))

        // Outputs per state, by pattern index.
        ends.sort { a, b in a.state < b.state || (a.state == b.state && a.pattern < b.pattern) }
        var outputOffsets = ContiguousArray<Int32>(repeating: 0, count: states &+ 1)
        for end in ends {
            outputOffsets[Int(end.state) &+ 1] &+= 1
        }
        for s in 0 ..< states {
            outputOffsets[s &+ 1] &+= outputOffsets[s]
        }
        let outputPatterns = ContiguousArray(ends.lazy.map(\.pattern))

        /// The goto target of `state` along `symbol`, or −1.
        func goto(_ state: Int32, _ symbol: Int32) -> Int32 {
            var low = Int(gotoOffsets[Int(state)])
            var high = Int(gotoOffsets[Int(state) &+ 1])
            while low < high {
                let middle = low &+ (high &- low) >> 1
                if gotoSymbols[middle] < symbol {
                    low = middle &+ 1
                } else {
                    high = middle
                }
            }
            return low < Int(gotoOffsets[Int(state) &+ 1]) && gotoSymbols[low] == symbol ? gotoTargets[low] : -1
        }

        // Failure and output links, breadth first so a state's failure is done before it.
        var failures = ContiguousArray<Int32>(repeating: 0, count: states)
        var outputLinks = ContiguousArray<Int32>(repeating: -1, count: states)
        var order = ContiguousArray<Int32>()
        order.reserveCapacity(states)
        order.append(0)
        var head = 0
        while head < order.count {
            let state = order[head]
            head &+= 1
            var e = Int(gotoOffsets[Int(state)])
            let end = Int(gotoOffsets[Int(state) &+ 1])
            while e < end {
                let symbol = gotoSymbols[e]
                let child = gotoTargets[e]
                var failure: Int32 = 0
                if state != 0 {
                    var f = failures[Int(state)]
                    while true {
                        let next = goto(f, symbol)
                        if next >= 0 {
                            failure = next
                            break
                        }
                        if f == 0 { break }
                        f = failures[Int(f)]
                    }
                }
                failures[Int(child)] = failure
                let failureHasOutput = outputOffsets[Int(failure)] < outputOffsets[Int(failure) &+ 1]
                outputLinks[Int(child)] = failureHasOutput ? failure : outputLinks[Int(failure)]
                order.append(child)
                e &+= 1
            }
        }

        // Every transition, when the table is small enough.
        var transitions = ContiguousArray<Int32>()
        let width = sigma &+ 1
        if sigma > 0 && states <= Self._maximumTableEntries / width {
            transitions = ContiguousArray(repeating: 0, count: states &* width)
            for state in order {
                let row = Int(state) &* width
                let failureRow = Int(failures[Int(state)]) &* width
                if state != 0 {
                    var a = 0
                    while a < sigma {
                        transitions[row &+ a] = transitions[failureRow &+ a]
                        a &+= 1
                    }
                }
                var e = Int(gotoOffsets[Int(state)])
                let end = Int(gotoOffsets[Int(state) &+ 1])
                while e < end {
                    transitions[row &+ Int(gotoSymbols[e])] = gotoTargets[e]
                    e &+= 1
                }
            }
        }

        var byteIndices = ContiguousArray<Int32>()
        if Symbol.self == UInt8.self {
            byteIndices = ContiguousArray(repeating: Int32(truncatingIfNeeded: sigma), count: 256)
            for (index, symbol) in alphabet.enumerated() {
                byteIndices[Int(unsafeBitCast(symbol, to: UInt8.self))] = Int32(truncatingIfNeeded: index)
            }
        }

        _alphabet = alphabet
        _alphabetIndices = alphabetIndices
        _byteIndices = byteIndices
        _gotoOffsets = gotoOffsets
        _gotoSymbols = gotoSymbols
        _gotoTargets = gotoTargets
        _failures = failures
        _outputLinks = outputLinks
        _reportStates = ContiguousArray((0 ..< states).lazy.map { state in
            outputOffsets[state] < outputOffsets[state &+ 1] ? Int32(truncatingIfNeeded: state) : outputLinks[state]
        })
        _outputOffsets = outputOffsets
        _outputPatterns = outputPatterns
        _patternLengths = lengths
        _transitions = transitions
    }

    /// The number of patterns. O(1).
    @inlinable
    public var patternCount: Int { _patternLengths.count }

    /// The number of states: the distinct prefixes of the patterns, the empty one included.
    /// O(1).
    @inlinable
    public var stateCount: Int { _failures.count }

    /// The length of the pattern at `index`.
    ///
    /// - Parameter index: The pattern's index. Traps unless it is in `0 ..< patternCount`; use
    ///   ``patternLength(checkedAt:)`` to throw instead.
    /// - Complexity: O(1).
    @inlinable
    public func patternLength(at index: Int) -> Int {
        precondition(index >= 0 && index < _patternLengths.count, "Pattern index out of range")
        return _patternLengths[index]
    }

    /// The length of the pattern at `index`, throwing instead of trapping on an invalid index.
    ///
    /// - Parameter index: The pattern's index.
    /// - Throws: `IndexOutOfRange` unless `index` is in `0 ..< patternCount`.
    /// - Complexity: O(1).
    @inlinable
    public func patternLength(checkedAt index: Int) throws(IndexOutOfRange) -> Int {
        guard index >= 0 && index < _patternLengths.count else { throw IndexOutOfRange() }
        return _patternLengths[index]
    }

    /// Every occurrence of every pattern in `text`, overlapping ones included, in order of where
    /// they end and, of those ending at one place, longest first.
    ///
    /// - Parameter text: The text, read once as the matches are read.
    /// - Returns: A view of the matches, found as it is iterated: O(*t* + *k*) for all of them.
    @inlinable
    public func matches<Text: Sequence>(in text: Text) -> MatchesView<Text> where Text.Element == Symbol {
        MatchesView(self, text)
    }

    /// The first match of `matches(in:)`: of the matches ending first, the longest; nil when no
    /// pattern occurs. O(*t*) up to where the match ends.
    @inlinable
    public func firstMatch(in text: some Sequence<Symbol>) -> Match? {
        var matches = MatchesView(self, text).makeIterator()
        return matches.next()
    }

    /// Whether some pattern occurs in `text`. O(*t*) up to where the first match ends.
    @inlinable
    public func containsMatch(in text: some Sequence<Symbol>) -> Bool {
        firstMatch(in: text) != nil
    }

    /// The alphabet index of `symbol`, or the alphabet's count when no pattern has it.
    @inlinable
    @inline(__always)
    func _index(of symbol: Symbol) -> Int32 {
        if Symbol.self == UInt8.self {
            return _byteIndices[Int(unsafeBitCast(symbol, to: UInt8.self))]
        }
        return _alphabetIndices[symbol] ?? Int32(truncatingIfNeeded: _alphabet.count)
    }

    /// `_step` without a transition table: the goto transition of `state` or of the first state
    /// along its failure links that has one, or the root.
    @inlinable
    @inline(never)
    func _stepAlongFailures(_ state: Int32, _ symbol: Int32) -> Int32 {
        guard Int(symbol) < _alphabet.count else { return 0 }
        var s = state
        while true {
            var e = Int(_gotoOffsets[Int(s)])
            let end = Int(_gotoOffsets[Int(s) &+ 1])
            while e < end && _gotoSymbols[e] < symbol {
                e &+= 1
            }
            if e < end && _gotoSymbols[e] == symbol { return _gotoTargets[e] }
            if s == 0 { return 0 }
            s = _failures[Int(s)]
        }
    }

    /// Whether some pattern ends at `state`.
    @inlinable
    func _hasOutput(_ state: Int32) -> Bool {
        _outputOffsets[Int(state)] < _outputOffsets[Int(state) &+ 1]
    }
}

extension AhoCorasickAutomaton {
    /// An occurrence of a pattern in a text: which pattern, and where.
    @frozen
    public struct Match: Hashable, Sendable {
        /// The index of the pattern, its position in the patterns the automaton was built from.
        public var patternIndex: Int
        /// The symbols of the text the pattern covers, counted from 0.
        public var range: Range<Int>

        /// The occurrence of pattern `patternIndex` at `range`.
        ///
        /// - Parameters:
        ///   - patternIndex: The index of the pattern.
        ///   - range: The symbols of the text it covers.
        @inlinable
        public init(patternIndex: Int, range: Range<Int>) {
            self.patternIndex = patternIndex
            self.range = range
        }
    }

    /// The matches of an automaton's patterns in a text, found as they are read; see
    /// ``AhoCorasickAutomaton/matches(in:)``.
    @frozen
    public struct MatchesView<Text: Sequence>: Sequence where Text.Element == Symbol {
        @usableFromInline let _automaton: AhoCorasickAutomaton
        @usableFromInline let _text: Text

        @inlinable
        init(_ automaton: AhoCorasickAutomaton, _ text: Text) {
            _automaton = automaton
            _text = text
        }

        @inlinable
        public func makeIterator() -> Iterator {
            Iterator(_automaton, _text.makeIterator())
        }

        /// An iterator over the matches: O(1) per symbol and per match.
        @frozen
        public struct Iterator: IteratorProtocol {
            @usableFromInline let _automaton: AhoCorasickAutomaton
            @usableFromInline var _text: Text.Iterator
            @usableFromInline var _state: Int32
            /// The number of symbols read.
            @usableFromInline var _position: Int
            /// The state whose patterns are being reported, −1 for none, and the next of them.
            @usableFromInline var _outputState: Int32
            @usableFromInline var _output: Int

            @inlinable
            init(_ automaton: AhoCorasickAutomaton, _ text: Text.Iterator) {
                _automaton = automaton
                _text = text
                _state = 0
                _position = 0
                _outputState = automaton._hasOutput(0) ? 0 : -1
                _output = Int(automaton._outputOffsets[0])
            }

            @inlinable
            public mutating func next() -> Match? {
                while true {
                    if _outputState >= 0 {
                        if _output < Int(_automaton._outputOffsets[Int(_outputState) &+ 1]) {
                            let pattern = Int(_automaton._outputPatterns[_output])
                            _output &+= 1
                            let length = _automaton._patternLengths[pattern]
                            return Match(patternIndex: pattern, range: _position &- length ..< _position)
                        }
                        _outputState = _automaton._outputLinks[Int(_outputState)]
                        if _outputState >= 0 {
                            _output = Int(_automaton._outputOffsets[Int(_outputState)])
                        }
                        continue
                    }
                    guard _scan() else { return nil }
                }
            }

            /// Reads symbols up to the next state with a pattern to report, and makes it the
            /// output state.
            ///
            /// - Returns: False when the text ran out first.
            @inlinable
            mutating func _scan() -> Bool {
                let automaton = _automaton
                let reportState: Int32 = automaton._reportStates.withUnsafeBufferPointer { reports in
                    if automaton._transitions.isEmpty {
                        while let symbol = _text.next() {
                            _state = automaton._stepAlongFailures(_state, automaton._index(of: symbol))
                            _position &+= 1
                            let report = reports[Int(_state)]
                            if report >= 0 { return report }
                        }
                        return -1
                    }
                    let width = automaton._alphabet.count &+ 1
                    return automaton._transitions.withUnsafeBufferPointer { transitions in
                        if Symbol.self == UInt8.self {
                            return automaton._byteIndices.withUnsafeBufferPointer { bytes in
                                var state = Int(_state)
                                var position = _position
                                defer {
                                    _state = Int32(truncatingIfNeeded: state)
                                    _position = position
                                }
                                while let symbol = _text.next() {
                                    let index = Int(bytes[Int(unsafeBitCast(symbol, to: UInt8.self))])
                                    state = Int(transitions[state &* width &+ index])
                                    position &+= 1
                                    let report = reports[state]
                                    if report >= 0 { return report }
                                }
                                return -1
                            }
                        }
                        var state = Int(_state)
                        var position = _position
                        defer {
                            _state = Int32(truncatingIfNeeded: state)
                            _position = position
                        }
                        while let symbol = _text.next() {
                            state = Int(transitions[state &* width &+ Int(automaton._index(of: symbol))])
                            position &+= 1
                            let report = reports[state]
                            if report >= 0 { return report }
                        }
                        return -1
                    }
                }
                guard reportState >= 0 else { return false }
                _outputState = reportState
                _output = Int(automaton._outputOffsets[Int(reportState)])
                return true
            }
        }
    }
}

extension AhoCorasickAutomaton: Sendable where Symbol: Sendable {}
extension AhoCorasickAutomaton.MatchesView: Sendable where Symbol: Sendable, Text: Sendable {}
extension AhoCorasickAutomaton.MatchesView.Iterator: Sendable where Symbol: Sendable, Text.Iterator: Sendable {}
