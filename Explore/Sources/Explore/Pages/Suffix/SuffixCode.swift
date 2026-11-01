// snippet: suffix-imports
import SuffixStructures
// snippet end

// The suffix array and suffix tree page's code. The marked regions are its code panel.

/// The text in `text`: lowercase letters only, at most 16.
func suffixText(_ text: String) -> String {
    String(text.lowercased().filter { $0.isLetter && $0.isASCII }.prefix(16))
}

/// The patterns in `text`: words of lowercase letters, separated by spaces; at most 12.
func suffixPatterns(_ text: String) -> [String] {
    Array(text.lowercased().split(separator: " ").map { String($0.filter { $0.isLetter && $0.isASCII }) }.filter { !$0.isEmpty }.prefix(12))
}

/// Both structures over `text`, and each pattern's occurrences in each: a range of the suffix
/// array's sorted positions, and the starts the suffix tree reports.
func suffixRun(_ text: String, _ patterns: [String]) -> (array: SuffixArray<Character>, tree: SuffixTree<Character>, ranges: [Range<Int>], starts: [[Int]]) {
    // snippet: suffix-run
    let array = SuffixArray(text)
    let tree = SuffixTree(text)
    var ranges: [Range<Int>] = []
    var starts: [[Int]] = []
    for pattern in patterns {
        ranges.append(array.occurrences(of: pattern))
        starts.append(tree.occurrences(of: pattern).map(\.range.lowerBound))
    }
    let repeated = tree.longestRepeatedSubstring?.range  // →
    // snippet end
    _ = repeated
    return (array, tree, ranges, starts)
}
