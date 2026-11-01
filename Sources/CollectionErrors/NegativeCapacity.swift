/// The error a `checked:` spelling throws for a capacity below zero.
@frozen
public struct NegativeCapacity: Error, Hashable, Sendable {
    @inlinable
    public init() {}
}
