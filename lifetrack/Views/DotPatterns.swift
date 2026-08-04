import Foundation

enum ChangeDirection {
  case increasing, decreasing

  func delay(forRow row: Int, rowCount: Int) -> Double {
    let interval = 0.035
    switch self {
    case .decreasing: return Double(row) * interval
    case .increasing: return Double(rowCount - 1 - row) * interval
    }
  }
}

/// One bitmap-font definition for the dot-matrix life total. Rows/columns are
/// per-font, so the whole rendering pipeline (`DotDigitView`, `DotNumberView`,
/// `GameBoardView`'s dot-size fitting) stays size-agnostic — swapping fonts of
/// different dimensions just reflows.
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

/// Points at the active `DotFont`. Defaults to `.wide` (the original app font).
/// Assigning a different style posts `didChange`, which `DotNumberView` observes
/// to rebuild its digit views at the new dimensions.
enum DotFontSettings {
  static let didChange = Notification.Name("DotFontDidChange")

  static var current: DotFont = .wide {
    didSet {
      guard current.id != oldValue.id else { return }
      NotificationCenter.default.post(name: didChange, object: nil)
    }
  }
}

// MARK: - Font catalog
//
// Six dot-matrix styles, all transcribed from the reference artwork. They share
// the same glyph shapes but differ in cell dimensions (columns × rows):
//
//   tall    3 × 7
//   narrow  3 × 5
//   normal  4 × 5
//   wide    5 × 5   (the original app font — `grid` is kept as an alias)
//   xwide   6 × 5
//   xxwide  7 × 5
//
// Each `*Raw` array is indexed by value (`digits[0] == "0"`), with each glyph a
// flat row-major `columns × rows` array of 0/1. `*Minus` is the matching minus
// glyph (a centered horizontal bar on the middle row).

extension DotFont {
    static let tall = DotFont(
        id: "tall3x7", rows: 7, columns: 3,
        digits: tallRaw.map { $0.map { $0 == 1 } },
        minus: tallMinus.map { $0 == 1 }
    )
    static let narrow = DotFont(
        id: "narrow3x5", rows: 5, columns: 3,
        digits: narrowRaw.map { $0.map { $0 == 1 } },
        minus: narrowMinus.map { $0 == 1 }
    )
    static let normal = DotFont(
        id: "normal4x5", rows: 5, columns: 4,
        digits: normalRaw.map { $0.map { $0 == 1 } },
        minus: normalMinus.map { $0 == 1 }
    )
    /// The original app font (5 × 5). `grid` keeps its old id for compatibility.
    static let wide = grid
    static let grid = DotFont(
        id: "grid5", rows: 5, columns: 5,
        digits: wideRaw.map { $0.map { $0 == 1 } },
        minus: wideMinus.map { $0 == 1 }
    )
    static let xwide = DotFont(
        id: "xwide6x5", rows: 5, columns: 6,
        digits: xwideRaw.map { $0.map { $0 == 1 } },
        minus: xwideMinus.map { $0 == 1 }
    )
    static let xxwide = DotFont(
        id: "xxwide7x5", rows: 5, columns: 7,
        digits: xxwideRaw.map { $0.map { $0 == 1 } },
        minus: xxwideMinus.map { $0 == 1 }
    )

    /// All styles in display order (tall → xxwide), for any picker UI.
    static let allStyles: [DotFont] = [tall, narrow, normal, wide, xwide, xxwide]
}

// MARK: - tall 3 × 7

private let tallRaw: [[Int]] = [
    // 0
    [1,1,1,
     1,0,1,
     1,0,1,
     1,0,1,
     1,0,1,
     1,0,1,
     1,1,1],
    // 1
    [1,1,0,
     0,1,0,
     0,1,0,
     0,1,0,
     0,1,0,
     0,1,0,
     1,1,1],
    // 2
    [1,1,1,
     0,0,1,
     0,0,1,
     1,1,1,
     1,0,0,
     1,0,0,
     1,1,1],
    // 3
    [1,1,1,
     0,0,1,
     0,0,1,
     0,1,1,
     0,0,1,
     0,0,1,
     1,1,1],
    // 4
    [1,0,1,
     1,0,1,
     1,0,1,
     1,0,1,
     1,1,1,
     0,0,1,
     0,0,1],
    // 5
    [1,1,1,
     1,0,0,
     1,0,0,
     1,1,1,
     0,0,1,
     0,0,1,
     1,1,1],
    // 6
    [1,1,1,
     1,0,0,
     1,0,0,
     1,1,1,
     1,0,1,
     1,0,1,
     1,1,1],
    // 7
    [1,1,1,
     0,0,1,
     0,0,1,
     0,0,1,
     0,1,0,
     0,1,0,
     0,1,0],
    // 8
    [1,1,1,
     1,0,1,
     1,0,1,
     1,1,1,
     1,0,1,
     1,0,1,
     1,1,1],
    // 9
    [1,1,1,
     1,0,1,
     1,0,1,
     1,1,1,
     0,0,1,
     0,0,1,
     1,1,1],
]
private let tallMinus: [Int] = [
    0,0,0,
    0,0,0,
    0,0,0,
    1,1,1,
    0,0,0,
    0,0,0,
    0,0,0,
]

// MARK: - narrow 3 × 5

private let narrowRaw: [[Int]] = [
    // 0
    [1,1,1,
     1,0,1,
     1,0,1,
     1,0,1,
     1,1,1],
    // 1
    [1,1,0,
     0,1,0,
     0,1,0,
     0,1,0,
     1,1,1],
    // 2
    [1,1,1,
     0,0,1,
     1,1,1,
     1,0,0,
     1,1,1],
    // 3
    [1,1,1,
     0,0,1,
     0,1,1,
     0,0,1,
     1,1,1],
    // 4
    [1,0,1,
     1,0,1,
     1,0,1,
     1,1,1,
     0,0,1],
    // 5
    [1,1,1,
     1,0,0,
     1,1,1,
     0,0,1,
     1,1,1],
    // 6
    [1,1,1,
     1,0,0,
     1,1,1,
     1,0,1,
     1,1,1],
    // 7
    [1,1,1,
     0,0,1,
     0,1,0,
     0,1,0,
     0,1,0],
    // 8
    [1,1,1,
     1,0,1,
     1,1,1,
     1,0,1,
     1,1,1],
    // 9
    [1,1,1,
     1,0,1,
     1,1,1,
     0,0,1,
     1,1,1],
]
private let narrowMinus: [Int] = [
    0,0,0,
    0,0,0,
    1,1,1,
    0,0,0,
    0,0,0,
]

// MARK: - normal 4 × 5

private let normalRaw: [[Int]] = [
    // 0
    [1,1,1,1,
     1,0,0,1,
     1,0,0,1,
     1,0,0,1,
     1,1,1,1],
    // 1
    [0,1,1,0,
     1,0,1,0,
     0,0,1,0,
     0,0,1,0,
     1,1,1,1],
    // 2
    [1,1,1,1,
     0,0,0,1,
     1,1,1,1,
     1,0,0,0,
     1,1,1,1],
    // 3
    [1,1,1,1,
     0,0,0,1,
     0,1,1,1,
     0,0,0,1,
     1,1,1,1],
    // 4
    [1,0,0,1,
     1,0,0,1,
     1,0,0,1,
     1,1,1,1,
     0,0,0,1],
    // 5
    [1,1,1,1,
     1,0,0,0,
     1,1,1,1,
     0,0,0,1,
     1,1,1,1],
    // 6
    [1,1,1,1,
     1,0,0,0,
     1,1,1,1,
     1,0,0,1,
     1,1,1,1],
    // 7
    [1,1,1,1,
     0,0,0,1,
     0,0,1,0,
     0,1,0,0,
     0,1,0,0],
    // 8
    [1,1,1,1,
     1,0,0,1,
     1,1,1,1,
     1,0,0,1,
     1,1,1,1],
    // 9
    [1,1,1,1,
     1,0,0,1,
     1,1,1,1,
     0,0,0,1,
     1,1,1,1],
]
private let normalMinus: [Int] = [
    0,0,0,0,
    0,0,0,0,
    0,1,1,0,
    0,0,0,0,
    0,0,0,0,
]

// MARK: - wide 5 × 5 (original app font)

private let wideRaw: [[Int]] = [
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
private let wideMinus: [Int] = [
    0,0,0,0,0,
    0,0,0,0,0,
    0,1,1,1,0,
    0,0,0,0,0,
    0,0,0,0,0,
]

// MARK: - xwide 6 × 5

private let xwideRaw: [[Int]] = [
    // 0
    [1,1,1,1,1,1,
     1,0,0,0,0,1,
     1,0,0,0,0,1,
     1,0,0,0,0,1,
     1,1,1,1,1,1],
    // 1
    [0,1,1,1,0,0,
     1,0,0,1,0,0,
     0,0,0,1,0,0,
     0,0,0,1,0,0,
     1,1,1,1,1,1],
    // 2
    [1,1,1,1,1,1,
     0,0,0,0,0,1,
     1,1,1,1,1,1,
     1,0,0,0,0,0,
     1,1,1,1,1,1],
    // 3
    [1,1,1,1,1,1,
     0,0,0,0,0,1,
     0,1,1,1,1,1,
     0,0,0,0,0,1,
     1,1,1,1,1,1],
    // 4
    [1,0,0,0,0,1,
     1,0,0,0,0,1,
     1,0,0,0,0,1,
     1,1,1,1,1,1,
     0,0,0,0,0,1],
    // 5
    [1,1,1,1,1,1,
     1,0,0,0,0,0,
     1,1,1,1,1,1,
     0,0,0,0,0,1,
     1,1,1,1,1,1],
    // 6
    [1,1,1,1,1,1,
     1,0,0,0,0,0,
     1,1,1,1,1,1,
     1,0,0,0,0,1,
     1,1,1,1,1,1],
    // 7
    [1,1,1,1,1,1,
     0,0,0,0,0,1,
     0,0,0,1,1,0,
     0,0,1,0,0,0,
     0,0,1,0,0,0],
    // 8
    [1,1,1,1,1,1,
     1,0,0,0,0,1,
     1,1,1,1,1,1,
     1,0,0,0,0,1,
     1,1,1,1,1,1],
    // 9
    [1,1,1,1,1,1,
     1,0,0,0,0,1,
     1,1,1,1,1,1,
     0,0,0,0,0,1,
     1,1,1,1,1,1],
]
private let xwideMinus: [Int] = [
    0,0,0,0,0,0,
    0,0,0,0,0,0,
    0,1,1,1,1,0,
    0,0,0,0,0,0,
    0,0,0,0,0,0,
]

// MARK: - xxwide 7 × 5

private let xxwideRaw: [[Int]] = [
    // 0
    [1,1,1,1,1,1,1,
     1,0,0,0,0,0,1,
     1,0,0,0,0,0,1,
     1,0,0,0,0,0,1,
     1,1,1,1,1,1,1],
    // 1
    [0,1,1,1,0,0,0,
     1,0,0,1,0,0,0,
     0,0,0,1,0,0,0,
     0,0,0,1,0,0,0,
     1,1,1,1,1,1,1],
    // 2
    [1,1,1,1,1,1,1,
     0,0,0,0,0,0,1,
     1,1,1,1,1,1,1,
     1,0,0,0,0,0,0,
     1,1,1,1,1,1,1],
    // 3
    [1,1,1,1,1,1,1,
     0,0,0,0,0,0,1,
     0,1,1,1,1,1,1,
     0,0,0,0,0,0,1,
     1,1,1,1,1,1,1],
    // 4
    [1,0,0,0,0,0,1,
     1,0,0,0,0,0,1,
     1,0,0,0,0,0,1,
     1,1,1,1,1,1,1,
     0,0,0,0,0,0,1],
    // 5
    [1,1,1,1,1,1,1,
     1,0,0,0,0,0,0,
     1,1,1,1,1,1,1,
     0,0,0,0,0,0,1,
     1,1,1,1,1,1,1],
    // 6
    [1,1,1,1,1,1,1,
     1,0,0,0,0,0,0,
     1,1,1,1,1,1,1,
     1,0,0,0,0,0,1,
     1,1,1,1,1,1,1],
    // 7
    [1,1,1,1,1,1,1,
     0,0,0,0,0,0,1,
     0,0,0,0,1,1,0,
     0,0,0,1,0,0,0,
     0,0,0,1,0,0,0],
    // 8
    [1,1,1,1,1,1,1,
     1,0,0,0,0,0,1,
     1,1,1,1,1,1,1,
     1,0,0,0,0,0,1,
     1,1,1,1,1,1,1],
    // 9
    [1,1,1,1,1,1,1,
     1,0,0,0,0,0,1,
     1,1,1,1,1,1,1,
     0,0,0,0,0,0,1,
     1,1,1,1,1,1,1],
]
private let xxwideMinus: [Int] = [
    0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,
    0,1,1,1,1,1,0,
    0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,
]
