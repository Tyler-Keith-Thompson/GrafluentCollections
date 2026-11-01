import Caches
import ElementaryUI
import Reactivity

/// What one operation did, with the cache's entries before and after it.
struct CacheStep {
    var operation: CacheOperation
    var outcome: CacheOutcome
    var hadKey: Bool
}

@Reactive
final class CacheModel {
    var capacityInput = "3"
    var operationsInput = "a=1 b=2 c=3 a? d=4 b? c? e=5 a? f=6 d? e=7"
    var capacity = 3
    var operations: [CacheOperation] = []
    var history: [LRUCache<String, Int>] = [LRUCache(capacity: 3)]
    var steps: [CacheStep] = []
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_200, scrubID: "scrub-lru")

    init() {
        run()
    }

    func set(capacity newText: String) {
        capacityInput = String(newText.prefix(2))
        run()
    }

    func set(operations newText: String) {
        operationsInput = String(newText.prefix(160))
        run()
    }

    func run() {
        capacity = min(max(Int(capacityInput.filter(\.isNumber)) ?? 3, 1), 8)
        operations = cacheOperations(operationsInput)
        let run = cacheHistory(capacity: capacity, operations)
        history = run.caches
        steps = operations.indices.map { i in
            let key = switch operations[i] {
            case .insert(let key, _), .lookup(let key): key
            }
            return CacheStep(operation: operations[i], outcome: run.outcomes[i], hadKey: history[i].contains(key))
        }
        playback.reset(count: steps.count)
    }
}

let cache = CacheModel()

func cacheKey(_ operation: CacheOperation) -> String {
    switch operation {
    case .insert(let key, _), .lookup(let key): key
    }
}

func describeCache(_ step: CacheStep, capacity: Int) -> String {
    switch (step.operation, step.outcome) {
    case (.lookup(let key), .found(let value?)):
        return "Look up \(key): a hit, \(value). Reading it makes \(key) the most recent entry, so it moves to the front, and the others keep their order."
    case (.lookup(let key), _):
        return "Look up \(key): a miss. The cache doesn’t hold it, so nothing moves. A program would now fetch the value the slow way and store it."
    case (.insert(let key, let value), .stored(let evicted)):
        if step.hadKey {
            return "Store \(value) for \(key): \(key) is already there, so its value is replaced and it moves to the front. Nothing is evicted."
        }
        if let evicted {
            return "Store \(value) for \(key): the cache already holds \(capacity), its capacity, so the least recently used entry, \(evicted.key) = \(evicted.value), is evicted, and \(key) goes in at the front."
        }
        return "Store \(value) for \(key): there is room, so \(key) goes in at the front as the most recent entry."
    default:
        return ""
    }
}

/// The entries in a row from most recent at the left to least recent, linked by the recency
/// path, and the entry an insert evicted after a gap at the right.
func cacheDrawing(_ current: LRUCache<String, Int>, capacity: Int, step: CacheStep?) -> (nodes: [CanvasNode], edges: [CanvasEdge]) {
    let entries = Array(current)
    let slots = capacity + 1
    let gap = min(130.0, 600.0 / Double(max(slots, 1)))
    let left = 340 - gap * Double(slots - 1) / 2
    let touched = step.map { cacheKey($0.operation) }
    let hit: Bool
    switch step?.outcome {
    case .found(let value): hit = value != nil
    default: hit = step != nil
    }
    var nodes = entries.enumerated().map { rank, entry in
        let classes = entry.key == touched && hit ? " selected" : ""
        return CanvasNode(x: left + gap * Double(rank), y: 60, name: entry.key, badge: "\(entry.value)",
                          note: rank == 0 ? "most recent" : rank == entries.count - 1 ? "least" : "", radius: 26, classes: classes, nameAbove: true)
    }
    nodes += (entries.count ..< capacity).map { rank in
        CanvasNode(x: left + gap * Double(rank), y: 60, name: "", note: "free", radius: 26, classes: " free", nameAbove: true)
    }
    var edges = cacheLinks(current).map { CanvasEdge(from: $0.from, to: $0.to, directed: true) }
    if case .stored(let evicted?)? = step?.outcome {
        nodes.append(CanvasNode(x: left + gap * Double(capacity), y: 60, name: evicted.key, badge: "\(evicted.value)", note: "evicted",
                                radius: 26, classes: " current", nameAbove: true))
        if !entries.isEmpty {
            edges.append(CanvasEdge(from: entries.count - 1, to: nodes.count - 1, directed: true, classes: "route"))
        }
    }
    return (nodes, edges)
}

func cacheMarbleKind(_ step: CacheStep) -> String {
    switch step.outcome {
    case .found(let value): value == nil ? "m-red" : "m-green"
    case .stored(let evicted): evicted == nil ? "m-blue" : "m-red"
    }
}

@View
struct CacheLab {
    var body: some View {
        let model = cache
        let playback = model.playback
        let k = playback.k
        let steps = model.steps
        let last = k > 0 ? steps[k - 1] : nil
        let current = model.history[k]
        let drawing = cacheDrawing(current, capacity: model.capacity, step: last)
        let done = steps.prefix(k)
        let hits = done.filter { if case .found(let value) = $0.outcome { value != nil } else { false } }.count
        let misses = done.filter { if case .found(nil) = $0.outcome { true } else { false } }.count
        let evictions = done.filter { if case .stored(let evicted) = $0.outcome { evicted != nil } else { false } }.count

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your capacity and operations")) {
                label(.class("field"), .for("lru-capacity")) {
                    "Capacity, 1 to 8 "
                    input(.id("lru-capacity"), .type(.text), .value(model.capacityInput), .custom(name: "maxlength", value: "2"),
                          .custom(name: "inputmode", value: "numeric"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in cache.set(capacity: event.targetValue ?? "") }
                }
                label(.class("field"), .for("lru-operations")) {
                    "key=value stores, key? looks up "
                    input(.id("lru-operations"), .type(.text), .value(model.operationsInput), .custom(name: "maxlength", value: "160"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in cache.set(operations: event.targetValue ?? "") }
                }
            }
            section(.class("lab"), .custom(name: "aria-label", value: "The cache")) {
                div(.class("panel stage")) {
                    span(.class("label")) { "The entries, most recent first" }
                    if current.isEmpty && last == nil {
                        p(.class("empty")) { "The cache starts empty. Step to store the first entry." }
                    } else {
                        GraphCanvas(label: "The cache's \(current.count) entries from most to least recent", width: 680, height: 140, nodes: drawing.nodes, edges: drawing.edges)
                    }
                    div(.class("legend")) {
                        span { i(.class("dot selected")) {}; "the entry this step stored or read" }
                        span { i(.class("dot current")) {}; "the entry evicted" }
                    }
                    p(.class("legend")) { "Above each entry its key; inside, its value. The arrows run from each entry to the next less recently used, the path RootedTree(cache) gives." }
                }
                div(.class("side")) {
                    div(.class("panel"), .custom(name: "aria-live", value: "polite")) {
                        span(.class("label")) { k == steps.count ? "Done after \(steps.count) operations" : "Operation \(k) of \(steps.count)" }
                        p(.class("narration")) {
                            if steps.isEmpty {
                                "Type an operation, such as a=1 or a?."
                            } else if let last {
                                describeCache(last, capacity: model.capacity)
                            } else {
                                "A cache with room for \(model.capacity) entries. Every store and every hit moves its entry to the front; when a store finds the cache full, the entry at the back, the least recently used, goes."
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "So far" }
                        div(.class("stat")) {
                            div(.class("good")) {
                                span(.class("num")) { "\(hits)" }
                                "hits"
                            }
                            div {
                                span(.class("num")) { "\(misses)" }
                                "misses"
                            }
                            div(.class("bad")) {
                                span(.class("num")) { "\(evictions)" }
                                "evictions"
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
                        Marble(kind: cacheMarbleKind(step), radius: 9, letter: String(cacheKey(step.operation).prefix(1)), title: describeCache(step, capacity: model.capacity))
                    },
                    legend: [
                        (Marble(kind: "m-blue", radius: 6), "store"),
                        (Marble(kind: "m-green", radius: 6), "hit"),
                        (Marble(kind: "m-red", radius: 6), "miss or eviction"),
                    ])
            }
        }
    }
}

/// Swift source for an operation, as the code panel's `operations` binding spells it.
func cacheOperationCode(_ operation: CacheOperation) -> String {
    switch operation {
    case .insert(let key, let value): ".insert(\"\(key)\", value: \(value))"
    case .lookup(let key): ".lookup(\"\(key)\")"
    }
}

@View
struct CacheCodePanel {
    var body: some View {
        let model = cache
        let last = model.history.last ?? LRUCache(capacity: 0)
        CodePanel(
            snippets: [
                .lruImports,
                Snippet(lines: [
                    "let capacity = \(model.capacity)",
                    "let operations: [CacheOperation] = [\(model.operations.map(cacheOperationCode).joined(separator: ", "))]",
                ]),
                .lruRun, .lruShape,
            ],
            results: ["[\(last.map { "\"\($0.key)\"" }.joined(separator: ", "))]", last.isEmpty ? "nil" : "\(last.count - 1)"])
    }
}

enum CachePage {
    static func mount() {
        mountView(CacheLab(), in: "app")
        mountView(CacheCodePanel(), in: "code")
    }
}
