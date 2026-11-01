// KDTree, Quadtree and Octree on points of a coarse grid (so points coincide and lie on cell
// boundaries) against brute force: box, radius and nearest searches after every insertion and
// removal.

import FuzzSupport
import SpatialTrees

@main
enum FuzzSpatialTrees {
    static func main() { runFuzzer(fuzz) }

    static func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d = a - b
        return (d * d).sum()
    }

    static func fuzz(_ input: inout FuzzInput) {
        let capacity = 1 + input.int(below: 4)
        var tree = Quadtree<Int>(bounds: BoundingBox(lower: [0, 0], upper: [8, 8]), bucketCapacity: capacity)
        var space = Octree<Int>(bounds: BoundingBox(lower: [0, 0, 0], upper: [8, 8, 8]), bucketCapacity: capacity)
        var model: [(point: SIMD2<Double>, element: Int)] = []
        var serial = 0
        while !input.isEmpty {
            let point = SIMD2<Double>(Double(input.int(below: 9)), Double(input.int(below: 9)))
            let lifted = SIMD3<Double>(point.x, point.y, Double(serial % 3))
            serial += 1
            if input.int(below: 3) == 0, let index = model.firstIndex(where: { $0.point == point }) {
                let element = model.remove(at: index).element
                check(tree.remove(element, at: point) == element, "Quadtree.remove")
                check(space.remove(element, at: SIMD3(point.x, point.y, Double(element % 3))) == element, "Octree.remove")
            } else {
                tree.insert(serial - 1, at: point)
                space.insert(serial - 1, at: lifted)
                model.append((point, serial - 1))
            }
            let query = SIMD2<Double>(Double(input.int(below: 17)) / 2, Double(input.int(below: 17)) / 2)
            let radius = Double(input.int(below: 5))
            let within = Set(model.filter { distance($0.point, query) <= radius * radius }.map(\.element))
            check(Set(tree.items(within: radius, of: query).map(\.element)) == within, "Quadtree.items(within:of:)")
            let box = BoundingBox(lower: query, upper: query + [radius, radius / 2])
            let inBox = Set(model.filter { box.contains($0.point) }.map(\.element))
            check(Set(tree.items(in: box).map(\.element)) == inBox, "Quadtree.items(in:)")
            let distances = model.map { distance($0.point, query) }.sorted()
            let wanted = input.int(below: 4)
            check(tree.nearest(to: query, count: wanted).map { distance($0.point, query) } == Array(distances.prefix(wanted)), "Quadtree.nearest(to:count:)")
            check(space.count == model.count && tree.count == model.count, "count")

            let kd = KDTree(model.map(\.point))
            check(Set(kd.indices(within: radius, of: query)) == Set(model.indices.filter { distance(model[$0].point, query) <= radius * radius }), "KDTree.indices(within:of:)")
            check(Set(kd.indices(in: box)) == Set(model.indices.filter { box.contains(model[$0].point) }), "KDTree.indices(in:)")
            check(kd.nearestIndices(to: query, count: wanted).map { distance(model[$0].point, query) } == Array(distances.prefix(wanted)), "KDTree.nearestIndices(to:count:)")
        }
    }
}
