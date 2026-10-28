import SwiftUI

struct ContentView: View {
    @StateObject private var state = CalculatorState()
    @Environment(\.binaryTheme) private var theme
    @Environment(\.binaryDisplayMode) private var displayMode

    var body: some View {
        ZStack {
            // Background extends under the notch and home indicator; the
            // calculator itself stays within the safe area.
            theme.appBackground
                .ignoresSafeArea()

            GeometryReader { proxy in
                let size = proxy.size
                // Reserve symmetric top/bottom room — sized off the shorter
                // side of the screen rather than its height, so the vertical
                // margin is consistent across portrait and landscape.
                let shortSide = min(size.width, size.height)
                let reserve = shortSide * CalcLayout.verticalReserveRatio
                let avail = CGSize(width: size.width,
                                   height: max(1, size.height - 2 * reserve))
                let maxCalcWidth = shortSide * CalcLayout.maxCalcWidthRatio
                let metrics = CalculatorMetrics.fit(into: avail, maxCalcWidth: maxCalcWidth)

                CalculatorView(state: state, metrics: metrics)
                    .position(x: size.width / 2, y: size.height / 2)
            }
        }
        .statusBarHidden(true)
        .onAppear {
            state.setDisplayMode(displayMode)
            #if DEBUG
            if let keys = UserDefaults.standard.string(forKey: "replayKeys") {
                state.replay(keys)
            }
            #endif
        }
        .onChange(of: displayMode) { new in state.setDisplayMode(new) }
    }
}

#Preview {
    ContentView()
}
