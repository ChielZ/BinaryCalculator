import Foundation

enum Bit: Int, Hashable, CaseIterable {
    case zero = 0
    case one  = 1
}

/// Exact rational number stored as p/q (denominator > 0, GCD-reduced).
/// Used as the calculator's authoritative value type — the display is
/// derived by truncating the binary expansion to the available digits.
struct BinaryNumber: Equatable {
    let numerator: Int
    let denominator: Int

    static let zero = BinaryNumber(rawNumerator: 0, rawDenominator: 1)

    enum OperationError: Error {
        case overflow
        case divisionByZero
    }

    private init(rawNumerator: Int, rawDenominator: Int) {
        self.numerator   = rawNumerator
        self.denominator = rawDenominator
    }

    /// Construct from any p/q (q ≠ 0); normalizes sign and reduces by GCD.
    static func make(numerator: Int, denominator: Int) -> BinaryNumber? {
        guard denominator != 0 else { return nil }
        var n = numerator, d = denominator
        if d < 0 {
            guard d != .min, n != .min else { return nil }
            n = -n; d = -d
        }
        let g = gcd(abs(n), d)
        if g > 1 { n /= g; d /= g }
        return BinaryNumber(rawNumerator: n, rawDenominator: d)
    }

    static func from(integer n: Int) -> BinaryNumber {
        BinaryNumber(rawNumerator: n, rawDenominator: 1)
    }

    /// Value of a typed entry: integer bits most-significant first, then the
    /// fractional bits. Entries are at most 16 digits, so this can't overflow.
    static func from(integer: [Bit], fractional: [Bit]) -> BinaryNumber? {
        var n = 0
        for bit in integer + fractional {
            n = n * 2 + bit.rawValue
        }
        return make(numerator: n, denominator: 1 << fractional.count)
    }
}

private func gcd(_ a: Int, _ b: Int) -> Int {
    var a = abs(a), b = abs(b)
    while b != 0 { (a, b) = (b, a % b) }
    return a == 0 ? 1 : a
}

// MARK: - Operations

extension BinaryNumber {
    func adding(_ other: BinaryNumber) -> Result<BinaryNumber, OperationError> {
        let (ad, o1) = numerator.multipliedReportingOverflow(by: other.denominator)
        let (bc, o2) = other.numerator.multipliedReportingOverflow(by: denominator)
        let (sum, o3) = ad.addingReportingOverflow(bc)
        let (denom, o4) = denominator.multipliedReportingOverflow(by: other.denominator)
        if o1 || o2 || o3 || o4 { return .failure(.overflow) }
        guard let r = BinaryNumber.make(numerator: sum, denominator: denom) else {
            return .failure(.overflow)
        }
        return .success(r)
    }

    func subtracting(_ other: BinaryNumber) -> Result<BinaryNumber, OperationError> {
        let (ad, o1) = numerator.multipliedReportingOverflow(by: other.denominator)
        let (bc, o2) = other.numerator.multipliedReportingOverflow(by: denominator)
        let (diff, o3) = ad.subtractingReportingOverflow(bc)
        let (denom, o4) = denominator.multipliedReportingOverflow(by: other.denominator)
        if o1 || o2 || o3 || o4 { return .failure(.overflow) }
        guard let r = BinaryNumber.make(numerator: diff, denominator: denom) else {
            return .failure(.overflow)
        }
        return .success(r)
    }

    func multiplying(_ other: BinaryNumber) -> Result<BinaryNumber, OperationError> {
        let (p, op) = numerator.multipliedReportingOverflow(by: other.numerator)
        let (q, oq) = denominator.multipliedReportingOverflow(by: other.denominator)
        if op || oq { return .failure(.overflow) }
        guard let r = BinaryNumber.make(numerator: p, denominator: q) else {
            return .failure(.overflow)
        }
        return .success(r)
    }

    func dividing(by other: BinaryNumber) -> Result<BinaryNumber, OperationError> {
        guard other.numerator != 0 else { return .failure(.divisionByZero) }
        let (p, op) = numerator.multipliedReportingOverflow(by: other.denominator)
        let (q, oq) = denominator.multipliedReportingOverflow(by: other.numerator)
        if op || oq { return .failure(.overflow) }
        guard let r = BinaryNumber.make(numerator: p, denominator: q) else {
            return .failure(.overflow)
        }
        return .success(r)
    }
}

// MARK: - Display conversion

/// One number's display digits. Integer digits are most-significant first
/// (at least one — fractions show a leading `0`); fractional digits follow
/// the binary point. `showPoint` is normally true iff there are fractional
/// digits, but an in-progress entry shows the point as soon as `.` is
/// pressed, before any fractional digit is typed.
struct DisplayDigits: Hashable {
    let negative: Bool
    let integer: [Bit]
    let fractional: [Bit]
    let showPoint: Bool

    init(negative: Bool, integer: [Bit], fractional: [Bit]) {
        self.negative = negative
        self.integer = integer
        self.fractional = fractional
        self.showPoint = !fractional.isEmpty
    }

    init(negative: Bool, integer: [Bit], fractional: [Bit], showPoint: Bool) {
        self.negative = negative
        self.integer = integer
        self.fractional = fractional
        self.showPoint = showPoint
    }
}

extension BinaryNumber {
    /// Convert to at most `maxDigits` binary digits. The integer part always
    /// shows in full — nil (overflow) if it needs more than `maxDigits` —
    /// and the fraction gets whatever digits remain, truncated toward zero:
    /// the displayed value has the same sign as the true value, with
    /// magnitude ≤ |true value|.
    ///
    /// Exact values drop trailing fractional zeros (1.1, not 1.1000000). A
    /// truncated value keeps every digit, as in the design's −1.0101010 for
    /// −4/3, so a full row of digits signals that the expansion continues —
    /// a tiny non-zero value shows as 0.0000000 rather than 0.
    func displayDigits(maxDigits: Int) -> DisplayDigits? {
        guard numerator != .min else { return nil }
        let p = abs(numerator)
        let q = denominator   // already > 0

        let intPart = p / q
        var integer: [Bit] = []
        var n = intPart
        repeat {
            integer.insert(n % 2 == 1 ? .one : .zero, at: 0)
            n /= 2
        } while n > 0
        if integer.count > maxDigits { return nil }

        var r = p - intPart * q
        var fractional: [Bit] = []
        for _ in 0..<(maxDigits - integer.count) {
            let (r2, ovf) = r.multipliedReportingOverflow(by: 2)
            if ovf { return nil }
            if r2 >= q {
                fractional.append(.one)
                r = r2 - q
            } else {
                fractional.append(.zero)
                r = r2
            }
        }
        if r == 0 {
            while let last = fractional.last, last == .zero {
                fractional.removeLast()
            }
        }

        return DisplayDigits(negative: numerator < 0,
                             integer: integer,
                             fractional: fractional)
    }
}
