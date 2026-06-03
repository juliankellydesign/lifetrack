import Foundation

enum ChangeDirection {
    case increasing, decreasing

    func delay(forRow row: Int) -> Double {
        let interval = 0.035
        switch self {
        case .decreasing: return Double(row) * interval
        case .increasing: return Double(DotPatterns.rows - 1 - row) * interval
        }
    }
}

/// One bitmap-font definition for the dot-matrix life total.
struct DotFont {
    let id: String
    let rows: Int
    let columns: Int
    let digits: [[Bool]]
    let minus: [Bool]

    func pattern(for digit: Int) -> [Bool] {
        guard digit >= 0, digit <= 9 else { return minus }
        return digits[digit]
    }
}

/// Points at the active `DotFont`. There's no longer an in-app font picker, so
/// this just vends the one bundled font. `didChange` is kept because
/// `DotNumberView` observes it to rebuild — it simply never fires now.
enum DotFontSettings {
    static let didChange = Notification.Name("DotFontDidChange")
    static var current: DotFont { .grid }
}

/// Thin proxy used by all the dot-rendering views — reads through to whatever
/// font `DotFontSettings` currently points at.
enum DotPatterns {
    static var rows: Int { DotFontSettings.current.rows }
    static var columns: Int { DotFontSettings.current.columns }
    static func pattern(for digit: Int) -> [Bool] { DotFontSettings.current.pattern(for: digit) }
    static var minus: [Bool] { DotFontSettings.current.minus }
}

// MARK: - Grid 5 × 5
//
// Transcribed from the reference artwork: a compact 5-wide × 5-tall dot grid
// with full-width strokes. `digits` is indexed by value (digits[0] == "0").

extension DotFont {
    static let grid = DotFont(
        id: "grid5",
        rows: 5,
        columns: 5,
        digits: gridRaw.map { $0.map { $0 == 1 } },
        minus: gridMinus.map { $0 == 1 }
    )
}

private let gridRaw: [[Int]] = [
    // 0
    [1,1,1,1,1,
     1,0,0,0,1,
     1,0,0,0,1,
     1,0,0,0,1,
     1,1,1,1,1],
    // 1
    [0,1,1,0,0,
     1,0,1,0,0,
     0,0,1,0,0,
     0,0,1,0,0,
     1,1,1,1,1],
    // 2
    [1,1,1,1,1,
     0,0,0,0,1,
     1,1,1,1,1,
     1,0,0,0,0,
     1,1,1,1,1],
    // 3
    [1,1,1,1,1,
     0,0,0,0,1,
     0,1,1,1,1,
     0,0,0,0,1,
     1,1,1,1,1],
    // 4
    [1,0,0,0,1,
     1,0,0,0,1,
     1,0,0,0,1,
     1,1,1,1,1,
     0,0,0,0,1],
    // 5
    [1,1,1,1,1,
     1,0,0,0,0,
     1,1,1,1,1,
     0,0,0,0,1,
     1,1,1,1,1],
    // 6
    [1,1,1,1,1,
     1,0,0,0,0,
     1,1,1,1,1,
     1,0,0,0,1,
     1,1,1,1,1],
    // 7
    [1,1,1,1,1,
     0,0,0,0,1,
     0,0,0,1,0,
     0,0,1,0,0,
     0,0,1,0,0],
    // 8
    [1,1,1,1,1,
     1,0,0,0,1,
     1,1,1,1,1,
     1,0,0,0,1,
     1,1,1,1,1],
    // 9
    [1,1,1,1,1,
     1,0,0,0,1,
     1,1,1,1,1,
     0,0,0,0,1,
     1,1,1,1,1],
]

private let gridMinus: [Int] = [
    0,0,0,0,0,
    0,0,0,0,0,
    0,1,1,1,0,
    0,0,0,0,0,
    0,0,0,0,0,
]
