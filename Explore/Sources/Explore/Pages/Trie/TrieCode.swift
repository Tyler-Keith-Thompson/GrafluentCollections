// snippet: trie-imports
import Trees
import Tries
// snippet end

// The trie page's code. The marked regions are its code panel.

/// The words in `text`: runs of the letters a to z, at most 10 letters each and at most 10
/// words. Anything else separates words.
func trieWords(_ text: String) -> [String] {
    let words = text.lowercased().split { !("a" ... "z").contains($0) }.map { String($0.prefix(10)) }
    return Array(words.prefix(10))
}

/// The query in `text`: its letters a to z, at most 12.
func trieQuery(_ text: String) -> String {
    String(text.lowercased().filter { ("a" ... "z").contains($0) }.prefix(12))
}

/// The trie and the radix tree after each word goes in, starting from empty ones.
func trieHistory(_ words: [String]) -> [(trie: Trie<Character>, radix: RadixTree<Character>)] {
    // snippet: trie-run
    var trie = Trie<Character>()
    var radix = RadixTree<Character>()
    var history = [(trie, radix)]
    for word in words {
        trie.insert(word)
        radix.insert(word)
        history.append((trie, radix))
    }
    let vertices = PrefixTree(trie).arborescence.vertexCount  // →
    let radixVertices = Arborescence(radix).vertexCount  // →
    // snippet end
    _ = (vertices, radixVertices)
    return history
}

/// The trie's answers to the page's two questions: the words that start with `prefix`, and the
/// longest word that `text` starts with.
func trieAnswers(_ trie: Trie<Character>, prefix: String, text: String) -> (matches: [String], longest: String?) {
    // snippet: trie-query
    let matches = trie.elements(withPrefix: prefix).map { String($0) }  // →
    let longest = trie.longestPrefix(of: text).map { String($0) }  // →
    // snippet end
    return (matches, longest)
}
