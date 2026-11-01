// Suffix tree construction by Ukkonen's algorithm ("On-Line Construction of Suffix Trees", 1995)
// over a text of Int32 codes: symbols ranked from 0, each text ending in its own negative
// terminator, so every suffix ends at a leaf. Children are kept in a chain sorted by the code that
// starts their edge, and the finished tree is renumbered in preorder, so a node's subtree is the
// range of nodes from it to its subtree end and the leaves come in the suffixes' sorted order.

/// A suffix tree's nodes, numbered in preorder from the root at 0. A node's first child, when it
/// has one, is the next node.
@usableFromInline
struct _SuffixTreeNodes: Sendable {
    /// Where each node's edge label starts in the codes; the root's is empty.
    @usableFromInline var starts: ContiguousArray<Int32>
    /// Where each node's edge label ends in the codes, its terminator included for a leaf.
    @usableFromInline var ends: ContiguousArray<Int32>
    /// Each node's next sibling in code order, or −1.
    @usableFromInline var nextSiblings: ContiguousArray<Int32>
    /// Each node's parent; the root's is −1.
    @usableFromInline var parents: ContiguousArray<Int32>
    /// The number of codes on the path from the root to each node, a leaf's terminator included.
    @usableFromInline var depths: ContiguousArray<Int32>
    /// For a leaf, where its suffix starts in the codes; −1 for an internal node.
    @usableFromInline var suffixStarts: ContiguousArray<Int32>
    /// One past the last node of each node's subtree.
    @usableFromInline var subtreeEnds: ContiguousArray<Int32>
    /// Each internal node's suffix link: the node whose path label is its own without the first
    /// symbol. The root's is itself, and a leaf's −1.
    @usableFromInline var suffixLinks: ContiguousArray<Int32>

    @inlinable
    init(
        starts: ContiguousArray<Int32>, ends: ContiguousArray<Int32>, nextSiblings: ContiguousArray<Int32>,
        parents: ContiguousArray<Int32>, depths: ContiguousArray<Int32>, suffixStarts: ContiguousArray<Int32>,
        subtreeEnds: ContiguousArray<Int32>, suffixLinks: ContiguousArray<Int32>
    ) {
        self.starts = starts
        self.ends = ends
        self.nextSiblings = nextSiblings
        self.parents = parents
        self.depths = depths
        self.suffixStarts = suffixStarts
        self.subtreeEnds = subtreeEnds
        self.suffixLinks = suffixLinks
    }

    @inlinable
    var count: Int { starts.count }

    @inlinable
    func isLeaf(_ node: Int) -> Bool { suffixStarts[node] >= 0 }
}

/// The suffix tree of `codes`, whose texts end at `terminators`, ascending: positions holding a
/// negative code that occurs nowhere else, the last of them at the end of the codes.
@usableFromInline
func _buildSuffixTree(_ codes: UnsafeBufferPointer<Int32>, terminators: UnsafeBufferPointer<Int>) -> _SuffixTreeNodes {
    let n = codes.count
    guard n > 0 else {
        return _SuffixTreeNodes(
            starts: [0], ends: [0], nextSiblings: [-1], parents: [-1], depths: [0], suffixStarts: [-1],
            subtreeEnds: [1], suffixLinks: [0]
        )
    }
    // At most one leaf per suffix and one internal node per leaf but one, and the root.
    let capacity = 2 &* n &+ 1
    let start = UnsafeMutablePointer<Int32>.allocate(capacity: capacity)
    let end = UnsafeMutablePointer<Int32>.allocate(capacity: capacity)
    let firstChild = UnsafeMutablePointer<Int32>.allocate(capacity: capacity)
    let nextSibling = UnsafeMutablePointer<Int32>.allocate(capacity: capacity)
    let link = UnsafeMutablePointer<Int32>.allocate(capacity: capacity)
    let suffix = UnsafeMutablePointer<Int32>.allocate(capacity: capacity)
    // The code that starts each node's edge, kept beside the edge so a child search reads one
    // array rather than the edge's start and then the codes.
    let head = UnsafeMutablePointer<Int32>.allocate(capacity: capacity)
    let parent = UnsafeMutablePointer<Int32>.allocate(capacity: capacity)
    let open = Int32.max
    start[0] = 0
    end[0] = 0
    firstChild[0] = -1
    nextSibling[0] = -1
    link[0] = 0
    suffix[0] = -1
    parent[0] = -1
    var count = 1

    var activeNode = 0
    var activeEdge = 0
    var activeLength = 0
    var remainder = 0
    for i in 0 ..< n {
        let symbol = codes[i]
        remainder &+= 1
        // The internal node made last in this phase, still waiting for its suffix link.
        var pending = -1
        while remainder > 0 {
            if activeLength == 0 {
                activeEdge = i
            }
            let wanted = codes[activeEdge]
            // The first child whose edge starts at or after `wanted`, and the one before it.
            var previous = -1
            var child = Int(firstChild[activeNode])
            while child >= 0 && head[child] < wanted {
                previous = child
                child = Int(nextSibling[child])
            }
            if child < 0 || head[child] != wanted {
                // Rule 2: no edge continues the active point, so a leaf hangs from its node.
                let leaf = count
                count &+= 1
                start[leaf] = Int32(truncatingIfNeeded: i)
                head[leaf] = symbol
                end[leaf] = open
                firstChild[leaf] = -1
                link[leaf] = -1
                suffix[leaf] = Int32(truncatingIfNeeded: i &- remainder &+ 1)
                parent[leaf] = Int32(truncatingIfNeeded: activeNode)
                nextSibling[leaf] = Int32(truncatingIfNeeded: child)
                if previous < 0 {
                    firstChild[activeNode] = Int32(truncatingIfNeeded: leaf)
                } else {
                    nextSibling[previous] = Int32(truncatingIfNeeded: leaf)
                }
                if pending >= 0 {
                    link[pending] = Int32(truncatingIfNeeded: activeNode)
                    pending = -1
                }
            } else {
                let edgeStart = Int(start[child])
                let edgeLength = Swift.min(Int(end[child]), i &+ 1) &- edgeStart
                if activeLength >= edgeLength {
                    // Walk down: the active point lies past this edge.
                    activeEdge &+= edgeLength
                    activeLength &-= edgeLength
                    activeNode = child
                    continue
                }
                if codes[edgeStart &+ activeLength] == symbol {
                    // Rule 3: the suffix is already in the tree, and so are all shorter ones;
                    // the phase ends here.
                    if pending >= 0 && activeNode != 0 {
                        link[pending] = Int32(truncatingIfNeeded: activeNode)
                        pending = -1
                    }
                    activeLength &+= 1
                    break
                }
                // Rule 2 inside an edge: split it, and hang a leaf from the new node.
                let split = count
                let leaf = count &+ 1
                count &+= 2
                start[split] = Int32(truncatingIfNeeded: edgeStart)
                head[split] = head[child]
                end[split] = Int32(truncatingIfNeeded: edgeStart &+ activeLength)
                link[split] = 0
                suffix[split] = -1
                parent[split] = Int32(truncatingIfNeeded: activeNode)
                parent[child] = Int32(truncatingIfNeeded: split)
                parent[leaf] = Int32(truncatingIfNeeded: split)
                nextSibling[split] = nextSibling[child]
                if previous < 0 {
                    firstChild[activeNode] = Int32(truncatingIfNeeded: split)
                } else {
                    nextSibling[previous] = Int32(truncatingIfNeeded: split)
                }
                start[child] = Int32(truncatingIfNeeded: edgeStart &+ activeLength)
                head[child] = codes[edgeStart &+ activeLength]
                start[leaf] = Int32(truncatingIfNeeded: i)
                head[leaf] = symbol
                end[leaf] = open
                firstChild[leaf] = -1
                link[leaf] = -1
                suffix[leaf] = Int32(truncatingIfNeeded: i &- remainder &+ 1)
                if head[child] < symbol {
                    firstChild[split] = Int32(truncatingIfNeeded: child)
                    nextSibling[child] = Int32(truncatingIfNeeded: leaf)
                    nextSibling[leaf] = -1
                } else {
                    firstChild[split] = Int32(truncatingIfNeeded: leaf)
                    nextSibling[leaf] = Int32(truncatingIfNeeded: child)
                    nextSibling[child] = -1
                }
                if pending >= 0 {
                    link[pending] = Int32(truncatingIfNeeded: split)
                }
                pending = split
            }
            remainder &-= 1
            if activeNode == 0 && activeLength > 0 {
                activeLength &-= 1
                activeEdge = i &- remainder &+ 1
            } else if activeNode != 0 {
                activeNode = Int(link[activeNode])
            }
        }
    }

    // Each leaf's edge runs to the end of the codes; cut it after its own text's terminator.
    for node in 1 ..< count where suffix[node] >= 0 {
        let position = Int(suffix[node])
        var low = 0
        var high = terminators.count
        while low < high {
            let middle = low &+ (high &- low) >> 1
            if terminators[middle] < position {
                low = middle &+ 1
            } else {
                high = middle
            }
        }
        end[node] = Int32(truncatingIfNeeded: terminators[low] &+ 1)
    }

    // Renumber in preorder, children in chain order, in one walk that descends by first
    // children, moves on by next siblings and climbs by parents, writing each node's entries as
    // it is reached and its subtree end as it is left.
    let renumbered = UnsafeMutablePointer<Int32>.allocate(capacity: count)
    let newStarts = UnsafeMutablePointer<Int32>.allocate(capacity: count)
    let newEnds = UnsafeMutablePointer<Int32>.allocate(capacity: count)
    let newParents = UnsafeMutablePointer<Int32>.allocate(capacity: count)
    let newDepths = UnsafeMutablePointer<Int32>.allocate(capacity: count)
    let newSuffixes = UnsafeMutablePointer<Int32>.allocate(capacity: count)
    let newSubtreeEnds = UnsafeMutablePointer<Int32>.allocate(capacity: count)
    let newLinks = UnsafeMutablePointer<Int32>.allocate(capacity: count)
    let newSiblings = UnsafeMutablePointer<Int32>.allocate(capacity: count)
    defer {
        for buffer in [renumbered, newStarts, newEnds, newParents, newDepths, newSuffixes, newSubtreeEnds, newLinks, newSiblings] {
            buffer.deallocate()
        }
    }
    var old = 0
    var new = 0
    walk: while true {
        renumbered[old] = Int32(truncatingIfNeeded: new)
        newStarts[new] = start[old]
        newEnds[new] = end[old]
        newSuffixes[new] = suffix[old]
        newLinks[new] = link[old]
        if old == 0 {
            newParents[0] = -1
            newDepths[0] = 0
        } else {
            let newParent = renumbered[Int(parent[old])]
            newParents[new] = newParent
            newDepths[new] = newDepths[Int(newParent)] &+ end[old] &- start[old]
        }
        new &+= 1
        let child = firstChild[old]
        if child >= 0 {
            old = Int(child)
            continue walk
        }
        while true {
            newSubtreeEnds[Int(renumbered[old])] = Int32(truncatingIfNeeded: new)
            if old == 0 { break walk }
            let sibling = nextSibling[old]
            if sibling >= 0 {
                old = Int(sibling)
                continue walk
            }
            old = Int(parent[old])
        }
    }
    for node in 0 ..< count {
        if newLinks[node] >= 0 {
            newLinks[node] = renumbered[Int(newLinks[node])]
        }
        // In preorder a node's next sibling, when it has one, is where its subtree ends.
        let after = Int(newSubtreeEnds[node])
        newSiblings[node] = node > 0 && after < count && newParents[after] == newParents[node] ? Int32(truncatingIfNeeded: after) : -1
    }
    // The construction's arrays go before the results are copied out.
    for buffer in [start, end, firstChild, nextSibling, link, suffix, head, parent] {
        buffer.deallocate()
    }
    func array(_ buffer: UnsafeMutablePointer<Int32>) -> ContiguousArray<Int32> {
        ContiguousArray(UnsafeBufferPointer(start: buffer, count: count))
    }
    let starts = array(newStarts)
    let ends = array(newEnds)
    let nextSiblings = array(newSiblings)
    let parents = array(newParents)
    let depths = array(newDepths)
    let suffixStarts = array(newSuffixes)
    let subtreeEnds = array(newSubtreeEnds)
    let suffixLinks = array(newLinks)
    return _SuffixTreeNodes(
        starts: starts, ends: ends, nextSiblings: nextSiblings, parents: parents, depths: depths,
        suffixStarts: suffixStarts, subtreeEnds: subtreeEnds, suffixLinks: suffixLinks
    )
}

/// The node whose path label is the shortest that begins with `pattern`, or −1 when no suffix
/// begins with it.
@usableFromInline
func _locate(_ pattern: UnsafeBufferPointer<Int32>, in codes: UnsafeBufferPointer<Int32>, nodes: _SuffixTreeNodes) -> Int {
    let m = pattern.count
    var node = 0
    var k = 0
    return nodes.starts.withUnsafeBufferPointer { starts in
        nodes.ends.withUnsafeBufferPointer { ends in
            nodes.nextSiblings.withUnsafeBufferPointer { nextSiblings in
                nodes.suffixStarts.withUnsafeBufferPointer { suffixStarts in
                    while k < m {
                        let wanted = pattern[k]
                        var child = suffixStarts[node] >= 0 ? -1 : node &+ 1
                        while child >= 0 && codes[Int(starts[child])] < wanted {
                            child = Int(nextSiblings[child])
                        }
                        guard child >= 0 && codes[Int(starts[child])] == wanted else { return -1 }
                        var position = Int(starts[child])
                        let edgeEnd = Int(ends[child])
                        while position < edgeEnd && k < m {
                            if codes[position] != pattern[k] { return -1 }
                            position &+= 1
                            k &+= 1
                        }
                        node = child
                    }
                    return node
                }
            }
        }
    }
}
