// Each test is self-contained: it builds its own values and states its own expectations, so it
// can be copied into another file and still run. Nothing here is shared but the imports.

import Greetings
import GrafluentCollectionsTestSupport
import Testing

@Suite("Greeting: hand-worked cases")
struct GreetingTests {
    @Test("A greeting is casual and unpunctuated until modified")
    func defaults() {
        let greeting = Greeting(name: "Ada")
        #expect(greeting.name == "Ada")
        #expect(greeting.register == .casual)
        #expect(greeting.punctuation == nil)
        #expect(greeting.text == "Hi, Ada")
    }

    @Test("Modifiers compose in any order")
    func composition() {
        let expected = "Good day, Ada!"
        #expect(Greeting(name: "Ada").formal().punctuated(with: "!").text == expected)
        #expect(Greeting(name: "Ada").punctuated(with: "!").formal().text == expected)
    }

    @Test("The last modifier of a kind wins")
    func lastWins() {
        let greeting = Greeting(name: "Ada").formal().casual().punctuated(with: "?").punctuated(with: ".")
        #expect(greeting.register == .casual)
        #expect(greeting.punctuation == ".")
        #expect(greeting.text == "Hi, Ada.")
    }

    @Test("A modifier returns a new value and leaves the receiver alone", .tags(.copyOnWrite))
    func valueSemantics() {
        let original = Greeting(name: "Ada")
        let formal = original.formal()
        #expect(original.register == .casual)
        #expect(formal.register == .formal)
        #expect(original != formal)
    }

    @Test("Equal greetings hash equally", .tags(.conformance))
    func hashing() {
        let a = Greeting(name: "Ada").formal().punctuated(with: "!")
        let b = Greeting(name: "Ada").punctuated(with: "!").formal()
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(Set([a, b]).count == 1)
    }

    @Test("The checked spelling throws EmptyName for an empty name")
    func checkedEmptyName() {
        #expect(throws: EmptyName()) {
            try Greeting(checkedName: "")
        }
        #expect(throws: Never.self) {
            try Greeting(checkedName: "Ada")
        }
    }

    @Test("The checked spelling gives the same greeting as the plain one")
    func checkedAgreesWithPlain() throws {
        let plain = Greeting(name: "Grace")
        let checked = try Greeting(checkedName: "Grace")
        #expect(plain == checked)
    }

    @Test("A name of one character, of spaces, and with multibyte characters", .tags(.fixture))
    func edgeNames() {
        #expect(Greeting(name: "A").text == "Hi, A")
        #expect(Greeting(name: "  ").text == "Hi,   ")
        #expect(Greeting(name: "Zoë 👋").formal().text == "Good day, Zoë 👋")
    }

    @Test("The plain spelling traps on an empty name", .tags(.precondition))
    func plainEmptyNameTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = Greeting(name: "")
        }
    }
}
