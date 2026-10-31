// The README's examples, verbatim, so the README cannot drift from the code.

import GrafluentCollections
import Testing

@Suite("README examples")
struct READMEExamplesTests {
    @Test("Usage")
    func usage() {
        let greeting = Greeting(name: "Ada").formal().punctuated(with: "!")
        #expect(greeting.text == "Good day, Ada!")
    }
}
