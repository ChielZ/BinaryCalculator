import SwiftUI

struct KeypadView: View {
    @ObservedObject var state: CalculatorState
    let metrics: CalculatorMetrics
    @Environment(\.binaryTheme) private var theme
    @Environment(\.displayScale) private var displayScale

    /// Held clear key — the gesture-driven key's stand-in for a Button's
    /// `isPressed`.
    @State private var clearPressed = false

    /// How long the clear key must be held to clear everything.
    private let clearAllDuration = 0.5

    private let layout: [[Glyph]] = [
        [.clear, .times, .divide],
        [.one,   .plus,  .minus],
        [.zero,  .point, .equals]
    ]

    var body: some View {
        ZStack {
            Panel(cornerRadius: metrics.panelCorner,
                  fill: theme.keypadBackground,
                  stroke: theme.keypadFrameStroke,
                  strokeWidth: metrics.stroke)
            grid
                .padding(metrics.stroke + metrics.spacing)
        }
        .frame(width: metrics.panelSize, height: metrics.panelSize)
    }

    private var grid: some View {
        VStack(spacing: metrics.spacing) {
            ForEach(layout.indices, id: \.self) { row in
                HStack(spacing: metrics.spacing) {
                    ForEach(layout[row], id: \.self) { key in
                        keyButton(key)
                            .background(keyBacking)
                    }
                }
            }
        }
    }

    /// Backing under each key, so a pressed key (drawn at
    /// `KeyButtonStyle.pressedOpacity`) darkens rather than letting the light
    /// keypad show through. Inset by a pixel so its anti-aliased edge stays
    /// hidden under the key's border when the key isn't pressed.
    private var keyBacking: some View {
        RoundedRectangle(cornerRadius: metrics.keyCorner, style: .circular)
            .inset(by: 1 / displayScale)
            .fill(theme.keyBacking)
    }

    @ViewBuilder
    private func keyButton(_ key: Glyph) -> some View {
        if key == .clear {
            clearKey
        } else {
            Button(action: { state.press(key) }) {
                keyFace(key)
            }
            .buttonStyle(KeyButtonStyle())
            .accessibilityLabel(accessibilityName(key))
        }
    }

    /// The clear key doubles as backspace: a short press undoes the last key
    /// press, holding it clears everything. Built from gestures rather than
    /// a Button, so the two are exclusive — a Button would still fire its
    /// tap action when a long press is released. The long press must be
    /// attached before the tap: the other way round it only wins once the
    /// tap gesture gives up, so clearing took a 0.6–0.8 s hold instead of
    /// `clearAllDuration` (measured with a UI test).
    private var clearKey: some View {
        keyFace(.clear)
            .opacity(clearPressed ? KeyButtonStyle.pressedOpacity : 1)
            .onLongPressGesture(minimumDuration: clearAllDuration,
                                perform: { state.press(.clear) },
                                onPressingChanged: { clearPressed = $0 })
            .onTapGesture { state.backspace() }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(accessibilityName(.clear))
            .accessibilityHint("Touch and hold to clear all")
            .accessibilityAction { state.backspace() }
            .accessibilityAction(named: "Clear all") { state.press(.clear) }
    }

    private func keyFace(_ key: Glyph) -> some View {
        ZStack {
            Panel(cornerRadius: metrics.keyCorner,
                  fill: keyFill(key),
                  stroke: theme.keyStroke,
                  strokeWidth: metrics.stroke)
            GlyphView(glyph: key,
                      metrics: .key,
                      center: CGPoint(x: Design.keyFace / 2, y: Design.keyFace / 2),
                      designSize: Design.keyFace,
                      color: theme.keyGlyph)
                .padding(metrics.stroke)
        }
        .frame(width: metrics.keySize, height: metrics.keySize)
    }

    private func keyFill(_ key: Glyph) -> Color {
        switch key {
        case .zero, .one, .point:              return theme.keyBackgroundDigit
        case .plus, .minus, .times, .divide:   return theme.keyBackgroundOperator
        case .clear, .equals:                  return theme.keyBackgroundControl
        }
    }

    private func accessibilityName(_ key: Glyph) -> String {
        switch key {
        case .zero:   return "Zero"
        case .one:    return "One"
        case .point:  return "Point"
        case .plus:   return "Plus"
        case .minus:  return "Minus"
        case .times:  return "Times"
        case .divide: return "Divide"
        case .equals: return "Equals"
        case .clear:  return "Delete"
        }
    }
}

/// Key press feedback: the key fades over its black backing (see
/// `KeypadView.keyBacking`), so it darkens while held. Shared by the Button
/// keys and the gesture-driven clear key, so all nine respond alike.
struct KeyButtonStyle: ButtonStyle {
    static let pressedOpacity = 0.5

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? Self.pressedOpacity : 1)
    }
}
