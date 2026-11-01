/// The error a `checked:` spelling throws when a sequence that must hold unique keys repeats one.
@frozen
public struct DuplicateKey: Error, Hashable, Sendable {
    /// The error, which carries no payload.
    @inlinable
    public init() {}
}
