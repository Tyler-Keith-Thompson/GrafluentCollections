/// The error a join throws when the two collections' key ranges overlap, so neither collection's
/// keys all lie below the other's.
@frozen
public struct OverlappingKeys: Error, Hashable, Sendable {
    /// The error, which carries no payload.
    @inlinable
    public init() {}
}
