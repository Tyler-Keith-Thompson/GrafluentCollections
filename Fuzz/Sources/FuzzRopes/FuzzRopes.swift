// Rope against an Array: inserts, removals, replacements, element writes, extractions and
// concatenations, some long enough to cross chunks. After every operation the rope's elements
// must be the array's, and a snapshot is unaffected by later edits.

import FuzzSupport
import Ropes

@main
enum FuzzRopes {
    static func main() { runFuzzer(fuzz) }

    static func fuzz(_ input: inout FuzzInput) {
        var rope = Rope<Int>()
        var model: [Int] = []
        var snapshot: (Rope<Int>, [Int])?
        var serial = 0
        while !input.isEmpty {
            let a = (input.byte() << 8 | input.byte()) % (model.count + 1)
            let b = model.isEmpty ? 0 : (a + input.byte() * 3) % (model.count + 1)
            let range = min(a, b) ..< max(a, b)
            // Lengths up to 765 cross the 256-element chunks of Int.
            let length = input.byte() * 3
            let new = Array(serial ..< serial + length)
            serial += length + 1
            switch input.int(below: 7) {
            case 0, 1:
                rope.insert(contentsOf: new, at: a)
                model.insert(contentsOf: new, at: a)
            case 2:
                rope.removeSubrange(range)
                model.removeSubrange(range)
            case 3:
                rope.replaceSubrange(range, with: new.prefix(length % 7))
                model.replaceSubrange(range, with: new.prefix(length % 7))
            case 4:
                if !model.isEmpty {
                    rope[a % model.count] = -serial
                    model[a % model.count] = -serial
                }
            case 5:
                let extracted = rope.extracting(range)
                check(Array(extracted) == Array(model[range]), "extracting(\(range))")
                rope = extracted + rope
                model = Array(model[range]) + model
            default:
                snapshot = (rope, model)
            }
            check(rope.count == model.count, "count")
            if !model.isEmpty {
                check(rope[a % model.count] == model[a % model.count], "subscript")
            }
        }
        check(Array(rope) == model, "elements")
        if let (copy, saved) = snapshot {
            check(Array(copy) == saved, "the snapshot changed")
        }
    }
}
