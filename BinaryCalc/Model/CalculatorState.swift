import Foundation
import SwiftUI
import Combine

enum BinaryOp: Hashable {
    case add
    case subtract
    case multiply
    case divide

    var glyph: Glyph {
        switch self {
        case .add:      return .plus
        case .subtract: return .minus
        case .multiply: return .times
        case .divide:   return .divide
        }
    }

    /// × and ÷ bind tighter than + and −.
    var bindsTightly: Bool {
        switch self {
        case .multiply, .divide: return true
        case .add, .subtract:    return false
        }
    }

    func apply(_ a: BinaryNumber, _ b: BinaryNumber) -> Result<BinaryNumber, BinaryNumber.OperationError> {
        switch self {
        case .add:      return a.adding(b)
        case .subtract: return a.subtracting(b)
        case .multiply: return a.multiplying(b)
        case .divide:   return a.dividing(by: b)
        }
    }
}

/// One row in the running display history. Numbers and operators
/// alternate, like a paper tape; an overflow row stands in for a result
/// that doesn't fit.
enum DisplayRow: Hashable {
    case number(DisplayDigits)
    case op(Glyph)
    case overflow
}

final class CalculatorState: ObservableObject {
    @Published private(set) var integerEntry:    [Bit] = []
    @Published private(set) var fractionalEntry: [Bit] = []
    @Published private(set) var inFractional:    Bool  = false

    @Published private(set) var history: [DisplayRow] = []

    /// Operator chosen but not yet followed by an operand. Shown live below
    /// the history, and replaced if another operator is pressed.
    @Published private(set) var pendingOp: BinaryOp? = nil

    @Published private(set) var errored: Bool = false

    @Published private(set) var displayMode: BinaryDisplayMode = .wide

    /// The expression so far: `operands[0] operators[0] operands[1] …`.
    /// Evaluated with standard precedence when `=` is pressed. After `=`
    /// it holds just the result, ready to be continued with an operator.
    private var operands:  [BinaryNumber] = []
    private var operators: [BinaryOp]     = []

    private var maxDigits: Int { displayMode.digitCount }

    /// Stack of past states (most recent last). Every key press that changes
    /// anything pushes the state from before it; backspace pops and
    /// restores. This gives full-fidelity undo — not just "delete last
    /// digit" — so backspace also takes back an operator, a result or a
    /// clear-all. Capped at 500 entries.
    private var undoStack: [StateSnapshot] = []
    private let undoLimit = 500

    private struct StateSnapshot: Equatable {
        let integerEntry: [Bit]
        let fractionalEntry: [Bit]
        let inFractional: Bool
        let history: [DisplayRow]
        let pendingOp: BinaryOp?
        let errored: Bool
        let operands: [BinaryNumber]
        let operators: [BinaryOp]
    }

    // MARK: - Derived

    var entryIsEmpty: Bool {
        integerEntry.isEmpty && fractionalEntry.isEmpty && !inFractional
    }

    /// The number being typed, digits shown verbatim (including trailing
    /// fractional zeros, so every typed digit visibly lands).
    var entryDisplay: DisplayDigits? {
        if entryIsEmpty { return nil }
        return DisplayDigits(negative: false,
                             integer: integerEntry.isEmpty ? [.zero] : integerEntry,
                             fractional: fractionalEntry,
                             showPoint: inFractional)
    }

    // MARK: - Key actions

    /// Every key press but backspace comes in here, so each one is recorded
    /// for undo. `.clear` is clear-all (the clear key's long press).
    func press(_ key: Glyph) {
        let before = takeSnapshot()
        switch key {
        case .zero:   type(.zero)
        case .one:    type(.one)
        case .point:  point()
        case .plus:   operation(.add)
        case .minus:  operation(.subtract)
        case .times:  operation(.multiply)
        case .divide: operation(.divide)
        case .equals: equals()
        case .clear:  clear()
        }
        // Presses that changed nothing (a digit past the display's width,
        // any key but clear after an overflow, …) aren't recorded, so
        // backspace never spends itself on a press that had no effect.
        if takeSnapshot() != before {
            pushSnapshot(before)
        }
    }

    /// Undo the most recent key press (the clear key's short press). Pops
    /// one state snapshot off the undo stack; no-op if empty. Works even
    /// when `errored` is true, so the user can walk back out of an overflow.
    func backspace() {
        guard let snap = undoStack.popLast() else { return }
        restore(snap)
    }

    private func type(_ bit: Bit) {
        if errored { return }
        if inFractional {
            // +1 for the new digit; the integer side always shows ≥ 1 digit.
            guard max(1, integerEntry.count) + fractionalEntry.count + 1 <= maxDigits else { return }
            beginEntry()
            fractionalEntry.append(bit)
        } else {
            // A lone leading zero is replaced rather than extended.
            if integerEntry == [.zero] {
                integerEntry = [bit]
                return
            }
            guard integerEntry.count + 1 <= maxDigits else { return }
            beginEntry()
            integerEntry.append(bit)
        }
    }

    private func point() {
        if errored || inFractional { return }
        // The point sits right of the last integer digit, and the rightmost
        // cell has no point — so it needs at least one free cell after it.
        guard max(1, integerEntry.count) < maxDigits else { return }
        beginEntry()
        inFractional = true
    }

    private func operation(_ op: BinaryOp) {
        if errored { return }
        if let value = currentEntryValue() {
            guard commitOperand(value) else { return }
        } else if operands.isEmpty {
            // Nothing entered yet: start from 0, as on a pocket calculator
            // (this is also the only way to enter a negative number).
            guard commitOperand(.zero) else { return }
        }
        pendingOp = op
    }

    private func equals() {
        if errored { return }
        if let value = currentEntryValue() {
            guard commitOperand(value) else { return }
        }
        // An operator with no operand after it is dropped.
        pendingOp = nil
        guard operands.count > 1 else { return }

        switch evaluate() {
        case .success(let r):
            if let dr = displayFor(r) {
                appendRow(.op(.equals))
                appendRow(.number(dr))
                operands = [r]
                operators = []
            } else {
                finalizeWithOverflow()
            }
        case .failure:
            finalizeWithOverflow()
        }
    }

    private func clear() {
        integerEntry.removeAll()
        fractionalEntry.removeAll()
        inFractional = false
        history.removeAll()
        operands.removeAll()
        operators.removeAll()
        pendingOp = nil
        errored = false
    }

    /// Switch between wide (8-digit) and narrow (16-digit) display. Always
    /// resets the calculator, undo included — history rows are formatted for
    /// one width.
    func setDisplayMode(_ mode: BinaryDisplayMode) {
        guard mode != displayMode else { return }
        displayMode = mode
        clear()
        undoStack.removeAll()
    }

    // MARK: - Helpers

    /// Called before the first digit or point of a new entry. If the last
    /// expression was finished with `=` (a result with no operator after
    /// it), typing starts a fresh expression instead of continuing it.
    private func beginEntry() {
        guard entryIsEmpty, pendingOp == nil else { return }
        operands.removeAll()
        operators.removeAll()
    }

    private func currentEntryValue() -> BinaryNumber? {
        if entryIsEmpty { return nil }
        return BinaryNumber.from(integer: integerEntry, fractional: fractionalEntry)
    }

    /// Move a value into the expression (after the pending operator, if
    /// any) and onto the tape, and clear the entry. Returns false — after
    /// showing an overflow — if the value can't be displayed.
    private func commitOperand(_ value: BinaryNumber) -> Bool {
        guard let dv = displayFor(value) else {
            finalizeWithOverflow()
            return false
        }
        if let op = pendingOp, !operands.isEmpty {
            operators.append(op)
            operands.append(value)
            appendRow(.op(op.glyph))
        } else {
            operands = [value]
            operators = []
        }
        appendRow(.number(dv))
        commitEntry()
        pendingOp = nil
        return true
    }

    /// Evaluate `operands`/`operators` with × and ÷ before + and −, each
    /// level left to right.
    private func evaluate() -> Result<BinaryNumber, BinaryNumber.OperationError> {
        // First pass: fold every × / ÷ into the term on its left.
        var terms: [BinaryNumber] = [operands[0]]
        var termOps: [BinaryOp] = []
        for (op, operand) in zip(operators, operands.dropFirst()) {
            if op.bindsTightly {
                switch op.apply(terms[terms.count - 1], operand) {
                case .success(let r): terms[terms.count - 1] = r
                case .failure(let e): return .failure(e)
                }
            } else {
                terms.append(operand)
                termOps.append(op)
            }
        }
        // Second pass: + / − across the terms.
        var result = terms[0]
        for (op, term) in zip(termOps, terms.dropFirst()) {
            switch op.apply(result, term) {
            case .success(let r): result = r
            case .failure(let e): return .failure(e)
            }
        }
        return .success(result)
    }

    private func commitEntry() {
        integerEntry.removeAll()
        fractionalEntry.removeAll()
        inFractional = false
    }

    private func displayFor(_ value: BinaryNumber) -> DisplayDigits? {
        value.displayDigits(maxDigits: maxDigits)
    }

    private func appendRow(_ row: DisplayRow) {
        history.append(row)
    }

    /// Show the overflow as the "answer" of the expression — an `=` row then
    /// the overflow row — and lock the calculator until it's cleared.
    private func finalizeWithOverflow() {
        appendRow(.op(.equals))
        appendRow(.overflow)
        errored = true
        commitEntry()
        operands.removeAll()
        operators.removeAll()
        pendingOp = nil
    }

    // MARK: - Undo stack

    private func takeSnapshot() -> StateSnapshot {
        StateSnapshot(
            integerEntry: integerEntry,
            fractionalEntry: fractionalEntry,
            inFractional: inFractional,
            history: history,
            pendingOp: pendingOp,
            errored: errored,
            operands: operands,
            operators: operators
        )
    }

    private func pushSnapshot(_ snap: StateSnapshot) {
        undoStack.append(snap)
        if undoStack.count > undoLimit {
            undoStack.removeFirst(undoStack.count - undoLimit)
        }
    }

    private func restore(_ s: StateSnapshot) {
        integerEntry    = s.integerEntry
        fractionalEntry = s.fractionalEntry
        inFractional    = s.inFractional
        history         = s.history
        pendingOp       = s.pendingOp
        errored         = s.errored
        operands        = s.operands
        operators       = s.operators
    }
}

#if DEBUG
extension CalculatorState {
    /// Replays keys typed as text — `0 1 . + - * / =`, `<` for backspace,
    /// `c` for clear-all — e.g. from the `-replayKeys "10001-110111/11="`
    /// launch argument, to put the display into a known state for
    /// screenshots.
    func replay(_ keys: String) {
        let map: [Character: Glyph] = [
            "0": .zero, "1": .one, ".": .point,
            "+": .plus, "-": .minus, "*": .times, "/": .divide,
            "=": .equals, "c": .clear,
        ]
        for key in keys {
            if key == "<" {
                backspace()
            } else if let glyph = map[key] {
                press(glyph)
            }
        }
    }
}
#endif
