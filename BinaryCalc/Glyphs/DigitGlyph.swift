import SwiftUI

/// Lit segments of one display character cell.
struct Segments: OptionSet, Hashable {
    let rawValue: Int

    static let ring  = Segments(rawValue: 1 << 0)   // 0
    static let bar   = Segments(rawValue: 1 << 1)   // 1
    static let dash  = Segments(rawValue: 1 << 2)   // minus sign
    static let point = Segments(rawValue: 1 << 3)   // binary point, right of the cell

    static let all: Segments = [.ring, .bar, .dash, .point]
}

extension DisplayDigits {
    /// Segments for each of a line's `count` cells. Digits are right-aligned
    /// in all but the leftmost cell, with the binary point lit on the last
    /// integer digit's cell. The minus sign sits directly left of the
    /// leading digit, as in ordinary notation — the leftmost cell is kept
    /// free of digits so that even a full-width number has room for it.
    func cells(count: Int) -> [Segments] {
        var cells = Array(repeating: Segments(), count: count)

        // The rightmost cell has no point, so a point typed before any
        // fractional digit keeps that cell free for the first one.
        let reserve = showPoint && fractional.isEmpty ? 1 : 0
        let digits = integer + fractional
        let first = count - reserve - digits.count
        for (i, bit) in digits.enumerated() where first + i >= 1 {
            cells[first + i] = bit == .one ? .bar : .ring
        }
        let pointCell = first + integer.count - 1
        if showPoint, pointCell >= 1 {
            cells[pointCell].insert(.point)
        }
        if negative {
            cells[max(0, first - 1)] = .dash
        }
        return cells
    }
}

/// One digit line of the display, drawn in display-fill design space
/// (`DisplayGeometry.size` units across the shape's rect).
struct DigitLineShape: Shape {
    let cells: [Segments]
    let line: Int
    let geometry: DisplayGeometry
    let part: GlyphPart

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / DisplayGeometry.size
        let top = DisplayGeometry.lineY(line)
        let w = geometry.cellWidth
        let h = DisplayGeometry.cellHeight
        // Segments run stroke-centre to stroke-centre, so their round caps
        // and the ring's outer edge just touch the cell's box.
        let inset = DisplayGeometry.stroke / 2

        var p = Path()
        for (column, segments) in cells.enumerated() {
            let left = geometry.cellX(column)

            // P(x, y) takes a point in the cell's own design coordinates.
            func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: rect.minX + (left + x) * scale,
                        y: rect.minY + (top + y) * scale)
            }

            switch part {
            case .strokes:
                if segments.contains(.ring) {
                    p.addEllipse(in: CGRect(origin: P(inset, inset),
                                            size: CGSize(width: (w - 2 * inset) * scale,
                                                         height: (h - 2 * inset) * scale)))
                }
                if segments.contains(.bar) {
                    p.move(to: P(w / 2, inset)); p.addLine(to: P(w / 2, h - inset))
                }
                if segments.contains(.dash) {
                    p.move(to: P(inset, h / 2)); p.addLine(to: P(w - inset, h / 2))
                }
            case .dots:
                // Every cell but the rightmost has a point.
                if segments.contains(.point), column < geometry.cellCount - 1 {
                    let c = P(geometry.pointX, DisplayGeometry.pointY)
                    let r = DisplayGeometry.pointRadius * scale
                    p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                }
            }
        }
        return p
    }
}

struct DigitLineView: View {
    let cells: [Segments]
    let line: Int
    let geometry: DisplayGeometry
    var color: Color = .black

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / DisplayGeometry.size
            ZStack {
                DigitLineShape(cells: cells, line: line, geometry: geometry, part: .strokes)
                    .stroke(color, style: StrokeStyle(lineWidth: DisplayGeometry.stroke * scale,
                                                      lineCap: .round))
                DigitLineShape(cells: cells, line: line, geometry: geometry, part: .dots)
                    .fill(color)
            }
        }
    }
}
