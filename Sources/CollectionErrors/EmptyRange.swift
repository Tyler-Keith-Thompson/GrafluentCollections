/// The error a `checked:` spelling throws for an empty range where only a non-empty one has a
/// meaning, such as an interval stored in an interval tree.
@frozen
public struct EmptyRange: Error, Hashable, Sendable {
    /// The error, which carries no payload.
    @inlinable
    public init() {}
}
