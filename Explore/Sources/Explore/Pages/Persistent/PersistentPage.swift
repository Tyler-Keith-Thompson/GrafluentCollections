import ElementaryUI
import PersistentTrees
import Reactivity
import Trees

/// What one edit made: the version's elements, which of their vertices it shares with the
/// version before, and the version each vertex was first made in.
struct PersistentStep {
    var edit: PersistentEdit
    var shared: Set<Int>
    var made: [Int]
    var changed: Bool
}

@Reactive
final class PersistentModel {
    var elementsInput = "8 3 12 1 5 10 14 2 4 6 9 11 13 15"
    var editsInput = "+7 -12 +16 -3 +12 -20"
    var edits: [PersistentEdit] = []
    var versions: [PersistentTreeSet<Int>] = [PersistentTreeSet()]
    /// For each version, the version each of its elements' vertices was made in.
    var origins: [[Int: Int]] = [[:]]
    var steps: [PersistentStep] = []
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_500, scrubID: "scrub-persistent")

    init() {
        run()
    }

    func set(elements newText: String) {
        elementsInput = String(newText.prefix(100))
        run()
    }

    func set(edits newText: String) {
        editsInput = String(newText.prefix(100))
        run()
    }

    func run() {
        edits = persistentEdits(editsInput)
        let history = persistentHistory(persistentElements(elementsInput), edits)
        versions = history.versions
        var origins = [Dictionary(uniqueKeysWithValues: versions[0].map { ($0, 0) })]
        for v in 1 ..< versions.count {
            let shared = Set(history.shared[v])
            origins.append(Dictionary(uniqueKeysWithValues: versions[v].map { ($0, shared.contains($0) ? origins[v - 1][$0] ?? v : v) }))
        }
        self.origins = origins
        steps = edits.indices.map { i in
            let shared = Set(history.shared[i + 1])
            return PersistentStep(edit: edits[i], shared: shared, made: versions[i + 1].filter { !shared.contains($0) },
                                  changed: versions[i + 1].count != versions[i].count)
        }
        playback.reset(count: steps.count)
    }
}

let persistent = PersistentModel()

func persistentVertices(_ count: Int) -> String { count == 1 ? "1 vertex" : "\(count) vertices" }

func describePersistent(_ step: PersistentStep, version: Int) -> String {
    let made = step.made.map(String.init).joined(separator: ", ")
    switch step.edit {
    case .insert(let element) where !step.changed:
        return "Insert \(element): it is already there, so version \(version) is version \(version - 1) itself, every vertex shared."
    case .remove(let element) where !step.changed:
        return "Remove \(element): it is not there, so version \(version) is version \(version - 1) itself, every vertex shared."
    case .insert(let element):
        return "Insert \(element) into version \(version - 1): \(persistentVertices(step.made.count)) made (\(made)), the path from the root down to where \(element) goes, rebalanced where needed. The other \(step.shared.count) are shared with version \(version - 1), which is unchanged."
    case .remove(let element):
        let path = step.made.isEmpty ? "No vertex made: the root itself went" : "\(persistentVertices(step.made.count).prefix(1).uppercased() + persistentVertices(step.made.count).dropFirst()) made (\(made)) on the path down to \(element)"
        return "Remove \(element) from version \(version - 1). \(path), and the other \(step.shared.count) are shared with version \(version - 1), which still holds \(element)."
    }
}

/// One version's tree: elements left to right in order, down by depth, starting at `top`;
/// each vertex noting the version it was made in. Vertices made by this version are ringed
/// and shared ones tinted when `mark` is set; vertices the next version dropped or rebuilt are
/// dimmed when `fading` holds them.
func persistentTree(_ version: PersistentTreeSet<Int>, origins: [Int: Int], top: Double, offset: Int,
                    made: Set<Int>?, fading: Set<Int>?) -> (nodes: [CanvasNode], edges: [CanvasEdge], bottom: Double) {
    let shape = persistentShape(version)
    let elements = Array(version)
    let gap = min(46.0, 640.0 / Double(max(elements.count, 1)))
    var place: [Int: Int] = [:]
    let nodes = elements.enumerated().map { rank, element in
        place[element] = offset + rank
        var classes = ""
        if let made { classes = made.contains(element) ? " selected" : " done" }
        if let fading, fading.contains(element) { classes = " dim" }
        return CanvasNode(x: 340 - gap * Double(elements.count - 1) / 2 + gap * Double(rank), y: top + 62 * Double(shape.depths[element] ?? 0),
                          name: "\(element)", note: "v\(origins[element] ?? 0)", radius: 14, classes: classes)
    }
    let edges = elements.compactMap { element in
        shape.parents[element].map { CanvasEdge(from: place[$0]!, to: place[element]!) }
    }
    return (nodes, edges, top + 62 * Double(shape.depths.values.max() ?? 0))
}

func persistentDrawing(_ model: PersistentModel, k: Int) -> (nodes: [CanvasNode], edges: [CanvasEdge], height: Int, split: Double) {
    guard k > 0 else {
        let only = persistentTree(model.versions[0], origins: model.origins[0], top: 34, offset: 0, made: nil, fading: nil)
        return (only.nodes, only.edges, Int(only.bottom) + 50, 0)
    }
    let step = model.steps[k - 1]
    let previous = model.versions[k - 1]
    let rebuilt = Set(previous.filter { !step.shared.contains($0) })
    let before = persistentTree(previous, origins: model.origins[k - 1], top: 34, offset: 0, made: nil, fading: rebuilt)
    let split = before.bottom + 50
    let after = persistentTree(model.versions[k], origins: model.origins[k], top: split + 34, offset: before.nodes.count,
                               made: Set(step.made), fading: nil)
    return (before.nodes + after.nodes, before.edges + after.edges, Int(after.bottom) + 50, split)
}

@View
struct PersistentLab {
    var body: some View {
        let model = persistent
        let playback = model.playback
        let k = playback.k
        let steps = model.steps
        let last = k > 0 ? steps[k - 1] : nil
        let drawing = persistentDrawing(model, k: k)
        let version = model.versions[k]

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your elements and edits")) {
                label(.class("field"), .for("persistent-elements")) {
                    "Version 0's elements "
                    input(.id("persistent-elements"), .type(.text), .value(model.elementsInput), .custom(name: "maxlength", value: "100"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in persistent.set(elements: event.targetValue ?? "") }
                }
                label(.class("field"), .for("persistent-edits")) {
                    "+x inserts x, -x removes it, each making the next version "
                    input(.id("persistent-edits"), .type(.text), .value(model.editsInput), .custom(name: "maxlength", value: "100"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in persistent.set(edits: event.targetValue ?? "") }
                }
            }
            section(.class("lab"), .custom(name: "aria-label", value: "The versions")) {
                div(.class("panel stage")) {
                    span(.class("label")) { k == 0 ? "Version 0" : "Version \(k - 1), above, and version \(k), below" }
                    if model.versions[k - (k > 0 ? 1 : 0)].isEmpty && version.isEmpty {
                        p(.class("empty")) { "Type some elements to build version 0 from." }
                    } else {
                        GraphCanvas(label: k == 0 ? "Version 0 of the set" : "Versions \(k - 1) and \(k) of the set", width: 680, height: drawing.height, nodes: drawing.nodes, edges: drawing.edges)
                    }
                    div(.class("legend")) {
                        span { i(.class("dot selected")) {}; "a vertex this version made" }
                        span { i(.class("dot done")) {}; "a vertex shared with the version before" }
                    }
                    p(.class("legend")) { "Under each vertex, the version that made it. Faded vertices in the version above are the ones the edit replaced; that version keeps them." }
                    span(.class("label")) { "Every version" }
                    table(.class("suffixes")) {
                        thead {
                            tr {
                                th { "version" }
                                th { "edit" }
                                th { "elements" }
                                th { "vertices made" }
                            }
                        }
                        tbody {
                            for v in model.versions.indices {
                                tr(.class(v == k ? "found" : "")) {
                                    td { "\(v)" }
                                    td { v == 0 ? "built" : persistentEditText(model.edits[v - 1]) }
                                    td(.class("suffix")) { model.versions[v].map(String.init).joined(separator: " ") }
                                    td { v == 0 ? "\(model.versions[0].count)" : "\(steps[v - 1].made.count)" }
                                }
                            }
                        }
                    }
                }
                div(.class("side")) {
                    div(.class("panel"), .custom(name: "aria-live", value: "polite")) {
                        span(.class("label")) { k == steps.count ? "Done after \(steps.count) edits" : "Edit \(k) of \(steps.count)" }
                        p(.class("narration")) {
                            if steps.isEmpty {
                                "Type an edit, such as +7 or -3."
                            } else if let last {
                                describePersistent(last, version: k)
                            } else {
                                "Each edit makes a new version and leaves the old one as it was. The new version makes vertices only on the path to the change and points at the old version’s vertices for everything else."
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "This version" }
                        div(.class("stat")) {
                            div {
                                span(.class("num")) { "\(version.count)" }
                                "elements"
                            }
                            div(.class("good")) {
                                span(.class("num")) { "\(last?.made.count ?? version.count)" }
                                "vertices made"
                            }
                            div {
                                span(.class("num")) { "\(last?.shared.count ?? 0)" }
                                "shared"
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
                    marbles: steps.indices.map { i in
                        Marble(kind: persistentMarbleKind(steps[i].edit), radius: 9, letter: "\(i + 1)", title: describePersistent(steps[i], version: i + 1))
                    },
                    legend: [
                        (Marble(kind: "m-green", radius: 6), "insert"),
                        (Marble(kind: "m-red", radius: 6), "remove"),
                    ])
            }
        }
    }
}

func persistentMarbleKind(_ edit: PersistentEdit) -> String {
    switch edit {
    case .insert: "m-green"
    case .remove: "m-red"
    }
}

func persistentEditText(_ edit: PersistentEdit) -> String {
    switch edit {
    case .insert(let element): "insert \(element)"
    case .remove(let element): "remove \(element)"
    }
}

/// Swift source for an edit, as the code panel's `edits` binding spells it.
func persistentEditCode(_ edit: PersistentEdit) -> String {
    switch edit {
    case .insert(let element): ".insert(\(element))"
    case .remove(let element): ".remove(\(element))"
    }
}

@View
struct PersistentCodePanel {
    var body: some View {
        let model = persistent
        let latest = model.versions.last ?? PersistentTreeSet()
        CodePanel(
            snippets: [
                .persistentImports,
                Snippet(lines: [
                    "let elements = [\(persistentElements(model.elementsInput).map(String.init).joined(separator: ", "))]",
                    "let edits: [PersistentEdit] = [\(model.edits.map(persistentEditCode).joined(separator: ", "))]",
                ]),
                .persistentRun, .persistentShape,
            ],
            results: ["[\(latest.map(String.init).joined(separator: ", "))]", persistentHeight(latest)])
    }
}

func persistentHeight(_ version: PersistentTreeSet<Int>) -> String {
    BinaryTree(version).map { "\($0.height)" } ?? "nil"
}

enum PersistentPage {
    static func mount() {
        mountView(PersistentLab(), in: "app")
        mountView(PersistentCodePanel(), in: "code")
    }
}
