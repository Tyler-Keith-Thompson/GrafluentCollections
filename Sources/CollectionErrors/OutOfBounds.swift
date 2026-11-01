/// The error a `checked:` spelling throws for a point that lies outside the region a spatial
/// index covers.
@frozen
public struct OutOfBounds: Error, Hashable, Sendable {
    /// The error, which carries no payload.
    @inlinable
    public init() {}
}
