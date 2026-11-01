extension BinaryDecisionDiagram {
    /// One of the sixteen binary Boolean operators, as its truth table.
    @frozen
    public struct Operator: Hashable, Sendable {
        /// Bit `2a + b` is the operator's result for operands `a` and `b`.
        public let truthTable: UInt8

        /// The operator whose truth table is `truthTable`: bit `2a + b` is its result for `a` and
        /// `b`.
        ///
        /// - Parameter truthTable: Traps unless it is below 16.
        @inlinable
        public init(truthTable: UInt8) {
            precondition(truthTable < 16, "A binary operator's truth table has four bits")
            self.truthTable = truthTable
        }

        /// The operator that `function` computes.
        @inlinable
        public init(_ function: (Bool, Bool) -> Bool) {
            var table: UInt8 = 0
            for (bit, (a, b)) in [(false, false), (false, true), (true, false), (true, true)].enumerated() where function(a, b) {
                table |= 1 << UInt8(bit)
            }
            self.truthTable = table
        }

        /// The operator's result for `a` and `b`.
        @inlinable
        public func callAsFunction(_ a: Bool, _ b: Bool) -> Bool {
            (truthTable >> ((a ? 2 : 0) + (b ? 1 : 0))) & 1 == 1
        }

        /// Always false.
        public static let `false` = Operator(truthTable: 0b0000)
        /// ¬(a ∨ b).
        public static let nor = Operator(truthTable: 0b0001)
        /// ¬a ∧ b.
        public static let converseNonimplication = Operator(truthTable: 0b0010)
        /// ¬a.
        public static let notFirst = Operator(truthTable: 0b0011)
        /// a ∧ ¬b.
        public static let nonimplication = Operator(truthTable: 0b0100)
        /// ¬b.
        public static let notSecond = Operator(truthTable: 0b0101)
        /// a ⊕ b.
        public static let xor = Operator(truthTable: 0b0110)
        /// ¬(a ∧ b).
        public static let nand = Operator(truthTable: 0b0111)
        /// a ∧ b.
        public static let and = Operator(truthTable: 0b1000)
        /// a ↔ b.
        public static let equivalence = Operator(truthTable: 0b1001)
        /// b.
        public static let second = Operator(truthTable: 0b1010)
        /// a → b.
        public static let implication = Operator(truthTable: 0b1011)
        /// a.
        public static let first = Operator(truthTable: 0b1100)
        /// b → a.
        public static let converseImplication = Operator(truthTable: 0b1101)
        /// a ∨ b.
        public static let or = Operator(truthTable: 0b1110)
        /// Always true.
        public static let `true` = Operator(truthTable: 0b1111)
    }
}
