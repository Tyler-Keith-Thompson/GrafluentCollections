import ElementaryUI
import Reactivity
import SpatialTrees
import Trees

/// An axis-aligned rectangle of the plane.
struct PlaneBox: Hashable {
    var lower: SIMD2<Double>
    var upper: SIMD2<Double>

    func intersects(_ other: BoundingBox<SIMD2<Double>>) -> Bool {
        lower.x <= other.upper.x && other.lower.x <= upper.x && lower.y <= other.upper.y && other.lower.y <= upper.y
    }

    /// The distance from `point` to the nearest point of the box: 0 inside it.
    func distance(to point: SIMD2<Double>) -> Double {
        let dx = max(lower.x - point.x, 0, point.x - upper.x)
        let dy = max(lower.y - point.y, 0, point.y - upper.y)
        return (dx * dx + dy * dy).squareRoot()
    }
}

func planeDistance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
    let d = a - b
    return (d.x * d.x + d.y * d.y).squareRoot()
}

/// A k-d tree's splits: each vertex's point index, the axis it splits on, and the region it
/// splits, from `BinaryTree(tree)` and the points.
struct KDSplit {
    var vertex: Int
    var axis: Int
    var region: PlaneBox
}

func kdSplits(_ shape: BinaryTree<Int>?, _ points: [SIMD2<Double>]) -> [Int: KDSplit] {
    guard let shape else { return [:] }
    var splits: [Int: KDSplit] = [:]
    var stack = [(shape.root, PlaneBox(lower: [0, 0], upper: [100, 100]))]
    while let (vertex, region) = stack.popLast() {
        let axis = shape.depth(of: vertex) % 2
        splits[vertex] = KDSplit(vertex: vertex, axis: axis, region: region)
        let cut = points[vertex][axis]
        var below = region, above = region
        below.upper[axis] = cut
        above.lower[axis] = cut
        if let left = shape.left(of: vertex) { stack.append((left, below)) }
        if let right = shape.right(of: vertex) { stack.append((right, above)) }
    }
    return splits
}

/// The points a k-d tree search examines, and the subtrees it skips: a nearest search goes to the
/// query's side of each split first and crosses only when the splitting line is closer than the
/// best found; a box search enters only regions that meet the box.
func kdSearch(_ query: SpatialQuery, _ shape: BinaryTree<Int>?, _ points: [SIMD2<Double>], _ splits: [Int: KDSplit]) -> (visited: [Int], pruned: [Int]) {
    guard let shape else { return ([], []) }
    var visited: [Int] = [], pruned: [Int] = []
    var best = Double.infinity
    func nearest(_ vertex: Int?, _ spot: SIMD2<Double>) {
        guard let vertex else { return }
        visited.append(vertex)
        best = min(best, planeDistance(points[vertex], spot))
        let axis = splits[vertex]!.axis
        let gap = spot[axis] - points[vertex][axis]
        let (near, far) = gap < 0 ? (shape.left(of: vertex), shape.right(of: vertex)) : (shape.right(of: vertex), shape.left(of: vertex))
        nearest(near, spot)
        if let far {
            if abs(gap) < best { nearest(far, spot) } else { pruned.append(far) }
        }
    }
    func inside(_ vertex: Int?, _ box: BoundingBox<SIMD2<Double>>) {
        guard let vertex else { return }
        guard splits[vertex]!.region.intersects(box) else {
            pruned.append(vertex)
            return
        }
        visited.append(vertex)
        inside(shape.left(of: vertex), box)
        inside(shape.right(of: vertex), box)
    }
    switch query {
    case .nearest(let spot): nearest(shape.root, spot)
    case .box(let box): inside(shape.root, box)
    }
    return (visited, pruned)
}

/// Each quadtree cell's region, from `RootedTree(tree)`: a split cell's children are its
/// quadrants, bit 0 for the upper x half and bit 1 for the upper y half.
func quadRegions(_ cells: RootedTree<Int>) -> [Int: PlaneBox] {
    var regions = [cells.root: PlaneBox(lower: [0, 0], upper: [100, 100])]
    var stack = [cells.root]
    while let cell = stack.popLast() {
        let region = regions[cell]!
        let center = (region.lower + region.upper) / 2
        for (orthant, child) in cells.children(of: cell).enumerated() {
            var box = region
            if orthant & 1 != 0 { box.lower.x = center.x } else { box.upper.x = center.x }
            if orthant & 2 != 0 { box.lower.y = center.y } else { box.upper.y = center.y }
            regions[child] = box
            stack.append(child)
        }
    }
    return regions
}

/// The leaf cell each point lies in: a point on a dividing line goes to the upper side.
func quadLeaf(_ point: SIMD2<Double>, _ cells: RootedTree<Int>, _ regions: [Int: PlaneBox]) -> Int {
    var cell = cells.root
    while true {
        let children = Array(cells.children(of: cell))
        guard !children.isEmpty else { return cell }
        let center = (regions[cell]!.lower + regions[cell]!.upper) / 2
        cell = children[(point.x >= center.x ? 1 : 0) | (point.y >= center.y ? 2 : 0)]
    }
}

/// The cells a quadtree search opens: a nearest search opens cells nearest first and stops once
/// the next is no nearer than the best point found; a box search opens the cells that meet it.
func quadSearch(_ query: SpatialQuery, _ cells: RootedTree<Int>, _ regions: [Int: PlaneBox], _ points: [SIMD2<Double>], _ leaves: [Int]) -> [Int] {
    var opened: [Int] = []
    switch query {
    case .box(let box):
        var stack = [cells.root]
        while let cell = stack.popLast() {
            guard regions[cell]!.intersects(box) else { continue }
            opened.append(cell)
            stack += cells.children(of: cell)
        }
    case .nearest(let spot):
        var queue = [(cells.root, regions[cells.root]!.distance(to: spot))]
        var best = Double.infinity
        while let next = queue.indices.min(by: { queue[$0].1 < queue[$1].1 }) {
            let (cell, distance) = queue.remove(at: next)
            guard distance < best else { break }
            opened.append(cell)
            let children = Array(cells.children(of: cell))
            if children.isEmpty {
                for index in points.indices where leaves[index] == cell {
                    best = min(best, planeDistance(points[index], spot))
                }
            } else {
                queue += children.map { ($0, regions[$0]!.distance(to: spot)) }
            }
        }
    }
    return opened
}

/// What one query did in each structure.
struct SpatialStep {
    var query: SpatialQuery
    var kdVisited: [Int]
    var kdPruned: [Int]
    var kdFound: [Int]
    var quadOpened: [Int]
    var quadFound: [Int]
}

@Reactive
final class KDTreeModel {
    var pointsText = "12,18 30,72 44,40 58,86 71,22 86,58 22,48 64,62 90,90 8,88 52,10 78,40 36,8 95,12"
    var text = "?60,50 ?20,30 30,30:70,70 ?92,80 5,60:40,95"
    var points: [SIMD2<Double>] = []
    var queries: [SpatialQuery] = []
    var kdShape: BinaryTree<Int>? = nil
    var splits: [Int: KDSplit] = [:]
    var cells: RootedTree<Int> = spatialShapes([]).quad
    var regions: [Int: PlaneBox] = [:]
    var steps: [SpatialStep] = []
    @ReactiveIgnored let playback = Playback(millisecondsPerStep: 1_400, scrubID: "scrub-kdtree")

    init() {
        run()
    }

    func set(points newText: String) {
        pointsText = String(newText.prefix(200))
        run()
    }

    func set(text newText: String) {
        text = String(newText.prefix(160))
        run()
    }

    func run() {
        points = spatialPoints(pointsText)
        queries = spatialQueries(text)
        let shapes = spatialShapes(points)
        kdShape = shapes.kd
        cells = shapes.quad
        splits = kdSplits(kdShape, points)
        regions = quadRegions(cells)
        let leaves = points.map { quadLeaf($0, cells, regions) }
        let answers = spatialAnswers(points, queries)
        steps = queries.indices.map { i in
            let kd = kdSearch(queries[i], kdShape, points, splits)
            return SpatialStep(query: queries[i], kdVisited: kd.visited, kdPruned: kd.pruned, kdFound: answers.kd[i],
                               quadOpened: quadSearch(queries[i], cells, regions, points, leaves), quadFound: answers.quad[i])
        }
        playback.reset(count: steps.count)
    }
}

let kdTree = KDTreeModel()

func pointText(_ point: SIMD2<Double>) -> String {
    func number(_ value: Double) -> String { value == value.rounded() ? "\(Int(value))" : "\(value)" }
    return "(\(number(point.x)), \(number(point.y)))"
}

func describeSpatial(_ step: SpatialStep, points: [SIMD2<Double>], cellCount: Int) -> String {
    let quad = "The quadtree opened \(step.quadOpened.count) of its \(cellCount) cells."
    switch step.query {
    case .nearest(let spot):
        let found = step.kdFound.first.map { pointText(points[$0]) } ?? "nothing"
        return "Nearest to \(pointText(spot)): \(found). The k-d tree examined \(step.kdVisited.count) of \(points.count) points. It goes to the query’s side of each split first, and crosses a split line only when the line is nearer than the best point so far. \(quad) It opens cells nearest first and stops when the next cell is no nearer than the best point."
    case .box(let box):
        let found = step.kdFound.sorted().map { pointText(points[$0]) }
        let list = found.isEmpty ? "no points" : found.joined(separator: ", ")
        return "Points in the box from \(pointText(box.lower)) to \(pointText(box.upper)): \(list). The k-d tree examined \(step.kdVisited.count) of \(points.count) points and skipped \(step.kdPruned.count) \(step.kdPruned.count == 1 ? "region" : "regions") the box misses. \(quad)"
    }
}

/// The two structures side by side on the same square: the k-d tree's split lines, and the
/// quadtree's cells, with the points, the query, and what each search touched.
@View
struct SpatialCanvas {
    var points: [SIMD2<Double>]
    var splits: [Int: KDSplit]
    var regions: [Int: PlaneBox]
    var leaves: Set<Int>
    var step: SpatialStep?

    var body: some View {
        let size = 300.0
        let kdVisited = Set(step?.kdVisited ?? []), opened = Set(step?.quadOpened ?? [])
        let kdFound = Set(step?.kdFound ?? []), quadFound = Set(step?.quadFound ?? [])
        // Everything under a skipped vertex is skipped too: shade the skipped vertices' regions.
        let skipped = (step?.kdPruned ?? []).compactMap { splits[$0]?.region }
        let panels: [(left: Double, title: String)] = [(20, "k-d tree"), (360, "quadtree, 2 points a cell")]
        let spot: SIMD2<Double>? = if case .nearest(let spot) = step?.query { spot } else { nil }
        let box: BoundingBox<SIMD2<Double>>? = if case .box(let box) = step?.query { box } else { nil }
        let reach = spot.flatMap { spot in step?.kdFound.first.map { planeDistance(points[$0], spot) * 3 } } ?? 0
        SVG.svg(.class("canvas plane"), .viewBox(0, 0, 680, 360), .custom(name: "role", value: "img"),
                .custom(name: "aria-label", value: "A k-d tree and a quadtree over the same \(points.count) points")) {
            for panel in panels {
                SVG.text(.x(.init(panel.left)), .y(22), .class("ptitle")) { panel.title }
                SVG.rect(.x(.init(panel.left)), .y(40), .width(.init(size)), .height(.init(size)), .class("frame")) {}
            }
            for region in skipped {
                SVG.rect(.x(.init(20 + region.lower.x * 3)), .y(.init(340 - region.upper.y * 3)),
                         .width(.init((region.upper.x - region.lower.x) * 3)), .height(.init((region.upper.y - region.lower.y) * 3)), .class("skipped")) {}
            }
            for (cell, region) in regions.sorted(by: { $0.key < $1.key }) {
                SVG.rect(.x(.init(360 + region.lower.x * 3)), .y(.init(340 - region.upper.y * 3)),
                         .width(.init((region.upper.x - region.lower.x) * 3)), .height(.init((region.upper.y - region.lower.y) * 3)),
                         .class(opened.contains(cell) && leaves.contains(cell) ? "cell opened" : "cell")) {}
            }
            for split in splits.values.sorted(by: { $0.vertex < $1.vertex }) {
                let cut = points[split.vertex][split.axis]
                let line = split.axis == 0
                    ? (x1: cut, y1: split.region.lower.y, x2: cut, y2: split.region.upper.y)
                    : (x1: split.region.lower.x, y1: cut, x2: split.region.upper.x, y2: cut)
                SVG.line(.x1(.init(20 + line.x1 * 3)), .y1(.init(340 - line.y1 * 3)), .x2(.init(20 + line.x2 * 3)), .y2(.init(340 - line.y2 * 3)),
                         .class(kdVisited.contains(split.vertex) ? "split seen" : "split")) {}
            }
            if let spot {
                for left in [20.0, 360.0] {
                    SVG.circle(.cx(.init(left + spot.x * 3)), .cy(.init(340 - spot.y * 3)), .r(.init(reach)), .class("reach")) {}
                    SVG.circle(.cx(.init(left + spot.x * 3)), .cy(.init(340 - spot.y * 3)), .r(5), .class("spot")) {}
                }
            }
            if let box {
                for left in [20.0, 360.0] {
                    SVG.rect(.x(.init(left + box.lower.x * 3)), .y(.init(340 - box.upper.y * 3)),
                             .width(.init((box.upper.x - box.lower.x) * 3)), .height(.init((box.upper.y - box.lower.y) * 3)), .class("qbox")) {}
                }
            }
            for (index, point) in points.enumerated() {
                SVG.circle(.cx(.init(20 + point.x * 3)), .cy(.init(340 - point.y * 3)), .r(5),
                           .class(kdFound.contains(index) ? "pt found" : kdVisited.contains(index) ? "pt seen" : "pt")) {}
                SVG.circle(.cx(.init(360 + point.x * 3)), .cy(.init(340 - point.y * 3)), .r(5), .class(quadFound.contains(index) ? "pt found" : "pt")) {}
            }
        }
    }
}

@View
struct KDTreeLab {
    var body: some View {
        let model = kdTree
        let playback = model.playback
        let k = playback.k
        let steps = model.steps
        let last = k > 0 ? steps[k - 1] : nil
        let cellCount = model.cells.vertexCount

        div {
            section(.class("panel controls"), .custom(name: "aria-label", value: "Your points and queries")) {
                label(.class("field"), .for("kdtree-points")) {
                    "Points x,y from 0 to 100 "
                    input(.id("kdtree-points"), .type(.text), .value(model.pointsText), .custom(name: "maxlength", value: "200"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in kdTree.set(points: event.targetValue ?? "") }
                }
                label(.class("field"), .for("kdtree-text")) {
                    "?x,y for the nearest point, x1,y1:x2,y2 for a box "
                    input(.id("kdtree-text"), .type(.text), .value(model.text), .custom(name: "maxlength", value: "160"),
                          .custom(name: "spellcheck", value: "false"), .custom(name: "autocomplete", value: "off"))
                        .onInput { event in kdTree.set(text: event.targetValue ?? "") }
                }
            }
            section(.class("lab"), .custom(name: "aria-label", value: "The k-d tree and the quadtree")) {
                div(.class("panel stage")) {
                    if model.points.isEmpty {
                        p(.class("empty")) { "Type some points, such as 20,30 70,60." }
                    } else {
                        SpatialCanvas(points: model.points, splits: model.splits, regions: model.regions,
                                      leaves: Set(model.regions.keys.filter { model.cells.children(of: $0).isEmpty }), step: last)
                    }
                    div(.class("legend")) {
                        span { i(.class("dot selected")) {}; "examined, or a cell opened" }
                        span { i(.class("dot current")) {}; "the answer" }
                    }
                    p(.class("legend")) { "Left, each point splits its region at the median, across then up and down in turn; regions a search skipped are shaded. Right, a cell splits into quarters when it holds more than 2 points; the cells a search opened are shaded." }
                }
                div(.class("side")) {
                    div(.class("panel"), .custom(name: "aria-live", value: "polite")) {
                        span(.class("label")) { k == steps.count ? "Done after \(steps.count) queries" : "Query \(k) of \(steps.count)" }
                        p(.class("narration")) {
                            if steps.isEmpty {
                                "Type a query, such as ?50,50 or 20,20:60,60."
                            } else if let last {
                                describeSpatial(last, points: model.points, cellCount: cellCount)
                            } else {
                                "Both structures cut the square into regions so a search can ignore most of it. The k-d tree cuts at a point, the median of its region, alternating directions; the quadtree cuts any crowded cell into four equal quarters."
                            }
                        }
                    }
                    div(.class("panel")) {
                        span(.class("label")) { "This query" }
                        div(.class("stat")) {
                            div {
                                span(.class("num")) { "\(model.points.count)" }
                                "points"
                            }
                            div(.class("good")) {
                                span(.class("num")) { "\(last?.kdVisited.count ?? 0)" }
                                "examined by the k-d tree"
                            }
                            div {
                                span(.class("num")) { "\(last?.quadOpened.count ?? 0)" }
                                "quadtree cells opened"
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
                        switch step.query {
                        case .nearest: Marble(kind: "m-green", radius: 9, letter: "?", title: describeSpatial(step, points: model.points, cellCount: cellCount))
                        case .box: Marble(kind: "m-blue", radius: 9, letter: "□", title: describeSpatial(step, points: model.points, cellCount: cellCount))
                        }
                    },
                    legend: [
                        (Marble(kind: "m-green", radius: 6), "nearest point"),
                        (Marble(kind: "m-blue", radius: 6), "box"),
                    ])
            }
        }
    }
}

/// Swift source for a query, as the code panel's `queries` binding spells it.
func spatialQueryCode(_ query: SpatialQuery) -> String {
    func point(_ p: SIMD2<Double>) -> String { "[\(Int(p.x)), \(Int(p.y))]" }
    switch query {
    case .nearest(let spot): return ".nearest(\(point(spot)))"
    case .box(let box): return ".box(BoundingBox(lower: \(point(box.lower)), upper: \(point(box.upper))))"
    }
}

@View
struct KDTreeCodePanel {
    var body: some View {
        let model = kdTree
        let points = model.points.map { "[\(Int($0.x)), \(Int($0.y))]" }.joined(separator: ", ")
        CodePanel(
            snippets: [
                .kdtreeImports,
                Snippet(lines: [
                    "let points: [SIMD2<Double>] = [\(points)]",
                    "let queries: [SpatialQuery] = [\(model.queries.map(spatialQueryCode).joined(separator: ", "))]",
                ]),
                .kdtreeRun, .kdtreeShapes,
            ],
            results: ["\(model.cells.vertexCount)", model.kdShape.map { "\($0.height)" } ?? "nil"])
    }
}

enum KDTreePage {
    static func mount() {
        mountView(KDTreeLab(), in: "app")
        mountView(KDTreeCodePanel(), in: "code")
    }
}
