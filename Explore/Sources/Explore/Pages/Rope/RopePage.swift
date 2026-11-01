import ElementaryUI
import Reactivity
import Ropes
import Trees

/// Where a chunk's elements are stored, which stays the same while the chunk is shared.
func ropeAddress(_ chunk: ContiguousArray<Character>) -> UInt {
    chunk.withUnsafeBufferPointer { UInt(bitPattern: $0.baseAddress) }
}

/// How each chunk of a rope relates to the rope before an edit.
enum ChunkState: Equatable {
    /// The same storage as a chunk of the rope before, in the same place.
    case kept
    /// Storage the edit wrote.
    case written
    /// The same storage as a chunk of the rope before, linked in a second time.
    case shared
}

/// What one edit did: the operation, each chunk's state afterwards, and how many chunks of
/// the rope before it no longer holds.
struct RopeStep {
    var operation: RopeOperation
    var states: [ChunkState]
    /// How many chunks of the rope before lay wholly inside a removed range.
    var unlinked: Int
    var countBefore: Int
    var countAfter: Int
}

func ropeStep(_ operation: RopeOperation, before: Rope<Character>, after: Rope<Character>) -> RopeStep {
    let old = before.chunksView.map(ropeAddress)
    let new = after.chunksView.map(ropeAddress)
    let oldSet = Set(old)
    var seen: Set<UInt> = []
    let states = new.map { address -> ChunkState in
        defer { seen.insert(address) }
        guard oldSet.contains(address) else { return .written }
        return seen.contains(address) ? .shared : .kept
    }
    var unlinked = 0
    if case .remove(let range) = operation {
        var start = 0
        for chunk in before.chunksView {
            if range.lowerBound <= start && start + chunk.count <= range.upperBound { unlinked += 1 }
            start += chunk.count
        }
    }
    return RopeStep(operation: operation, states: states, unlinked: unlinked, countBefore: before.count, countAfter: after.count)
}

@Reactive
final class RopeModel {
    var textInput = "A rope keeps a long text as a tree of short chunks, each a run of characters stored together. Editing the middle of the text rewrites only the chunks the edit lands in, so a change near the start costs the same as one near the end, however long the text grows. The other chunks stay exactly where they were, and a copy of the rope shares every one of them until it changes. Extracting a range shares the chunks wholly inside it, and joining two ropes links their chunks into one tree without copying a character."
    var operationsInput = "+60 \"(and a sentence typed into the middle of it) \" -200..420 >100..300 +5 \"!\""
    var operations: [RopeOperation] = []
    var history: [Rope<Character>] = [Rope()]
    var steps: [RopeStep] = []
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_500, scrubID: "scrub-rope")

    init() {
        run()
    }

    func set(text newText: String) {
        textInput = String(newText.prefix(1_200))
        run()
    }

    func set(operations newText: String) {
        operationsInput = String(newText.prefix(400))
        run()
    }

    func run() {
        var count = textInput.count
        var valid: [RopeOperation] = []
        for operation in ropeOperations(operationsInput) where ropeFits(operation, count: count) {
            valid.append(operation)
            switch operation {
            case .insert(let words, _): count += words.count
            case .remove(let range): count -= range.count
            case .copyToEnd(let range): count += range.count
            }
        }
        operations = valid
        history = ropeHistory(textInput, operations)
        steps = operations.indices.map { i in ropeStep(operations[i], before: history[i], after: history[i + 1]) }
        playback.reset(count: steps.count)
    }
}

let rope = RopeModel()

func ropeChunkCount(_ count: Int) -> String { count == 1 ? "1 chunk" : "\(count) chunks" }

func describeRope(_ step: RopeStep) -> String {
    let written = step.states.filter { $0 == .written }.count
    let shared = step.states.filter { $0 == .shared }.count
    let kept = step.states.filter { $0 == .kept }.count
    let summary = "\(ropeChunkCount(written).capitalizedFirst) written, \(kept) kept as they were"
    switch step.operation {
    case .insert(let words, let offset):
        let characters = words.count == 1 ? "1 character" : "\(words.count) characters"
        let how = written == 1
            ? "The words fit in the chunk they land in, so that chunk alone is copied with them in."
            : "The words would overfill the chunk they land in, so it splits in two, or the words get chunks of their own."
        return "Insert \(characters) at \(offset). \(summary). \(how)"
    case .remove(let range):
        let inside = step.unlinked == 0 ? "No chunk lay wholly inside the range" : "\(ropeChunkCount(step.unlinked).capitalizedFirst) wholly inside the range \(step.unlinked == 1 ? "was" : "were") unlinked without being read"
        return "Remove \(range.count) characters, \(range.lowerBound) up to \(range.upperBound). \(summary). \(inside); only the chunks at its two ends are copied, trimmed."
    case .copyToEnd(let range):
        return "Copy \(range.lowerBound) up to \(range.upperBound) to the end: extracting(_:) takes the \(range.count) characters, and + joins them after the last chunk. \(ropeChunkCount(shared).capitalizedFirst) linked in a second time without a character copied, \(written) written for the partial chunks at the range’s two ends, \(kept) kept."
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// The chunks, by number, at their places in the tree: left to right in sequence order, down by
/// depth; written chunks ringed, shared ones tinted.
func ropeDrawing(_ rope: Rope<Character>, step: RopeStep?) -> (nodes: [CanvasNode], edges: [CanvasEdge], height: Int) {
    let shape = ropeShape(rope)
    let chunks = Array(rope.chunksView)
    let count = chunks.count
    let gap = min(64.0, 640.0 / Double(max(count, 1)))
    let nodes = chunks.indices.map { i in
        let state = step?.states[i]
        let classes = state == .written ? " selected" : state == .shared ? " done" : ""
        return CanvasNode(x: 340 - gap * Double(count - 1) / 2 + gap * Double(i), y: 34 + 70 * Double(shape.depths[i]),
                          name: "\(i)", badge: "\(chunks[i].count)", radius: 15, classes: classes)
    }
    let edges = chunks.indices.compactMap { i in shape.parents[i].map { CanvasEdge(from: $0, to: i) } }
    return (nodes, edges, 34 + 70 * (shape.depths.max() ?? 0) + 50)
}

func ropeMarbleKind(_ operation: RopeOperation) -> String {
    switch operation {
    case .insert: "m-green"
    case .remove: "m-red"
    case .copyToEnd: "m-blue"
    }
}

func ropeMarbleLetter(_ operation: RopeOperation) -> String {
    switch operation {
    case .insert: "+"
    case .remove: "−"
    case .copyToEnd: ">"
    }
}

/// The class of chunk `i`'s strip in the text.
func ropeChunkClass(_ state: ChunkState?, _ i: Int) -> String {
    let parity = i % 2 == 0 ? "chunk" : "chunk odd"
    switch state {
    case .written: return parity + " written"
    case .shared: return parity + " shared"
    default: return parity
    }
}

@View
struct RopeLab {
    var body: some View {
        let model = rope
        let playback = model.playback
        let k = playback.k
        let steps = model.steps
        let last = k > 0 ? steps[k - 1] : nil
        let current = model.history[k]
        let chunks = Array(current.chunksView)
        let drawing = ropeDrawing(current, step: last)

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your text and edits")) {
                label(.class("field"), .for("rope-text")) {
                    "Text "
                    input(.id("rope-text"), .type(.text), .value(model.textInput), .custom(name: "maxlength", value: "1200"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in rope.set(text: event.targetValue ?? "") }
                }
                label(.class("field"), .for("rope-edits")) {
                    "+i \"words\" inserts at i, -a..b removes a up to b, >a..b copies a up to b to the end "
                    input(.id("rope-edits"), .type(.text), .value(model.operationsInput), .custom(name: "maxlength", value: "400"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in rope.set(operations: event.targetValue ?? "") }
                }
            }
            section(.class("lab"), .custom(name: "aria-label", value: "The rope")) {
                div(.class("panel stage")) {
                    span(.class("label")) { "The tree of chunks" }
                    if chunks.isEmpty {
                        p(.class("empty")) { "Type some text to build a rope from." }
                    } else {
                        GraphCanvas(label: "The rope’s \(chunks.count) chunks as a balanced tree after \(k) edits", width: 680, height: drawing.height, nodes: drawing.nodes, edges: drawing.edges)
                    }
                    div(.class("legend")) {
                        span { i(.class("dot selected")) {}; "a chunk this edit wrote" }
                        span { i(.class("dot done")) {}; "a chunk shared a second time" }
                    }
                    p(.class("legend")) { "In each circle, how many characters the chunk holds; under it, the chunk’s number in the text. Read left to right, the chunks spell the text." }
                    span(.class("label")) { "The text, chunk by chunk" }
                    p(.class("chunks")) {
                        for i in chunks.indices {
                            span(.class(ropeChunkClass(last?.states[i], i)), .custom(name: "title", value: "chunk \(i), \(chunks[i].count) characters")) { String(chunks[i]) }
                        }
                    }
                }
                div(.class("side")) {
                    div(.class("panel"), .custom(name: "aria-live", value: "polite")) {
                        span(.class("label")) { k == steps.count ? "Done after \(steps.count) edits" : "Edit \(k) of \(steps.count)" }
                        p(.class("narration")) {
                            if steps.isEmpty {
                                "Type an edit, such as +10 \"new \" or -20..40."
                            } else if let last {
                                describeRope(last)
                            } else {
                                "The text starts as full chunks of about 2 KB each, linked as a balanced tree. Each vertex knows how many characters lie below it, so finding an offset is a walk down from the root."
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "The rope" }
                        div(.class("stat")) {
                            div {
                                span(.class("num")) { "\(current.count)" }
                                "characters"
                            }
                            div {
                                span(.class("num")) { "\(chunks.count)" }
                                "chunks"
                            }
                            div(.class("good")) {
                                span(.class("num")) { "\(last?.states.filter { $0 == .written }.count ?? 0)" }
                                "written this edit"
                            }
                        }
                    }
                }
            }
            section(.class("panel controls"), .custom(name: "aria-label", value: "Playback")) {
                div(.class("buttons")) {
                    PlaybackButtons(playback: playback)
                }
                Timeline(
                    playback: playback,
                    marbles: steps.map { step in
                        Marble(kind: ropeMarbleKind(step.operation), radius: 9, letter: ropeMarbleLetter(step.operation), title: describeRope(step))
                    },
                    legend: [
                        (Marble(kind: "m-green", radius: 6), "insert"),
                        (Marble(kind: "m-red", radius: 6), "remove"),
                        (Marble(kind: "m-blue", radius: 6), "copy to the end"),
                    ])
            }
        }
    }
}

/// Swift source for an operation, as the code panel's `operations` binding spells it.
func ropeOperationCode(_ operation: RopeOperation) -> String {
    switch operation {
    case .insert(let words, let offset): ".insert(\"\(words)\", at: \(offset))"
    case .remove(let range): ".remove(\(range.lowerBound)..<\(range.upperBound))"
    case .copyToEnd(let range): ".copyToEnd(\(range.lowerBound)..<\(range.upperBound))"
    }
}

@View
struct RopeCodePanel {
    var body: some View {
        let model = rope
        let last = model.history.last ?? Rope()
        let preview = model.textInput.count > 40 ? String(model.textInput.prefix(40)) + "…" : model.textInput
        CodePanel(
            snippets: [
                .ropeImports,
                Snippet(lines: [
                    "let text = \"\(preview)\"",
                    "let operations: [RopeOperation] = [\(model.operations.map(ropeOperationCode).joined(separator: ", "))]",
                ]),
                .ropeRun, .ropeShape,
            ],
            results: ["[\(last.chunksView.map { "\($0.count)" }.joined(separator: ", "))]", BinaryTree(last).map { "\($0.root)" } ?? "nil"])
    }
}

enum RopePage {
    static func mount() {
        mountView(RopeLab(), in: "app")
        mountView(RopeCodePanel(), in: "code")
    }
}
