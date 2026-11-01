// PersistentTreeSet and PersistentTreeDictionary against Sets and Dictionaries, keeping every
// version: each operation makes a new version from an earlier one, and at the end every version
// must still equal the model it was made with, so a later edit that changed an earlier version's
// shared vertices is caught. The set operations combine two versions.

import FuzzSupport
import PersistentTrees

@main
enum FuzzPersistentTrees {
    static func main() { runFuzzer(fuzz) }

    static func fuzz(_ input: inout FuzzInput) {
        if input.int(below: 2) == 0 { sets(&input) } else { dictionaries(&input) }
    }

    static func sets(_ input: inout FuzzInput) {
        var versions = [PersistentTreeSet<Int>()]
        var models = [Set<Int>()]
        while !input.isEmpty {
            let source = input.int(below: versions.count)
            let other = input.int(below: versions.count)
            let key = input.int(below: 48)
            var version = versions[source], model = models[source]
            switch input.int(below: 8) {
            case 0, 1, 2:
                version = version.inserting(key)
                model.insert(key)
            case 3:
                version = version.removing(key)
                model.remove(key)
            case 4:
                version = version.union(versions[other])
                model.formUnion(models[other])
            case 5:
                version = version.intersection(versions[other])
                model.formIntersection(models[other])
            case 6:
                version = version.subtracting(versions[other])
                model.subtract(models[other])
            default:
                version = version.symmetricDifference(versions[other])
                model.formSymmetricDifference(models[other])
            }
            check(version.isSubset(of: versions[other]) == model.isSubset(of: models[other]), "isSubset")
            check(version.contains(key) == model.contains(key), "contains(\(key))")
            check(version.lowerBound(key) == model.filter { $0 < key }.count, "lowerBound(\(key))")
            versions.append(version)
            models.append(model)
        }
        for (version, model) in zip(versions, models) {
            check(Array(version) == model.sorted(), "a version is \(Array(version)), its model \(model.sorted())")
            check(version.count == model.count, "count")
        }
    }

    static func dictionaries(_ input: inout FuzzInput) {
        var versions = [PersistentTreeDictionary<Int, Int>()]
        var models = [[Int: Int]()]
        var serial = 0
        while !input.isEmpty {
            let source = input.int(below: versions.count)
            let other = input.int(below: versions.count)
            let key = input.int(below: 32)
            serial += 1
            var version = versions[source], model = models[source]
            switch input.int(below: 4) {
            case 0, 1:
                version = version.updatingValue(serial, forKey: key)
                model[key] = serial
            case 2:
                version = version.removingValue(forKey: key)
                model[key] = nil
            default:
                version = version.merging(versions[other]) { $0 &+ $1 }
                model.merge(models[other]) { $0 &+ $1 }
            }
            check(version[key] == model[key], "subscript(\(key))")
            versions.append(version)
            models.append(model)
        }
        for (version, model) in zip(versions, models) {
            check(version.map(\.key) == model.keys.sorted(), "keys")
            check(version.map(\.value) == model.keys.sorted().map { model[$0]! }, "values")
        }
    }
}
