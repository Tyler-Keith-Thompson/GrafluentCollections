// The DocC articles' examples, so the articles cannot drift from the code.

import GrafluentCollections
import GraphDrawing
import GraphFormats
import Testing
import Trees

@Suite("Article examples")
struct ArticleExamplesTests {
    // MARK: - GrafluentCollections (the landing page)

    @Test("Landing: a plain spelling traps where its checked spelling throws")
    func checkedSpelling() {
        let primes: AVLTree = [2, 3, 5, 7]
        let third: Int = 5
        #expect(primes[2] == third)
        #expect(throws: IndexOutOfRange.self) { try primes[checked: 9] }
    }

    @Test("Landing: a copy is a value, and mutating it leaves the original")
    func valueSemantics() {
        let original: BTree = [1, 2, 3]
        var copy = original
        copy.insert(4)
        let originalElements: [Int] = [1, 2, 3]
        let copyElements: [Int] = [1, 2, 3, 4]
        #expect(Array(original) == originalElements)
        #expect(Array(copy) == copyElements)
    }

    // MARK: - Choosing a search tree

    @Test("Choosing a search tree: the sorted sets share one API")
    func sharedAPI() {
        let avl: AVLTree = [40, 10, 30, 20]
        let redBlack: RedBlackTree = [40, 10, 30, 20]
        let bTree: BTree = [40, 10, 30, 20]
        let skipList: SkipList = [40, 10, 30, 20]
        let sorted: [Int] = [10, 20, 30, 40]
        let indexOfThirty: Int = 2
        #expect(Array(avl) == sorted)
        #expect(Array(redBlack) == sorted)
        #expect(Array(bTree) == sorted)
        #expect(Array(skipList) == sorted)
        #expect(avl.lowerBound(25) == indexOfThirty)
        #expect(bTree.lowerBound(25) == indexOfThirty)
    }

    @Test("Choosing a search tree: a treap splits at an element and joins again")
    func treapSplitAndJoin() throws {
        let numbers: Treap = [8, 3, 5, 1, 9]
        let parts = numbers.split(at: 5)
        let lower: [Int] = [1, 3]
        let upper: [Int] = [5, 8, 9]
        #expect(Array(parts.lower) == lower)
        #expect(Array(parts.upper) == upper)
        var rejoined = parts.lower
        try rejoined.join(parts.upper)
        #expect(rejoined == numbers)
    }

    @Test("Choosing a search tree: a splay tree's access brings an element to the root")
    func splayAccess() {
        var recent: SplayTree = [10, 20, 30, 40, 50]
        let forty: Int? = 40
        #expect(recent.access(40) == forty)
        let shape = BinaryTree(recent)!
        let root: Int = 40
        #expect(shape.root == root)
    }

    @Test("Choosing a search tree: every version of a persistent set stays usable")
    func persistentVersions() {
        let empty = PersistentTreeSet<Int>()
        let one = empty.inserting(5)
        let two = one.inserting(3)
        let three = two.removing(5)
        let oneElements: [Int] = [5]
        let twoElements: [Int] = [3, 5]
        let threeElements: [Int] = [3]
        #expect(Array(one) == oneElements)
        #expect(Array(two) == twoElements)
        #expect(Array(three) == threeElements)
    }

    // MARK: - Tries and suffix structures

    @Test("Tries: a trie dictionary routes by the longest prefix")
    func trieDictionaryRoutes() {
        var routes: TrieDictionary<Character, String> = [:]
        routes["/"] = "home"
        routes["/users"] = "user list"
        let longest: String? = "user list"
        let underU: Int = 1
        #expect(routes.longestPrefix(of: "/users/42")?.value == longest)
        #expect(routes.elements(withPrefix: "/u").count == underU)
    }

    @Test("Tries: a radix tree answers the same queries over shared edges")
    func radixTree() {
        let paths = RadixTree(["/usr/bin", "/usr/lib", "/usr/local/bin"])
        let underL: [String] = ["/usr/lib", "/usr/local/bin"]
        let longest: String? = "/usr/bin"
        #expect(paths.contains("/usr/lib"))
        #expect(paths.elements(withPrefix: "/usr/l").map { String($0) } == underL)
        #expect(paths.longestPrefix(of: "/usr/bin/swift").map { String($0) } == longest)
    }

    @Test("Tries: an Aho–Corasick automaton finds every pattern in one pass")
    func ahoCorasick() {
        let automaton = AhoCorasickAutomaton(patterns: ["he", "she", "his", "hers"])
        let found: [Int] = [1, 0, 3]
        #expect(automaton.matches(in: "ushers").map(\.patternIndex) == found)
    }

    @Test("Suffix structures: a suffix array finds every occurrence")
    func suffixArray() {
        let banana = SuffixArray("banana")
        let positions: [Int] = [3, 1]
        let distinct: Int64 = 15
        #expect(banana.occurrences(of: "ana").map { banana.positions[$0] } == positions)
        #expect(banana.distinctSubstringCount == distinct)
    }

    @Test("Suffix structures: a suffix tree finds a longest common substring")
    func suffixTree() {
        let both = SuffixTree(texts: ["xabxac", "abcabxabcd"])
        let common = SuffixTree<Character>.Occurrence(textIndex: 1, range: 3 ..< 7)
        #expect(both.longestCommonSubstring == common)
    }

    @Test("Suffix structures: a suffix automaton counts occurrences")
    func suffixAutomaton() {
        let automaton = SuffixAutomaton("abcbc")
        let bc: Int = 2
        let cb: Range<Int>? = 2 ..< 4
        #expect(automaton.contains("cbc"))
        #expect(automaton.occurrenceCount(of: "bc") == bc)
        #expect(automaton.firstOccurrence(of: "cb") == cb)
    }

    // MARK: - Decision diagrams

    @Test("Decision diagrams: equal functions are the same function")
    func bddCanonical() {
        var diagram = BinaryDecisionDiagram(variableCount: 3)
        let x0 = diagram.variable(0), x1 = diagram.variable(1), x2 = diagram.variable(2)
        let f = diagram.or(diagram.and(x0, x1), x2)
        let g = diagram.or(x2, diagram.and(x1, x0))
        let five: Double = 5
        #expect(f == g)
        #expect(diagram.satisfyingAssignmentCount(of: f) == five)
    }

    @Test("Decision diagrams: a ZDD holds a family of sets")
    func zddFamily() {
        var diagram = ZeroSuppressedDecisionDiagram(elementCount: 3)
        let f = diagram.family([[0, 1], [1, 2], [2]])
        let three: Double = 3
        #expect(diagram.count(of: f) == three)
        let g = diagram.including(2, in: f)
        let minimal = diagram.family([[2]])
        #expect(diagram.minimalSets(of: g) == minimal)
    }

    // MARK: - Range and spatial trees

    @Test("Range trees: a segment tree combines a range under any monoid")
    func segmentTree() {
        var tree = SegmentTree<Minimum<Int>>([5, 3, 8, 6, 1, 9])
        let before: Int = 3
        let after: Int = 0
        #expect(tree.combined(in: 0 ..< 4) == before)
        tree.update(at: 2, to: 0)
        #expect(tree.combined(in: 0 ..< 4) == after)
    }

    @Test("Range trees: an interval tree finds the intervals at a point")
    func intervalTree() {
        var meetings = IntervalTree<Int, String>()
        meetings.insert(9 ..< 10, value: "stand-up")
        meetings.insert(10 ..< 12, value: "design review")
        meetings.insert(11 ..< 13, value: "lunch")
        let atEleven: [String] = ["design review", "lunch"]
        #expect(meetings.containing(11).map(\.value) == atEleven)
    }

    @Test("Spatial trees: a k-d tree finds the nearest point")
    func kdTree() {
        let tree = KDTree<SIMD2<Double>>([[2, 3], [5, 4], [9, 6], [4, 7], [8, 1], [7, 2]])
        let nearest: Int? = 4
        let inBox: [Int] = [0, 1]
        #expect(tree.nearestIndex(to: [9, 2]) == nearest)
        #expect(tree.indices(in: BoundingBox(lower: [0, 0], upper: [5, 5])) == inBox)
    }

    @Test("Spatial trees: a quadtree takes insertions and finds what is near")
    func quadtree() {
        var map = Quadtree<String>(bounds: BoundingBox(lower: [0, 0], upper: [100, 100]))
        map.insert("café", at: [10, 20])
        map.insert("library", at: [12, 22])
        map.insert("station", at: [80, 75])
        let nearest: String? = "café"
        let nearby: Int = 2
        #expect(map.nearest(to: [11, 19])?.element == nearest)
        #expect(map.items(within: 5, of: [11, 21]).count == nearby)
    }

    // MARK: - Seeing a collection as a graph

    @Test("Graphs: a search tree's shape written as Mermaid")
    func mermaid() throws {
        let primes: AVLTree = [2, 3, 5, 7, 11, 13, 17]
        let shape = Arborescence(BinaryTree(primes)!)
        var text = ""
        try shape.writeMermaid(to: &text)
        let expected: String = """
            flowchart TD
                7
                3
                13
                2
                5
                11
                17
                7 --> 3
                7 --> 13
                3 --> 2
                3 --> 5
                13 --> 11
                13 --> 17

            """
        #expect(text == expected)
    }

    @Test("Graphs: a search tree's shape drawn by Reingold and Tilford's layout")
    func drawing() {
        let primes: AVLTree = [2, 3, 5, 7, 11, 13, 17]
        let shape = RootedTree(Arborescence(BinaryTree(primes)!))
        let drawing = shape.reingoldTilfordLayout()
        let root: SIMD2<Double> = [0, 0]
        let three: SIMD2<Double> = [-1, 1]
        let seventeen: SIMD2<Double> = [1.5, 2]
        #expect(drawing.position(of: 7) == root)
        #expect(drawing.position(of: 3) == three)
        #expect(drawing.position(of: 17) == seventeen)
    }

    @Test("Graphs: a conversion is a snapshot, and the collection's later edits don't reach it")
    func snapshot() {
        var primes: AVLTree = [2, 3, 5]
        let shape = BinaryTree(primes)!
        primes.insert(7)
        let before: Int = 3
        #expect(shape.vertexCount == before)
    }

    @Test("Graphs: a decision diagram's graph view is a Grafluent directed graph")
    func graphView() {
        var diagram = BinaryDecisionDiagram(variableCount: 2)
        _ = diagram.and(diagram.variable(0), diagram.variable(1))
        let view = diagram.graphView
        let vertices: Int = 5
        let edges: Int = 6
        #expect(view.vertexCount == vertices)
        #expect(view.edgeCount == edges)
    }
}
