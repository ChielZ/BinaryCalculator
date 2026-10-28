import SwiftUI

/// Calculator geometry in design units — the coordinate space of
/// `Binary Calculator.svg` and the Sketch file it was exported from. Views
/// multiply these by `CalculatorMetrics.scale` (points per unit), so every
/// shape and proportion of the SVG is reproduced exactly.
///
/// The design's panels and keys carry their 45-unit border *outside* their
/// fill (Sketch's "outside" border position). Sizes and corner radii below
/// are for the outer edge, border included: the display, for example, has a
/// 6950-unit fill with a 180 corner radius, so 7040 / 225 outside its border.
enum Design {
    /// Border width of every framed element: calculator body, display,
    /// keypad and keys.
    static let stroke: CGFloat = 45

    /// Base grid unit: keypad padding, gaps between keys and the calculator
    /// body's side padding. The gap between display and keypad is 2×.
    static let spacing: CGFloat = 470

    /// Calculator body ("Surround"): 7980 × 15940 fill.
    static let calcWidth: CGFloat  = 8070
    static let calcHeight: CGFloat = 16030
    static let calcCorner: CGFloat = 315

    /// Body padding between its border and the display / keypad panels.
    /// The SVG has the body 22.5 units left of centre (492.5 vs 447.5 side
    /// padding); it's centred here, on the 470 grid the keypad uses.
    static let calcPaddingH: CGFloat = spacing
    static let calcPaddingV: CGFloat = 460

    /// Display and keypad: both square, 6950 fill.
    static let panelSize: CGFloat   = 7040
    static let panelCorner: CGFloat = 225
    static let panelGap: CGFloat    = 2 * spacing

    /// Keys: 1600 fill, 3 × 3 on the 470 grid.
    static let keySize: CGFloat   = 1690
    static let keyCorner: CGFloat = 135
    static let keyFace: CGFloat   = 1600

    /// "BinaryCalc" / "CZ-IO" wordmarks: Comfortaa SemiBold, aligned with the
    /// display's fill edges, baseline measured from the display's outer
    /// bottom edge.
    static let brandFont = "Comfortaa-SemiBold"
    static let brandFontSize: CGFloat = 450
    static let brandBaseline: CGFloat = 616
}

/// Digit width of the display. `.wide` is the initial design: 8 binary
/// digits per line, range ±255. `.narrow` fits 16 (±65535) into the same
/// width. Both reserve the leftmost character cell for the minus sign.
enum BinaryDisplayMode: String, CaseIterable, Identifiable {
    case wide
    case narrow

    var id: String { rawValue }

    var geometry: DisplayGeometry {
        switch self {
        case .wide:   return .wide
        case .narrow: return .narrow
        }
    }

    /// Binary digits per line, excluding the sign cell.
    var digitCount: Int { geometry.cellCount - 1 }
}

/// Display layout in design units, relative to the display's fill (the
/// 6950-unit square inside its border). Values from the SVG's
/// `Display-segments-wide` / `Display-segments-narrow` groups.
///
/// The display has 9 lines: digit lines 1, 3, 5, 7, 9 with operator lines
/// between them. Each digit line is a row of character cells; a cell can
/// light a ring (0), a bar (1) and a dash (minus sign), plus a binary point
/// just right of it — every cell but the rightmost has one.
struct DisplayGeometry {
    let cellCount: Int
    let firstCellX: CGFloat
    let cellPitch: CGFloat
    let cellWidth: CGFloat
    /// Binary point centre, relative to its cell's left edge.
    let pointX: CGFloat

    static let wide   = DisplayGeometry(cellCount: 9,  firstCellX: 325, cellPitch: 720, cellWidth: 540, pointX: 630)
    static let narrow = DisplayGeometry(cellCount: 17, firstCellX: 349, cellPitch: 374, cellWidth: 270, pointX: 315)

    static let size: CGFloat       = 6950
    static let lineCount           = 9
    static let firstLineY: CGFloat = 415
    static let linePitch: CGFloat  = 697.5
    static let cellHeight: CGFloat = 540
    static let stroke: CGFloat     = 45
    static let pointY: CGFloat     = 495
    /// The SVG writes the point as r = 22.5, but it inherits the group's
    /// 45-unit stroke, so it renders at r = 45 (a 90 × 90 oval in Sketch).
    static let pointRadius: CGFloat = 45

    /// Operator glyph centre. Per the SVG this sits 22.5 units right of the
    /// wide display's last digit column (its dash ends flush with the
    /// digits' outer edge rather than their stroke centres).
    static let operatorX: CGFloat = 6377.5

    func cellX(_ column: Int) -> CGFloat {
        firstCellX + CGFloat(column) * cellPitch
    }

    static func lineY(_ line: Int) -> CGFloat {
        firstLineY + CGFloat(line) * linePitch
    }

    static func isDigitLine(_ line: Int) -> Bool {
        line % 2 == 0
    }
}

enum CalcLayout {
    /// Vertical reserve per side above/below the centered calculator, as a
    /// ratio of the screen's *short* side — consistent across orientations.
    static let verticalReserveRatio: CGFloat = 0.15

    /// Soft cap on calc width as a fraction of the screen's short side,
    /// applied when the calc is height-constrained.
    static let maxCalcWidthRatio: CGFloat = 0.85
}

/// Design geometry scaled to the screen. One uniform scale keeps every
/// proportion of the design intact.
struct CalculatorMetrics {
    /// Points per design unit.
    let scale: CGFloat

    var calcWidth: CGFloat    { Design.calcWidth * scale }
    var calcHeight: CGFloat   { Design.calcHeight * scale }
    var calcCorner: CGFloat   { Design.calcCorner * scale }
    var calcPaddingH: CGFloat { (Design.stroke + Design.calcPaddingH) * scale }
    var calcPaddingV: CGFloat { (Design.stroke + Design.calcPaddingV) * scale }
    var panelSize: CGFloat    { Design.panelSize * scale }
    var panelCorner: CGFloat  { Design.panelCorner * scale }
    var panelGap: CGFloat     { Design.panelGap * scale }
    var keySize: CGFloat      { Design.keySize * scale }
    var keyCorner: CGFloat    { Design.keyCorner * scale }
    var spacing: CGFloat      { Design.spacing * scale }
    var stroke: CGFloat       { Design.stroke * scale }

    static func fit(into available: CGSize,
                    maxCalcWidth: CGFloat = .infinity) -> CalculatorMetrics {
        let heightOverWidth = Design.calcHeight / Design.calcWidth
        let widthFromHeight = available.height / heightOverWidth

        // Same fitting as TernaryCalc: when height is the tighter constraint
        // apply `maxCalcWidth` so tablets don't end up with calcs glued to
        // the edges; when width is (phone portrait), still leave a small
        // margin (the 0.928 factor) so the calc doesn't kiss the screen edges.
        let calcWidth: CGFloat
        if widthFromHeight < available.width {
            calcWidth = min(widthFromHeight, maxCalcWidth)
        } else {
            calcWidth = available.width * 0.928
        }
        return CalculatorMetrics(scale: calcWidth / Design.calcWidth)
    }
}

private struct BinaryDisplayModeKey: EnvironmentKey {
    static let defaultValue: BinaryDisplayMode = .wide
}

extension EnvironmentValues {
    var binaryDisplayMode: BinaryDisplayMode {
        get { self[BinaryDisplayModeKey.self] }
        set { self[BinaryDisplayModeKey.self] = newValue }
    }
}
