// Property tests against a naive reference: what the text must contain, whatever the inputs.
// Each test is self-contained; see GreetingTests.swift.

import Greetings
import GrafluentCollectionsTestSupport
import PropertyBased
import Testing

@Suite("Greeting: properties")
struct GreetingPropertyTests {
    @Test("The text is the salutation, a comma and a space, the name, then the punctuation", .tags(.randomized))
    func textShape() async {
        let name = Gen.letter.array(of: 1 ... 12).map { String($0) }
        let formal = Gen.bool()
        let punctuate = Gen.bool()
        let mark = Gen.element(of: ["!", "?", "."] as [Character]).map { $0! }
        await propertyCheck(count: 500, input: name, formal, punctuate, mark) { name, formal, punctuate, mark in
            var greeting = Greeting(name: name)
            if formal { greeting = greeting.formal() }
            if punctuate { greeting = greeting.punctuated(with: mark) }
            let salutation = formal ? "Good day" : "Hi"
            let expected = "\(salutation), \(name)" + (punctuate ? String(mark) : "")
            #expect(greeting.text == expected)
        }
    }

    @Test("formal() and casual() are idempotent and inverse", .tags(.randomized))
    func registerLaws() async {
        let name = Gen.letter.array(of: 1 ... 12).map { String($0) }
        await propertyCheck(count: 200, input: name) { name in
            let greeting = Greeting(name: name)
            #expect(greeting.formal().formal() == greeting.formal())
            #expect(greeting.casual().casual() == greeting.casual())
            #expect(greeting.formal().casual() == greeting)
        }
    }

    @Test("A seeded generator reproduces the same names", .tags(.randomized))
    func seededReproducibility() {
        var first = SeededRandomNumberGenerator(seed: 42)
        var second = SeededRandomNumberGenerator(seed: 42)
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz")
        let a = (0 ..< 20).map { _ in String(alphabet.randomElement(using: &first)!) }
        let b = (0 ..< 20).map { _ in String(alphabet.randomElement(using: &second)!) }
        #expect(a == b)
        #expect(a.allSatisfy { Greeting(name: $0).text == "Hi, \($0)" })
    }
}
