// Suffix array construction by induced sorting (SA-IS: Nong, Zhang and Chan, "Two Efficient
// Algorithms for Linear Time Suffix Array Construction", 2011) and longest-common-prefix arrays by
// the permuted-LCP method (Kärkkäinen, Manzini and Puglisi, "Permuted Longest-Common-Prefix
// Array", 2009). Both run over integer texts: bytes, or a general text's symbol ranks. The
// algorithms are generic over the text's integer type and the index width, and specialized here,
// once per combination, behind concrete entry points.

/// A suffix array's two arrays at one index width.
@usableFromInline
struct _SuffixArrayParts<Index: FixedWidthInteger & SignedInteger & Sendable>: Sendable {
    @usableFromInline var positions: ContiguousArray<Index>
    @usableFromInline var longestCommonPrefixes: ContiguousArray<Index>

    @inlinable
    init(positions: ContiguousArray<Index>, longestCommonPrefixes: ContiguousArray<Index>) {
        self.positions = positions
        self.longestCommonPrefixes = longestCommonPrefixes
    }
}

/// The suffix array and LCP array of a byte text, with 32-bit indices. `text.count` must not
/// exceed `Int32.max`.
@usableFromInline
func _narrowSuffixArray(bytes text: UnsafeBufferPointer<UInt8>) -> _SuffixArrayParts<Int32> {
    _suffixArrayParts(text, upper: Int(UInt8.max))
}

/// The suffix array and LCP array of a byte text, with full-width indices.
@usableFromInline
func _wideSuffixArray(bytes text: UnsafeBufferPointer<UInt8>) -> _SuffixArrayParts<Int> {
    _suffixArrayParts(text, upper: Int(UInt8.max))
}

/// The suffix array and LCP array of a text of symbol ranks in `0 ... upper`, with 32-bit indices.
@usableFromInline
func _narrowSuffixArray(ranks text: UnsafeBufferPointer<Int32>, upper: Int) -> _SuffixArrayParts<Int32> {
    _suffixArrayParts(text, upper: upper)
}

/// The suffix array and LCP array of a text of symbol ranks in `0 ... upper`, with full-width
/// indices.
@usableFromInline
func _wideSuffixArray(ranks text: UnsafeBufferPointer<Int>, upper: Int) -> _SuffixArrayParts<Int> {
    _suffixArrayParts(text, upper: upper)
}

func _suffixArrayParts<Symbol: FixedWidthInteger, Index: FixedWidthInteger & SignedInteger>(
    _ text: UnsafeBufferPointer<Symbol>, upper: Int
) -> _SuffixArrayParts<Index> {
    let n = text.count
    let positions = ContiguousArray<Index>(unsafeUninitializedCapacity: n) { buffer, count in
        _inducedSort(text, upper: upper, into: buffer)
        count = n
    }
    let longestCommonPrefixes = positions.withUnsafeBufferPointer { positions in
        ContiguousArray<Index>(unsafeUninitializedCapacity: n) { buffer, count in
            _permutedLongestCommonPrefixes(text, positions, into: buffer)
            count = n
        }
    }
    return _SuffixArrayParts(positions: positions, longestCommonPrefixes: longestCommonPrefixes)
}

/// Writes the suffix array of `s`, whose symbols are in `0 ... upper`, into `sa`, which holds
/// `s.count` entries.
///
/// The suffixes are classed S (smaller than the next suffix) or L (larger); the leftmost S
/// suffixes of each run (LMS) are placed in their buckets, the L and S suffixes are induced from
/// them in two passes, the LMS substrings are named in their sorted order, and when two names
/// coincide the names' own suffix array, found recursively, orders the LMS suffixes for a last
/// induction. O(*n* + upper) per level, and each level has at most half the symbols of the last.
func _inducedSort<Symbol: FixedWidthInteger, Index: FixedWidthInteger & SignedInteger>(
    _ s: UnsafeBufferPointer<Symbol>, upper: Int, into sa: UnsafeMutableBufferPointer<Index>
) {
    let n = s.count
    if n == 0 { return }
    if n == 1 {
        sa[0] = 0
        return
    }
    if n < 10 {
        _naiveSort(s, into: sa)
        return
    }

    // The working arrays, as raw buffers so the induction loops carry no bounds checks.
    // isS[i]: whether the suffix at i is smaller than the one at i + 1. The last suffix is L,
    // being larger than the empty suffix after it.
    let isS = UnsafeMutableBufferPointer<Bool>.allocate(capacity: n)
    defer { isS.deallocate() }
    isS[n &- 1] = false
    var i = n &- 2
    while i >= 0 {
        isS[i] = s[i] == s[i &+ 1] ? isS[i &+ 1] : s[i] < s[i &+ 1]
        i &-= 1
    }
    // bucketStarts[c]: where symbol c's bucket starts; sStarts[c]: where its S suffixes start,
    // after its L suffixes; buckets: the moving heads of one induction pass.
    let alphabetSize = upper &+ 1
    let bucketStarts = UnsafeMutableBufferPointer<Int>.allocate(capacity: alphabetSize)
    let sStarts = UnsafeMutableBufferPointer<Int>.allocate(capacity: alphabetSize)
    let buckets = UnsafeMutableBufferPointer<Int>.allocate(capacity: alphabetSize)
    defer {
        bucketStarts.deallocate()
        sStarts.deallocate()
        buckets.deallocate()
    }
    bucketStarts.initialize(repeating: 0)
    sStarts.initialize(repeating: 0)
    for k in 0 ..< n {
        let c = Int(s[k])
        if isS[k] {
            // An S symbol is smaller than a later one, so c < upper.
            bucketStarts[c &+ 1] &+= 1
        } else {
            sStarts[c] &+= 1
        }
    }
    for c in 0 ..< alphabetSize {
        sStarts[c] &+= bucketStarts[c]
        if c < upper {
            bucketStarts[c &+ 1] &+= sStarts[c]
        }
    }

    func induce(_ lms: UnsafeMutableBufferPointer<Index>) {
        sa.update(repeating: -1)
        _ = buckets.update(fromContentsOf: sStarts)
        for d in lms {
            let c = Int(s[Int(d)])
            sa[buckets[c]] = d
            buckets[c] &+= 1
        }
        _ = buckets.update(fromContentsOf: bucketStarts)
        let last = Int(s[n &- 1])
        sa[buckets[last]] = Index(truncatingIfNeeded: n &- 1)
        buckets[last] &+= 1
        for k in 0 ..< n {
            let v = Int(sa[k]) &- 1
            if v >= 0 && !isS[v] {
                let c = Int(s[v])
                sa[buckets[c]] = Index(truncatingIfNeeded: v)
                buckets[c] &+= 1
            }
        }
        _ = buckets.update(fromContentsOf: bucketStarts)
        var k = n &- 1
        while k >= 0 {
            let v = Int(sa[k]) &- 1
            if v >= 0 && isS[v] {
                let c = Int(s[v]) &+ 1
                buckets[c] &-= 1
                sa[buckets[c]] = Index(truncatingIfNeeded: v)
            }
            k &-= 1
        }
    }

    // lmsNumbers[i]: the LMS position i's number in text order, or −1 when i is not LMS.
    let lmsNumbers = UnsafeMutableBufferPointer<Index>.allocate(capacity: n)
    defer { lmsNumbers.deallocate() }
    lmsNumbers.initialize(repeating: -1)
    var m = 0
    for k in 1 ..< n where !isS[k &- 1] && isS[k] {
        lmsNumbers[k] = Index(truncatingIfNeeded: m)
        m &+= 1
    }
    guard m > 0 else {
        // No LMS suffix: the text never rises, so its suffixes sort shortest first.
        let empty = UnsafeMutableBufferPointer<Index>(start: nil, count: 0)
        induce(empty)
        return
    }
    let lms = UnsafeMutableBufferPointer<Index>.allocate(capacity: m)
    let sortedLMS = UnsafeMutableBufferPointer<Index>.allocate(capacity: m)
    let names = UnsafeMutableBufferPointer<Index>.allocate(capacity: m)
    defer {
        lms.deallocate()
        sortedLMS.deallocate()
        names.deallocate()
    }
    var count = 0
    for k in 1 ..< n where !isS[k &- 1] && isS[k] {
        lms[count] = Index(truncatingIfNeeded: k)
        count &+= 1
    }

    induce(lms)

    // The LMS positions in the order the induction sorted their substrings, then a name per
    // distinct substring, in that order.
    count = 0
    for k in 0 ..< n where lmsNumbers[Int(sa[k])] != -1 {
        sortedLMS[count] = sa[k]
        count &+= 1
    }
    names[Int(lmsNumbers[Int(sortedLMS[0])])] = 0
    var name = 0
    for k in 1 ..< m {
        var l = Int(sortedLMS[k &- 1])
        var r = Int(sortedLMS[k])
        let nextL = Int(lmsNumbers[l]) &+ 1
        let nextR = Int(lmsNumbers[r]) &+ 1
        let endL = nextL < m ? Int(lms[nextL]) : n
        let endR = nextR < m ? Int(lms[nextR]) : n
        var same = endL &- l == endR &- r
        if same {
            while l < endL && s[l] == s[r] {
                l &+= 1
                r &+= 1
            }
            // Past the last LMS substring lies the text's end, which equals nothing.
            if l == n || r == n || s[l] != s[r] {
                same = false
            }
        }
        if !same {
            name &+= 1
        }
        names[Int(lmsNumbers[Int(sortedLMS[k])])] = Index(truncatingIfNeeded: name)
    }

    if name &+ 1 < m {
        // Some LMS substrings coincide: order the LMS suffixes by the suffix array of the names.
        _inducedSort(UnsafeBufferPointer(names), upper: name, into: sortedLMS)
        for k in 0 ..< m {
            sortedLMS[k] = lms[Int(sortedLMS[k])]
        }
    }
    induce(sortedLMS)
}

/// Sorts a short text's suffixes by comparing them directly.
func _naiveSort<Symbol: FixedWidthInteger, Index: FixedWidthInteger & SignedInteger>(
    _ s: UnsafeBufferPointer<Symbol>, into sa: UnsafeMutableBufferPointer<Index>
) {
    let n = s.count
    var order = Array(0 ..< n)
    order.sort { a, b in
        var a = a, b = b
        while a < n && b < n {
            if s[a] != s[b] { return s[a] < s[b] }
            a &+= 1
            b &+= 1
        }
        return a == n
    }
    for k in 0 ..< n {
        sa[k] = Index(truncatingIfNeeded: order[k])
    }
}

/// Writes the LCP array of `s` into `lcp`: `lcp[0]` is 0 and `lcp[k]` the length of the longest
/// common prefix of the suffixes at `sa[k - 1]` and `sa[k]`.
///
/// Computes the LCPs in text order (the permuted LCP array), where each is at least one less than
/// the one before, so the comparisons total O(*n*), then permutes them into suffix order.
func _permutedLongestCommonPrefixes<Symbol: FixedWidthInteger, Index: FixedWidthInteger & SignedInteger>(
    _ s: UnsafeBufferPointer<Symbol>, _ sa: UnsafeBufferPointer<Index>, into lcp: UnsafeMutableBufferPointer<Index>
) {
    let n = s.count
    guard n > 0 else { return }
    // previous[i]: the position of the suffix just before the one at i in suffix order, or −1;
    // then, in place, the LCP of the suffix at i with that one.
    var previous = [Index](repeating: -1, count: n)
    previous.withUnsafeMutableBufferPointer { previous in
        for k in 1 ..< n {
            previous[Int(sa[k])] = sa[k &- 1]
        }
        var h = 0
        for i in 0 ..< n {
            let j = Int(previous[i])
            if j < 0 {
                previous[i] = 0
                h = 0
                continue
            }
            while i &+ h < n && j &+ h < n && s[i &+ h] == s[j &+ h] {
                h &+= 1
            }
            previous[i] = Index(truncatingIfNeeded: h)
            if h > 0 {
                h &-= 1
            }
        }
        for k in 0 ..< n {
            lcp[k] = previous[Int(sa[k])]
        }
    }
}
