import Trees

extension Arborescence where Vertex == Int {
    /// A suffix automaton's suffix-link tree: a vertex per state, numbered as the automaton
    /// numbers them, rooted at the start state, each state's parent its suffix link. A state's
    /// substrings end at a subset of the places its parent's do.
    ///
    /// - Parameter automaton: The automaton whose suffix links are converted.
    /// - Complexity: O(*n*) for *n* states.
    @inlinable
    public init<Symbol: Hashable>(_ automaton: SuffixAutomaton<Symbol>) {
        let parents = automaton._states.links.map { $0 < 0 ? nil : Int($0) }
        guard let tree = Arborescence(parents: parents) else {
            preconditionFailure("A suffix automaton's suffix links form one tree")
        }
        self = tree
    }
}
