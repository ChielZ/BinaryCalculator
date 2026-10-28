import SwiftUI

/// Key glyphs, and the operator glyphs shown in the display. All are built
/// from the same few primitives around a centre point — bar, dash,
/// diagonals, ring, square and filled dots — so one shape draws both the
/// keys and the smaller display operators; `GlyphMetrics` sets the size.
enum Glyph: Hashable {
    case zero
    case one
    case point
    case plus
    case minus
    case times
    case divide
    case equals
    case clear       // square outline
}

/// Proportions of a glyph set, in design units.
struct GlyphMetrics {
    /// Length of bars, dashes and diagonals — also the diameter of the zero
    /// ring and the side of the clear square. Measured between stroke
    /// centres; round caps extend each line by half a stroke.
    let length: CGFloat
    let stroke: CGFloat
    let dotRadius: CGFloat
    /// Distance of each `=` line from the glyph centre.
    let equalsOffset: CGFloat

    /// Keypad glyphs, centred on a 1600-unit key face.
    static let key = GlyphMetrics(length: 900, stroke: 90, dotRadius: 90, equalsOffset: 180)

    /// Operator glyphs between the display's digit lines. As with the
    /// display's binary point, the ÷ dots render at r = 45 (see
    /// `DisplayGeometry.pointRadius`).
    static let display = GlyphMetrics(length: 495, stroke: 45, dotRadius: 45, equalsOffset: 90)
}

/// The two ways glyph parts are painted: lines and rings are stroked with
/// round caps, dots are filled.
enum GlyphPart {
    case strokes
    case dots
}

/// One part of a glyph, centred on `center` in a design space `designSize`
/// units wide, mapped onto the shape's rect.
struct GlyphShape: Shape {
    let glyph: Glyph
    let metrics: GlyphMetrics
    let center: CGPoint
    let designSize: CGFloat
    let part: GlyphPart

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / designSize

        // P(dx, dy) takes an offset from the glyph centre in design units.
        func P(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + (center.x + dx) * scale,
                    y: rect.minY + (center.y + dy) * scale)
        }

        let h = metrics.length / 2
        // Half-length of a 45° diagonal projected on either axis. The ÷ dots
        // sit at this height too — exactly where the × arms end.
        let d = h / 2.squareRoot()

        var p = Path()
        switch part {
        case .strokes:
            switch glyph {
            case .zero:
                p.addEllipse(in: CGRect(origin: P(-h, -h),
                                        size: CGSize(width: metrics.length * scale,
                                                     height: metrics.length * scale)))
            case .one:
                p.move(to: P(0, -h));  p.addLine(to: P(0, h))
            case .plus:
                p.move(to: P(0, -h));  p.addLine(to: P(0, h))
                p.move(to: P(-h, 0));  p.addLine(to: P(h, 0))
            case .minus, .divide:
                p.move(to: P(-h, 0));  p.addLine(to: P(h, 0))
            case .times:
                p.move(to: P(-d, -d)); p.addLine(to: P(d, d))
                p.move(to: P(d, -d));  p.addLine(to: P(-d, d))
            case .equals:
                let e = metrics.equalsOffset
                p.move(to: P(-h, -e)); p.addLine(to: P(h, -e))
                p.move(to: P(-h, e));  p.addLine(to: P(h, e))
            case .clear:
                // Four separate sides, as in the design: their round caps
                // overlap into softly rounded corners.
                p.move(to: P(-h, -h)); p.addLine(to: P(h, -h))
                p.move(to: P(h, -h));  p.addLine(to: P(h, h))
                p.move(to: P(h, h));   p.addLine(to: P(-h, h))
                p.move(to: P(-h, h));  p.addLine(to: P(-h, -h))
            case .point:
                break
            }
        case .dots:
            let r = metrics.dotRadius * scale
            func dot(_ c: CGPoint) {
                p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            }
            switch glyph {
            case .point:
                dot(P(0, 0))
            case .divide:
                dot(P(0, -d))
                dot(P(0, d))
            default:
                break
            }
        }
        return p
    }
}

/// A glyph drawn in a frame that spans `designSize` design units, e.g. a
/// 1600-unit key face, or the whole display fill for a display operator.
struct GlyphView: View {
    let glyph: Glyph
    let metrics: GlyphMetrics
    let center: CGPoint
    let designSize: CGFloat
    var color: Color = .black

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / designSize
            ZStack {
                GlyphShape(glyph: glyph, metrics: metrics, center: center,
                           designSize: designSize, part: .strokes)
                    .stroke(color, style: StrokeStyle(lineWidth: metrics.stroke * scale,
                                                      lineCap: .round,
                                                      lineJoin: .round))
                GlyphShape(glyph: glyph, metrics: metrics, center: center,
                           designSize: designSize, part: .dots)
                    .fill(color)
            }
        }
    }
}
