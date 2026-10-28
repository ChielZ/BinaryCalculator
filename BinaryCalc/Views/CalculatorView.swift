import SwiftUI

struct CalculatorView: View {
    @ObservedObject var state: CalculatorState
    let metrics: CalculatorMetrics
    @Environment(\.binaryTheme) private var theme

    var body: some View {
        ZStack {
            Panel(cornerRadius: metrics.calcCorner,
                  fill: theme.calculatorBackground,
                  stroke: theme.calculatorFrameStroke,
                  strokeWidth: metrics.stroke)

            VStack(spacing: 0) {
                DisplayView(state: state, metrics: metrics)
                brandLabels
                KeypadView(state: state, metrics: metrics)
            }
            .padding(.horizontal, metrics.calcPaddingH)
            .padding(.vertical, metrics.calcPaddingV)
        }
        .frame(width: metrics.calcWidth, height: metrics.calcHeight)
    }

    /// "BinaryCalc" and "CZ-IO" wordmarks in the band between display and
    /// keypad, aligned with the display's fill edges (inside its border).
    /// Placed by baseline, as in the SVG: the text's top alignment guide is
    /// moved to its baseline, which is then offset down into the band. An
    /// overlay (unlike a ZStack) doesn't grow to fit the shifted text, so
    /// the band keeps its exact height.
    private var brandLabels: some View {
        Color.clear
            .frame(width: metrics.panelSize, height: metrics.panelGap)
            .overlay(alignment: .top) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("BinaryCalc")
                    Spacer(minLength: 0)
                    Text("CZ-IO")
                }
                .font(.custom(Design.brandFont, fixedSize: Design.brandFontSize * metrics.scale))
                .foregroundStyle(theme.brandText)
                .lineLimit(1)
                .padding(.horizontal, metrics.stroke)
                .alignmentGuide(.top) { d in d[.firstTextBaseline] }
                .offset(y: Design.brandBaseline * metrics.scale)
                .accessibilityElement(children: .combine)
            }
    }
}
