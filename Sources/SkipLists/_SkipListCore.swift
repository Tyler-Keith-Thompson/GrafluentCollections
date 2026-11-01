/// One level of a skip-list tower: the slot of the next element on that level, −1 for none, the
/// offset of that element's tower, so a search steps to it without looking it up, and how many
/// elements of the bottom level the link passes, the target included.
@frozen
@usableFromInline
package struct _SkipLink: Sendable {
    @usableFromInline package var next: Int32
    @usableFromInline package var tower: Int32
    @usableFromInline package var span: Int32

    @inlinable
    init(next: Int32, tower: Int32, span: Int32) {
        self.next = next
        self.tower = tower
        self.span = span
    }
}

/// The heights of a skip list's towers: SplitMix64 (Steele, Lea and Flood, 2014), seeded once from
/// the list's random number generator and kept in the list, so a copy draws the same heights as
/// its original.
@frozen
@usableFromInline
package struct _SkipListHeights: Sendable {
    @usableFromInline var state: UInt64

    @inlinable
    init(using generator: inout some RandomNumberGenerator) {
        state = generator.next()
    }

    /// The next SplitMix64 output.
    @inlinable
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// The next tower height, from 1 to `_SkipListCore.maximumLevel`: each level above the first
    /// with probability 1/4 (Pugh, 1990), one pair of trailing zero bits per level.
    @inlinable
    mutating func nextHeight() -> Int {
        Swift.min(1 &+ next().trailingZeroBitCount >> 1, _SkipListCore<Int>.maximumLevel)
    }
}

/// A skip list's storage (Pugh, 1990). Slot `k` holds an element, its tower's height and the
/// offset of its tower in `links`, where a tower of height `h` is `h` consecutive links, the
/// bottom level first. The head's tower is the first `maximumLevel` links. Spans follow Redis's
/// sorted sets, so the links also answer rank queries: a link's span counts the bottom-level
/// elements it passes, and a link to no element spans to the end of the list.
///
/// Freed towers are kept on a list per height and reused by the next tower of that height, so a
/// tower never moves. A removed element's slot is filled by the last slot's element, and the links
/// to that element are redirected.
@frozen
@usableFromInline
package struct _SkipListCore<Element: Comparable> {
    /// The most levels a tower has: enough for 4³² elements at p = 1/4.
    @inlinable
    package static var maximumLevel: Int { 32 }

    @usableFromInline package var elements: ContiguousArray<Element>
    @usableFromInline package var heights: ContiguousArray<UInt8>
    @usableFromInline package var towers: ContiguousArray<Int32>
    @usableFromInline package var links: ContiguousArray<_SkipLink>
    /// The first free tower of each height, by height − 1; −1 for none. A free tower's bottom
    /// link holds the next free tower of its height.
    @usableFromInline var freeTowers: ContiguousArray<Int32>
    /// The number of levels in use: at least 1, and the head links above it lead nowhere.
    @usableFromInline package var level: Int
    @usableFromInline var randomHeights: _SkipListHeights

    @inlinable
    package var count: Int { elements.count }

    /// An empty list whose heights come from `heights`.
    @inlinable
    init(heights randomHeights: _SkipListHeights) {
        elements = []
        heights = []
        towers = []
        links = ContiguousArray(repeating: _SkipLink(next: -1, tower: 0, span: 0), count: Self.maximumLevel)
        freeTowers = ContiguousArray(repeating: -1, count: Self.maximumLevel)
        level = 1
        self.randomHeights = randomHeights
    }

    /// The list over elements sorted in strictly ascending order. Slot `k` holds the `k`-th
    /// element, so a pass through the list reads memory in order. O(*n*).
    @inlinable
    init(sortedUniqueElements sorted: ContiguousArray<Element>, heights randomHeights: _SkipListHeights) {
        precondition(sorted.count < Int(Int32.max), "A skip list holds fewer than 2³¹ − 1 elements")
        self.init(heights: randomHeights)
        let n = sorted.count
        elements = sorted
        heights.reserveCapacity(n)
        towers.reserveCapacity(n)
        links.reserveCapacity(Self.maximumLevel &+ n &+ n / 3 &+ 8)
        // The last tower reached on each level and its rank, counting the head as rank 0.
        var lastTower = ContiguousArray<Int32>(repeating: 0, count: Self.maximumLevel)
        var lastRank = ContiguousArray<Int32>(repeating: 0, count: Self.maximumLevel)
        var slot: Int32 = 0
        while Int(slot) < n {
            let height = self.randomHeights.nextHeight()
            let base = Int32(truncatingIfNeeded: links.count)
            let rank = slot &+ 1
            heights.append(UInt8(truncatingIfNeeded: height))
            towers.append(base)
            var l = 0
            while l < height {
                links.append(_SkipLink(next: -1, tower: 0, span: 0))
                links[Int(lastTower[l]) &+ l] = _SkipLink(next: slot, tower: base, span: rank &- lastRank[l])
                lastTower[l] = base
                lastRank[l] = rank
                l &+= 1
            }
            level = Swift.max(level, height)
            slot &+= 1
        }
        let total = Int32(truncatingIfNeeded: n)
        var l = 0
        while l < level {
            links[Int(lastTower[l]) &+ l].span = total &- lastRank[l]
            l &+= 1
        }
    }

    // MARK: Reads

    /// The number of elements less than `element`, or with `orEqual`, not greater. O(log *n*)
    /// expected.
    @inlinable
    package func countBelow(_ element: Element, orEqual: Bool) -> Int {
        links.withUnsafeBufferPointer { links in
            elements.withUnsafeBufferPointer { elements in
                towers.withUnsafeBufferPointer { towers in
                    var tower = 0
                    var rank = 0
                    // An element already compared and found not to be passed, met again on the
                    // levels below.
                    var stop: Int32 = -1
                    var l = level &- 1
                    while l >= 0 {
                        while true {
                            let link = links[tower &+ l]
                            guard link.next >= 0, link.next != stop else { break }
                            let candidate = elements[Int(link.next)]
                            guard orEqual ? !(element < candidate) : candidate < element else {
                                stop = link.next
                                break
                            }
                            rank &+= Int(link.span)
                            tower = Int(link.tower)
                        }
                        l &-= 1
                    }
                    return rank
                }
            }
        }
    }

    /// The slot of the element equal to `element`, or −1 when there is none. O(log *n*) expected.
    @inlinable
    package func slot(of element: Element) -> Int32 {
        links.withUnsafeBufferPointer { links in
            elements.withUnsafeBufferPointer { elements in
                towers.withUnsafeBufferPointer { towers in
                    var tower = 0
                    // An element already compared and found not less, met again on the levels
                    // below.
                    var stop: Int32 = -1
                    var l = level &- 1
                    while l >= 0 {
                        while true {
                            let link = links[tower &+ l]
                            guard link.next >= 0, link.next != stop else { break }
                            guard elements[Int(link.next)] < element else {
                                stop = link.next
                                break
                            }
                            tower = Int(link.tower)
                        }
                        l &-= 1
                    }
                    let candidate = links[tower].next
                    return candidate >= 0 && !(element < elements[Int(candidate)]) ? candidate : -1
                }
            }
        }
    }

    /// The rank of the element equal to `element`, or nil when there is none. O(log *n*) expected.
    @inlinable
    package func rank(of element: Element) -> Int? {
        let rank = countBelow(element, orEqual: false)
        return rank < count && !(element < elements[Int(slot(atRank: rank))]) ? rank : nil
    }

    /// The slot of the element of rank `rank`, which must be in `0 ..< count`. O(log *n*)
    /// expected.
    @inlinable
    package func slot(atRank rank: Int) -> Int32 {
        links.withUnsafeBufferPointer { links in
            towers.withUnsafeBufferPointer { towers in
                let target = rank &+ 1
                var tower = 0
                var reached = 0
                var slot: Int32 = -1
                var l = level &- 1
                while l >= 0 {
                    while true {
                        let link = links[tower &+ l]
                        guard link.next >= 0, reached &+ Int(link.span) <= target else { break }
                        reached &+= Int(link.span)
                        slot = link.next
                        tower = Int(link.tower)
                    }
                    if reached == target { return slot }
                    l &-= 1
                }
                return slot
            }
        }
    }

    /// The slot of the smallest element, or −1 when empty. O(1).
    @inlinable
    package var firstSlot: Int32 { links[0].next }

    /// The slot of the largest element, or −1 when empty. O(log *n*) expected.
    @inlinable
    package var lastSlot: Int32 {
        var tower = 0
        var slot: Int32 = -1
        var l = level &- 1
        while l >= 0 {
            while true {
                let link = links[tower &+ l]
                guard link.next >= 0 else { break }
                slot = link.next
                tower = Int(link.tower)
            }
            l &-= 1
        }
        return slot
    }

    /// The slot after `slot` on the bottom level, or −1 after the last. O(1).
    @inlinable
    package func slot(after slot: Int32) -> Int32 {
        links[Int(towers[Int(slot)])].next
    }

    // MARK: Mutations

    /// Inserts `element` unless an equal one is present.
    ///
    /// - Returns: Whether it was inserted, and the slot of the element equal to it afterwards.
    /// - Complexity: O(log *n*) expected.
    @inlinable
    package mutating func insert(_ element: Element) -> (inserted: Bool, slot: Int32) {
        withUnsafeTemporaryAllocation(of: Int32.self, capacity: Self.maximumLevel) { update in
            withUnsafeTemporaryAllocation(of: Int32.self, capacity: Self.maximumLevel) { ranks in
                _insert(element, update: update, ranks: ranks)
            }
        }
    }

    @inlinable
    mutating func _insert(
        _ element: Element,
        update: UnsafeMutableBufferPointer<Int32>,
        ranks: UnsafeMutableBufferPointer<Int32>
    ) -> (inserted: Bool, slot: Int32) {
        var tower: Int32 = 0
        var l = level &- 1
        while l >= 0 {
            ranks[l] = l == level &- 1 ? 0 : ranks[l &+ 1]
            while true {
                let link = links[Int(tower) &+ l]
                guard link.next >= 0, elements[Int(link.next)] < element else { break }
                ranks[l] &+= link.span
                tower = link.tower
            }
            update[l] = tower
            l &-= 1
        }
        let found = links[Int(tower)].next
        if found >= 0 && !(element < elements[Int(found)]) {
            return (false, found)
        }
        precondition(count < Int(Int32.max) &- 1, "A skip list holds fewer than 2³¹ − 1 elements")
        let height = randomHeights.nextHeight()
        let total = Int32(truncatingIfNeeded: count)
        if height > level {
            l = level
            while l < height {
                ranks[l] = 0
                update[l] = 0
                links[l].span = total
                l &+= 1
            }
            level = height
        }
        let slot = total
        let base = _allocateTower(height: height)
        elements.append(element)
        heights.append(UInt8(truncatingIfNeeded: height))
        towers.append(base)
        let rank = ranks[0]
        l = 0
        while l < height {
            let predecessor = Int(update[l]) &+ l
            let passed = rank &- ranks[l]
            let link = links[predecessor]
            links[Int(base) &+ l] = _SkipLink(next: link.next, tower: link.tower, span: link.span &- passed)
            links[predecessor] = _SkipLink(next: slot, tower: base, span: passed &+ 1)
            l &+= 1
        }
        while l < level {
            links[Int(update[l]) &+ l].span &+= 1
            l &+= 1
        }
        return (true, slot)
    }

    /// Removes and returns the element equal to `element`, or nil when there is none.
    /// O(log *n*) expected.
    @inlinable
    package mutating func remove(_ element: Element) -> Element? {
        withUnsafeTemporaryAllocation(of: Int32.self, capacity: Self.maximumLevel) { update in
            var tower: Int32 = 0
            var l = level &- 1
            while l >= 0 {
                while true {
                    let link = links[Int(tower) &+ l]
                    guard link.next >= 0, elements[Int(link.next)] < element else { break }
                    tower = link.tower
                }
                update[l] = tower
                l &-= 1
            }
            let found = links[Int(tower)].next
            guard found >= 0 && !(element < elements[Int(found)]) else { return nil }
            return _remove(found, update: update)
        }
    }

    /// Removes and returns the element of rank `rank`, which must be in `0 ..< count`.
    /// O(log *n*) expected.
    @inlinable
    package mutating func remove(atRank rank: Int) -> Element {
        withUnsafeTemporaryAllocation(of: Int32.self, capacity: Self.maximumLevel) { update in
            let target = rank &+ 1
            var tower: Int32 = 0
            var reached = 0
            var l = level &- 1
            while l >= 0 {
                while true {
                    let link = links[Int(tower) &+ l]
                    guard link.next >= 0, reached &+ Int(link.span) < target else { break }
                    reached &+= Int(link.span)
                    tower = link.tower
                }
                update[l] = tower
                l &-= 1
            }
            return _remove(links[Int(tower)].next, update: update)
        }
    }

    /// Unlinks `slot`, whose predecessor towers on every level in use are `update`, frees its
    /// tower, and fills its slot with the last one.
    @inlinable
    mutating func _remove(_ slot: Int32, update: UnsafeMutableBufferPointer<Int32>) -> Element {
        let base = Int(towers[Int(slot)])
        let height = Int(heights[Int(slot)])
        var l = 0
        while l < level {
            let predecessor = Int(update[l]) &+ l
            if l < height {
                let link = links[base &+ l]
                links[predecessor] = _SkipLink(
                    next: link.next,
                    tower: link.tower,
                    span: links[predecessor].span &+ link.span &- 1
                )
            } else {
                links[predecessor].span &-= 1
            }
            l &+= 1
        }
        while level > 1 && links[level &- 1].next < 0 {
            level &-= 1
        }
        links[base].next = freeTowers[height &- 1]
        freeTowers[height &- 1] = Int32(truncatingIfNeeded: base)

        let last = Int32(truncatingIfNeeded: count &- 1)
        if slot != last {
            _redirect(last, to: slot)
            elements.swapAt(Int(slot), Int(last))
            heights[Int(slot)] = heights[Int(last)]
            towers[Int(slot)] = towers[Int(last)]
        }
        heights.removeLast()
        towers.removeLast()
        return elements.removeLast()
    }

    /// Points every link to `slot` at `newSlot` instead, by searching for its element.
    @inlinable
    mutating func _redirect(_ slot: Int32, to newSlot: Int32) {
        let element = elements[Int(slot)]
        let height = Int(heights[Int(slot)])
        var tower = 0
        var l = level &- 1
        while l >= 0 {
            while true {
                let link = links[tower &+ l]
                guard link.next >= 0, elements[Int(link.next)] < element else { break }
                tower = Int(link.tower)
            }
            if l < height {
                links[tower &+ l].next = newSlot
            }
            l &-= 1
        }
    }

    /// A tower of `height` links: a freed one of that height, or new links at the end.
    @inlinable
    mutating func _allocateTower(height: Int) -> Int32 {
        let free = freeTowers[height &- 1]
        if free >= 0 {
            freeTowers[height &- 1] = links[Int(free)].next
            return free
        }
        let base = Int32(truncatingIfNeeded: links.count)
        links.append(contentsOf: repeatElement(_SkipLink(next: -1, tower: 0, span: 0), count: height))
        return base
    }
}

extension _SkipListCore: Sendable where Element: Sendable {}
