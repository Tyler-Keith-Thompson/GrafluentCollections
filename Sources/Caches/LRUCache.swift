@_exported import CollectionErrors

/// A bounded dictionary that evicts its least recently used entry to make room: lookup,
/// insertion, removal and eviction each take O(1) on average.
///
/// The entries sit in one flat array, threaded by previous and next indices into a list from the
/// most recently used to the least, and a hash table maps each key to its entry's position (as in
/// Java's access-ordered `LinkedHashMap`). Reading a value through ``subscript(_:)`` or storing
/// one makes its entry the most recent; ``peek(_:)`` reads without doing so. A cache with
/// capacity 0 holds nothing: every entry stored is evicted at once.
///
/// ```swift
/// var cache = LRUCache<String, Int>(capacity: 2)
/// cache["a"] = 1
/// cache["b"] = 2
/// _ = cache["a"]                     // 1, and "a" is now the most recent
/// cache["c"] = 3                     // evicts "b", the least recent
/// cache.map(\.key)                   // ["c", "a"]
/// ```
///
/// The cache is a value: a copy is a snapshot whose recency order changes independently.
@frozen
public struct LRUCache<Key: Hashable, Value> {
    /// The entries, in no order; `previous` and `next` link them from most to least recent.
    @usableFromInline var _slots: ContiguousArray<_Slot>
    @usableFromInline var _table: [Key: Int32]
    /// The most recently used entry, or −1 when empty.
    @usableFromInline var _head: Int32
    /// The least recently used entry, or −1 when empty.
    @usableFromInline var _tail: Int32

    /// The most entries the cache holds.
    public let capacity: Int

    @frozen
    @usableFromInline
    struct _Slot {
        @usableFromInline var key: Key
        @usableFromInline var value: Value
        @usableFromInline var previous: Int32
        @usableFromInline var next: Int32

        @inlinable
        init(key: Key, value: Value, previous: Int32, next: Int32) {
            self.key = key
            self.value = value
            self.previous = previous
            self.next = next
        }
    }

    /// An empty cache holding at most `capacity` entries.
    ///
    /// - Parameter capacity: Traps when negative or 2³¹ or more; use ``init(checkedCapacity:)``
    ///   to throw instead.
    @inlinable
    public init(capacity: Int) {
        precondition(capacity >= 0, "A cache's capacity is not negative")
        precondition(capacity < Int(Int32.max), "A cache holds fewer than 2³¹ entries")
        self.capacity = capacity
        _slots = []
        _table = [:]
        _head = -1
        _tail = -1
    }

    /// An empty cache holding at most `capacity` entries, throwing instead of trapping on a
    /// negative capacity.
    ///
    /// - Throws: ``NegativeCapacity`` when `capacity` is negative.
    @inlinable
    public init(checkedCapacity capacity: Int) throws(NegativeCapacity) {
        guard capacity >= 0 else { throw NegativeCapacity() }
        self.init(capacity: capacity)
    }

    /// The number of entries.
    @inlinable
    public var count: Int { _slots.count }

    /// Whether the cache holds no entries.
    @inlinable
    public var isEmpty: Bool { _slots.isEmpty }

    /// Whether the cache holds an entry for `key`, without changing its recency. O(1).
    @inlinable
    public func contains(_ key: Key) -> Bool {
        _table[key] != nil
    }

    /// The value for `key` without making it the most recent, or nil when absent. O(1).
    @inlinable
    public func peek(_ key: Key) -> Value? {
        guard let slot = _table[key] else { return nil }
        return _slots[Int(slot)].value
    }

    /// The value for `key`, or nil when absent; reading it makes its entry the most recent.
    /// Setting a value stores it as the most recent, evicting the least recent entry when the
    /// cache is full; setting nil removes the entry.
    ///
    /// - Complexity: O(1) on average.
    @inlinable
    public subscript(key: Key) -> Value? {
        mutating get {
            guard let slot = _table[key] else { return nil }
            _promote(slot)
            return _slots[Int(slot)].value
        }
        set {
            if let newValue {
                var evicted: Entry?
                _store(newValue, forKey: key, evicted: &evicted)
            } else {
                removeValue(forKey: key)
            }
        }
    }

    /// Stores `value` for `key` as the most recent entry, evicting the least recent one when the
    /// cache is full, and returns the value it replaced, or nil when `key` was absent.
    ///
    /// - Complexity: O(1) on average.
    @inlinable
    @discardableResult
    public mutating func updateValue(_ value: Value, forKey key: Key) -> Value? {
        var evicted: Entry?
        return _store(value, forKey: key, evicted: &evicted)
    }

    /// Stores `value` for `key` as the most recent entry, and returns the entry evicted to make
    /// room: nil when `key` was present (its value is replaced) or the cache had room, and the new
    /// entry itself when the capacity is 0.
    ///
    /// - Complexity: O(1) on average.
    @inlinable
    @discardableResult
    public mutating func insert(_ value: Value, forKey key: Key) -> Entry? {
        var evicted: Entry?
        _store(value, forKey: key, evicted: &evicted)
        return evicted
    }

    /// Removes the entry for `key` and returns its value, or nil when absent. O(1) on average.
    @inlinable
    @discardableResult
    public mutating func removeValue(forKey key: Key) -> Value? {
        guard let slot = _table.removeValue(forKey: key) else { return nil }
        return _removeSlot(slot).value
    }

    /// Removes the least recently used entry and returns it, or nil when the cache is empty.
    /// O(1) on average.
    @inlinable
    @discardableResult
    public mutating func removeLeastRecentlyUsed() -> Entry? {
        guard _tail >= 0 else { return nil }
        let slot = _tail
        _table.removeValue(forKey: _slots[Int(slot)].key)
        return _removeSlot(slot)
    }

    /// Removes every entry, keeping the capacity. O(*n*).
    @inlinable
    public mutating func removeAll() {
        _slots.removeAll()
        _table.removeAll()
        _head = -1
        _tail = -1
    }

    // MARK: - Internals

    /// Stores the value and returns the one it replaced; the entry evicted, if any, goes to
    /// `evicted`.
    @inlinable
    @discardableResult
    mutating func _store(_ value: Value, forKey key: Key, evicted: inout Entry?) -> Value? {
        guard capacity > 0 else {
            evicted = Entry(key: key, value: value)
            return nil
        }
        // One hash for the lookup and the insertion: a new key takes the slot it will occupy.
        let isFull = _slots.count == capacity
        let candidate = isFull ? _tail : Int32(truncatingIfNeeded: _slots.count)
        var existing: Int32 = -1
        Self._claim(&_table[key, default: -1], for: candidate, existing: &existing)
        if existing >= 0 {
            let old = _slots[Int(existing)].value
            _slots[Int(existing)].value = value
            _promote(existing)
            return old
        }
        if isFull {
            let old = _slots[Int(candidate)]
            _table.removeValue(forKey: old.key)
            evicted = Entry(key: old.key, value: old.value)
            _slots[Int(candidate)].key = key
            _slots[Int(candidate)].value = value
            _promote(candidate)
        } else {
            _slots.append(_Slot(key: key, value: value, previous: -1, next: _head))
            if _head >= 0 {
                _slots[Int(_head)].previous = candidate
            } else {
                _tail = candidate
            }
            _head = candidate
        }
        return nil
    }

    /// Gives a new key's table entry the slot it will occupy, or reports the slot of a present one.
    @inlinable @inline(__always)
    static func _claim(_ entry: inout Int32, for candidate: Int32, existing: inout Int32) {
        if entry < 0 {
            entry = candidate
        } else {
            existing = entry
        }
    }

    @inlinable
    mutating func _unlink(_ slot: Int32) {
        let previous = _slots[Int(slot)].previous
        let next = _slots[Int(slot)].next
        if previous >= 0 {
            _slots[Int(previous)].next = next
        } else {
            _head = next
        }
        if next >= 0 {
            _slots[Int(next)].previous = previous
        } else {
            _tail = previous
        }
    }

    /// Makes the entry at `slot` the most recent.
    @inlinable
    mutating func _promote(_ slot: Int32) {
        guard slot != _head else { return }
        _unlink(slot)
        _slots[Int(slot)].previous = -1
        _slots[Int(slot)].next = _head
        _slots[Int(_head)].previous = slot
        _head = slot
    }

    /// Unlinks and removes the entry at `slot`, whose key is already out of the table, moving the
    /// last entry into its place.
    @inlinable
    mutating func _removeSlot(_ slot: Int32) -> Entry {
        _unlink(slot)
        let removed = _slots[Int(slot)]
        let last = Int32(truncatingIfNeeded: _slots.count &- 1)
        if slot != last {
            let moved = _slots[Int(last)]
            _slots[Int(slot)] = moved
            if moved.previous >= 0 {
                _slots[Int(moved.previous)].next = slot
            } else {
                _head = slot
            }
            if moved.next >= 0 {
                _slots[Int(moved.next)].previous = slot
            } else {
                _tail = slot
            }
            _table[moved.key] = slot
        }
        _slots.removeLast()
        return Entry(key: removed.key, value: removed.value)
    }
}

extension LRUCache {
    /// A key and its value, as evicted, removed or iterated.
    @frozen
    public struct Entry {
        /// The key.
        public var key: Key
        /// The value.
        public var value: Value

        /// The entry of `key` and `value`.
        @inlinable
        public init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }
}

extension LRUCache.Entry: Equatable where Value: Equatable {}
extension LRUCache.Entry: Hashable where Value: Hashable {}
extension LRUCache.Entry: Sendable where Key: Sendable, Value: Sendable {}

extension LRUCache: Sequence {
    /// The entries from the most recently used to the least.
    @frozen
    public struct Iterator: IteratorProtocol {
        @usableFromInline let _slots: ContiguousArray<_Slot>
        @usableFromInline var _next: Int32

        @inlinable
        init(_ cache: LRUCache) {
            _slots = cache._slots
            _next = cache._head
        }

        @inlinable
        public mutating func next() -> Entry? {
            guard _next >= 0 else { return nil }
            let slot = _slots[Int(_next)]
            _next = slot.next
            return Entry(key: slot.key, value: slot.value)
        }
    }

    /// Iterates from the most recently used entry to the least, without changing their recency.
    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(self)
    }

    @inlinable
    public var underestimatedCount: Int { _slots.count }
}

extension LRUCache: Sendable where Key: Sendable, Value: Sendable {}
extension LRUCache._Slot: Sendable where Key: Sendable, Value: Sendable {}
extension LRUCache.Iterator: Sendable where Key: Sendable, Value: Sendable {}

extension LRUCache: CustomStringConvertible {
    /// The entries from most to least recent, written as a dictionary literal.
    public var description: String {
        guard !isEmpty else { return "[:]" }
        var text = "["
        var first = true
        for entry in self {
            if !first { text += ", " }
            first = false
            debugPrint(entry.key, terminator: "", to: &text)
            text += ": "
            debugPrint(entry.value, terminator: "", to: &text)
        }
        return text + "]"
    }
}
