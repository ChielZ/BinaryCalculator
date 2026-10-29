import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

/// The app's colour scheme. Every element gets its own variable, even where
/// several currently share a value, so the design can be adapted later (e.g.
/// 'skin' options). Default values are the colours of `Binary Calculator.svg`.
struct BinaryTheme {
    var appBackground          = Color(hex: 0x000000)
    var calculatorFrameStroke  = Color(hex: 0xF8A036)
    var calculatorBackground   = Color(hex: 0x358292)
    var displayFrameStroke     = Color(hex: 0x88ACA2)
    var displayBackground      = Color(hex: 0xECD9AF)
    var displayDigit           = Color(hex: 0x000000)
    var displayOperator        = Color(hex: 0x000000)
    var displayOperatorOpacity = 0.5
    var brandText              = Color(hex: 0xF8A036)   // "BinaryCalc" / "CZ-IO" wordmarks
    var keypadFrameStroke      = Color(hex: 0xECD9AF)
    var keypadBackground       = Color(hex: 0x88ACA2)
    var keyStroke              = Color(hex: 0xECD9AF)
    var keyGlyph               = Color(hex: 0xECD9AF)
    var keyBacking             = Color(hex: 0x000000)   // shows through a pressed key
    var keyBackgroundDigit     = Color(hex: 0xDC4029)   // 1 / 0 / point
    var keyBackgroundOperator  = Color(hex: 0xF08537)   // × ÷ + −
    var keyBackgroundControl   = Color(hex: 0x0F6385)   // clear / equals

    static let `default` = BinaryTheme()
}

private struct BinaryThemeKey: EnvironmentKey {
    static let defaultValue = BinaryTheme.default
}

extension EnvironmentValues {
    var binaryTheme: BinaryTheme {
        get { self[BinaryThemeKey.self] }
        set { self[BinaryThemeKey.self] = newValue }
    }
}
