/// The error a `checked:` spelling throws when a sequence that must hold unique keys repeats one.
@frozen
public struct DuplicateKey: Error, Hashable, Sendable {
    @inlinable
    public init() {}
}
