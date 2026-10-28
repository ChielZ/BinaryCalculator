import SwiftUI

struct DisplayView: View {
    @ObservedObject var state: CalculatorState
    let metrics: CalculatorMetrics
    @Environment(\.binaryTheme) private var theme
    @Environment(\.binaryDisplayMode) private var displayMode

    var body: some View {
        ZStack {
            Panel(cornerRadius: metrics.panelCorner,
                  fill: theme.displayBackground,
                  stroke: theme.displayFrameStroke,
                  strokeWidth: metrics.stroke)
            content
                .padding(metrics.stroke)
        }
        .frame(width: metrics.panelSize, height: metrics.panelSize)
    }

    /// Every line is drawn over the whole display fill, in display-fill
    /// design space, so each glyph lands at its exact SVG position.
    private var content: some View {
        let geometry = displayMode.geometry
        let lines = visibleLines()
        return ZStack {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, row in
                switch row {
                case .number(let digits):
                    DigitLineView(cells: digits.cells(count: geometry.cellCount),
                                  line: index,
                                  geometry: geometry,
                                  color: theme.displayDigit)
                case .overflow:
                    DigitLineView(cells: Array(repeating: .all, count: geometry.cellCount),
                                  line: index,
                                  geometry: geometry,
                                  color: theme.displayDigit)
                case .op(let glyph):
                    GlyphView(glyph: glyph,
                              metrics: .display,
                              center: CGPoint(x: DisplayGeometry.operatorX,
                                              y: DisplayGeometry.lineY(index) + DisplayGeometry.cellHeight / 2),
                              designSize: DisplayGeometry.size,
                              color: theme.displayOperator)
                        .opacity(theme.displayOperatorOpacity)
                case nil:
                    EmptyView()
                }
            }
        }
    }

    /// Lay the tape out on the display's lines: numbers on digit lines,
    /// operators on the lines between. Two numbers in a row (a new entry
    /// after a result) leave the operator line between them blank. Once the
    /// tape outgrows the display it scrolls up, two lines at a time so the
    /// top line stays a digit line.
    private func visibleLines() -> [DisplayRow?] {
        var rows: [DisplayRow] = state.history
        if let op = state.pendingOp {
            rows.append(.op(op.glyph))
        }
        if let entry = state.entryDisplay {
            rows.append(.number(entry))
        }

        var lines: [DisplayRow?] = []
        for row in rows {
            let isOp: Bool
            if case .op = row { isOp = true } else { isOp = false }
            if DisplayGeometry.isDigitLine(lines.count) == isOp {
                lines.append(nil)
            }
            lines.append(row)
        }

        let excess = lines.count - DisplayGeometry.lineCount
        if excess > 0 {
            lines.removeFirst(excess + excess % 2)
        }
        return lines
    }
}
