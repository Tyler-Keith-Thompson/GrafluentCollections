/// The error a join throws when the two collections' key ranges overlap, so neither collection's
/// keys all lie below the other's.
@frozen
public struct OverlappingKeys: Error, Hashable, Sendable {
    @inlinable
    public init() {}
}
