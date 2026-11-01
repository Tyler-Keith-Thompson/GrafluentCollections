// Each test is self-contained: it builds its own trees and states its own expectations, so it can
// be copied into another file and still run. Nothing here is shared but the imports.

import GrafluentCollectionsTestSupport
import GraphProtocols
import PropertyBased
import SuffixStructures
import Testing
import Trees

@Suite("SuffixTree: hand-worked cases")
struct SuffixTreeTests {
    typealias Occurrence = SuffixTree<Character>.Occurrence

    @Test("abaab's tree: the root branches on $, a and b, a on a and b, and ab and b on $ and a")
    func abaab() {
        let tree = SuffixTree("abaab")
        // Preorder: 0 root, 1 "$", 2 "a", 3 "aab$", 4 "ab", 5 "ab$", 6 "abaab$", 7 "b",
        // 8 "b$", 9 "baab$".
        #expect(tree.nodeCount == 10)
        let rootChildren: [Int] = [1, 2, 7]
        let aChildren: [Int] = [3, 4]
        let abChildren: [Int] = [5, 6]
        #expect(tree.children(of: 0) == rootChildren)
        #expect(tree.children(of: 2) == aChildren)
        #expect(tree.children(of: 4) == abChildren)
        #expect(tree.children(of: 3).isEmpty)
        let leaves = tree.nodes.filter { tree.isLeaf($0) }
        let suffixes: [Int] = [5, 2, 3, 0, 4, 1]
        #expect(leaves.map { tree.pathLabel(of: $0).range.lowerBound } == suffixes)
        let depths: [Int] = [0, 0, 1, 3, 2, 2, 5, 1, 1, 4]
        #expect(tree.nodes.map { tree.stringDepth(of: $0) } == depths)
        let abLabel = Occurrence(textIndex: 0, range: 3 ..< 5)
        #expect(tree.pathLabel(of: 4) == abLabel)
        let leafEdge = Occurrence(textIndex: 0, range: 3 ..< 5)
        #expect(tree.edgeLabel(of: 3) == leafEdge)
        let terminatorEdge = Occurrence(textIndex: 0, range: 5 ..< 5)
        #expect(tree.edgeLabel(of: 1) == terminatorEdge)
        #expect(tree.parent(of: 6) == 4)
        #expect(tree.parent(of: 0) == nil)
    }

    @Test("banana: ana occurs at 3 and 1, and the suffix links run ana → na → a → root")
    func banana() {
        let tree = SuffixTree("banana")
        #expect(tree.nodeCount == 11)
        let ana: [Occurrence] = [
            Occurrence(textIndex: 0, range: 3 ..< 6),
            Occurrence(textIndex: 0, range: 1 ..< 4),
        ]
        #expect(tree.occurrences(of: "ana") == ana)
        #expect(tree.contains("nan"))
        #expect(!tree.contains("nab"))
        #expect(!tree.contains("x"))
        let repeated: Occurrence? = Occurrence(textIndex: 0, range: 3 ..< 6)
        #expect(tree.longestRepeatedSubstring == repeated)

        let links = tree.suffixLinksView
        let internalNodes = tree.nodes.filter { $0 != tree.root && !tree.isLeaf($0) }
        #expect(internalNodes.count == 3)
        #expect(links.edges.count == 3)
        func node(_ path: String) -> Int {
            internalNodes.first { tree.stringDepth(of: $0) == path.count && tree.pathLabel(of: $0).range.count == path.count && Array("banana")[tree.pathLabel(of: $0).range].elementsEqual(path) }!
        }
        let a = node("a")
        let na = node("na")
        let anaNode = node("ana")
        #expect(links.successors(of: anaNode) == [na])
        #expect(links.successors(of: na) == [a])
        #expect(links.successors(of: a) == [tree.root])
        #expect(links.successors(of: tree.root).isEmpty)
        for edge in links.edges {
            #expect(tree.stringDepth(of: edge.target) == tree.stringDepth(of: edge.source) - 1)
        }
    }

    @Test("A text of one repeated symbol nests its internal nodes one symbol deeper each, by rule 3 ending every phase")
    func allEqual() {
        let tree = SuffixTree([UInt8](repeating: 7, count: 4))
        // Internal nodes for 7, 77, 777, and a leaf per suffix, the empty one included.
        #expect(tree.nodeCount == 9)
        let internalDepths = tree.nodes.filter { $0 != 0 && !tree.isLeaf($0) }.map { tree.stringDepth(of: $0) }
        let expected: [Int] = [1, 2, 3]
        #expect(internalDepths == expected)
        #expect(tree.longestRepeatedSubstring?.range.count == 3)
        #expect(tree.occurrences(of: [7, 7]).count == 3)
    }

    @Test("The empty text has the root and the empty suffix's leaf; only the empty pattern occurs in it")
    func emptyText() {
        let tree = SuffixTree<UInt8>([UInt8]())
        #expect(tree.nodeCount == 2)
        #expect(tree.contains([UInt8]()))
        #expect(!tree.contains([UInt8(1)]))
        #expect(tree.occurrences(of: [UInt8]()).isEmpty)
        #expect(tree.longestRepeatedSubstring == nil)
        #expect(tree.longestCommonSubstring == nil)
        #expect(tree.textCount == 1)
    }

    @Test("A one-symbol text has two leaves, repeats nothing, and has itself in common with itself")
    func oneSymbol() {
        let tree = SuffixTree("x")
        #expect(tree.nodeCount == 3)
        #expect(tree.longestRepeatedSubstring == nil)
        let whole: Occurrence? = Occurrence(textIndex: 0, range: 0 ..< 1)
        #expect(tree.longestCommonSubstring == whole)
        let x: [Occurrence] = [Occurrence(textIndex: 0, range: 0 ..< 1)]
        #expect(tree.occurrences(of: "x") == x)
    }

    @Test("The generalized tree of xabxac and abcabxabcd has abxa as their longest common substring")
    func generalized() {
        let tree = SuffixTree(texts: ["xabxac", "abcabxabcd"])
        #expect(tree.textCount == 2)
        let common = tree.longestCommonSubstring
        #expect(common?.range.count == 4)
        if let common {
            let texts = [Array("xabxac"), Array("abcabxabcd")]
            #expect(String(texts[common.textIndex][common.range]) == "abxa")
        }
        let ab = Set(tree.occurrences(of: "ab"))
        let expected: Set<Occurrence> = [
            Occurrence(textIndex: 0, range: 1 ..< 3),
            Occurrence(textIndex: 1, range: 0 ..< 2),
            Occurrence(textIndex: 1, range: 3 ..< 5),
            Occurrence(textIndex: 1, range: 6 ..< 8),
        ]
        #expect(ab == expected)
        // A repeat may span texts but never a terminator: "abxa" occurs once in each.
        #expect(tree.longestRepeatedSubstring?.range.count == 4)
        let none = SuffixTree(texts: ["aaa", "bbb"])
        #expect(none.longestCommonSubstring == nil)
    }

    @Test("Symbols that are only Hashable are found, with children in the order symbols first occur")
    func hashableSymbols() {
        struct Token: Hashable {
            let name: String
        }
        let text = ["to", "be", "or", "not", "to", "be"].map(Token.init)
        let tree = SuffixTree(text)
        let toBe = [Token(name: "to"), Token(name: "be")]
        let found = tree.occurrences(of: toBe).map(\.range.lowerBound).sorted()
        let expected: [Int] = [0, 4]
        #expect(found == expected)
        #expect(tree.longestRepeatedSubstring?.range.count == 2)
        #expect(!tree.contains([Token(name: "question")]))
    }

    @Test("The RootedTree conversion keeps every node and its parent", .tags(.fixture))
    func rootedTree() {
        let tree = SuffixTree("mississippi")
        let shape = RootedTree(tree)
        #expect(shape.vertexCount == tree.nodeCount)
        #expect(shape.root == tree.root)
        for node in tree.nodes {
            #expect(shape.parent(of: node) == tree.parent(of: node))
        }
    }

}

@Suite("SuffixTree: properties")
struct SuffixTreePropertyTests {
    @Test("The leaves in order are the suffix array, and the deepest common ancestors of neighbours give its LCP array", .tags(.randomized))
    func matchesSuffixArray() async {
        let text = Gen.int(in: 0 ... 3).array(of: 0 ... 120)
        let pattern = Gen.int(in: 0 ... 3).array(of: 0 ... 4)
        await propertyCheck(count: 300, input: text, pattern) { text, pattern in
            let tree = SuffixTree(text)
            let array = SuffixArray(text)
            #expect(tree.nodeCount <= 2 * (text.count + 1) + 1)
            let leaves = tree.nodes.filter { tree.isLeaf($0) && tree.stringDepth(of: $0) > 0 }
            #expect(leaves.map { tree.pathLabel(of: $0).range.lowerBound } == Array(array.positions))
            func ancestors(_ node: Int) -> [Int] {
                var chain = [node]
                while let parent = tree.parent(of: chain.last!) {
                    chain.append(parent)
                }
                return chain
            }
            var prefixes: [Int] = []
            for k in leaves.indices {
                if k == 0 {
                    prefixes.append(0)
                    continue
                }
                let above = Set(ancestors(leaves[k - 1]))
                let common = ancestors(leaves[k]).first { above.contains($0) }!
                prefixes.append(tree.stringDepth(of: common))
            }
            #expect(prefixes == Array(array.longestCommonPrefixes))

            let found = tree.occurrences(of: pattern).map(\.range.lowerBound)
            let expected = array.occurrences(of: pattern).map { array.positions[$0] }
            #expect(found == expected)
            #expect(tree.contains(pattern) == array.contains(pattern))
            #expect(tree.longestRepeatedSubstring?.range.count == array.longestRepeatedSubstring?.count)
            for link in tree.suffixLinksView.edges {
                #expect(tree.stringDepth(of: link.target) == tree.stringDepth(of: link.source) - 1)
            }
        }
    }

    @Test("The longest common substring of two texts matches a direct search", .tags(.randomized))
    func longestCommonSubstringMatchesNaive() async {
        let text = Gen.int(in: 0 ... 2).array(of: 0 ... 30)
        await propertyCheck(count: 300, input: text, text) { first, second in
            let tree = SuffixTree(texts: [first, second])
            var longest = 0
            for start in first.indices {
                for end in start + 1 ... first.count {
                    let piece = Array(first[start ..< end])
                    let inSecond = second.count >= piece.count
                        && (0 ... second.count - piece.count).contains { Array(second[$0 ..< $0 + piece.count]) == piece }
                    if inSecond {
                        longest = max(longest, piece.count)
                    }
                }
            }
            #expect((tree.longestCommonSubstring?.range.count ?? 0) == longest)
            if let common = tree.longestCommonSubstring {
                let texts = [first, second]
                let piece = Array(texts[common.textIndex][common.range])
                #expect(tree.occurrences(of: piece).contains { $0.textIndex == 0 })
                #expect(tree.occurrences(of: piece).contains { $0.textIndex == 1 })
            }
        }
    }
}
