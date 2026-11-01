// Suffix automaton construction, one symbol at a time (Blumer, Blumer, Haussler, Ehrenfeucht, Chen
// and Seiferas, "The Smallest Automaton Recognizing the Subwords of a Text", 1985), over a text of
// non-negative Int32 codes. Each state's transitions are kept in a chain while the automaton grows,
// then compacted into rows sorted by code.

/// A suffix automaton's states, the root at 0.
@usableFromInline
struct _SuffixAutomatonStates: Sendable {
    /// The length of the longest substring each state stands for.
    @usableFromInline var lengths: ContiguousArray<Int32>
    /// Each state's suffix link; the root's is −1.
    @usableFromInline var links: ContiguousArray<Int32>
    /// For each state, the offset just past the first place its substrings end in the text.
    @usableFromInline var firstEnds: ContiguousArray<Int32>
    /// The number of places each state's substrings end in the text; the root's is the text's
    /// length.
    @usableFromInline var occurrenceCounts: ContiguousArray<Int32>
    /// Whether each state stands for suffixes of the text.
    @usableFromInline var isTerminal: ContiguousArray<Bool>
    /// Where each state's transitions start in `codes` and `targets`, and then their count.
    @usableFromInline var rowStarts: ContiguousArray<Int32>
    /// Each transition's code, ascending within a state's row.
    @usableFromInline var codes: ContiguousArray<Int32>
    /// Each transition's target state.
    @usableFromInline var targets: ContiguousArray<Int32>

    @inlinable
    init(
        lengths: ContiguousArray<Int32>, links: ContiguousArray<Int32>, firstEnds: ContiguousArray<Int32>,
        occurrenceCounts: ContiguousArray<Int32>, isTerminal: ContiguousArray<Bool>, rowStarts: ContiguousArray<Int32>,
        codes: ContiguousArray<Int32>, targets: ContiguousArray<Int32>
    ) {
        self.lengths = lengths
        self.links = links
        self.firstEnds = firstEnds
        self.occurrenceCounts = occurrenceCounts
        self.isTerminal = isTerminal
        self.rowStarts = rowStarts
        self.codes = codes
        self.targets = targets
    }

    @inlinable
    var count: Int { lengths.count }

    /// The state the transition on `code` from `state` leads to, or −1.
    @inlinable
    func transition(from state: Int, on code: Int32) -> Int {
        var low = Int(rowStarts[state])
        var high = Int(rowStarts[state &+ 1])
        while high &- low > 8 {
            let middle = low &+ (high &- low) >> 1
            if codes[middle] < code {
                low = middle &+ 1
            } else {
                high = middle
            }
        }
        while low < high {
            if codes[low] == code { return Int(targets[low]) }
            low &+= 1
        }
        return -1
    }
}

/// The suffix automaton of `text`, whose codes are all non-negative.
@usableFromInline
func _buildSuffixAutomaton(_ text: UnsafeBufferPointer<Int32>) -> _SuffixAutomatonStates {
    let n = text.count
    // At most 2n − 1 states and 3n − 4 transitions once n ≥ 3; room for the small cases too.
    let stateCapacity = 2 &* n &+ 2
    let edgeCapacity = 3 &* n &+ 4
    let length = UnsafeMutablePointer<Int32>.allocate(capacity: stateCapacity)
    let link = UnsafeMutablePointer<Int32>.allocate(capacity: stateCapacity)
    let firstEnd = UnsafeMutablePointer<Int32>.allocate(capacity: stateCapacity)
    let isClone = UnsafeMutablePointer<Bool>.allocate(capacity: stateCapacity)
    let firstEdge = UnsafeMutablePointer<Int32>.allocate(capacity: stateCapacity)
    let edgeCode = UnsafeMutablePointer<Int32>.allocate(capacity: edgeCapacity)
    let edgeTarget = UnsafeMutablePointer<Int32>.allocate(capacity: edgeCapacity)
    let edgeNext = UnsafeMutablePointer<Int32>.allocate(capacity: edgeCapacity)
    defer {
        length.deallocate()
        link.deallocate()
        firstEnd.deallocate()
        isClone.deallocate()
        firstEdge.deallocate()
        edgeCode.deallocate()
        edgeTarget.deallocate()
        edgeNext.deallocate()
    }
    length[0] = 0
    link[0] = -1
    firstEnd[0] = 0
    isClone[0] = false
    firstEdge[0] = -1
    var states = 1
    var edges = 0
    var last = 0

    for i in 0 ..< n {
        let code = text[i]
        let current = states
        states &+= 1
        length[current] = length[last] &+ 1
        firstEnd[current] = Int32(truncatingIfNeeded: i &+ 1)
        isClone[current] = false
        firstEdge[current] = -1
        // Every suffix state without a transition on `code` gains one to the new state.
        var p = last
        var found = -1
        while p >= 0 {
            var edge = Int(firstEdge[p])
            while edge >= 0 && edgeCode[edge] != code {
                edge = Int(edgeNext[edge])
            }
            if edge >= 0 {
                found = edge
                break
            }
            edgeCode[edges] = code
            edgeTarget[edges] = Int32(truncatingIfNeeded: current)
            edgeNext[edges] = firstEdge[p]
            firstEdge[p] = Int32(truncatingIfNeeded: edges)
            edges &+= 1
            p = Int(link[p])
        }
        if p < 0 {
            link[current] = 0
        } else {
            let q = Int(edgeTarget[found])
            if length[p] &+ 1 == length[q] {
                link[current] = Int32(truncatingIfNeeded: q)
            } else {
                // q stands for longer substrings than p's extension: split off the shorter ones
                // into a clone with q's transitions.
                let clone = states
                states &+= 1
                length[clone] = length[p] &+ 1
                link[clone] = link[q]
                firstEnd[clone] = firstEnd[q]
                isClone[clone] = true
                firstEdge[clone] = -1
                var edge = Int(firstEdge[q])
                while edge >= 0 {
                    edgeCode[edges] = edgeCode[edge]
                    edgeTarget[edges] = edgeTarget[edge]
                    edgeNext[edges] = firstEdge[clone]
                    firstEdge[clone] = Int32(truncatingIfNeeded: edges)
                    edges &+= 1
                    edge = Int(edgeNext[edge])
                }
                // Redirect the transitions on `code` into q from p and its suffix states.
                var r = p
                while r >= 0 {
                    var edge = Int(firstEdge[r])
                    while edge >= 0 && edgeCode[edge] != code {
                        edge = Int(edgeNext[edge])
                    }
                    guard edge >= 0 && Int(edgeTarget[edge]) == q else { break }
                    edgeTarget[edge] = Int32(truncatingIfNeeded: clone)
                    r = Int(link[r])
                }
                link[q] = Int32(truncatingIfNeeded: clone)
                link[current] = Int32(truncatingIfNeeded: clone)
            }
        }
        last = current
    }

    // Rows sorted by code.
    var rowStarts = ContiguousArray<Int32>(repeating: 0, count: states &+ 1)
    var codes = ContiguousArray<Int32>(repeating: 0, count: edges)
    var targets = ContiguousArray<Int32>(repeating: 0, count: edges)
    var position = 0
    for state in 0 ..< states {
        rowStarts[state] = Int32(truncatingIfNeeded: position)
        let rowStart = position
        var edge = Int(firstEdge[state])
        while edge >= 0 {
            // Insertion into the sorted row: rows hold at most one transition per symbol.
            var k = position
            while k > rowStart && codes[k &- 1] > edgeCode[edge] {
                codes[k] = codes[k &- 1]
                targets[k] = targets[k &- 1]
                k &-= 1
            }
            codes[k] = edgeCode[edge]
            targets[k] = edgeTarget[edge]
            position &+= 1
            edge = Int(edgeNext[edge])
        }
    }
    rowStarts[states] = Int32(truncatingIfNeeded: position)

    // Occurrence counts: one end per state made for a new symbol, summed up the suffix links from
    // the longest states down, ordered by a counting sort on length.
    var occurrenceCounts = ContiguousArray<Int32>(repeating: 0, count: states)
    var byLength = [Int32](repeating: 0, count: n &+ 2)
    for state in 0 ..< states {
        byLength[Int(length[state])] &+= 1
    }
    var total: Int32 = 0
    for k in 0 ..< byLength.count {
        let here = byLength[k]
        byLength[k] = total
        total &+= here
    }
    var order = [Int32](repeating: 0, count: states)
    for state in 0 ..< states {
        let k = Int(length[state])
        order[Int(byLength[k])] = Int32(truncatingIfNeeded: state)
        byLength[k] &+= 1
    }
    for state in 1 ..< Swift.max(states, 1) where !isClone[state] {
        occurrenceCounts[state] = 1
    }
    var k = states &- 1
    while k > 0 {
        let state = Int(order[k])
        let parent = Int(link[state])
        if parent > 0 {
            occurrenceCounts[parent] &+= occurrenceCounts[state]
        }
        k &-= 1
    }
    occurrenceCounts[0] = Int32(truncatingIfNeeded: n)

    var isTerminal = ContiguousArray<Bool>(repeating: false, count: states)
    var state = last
    while state >= 0 {
        isTerminal[state] = true
        state = Int(link[state])
    }

    return _SuffixAutomatonStates(
        lengths: ContiguousArray(UnsafeBufferPointer(start: length, count: states)),
        links: ContiguousArray(UnsafeBufferPointer(start: link, count: states)),
        firstEnds: ContiguousArray(UnsafeBufferPointer(start: firstEnd, count: states)),
        occurrenceCounts: occurrenceCounts, isTerminal: isTerminal, rowStarts: rowStarts, codes: codes, targets: targets
    )
}
