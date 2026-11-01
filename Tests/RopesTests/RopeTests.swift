// Tests for Rope. Each test builds its own rope and checks it against a hand-worked answer or an
// Array given the same edits, so it can be copied into another file and still run. Nothing here
// is shared but the imports.

import GrafluentCollectionsTestSupport
import PropertyBased
import Ropes
import Testing
import Trees

@Suite("Rope: hand-worked cases")
struct RopeTests {
    @Test("Inserting and removing text in the middle")
    func handWorked() {
        var text = Rope("Hello, world!")
        text.insert(contentsOf: "brave new ", at: 7)
        let inserted = "Hello, brave new world!"
        #expect(String(text) == inserted)
        text.removeSubrange(5 ..< 16)
        let removed = "Hello world!"
        #expect(String(text) == removed)
        let w: Character = "w"
        #expect(text[6] == w)
        text[0] = "J"
        let replaced = "Jello world!"
        #expect(String(text) == replaced)
        text.replaceSubrange(6 ..< 11, with: "there")
        let there = "Jello there!"
        #expect(String(text) == there)
    }

    @Test("Empty ropes: concatenation, extraction and edits at offset 0")
    func empty() {
        let empty = Rope<Int>()
        #expect(empty.isEmpty)
        #expect((empty + empty).isEmpty)
        #expect(empty.extracting(0 ..< 0).isEmpty)
        let some: Rope = [1, 2, 3]
        #expect(empty + some == some)
        #expect(some + empty == some)
        var edited = empty
        edited.insert(contentsOf: [Int](), at: 0)
        #expect(edited.isEmpty)
        edited.removeSubrange(0 ..< 0)
        #expect(edited.isEmpty)
        edited.insert(7, at: 0)
        let seven: Rope = [7]
        #expect(edited == seven)
        #expect(BinaryTree(empty) == nil)
    }

    @Test("Extracting at 0 and at count gives the whole rope and nothing")
    func extractAtEnds() {
        let rope = Rope(0 ..< 1_000)
        let all = Array(0 ..< 1_000)
        #expect(Array(rope.extracting(0 ..< 1_000)) == all)
        #expect(rope.extracting(0 ..< 0).isEmpty)
        #expect(rope.extracting(1_000 ..< 1_000).isEmpty)
        let middle = Array(250 ..< 750)
        #expect(Array(rope.extracting(250 ..< 750)) == middle)
    }

    @Test("Edits at and across chunk boundaries keep the order")
    func chunkBoundaries() {
        // A chunk holds 2,048 bytes of elements: 256 Ints where Int is 64 bits, 512 where it is
        // 32. Four chunks' worth makes four full chunks.
        let chunk = 2_048 / MemoryLayout<Int>.stride
        var rope = Rope(0 ..< 4 * chunk)
        var reference = Array(0 ..< 4 * chunk)
        let fourChunks = 4
        #expect(BinaryTree(rope)?.vertexCount == fourChunks)
        for offset in [chunk, 2 * chunk, 3 * chunk, 0, 4 * chunk] {
            rope.insert(-offset, at: offset)
            reference.insert(-offset, at: offset)
        }
        #expect(Array(rope) == reference)
        rope.removeSubrange(250 ..< 530)
        reference.removeSubrange(250 ..< 530)
        #expect(Array(rope) == reference)
        rope.insert(contentsOf: 5_000 ..< 5_600, at: 300)
        reference.insert(contentsOf: 5_000 ..< 5_600, at: 300)
        #expect(Array(rope) == reference)
        rope.removeSubrange(0 ..< rope.count)
        #expect(rope.isEmpty)
    }

    @Test("A copy shares every chunk but the one an edit touches")
    func copyOnWriteAtChunks() {
        // Ten chunks of 2,048 bytes.
        let original = Rope(0 ..< 10 * (2_048 / MemoryLayout<Int>.stride))
        var copy = original
        copy[1_000] = -1
        func chunkAddresses(_ rope: Rope<Int>) -> [UnsafeRawPointer?] {
            rope._nodes.map { node in node.chunk.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress) } }
        }
        let before = chunkAddresses(original), after = chunkAddresses(copy)
        let changed = zip(before, after).filter { $0 != $1 }.count
        let one = 1
        #expect(changed == one)
        let unchanged = 1_000
        #expect(original[1_000] == unchanged)
        let appended = original + copy
        let shared = Set(chunkAddresses(appended)).intersection(chunkAddresses(original)).count
        let ten = 10
        #expect(shared == ten)
    }

    @Test("The chunks convert to a balanced BinaryTree in sequence order")
    func binaryTree() throws {
        // Seven chunks of 2,048 bytes.
        let rope = Rope(0 ..< 7 * (2_048 / MemoryLayout<Int>.stride))
        let tree = try #require(BinaryTree(rope))
        let seven = 7
        #expect(tree.vertexCount == seven)
        let sequence = Array(0 ..< 7)
        #expect(tree.inorder == sequence)
    }

    @Test("Collection laws: indices, counts, equality and hashing ignore chunking")
    func collectionLaws() {
        var built = Rope<Int>()
        for k in (0 ..< 600).reversed() {
            built.insert(k, at: 0)
        }
        let direct = Rope(0 ..< 600)
        #expect(built == direct)
        #expect(built.hashValue == direct.hashValue)
        let count = 600
        #expect(built.count == count)
        #expect(built.indices == 0 ..< 600)
        #expect(Array(built.reversed()) == Array((0 ..< 600).reversed()))
        #expect(built.index(after: 3) == 4)
        #expect(built.index(before: 3) == 2)
        #expect(built.distance(from: 10, to: 30) == 20)
        let description = "[1, 2, 3]"
        let small: Rope = [1, 2, 3]
        #expect(small.description == description)
    }

    @Test("The checked subscript throws IndexOutOfRange")
    func checkedSubscript() throws {
        let rope: Rope = [1, 2, 3]
        #expect(throws: IndexOutOfRange()) { try rope[checked: 3] }
        #expect(throws: IndexOutOfRange()) { try rope[checked: -1] }
        let three = 3
        #expect(try rope[checked: 2] == three)
    }

}

@Suite("Rope: properties")
struct RopePropertyTests {
    @Test("Random inserts, removals, replacements, extractions and concatenations match an Array", .tags(.randomized))
    func matchesArray() async {
        let operations = Gen.int(in: 0 ... 1_000_000).array(of: 0 ... 60)
        await propertyCheck(count: 200, input: operations) { operations in
            var rope = Rope<Int>()
            var reference: [Int] = []
            for (serial, operation) in operations.enumerated() {
                let a = operation % (reference.count + 1)
                let b = operation / 7 % (reference.count + 1)
                let range = Swift.min(a, b) ..< Swift.max(a, b)
                // Lengths up to 700 cross the 256-element chunks of Int.
                let length = operation / 50 % 700
                let new = Array(serial * 1_000 ..< serial * 1_000 + length)
                switch operation % 5 {
                case 0:
                    rope.insert(contentsOf: new, at: a)
                    reference.insert(contentsOf: new, at: a)
                case 1:
                    rope.removeSubrange(range)
                    reference.removeSubrange(range)
                case 2:
                    rope.replaceSubrange(range, with: new.prefix(length % 20))
                    reference.replaceSubrange(range, with: new.prefix(length % 20))
                case 3:
                    let extracted = rope.extracting(range)
                    #expect(Array(extracted) == Array(reference[range]))
                    rope = rope + extracted
                    reference += reference[range]
                default:
                    rope.insert(serial, at: a)
                    reference.insert(serial, at: a)
                }
            }
            #expect(Array(rope) == reference)
            #expect(rope.count == reference.count)
            for k in Swift.stride(from: 0, to: reference.count, by: 37) {
                #expect(rope[k] == reference[k])
            }
        }
    }
}
