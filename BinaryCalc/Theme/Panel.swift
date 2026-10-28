import SwiftUI

/// Rounded-rect panel/key background: a solid fill with a border along the
/// inside of its frame. Frame and `cornerRadius` describe the *outer* edge,
/// so with the design's outside borders the fill keeps its own radius of
/// `cornerRadius − strokeWidth` (see `Design`). Corners are circular, as in
/// the SVG — not the continuous "squircle" style.
struct Panel: View {
    let cornerRadius: CGFloat
    let fill: Color
    var stroke: Color = .clear
    var strokeWidth: CGFloat = 0

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .circular)
    }

    var body: some View {
        // The fill stops halfway under the border, so no fill colour can
        // fringe the anti-aliased outer edge.
        shape
            .inset(by: strokeWidth / 2)
            .fill(fill)
            .overlay(shape.strokeBorder(stroke, lineWidth: strokeWidth))
    }
}
