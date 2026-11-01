/// An associative operation with an identity element, written as a type so generic code
/// specializes on it: `SegmentTree<Sum<Int>>` combines with `+`, `SegmentTree<Minimum<Int>>` with
/// `min`.
///
/// Conforming types are usually empty enums or structs that are never instantiated. The
/// operation need not be commutative; trees combine values in index order.
///
/// ```swift
/// enum Concatenation: Monoid {
///     static var identity: String { "" }
///     static func combine(_ lhs: String, _ rhs: String) -> String { lhs + rhs }
/// }
/// ```
public protocol Monoid {
    /// The values the operation combines.
    associatedtype Element

    /// The value that leaves any other unchanged: `combine(identity, x) == x == combine(x, identity)`.
    static var identity: Element { get }

    /// `lhs` combined with `rhs`, in that order. Associative:
    /// `combine(combine(a, b), c) == combine(a, combine(b, c))`.
    static func combine(_ lhs: Element, _ rhs: Element) -> Element
}

/// Addition, with identity zero.
@frozen
public enum Sum<Value: AdditiveArithmetic>: Monoid {
    @inlinable public static var identity: Value { .zero }
    @inlinable public static func combine(_ lhs: Value, _ rhs: Value) -> Value { lhs + rhs }
}

/// Multiplication, with identity one.
@frozen
public enum Product<Value: Numeric>: Monoid {
    @inlinable public static var identity: Value { 1 }
    @inlinable public static func combine(_ lhs: Value, _ rhs: Value) -> Value { lhs * rhs }
}

/// The smaller of two integers, with identity `Value.max`.
@frozen
public enum Minimum<Value: FixedWidthInteger>: Monoid {
    @inlinable public static var identity: Value { .max }
    @inlinable public static func combine(_ lhs: Value, _ rhs: Value) -> Value { Swift.min(lhs, rhs) }
}

/// The larger of two integers, with identity `Value.min`.
@frozen
public enum Maximum<Value: FixedWidthInteger>: Monoid {
    @inlinable public static var identity: Value { .min }
    @inlinable public static func combine(_ lhs: Value, _ rhs: Value) -> Value { Swift.max(lhs, rhs) }
}

/// Updates that act on the values of a monoid, for ``LazySegmentTree``: a monoid of updates
/// under composition, each mapping a combined value of a run of elements to the combined value
/// after the update is applied to every element of the run.
///
/// ```swift
/// // Add a constant to every value in a range, reading back sums.
/// enum AddToSum: MonoidAction {
///     typealias Values = Sum<Int>
///     static var identity: Int { 0 }
///     static func compose(_ outer: Int, _ inner: Int) -> Int { outer + inner }
///     static func apply(_ update: Int, to sum: Int, count: Int) -> Int { sum + update * count }
/// }
/// ```
///
/// The laws, for updates `f`, `g`, combined values `x`, `y` of runs of `m` and `n` elements:
/// `apply(identity, to: x, count: m) == x`;
/// `apply(compose(f, g), to: x, count: m) == apply(f, to: apply(g, to: x, count: m), count: m)`;
/// `apply(f, to: combine(x, y), count: m + n) == combine(apply(f, to: x, count: m), apply(f, to: y, count: n))`.
public protocol MonoidAction {
    /// The monoid whose combined values the updates act on.
    associatedtype Values: Monoid
    /// An update.
    associatedtype Update

    /// The update that changes nothing.
    static var identity: Update { get }

    /// The update that applies `inner` and then `outer`.
    static func compose(_ outer: Update, _ inner: Update) -> Update

    /// The combined value of a run of `count` elements, `value` before the update, after `update`
    /// is applied to each of them.
    static func apply(_ update: Update, to value: Values.Element, count: Int) -> Values.Element
}
