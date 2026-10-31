/// A greeting, composed from a name and the modifiers applied to it.
///
/// A `Greeting` is a value: every modifier returns a new greeting and leaves the receiver as it
/// was, so a greeting can be declared in one expression and shared without copying rules.
///
/// ```swift
/// let greeting = Greeting(name: "Ada").formal().punctuated(with: "!")
/// greeting.text  // "Good day, Ada!"
/// ```
@frozen
public struct Greeting: Hashable, Sendable {
    /// How a greeting addresses its name.
    @frozen
    public enum Register: Hashable, Sendable {
        /// "Hi, name".
        case casual
        /// "Good day, name".
        case formal
    }

    /// The name addressed. Never empty.
    public var name: String
    /// How the name is addressed.
    public var register: Register
    /// The character the text ends with, or `nil` for none.
    public var punctuation: Character?

    /// A casual, unpunctuated greeting of `name`.
    ///
    /// - Parameter name: The name to address. Traps when empty; use ``init(checkedName:)`` to
    ///   throw instead.
    @inlinable
    public init(name: String) {
        precondition(!name.isEmpty, "A greeting needs a name")
        self.name = name
        self.register = .casual
        self.punctuation = nil
    }

    /// A casual, unpunctuated greeting of `name`.
    ///
    /// - Parameter name: The name to address.
    /// - Throws: ``EmptyName`` when `name` is empty.
    @inlinable
    public init(checkedName name: String) throws(EmptyName) {
        guard !name.isEmpty else { throw EmptyName() }
        self.init(name: name)
    }

    /// The same greeting in the formal register.
    @inlinable
    public func formal() -> Greeting {
        var copy = self
        copy.register = .formal
        return copy
    }

    /// The same greeting in the casual register.
    @inlinable
    public func casual() -> Greeting {
        var copy = self
        copy.register = .casual
        return copy
    }

    /// The same greeting ending in `character`.
    @inlinable
    public func punctuated(with character: Character) -> Greeting {
        var copy = self
        copy.punctuation = character
        return copy
    }

    /// The greeting as text: the register's salutation, a comma, the name and the punctuation.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the name.
    @inlinable
    public var text: String {
        let salutation = switch register {
        case .casual: "Hi"
        case .formal: "Good day"
        }
        var text = "\(salutation), \(name)"
        if let punctuation {
            text.append(punctuation)
        }
        return text
    }
}

/// The error ``Greeting/init(checkedName:)`` throws for an empty name.
@frozen
public struct EmptyName: Error, Hashable, Sendable {
    @inlinable
    public init() {}
}
