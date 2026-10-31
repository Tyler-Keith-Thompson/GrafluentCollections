/// The error a `checked:` spelling throws for an index or range that lies outside the collection.
@frozen
public struct IndexOutOfRange: Error, Hashable, Sendable {
    @inlinable
    public init() {}
}
