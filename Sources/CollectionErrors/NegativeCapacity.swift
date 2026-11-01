/// The error a `checked:` spelling throws for a capacity below zero.
@frozen
public struct NegativeCapacity: Error, Hashable, Sendable {
    /// The error, which carries no payload.
    @inlinable
    public init() {}
}
