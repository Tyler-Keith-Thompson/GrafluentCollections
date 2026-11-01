/// The error a `checked:` spelling throws for a floating-point value that is NaN where only an
/// ordered value has a meaning, such as a coordinate of a point in a k-d tree.
@frozen
public struct NotANumber: Error, Hashable, Sendable {
    /// The error, which carries no payload.
    @inlinable
    public init() {}
}
