import CoreGraphics
import Foundation

/// One seat in a `PlayerLayout`. Seats are ordered the same as the dots in the
/// matching SVG file in `playercounts/` so seat index == player id.
///
/// - `iconCenter`: dot center in the 32×32 icon viewbox; used by
///   `PlayerLayoutIconView` for the selector grid.
/// - `cellRect`: the cell's rectangle in unit-square (0…1) board coordinates.
///   `GameBoardView` projects this directly into the board's frame. Adjacent
///   rectangles share their normalized edge without an inter-cell gap.
/// - `rotationDegrees`: how the cell's content is rotated so the player at this
///   seat reads the screen right-side-up. 0 = bottom-edge player, 180 = top,
///   90 = left, -90 = right.
/// - `clockwiseIndex`: hand-tuned physical clockwise seat-order metadata.
///   Dot-level lighthouse motion uses projected dot angles directly, but this
///   remains the canonical ordering for any discrete seat sequence.
struct PlayerSeat {
  let iconCenter: CGPoint
  let cellRect: CGRect
  let rotationDegrees: CGFloat
  let clockwiseIndex: Int
}

/// All eight player-count + variant combinations the player-count selector
/// offers. The actual game-board cell layout, the dot icon shown in the
/// selector, and the commander-damage source indicator are all driven from
/// this enum.
///
/// **Coordinate frame.** The source SVGs in `playercounts/` are drawn in
/// portrait orientation: the 32×32 viewbox represents the phone screen with x
/// running across (left → right) and y running top → bottom. Each `iconCenter`
/// equals the SVG `cx, cy` verbatim. These are schematic seat positions for the
/// picker; `cellRect` remains the source of truth for real board geometry.
enum PlayerLayout: String, CaseIterable {
  case two   = "2"
  case three = "3"
  case fourA = "4a"
  case fourB = "4b"
  case fiveA = "5a"
  case fiveB = "5b"
  case sixA  = "6a"
  case sixB  = "6b"

  static let iconViewbox: CGFloat = 32

  var count: Int {
    switch self {
    case .two:   return 2
    case .three: return 3
    case .fourA, .fourB: return 4
    case .fiveA, .fiveB: return 5
    case .sixA,  .sixB:  return 6
    }
  }

  /// Order matches the dot order in the source SVG (so seat index == player id).
  var seats: [PlayerSeat] {
    switch self {
    case .two:
      // SVG: (16, 11.5), (16, 20.4) — vertical pair, top + bottom edges.
      return [
        PlayerSeat(iconCenter: CGPoint(x: 16, y: 11.5),
               cellRect: CGRect(x: 0, y: 0, width: 1, height: 0.5),
               rotationDegrees: 180,
               clockwiseIndex: 0),
        PlayerSeat(iconCenter: CGPoint(x: 16, y: 20.4),
               cellRect: CGRect(x: 0, y: 0.5, width: 1, height: 0.5),
               rotationDegrees: 0,
               clockwiseIndex: 1),
      ]

    case .three:
      // SVG: (13, 11.5), (13, 20.4), (21, 16) — 2 left-edge stacked, 1 right-edge full.
      return [
        PlayerSeat(iconCenter: CGPoint(x: 13, y: 11.5),
               cellRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5),
               rotationDegrees: 90,
               clockwiseIndex: 2),
        PlayerSeat(iconCenter: CGPoint(x: 13, y: 20.4),
               cellRect: CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5),
               rotationDegrees: 90,
               clockwiseIndex: 1),
        PlayerSeat(iconCenter: CGPoint(x: 21, y: 16),
               cellRect: CGRect(x: 0.5, y: 0, width: 0.5, height: 1),
               rotationDegrees: -90,
               clockwiseIndex: 0),
      ]

    case .fourA:
      // SVG: 2×2 corners at x=11.5 / 20.5. Left column rot +90, right column rot -90.
      return [
        PlayerSeat(iconCenter: CGPoint(x: 11.5, y: 11.5),
               cellRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5),
               rotationDegrees: 90,
               clockwiseIndex: 3),
        PlayerSeat(iconCenter: CGPoint(x: 11.5, y: 20.5),
               cellRect: CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5),
               rotationDegrees: 90,
               clockwiseIndex: 2),
        PlayerSeat(iconCenter: CGPoint(x: 20.5, y: 11.5),
               cellRect: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5),
               rotationDegrees: -90,
               clockwiseIndex: 0),
        PlayerSeat(iconCenter: CGPoint(x: 20.5, y: 20.5),
               cellRect: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
               rotationDegrees: -90,
               clockwiseIndex: 1),
      ]

    case .fourB:
      // SVG diamond: (10,16) left, (16,22) bottom, (16,10) top, (22,16) right.
      // Equal-area seats: quarter-height top/bottom bands and a half-height
      // middle band split between the left and right players.
      let quarter: CGFloat = 0.25
      return [
        PlayerSeat(iconCenter: CGPoint(x: 10, y: 16),
               cellRect: CGRect(x: 0, y: quarter, width: 0.5, height: 0.5),
               rotationDegrees: 90,
               clockwiseIndex: 3),
        PlayerSeat(iconCenter: CGPoint(x: 16, y: 22),
               cellRect: CGRect(x: 0, y: 0.75, width: 1, height: quarter),
               rotationDegrees: 0,
               clockwiseIndex: 2),
        PlayerSeat(iconCenter: CGPoint(x: 16, y: 10),
               cellRect: CGRect(x: 0, y: 0, width: 1, height: quarter),
               rotationDegrees: 180,
               clockwiseIndex: 0),
        PlayerSeat(iconCenter: CGPoint(x: 22, y: 16),
               cellRect: CGRect(x: 0.5, y: quarter, width: 0.5, height: 0.5),
               rotationDegrees: -90,
               clockwiseIndex: 1),
      ]

    case .fiveA:
      // SVG: 4 side-edge players in a 2×2 cluster (rows y=8 and y=17,
      // cols x=11.6 left and x=20.5 right) + 1 bottom-edge player at
      // (16, 25). The board uses five normalized rows: each split side-player
      // band receives two rows and the full-width end seat receives one.
      // The *players* in the split bands sit on the left and right sides of
      // the table (rot ±90), not the top edge.
      let fifth: CGFloat = 1.0 / 5.0
      let sideBandHeight = 2 * fifth
      return [
        PlayerSeat(iconCenter: CGPoint(x: 20.5, y: 8),
               cellRect: CGRect(x: 0.5, y: 0, width: 0.5, height: sideBandHeight),
               rotationDegrees: -90,
               clockwiseIndex: 0),
        PlayerSeat(iconCenter: CGPoint(x: 11.6, y: 8),
               cellRect: CGRect(x: 0, y: 0, width: 0.5, height: sideBandHeight),
               rotationDegrees: 90,
               clockwiseIndex: 4),
        PlayerSeat(iconCenter: CGPoint(x: 20.5, y: 17),
               cellRect: CGRect(x: 0.5, y: sideBandHeight, width: 0.5, height: sideBandHeight),
               rotationDegrees: -90,
               clockwiseIndex: 1),
        PlayerSeat(iconCenter: CGPoint(x: 11.6, y: 17),
               cellRect: CGRect(x: 0, y: sideBandHeight, width: 0.5, height: sideBandHeight),
               rotationDegrees: 90,
               clockwiseIndex: 3),
        PlayerSeat(iconCenter: CGPoint(x: 16, y: 25),
               cellRect: CGRect(x: 0, y: 4 * fifth, width: 1, height: fifth),
               rotationDegrees: 0,
               clockwiseIndex: 2),
      ]

    case .fiveB:
      // SVG: 3 left-edge players (thirds at y=7, 16, 25) + 2 right-edge players
      // (halves at y=11.5, 20.5).
      let third: CGFloat = 1.0 / 3.0
      return [
        PlayerSeat(iconCenter: CGPoint(x: 11.5, y: 25),
               cellRect: CGRect(x: 0, y: 2 * third, width: 0.5, height: third),
               rotationDegrees: 90,
               clockwiseIndex: 2),
        PlayerSeat(iconCenter: CGPoint(x: 11.5, y: 16),
               cellRect: CGRect(x: 0, y: third, width: 0.5, height: third),
               rotationDegrees: 90,
               clockwiseIndex: 3),
        PlayerSeat(iconCenter: CGPoint(x: 20, y: 20.5),
               cellRect: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
               rotationDegrees: -90,
               clockwiseIndex: 1),
        PlayerSeat(iconCenter: CGPoint(x: 20, y: 11.5),
               cellRect: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5),
               rotationDegrees: -90,
               clockwiseIndex: 0),
        PlayerSeat(iconCenter: CGPoint(x: 11.5, y: 7),
               cellRect: CGRect(x: 0, y: 0, width: 0.5, height: third),
               rotationDegrees: 90,
               clockwiseIndex: 4),
      ]

    case .sixA:
      // SVG: 3 rows × 2 cols. Left col rot +90, right col rot -90.
      let third: CGFloat = 1.0 / 3.0
      return [
        PlayerSeat(iconCenter: CGPoint(x: 20.5, y: 7),
               cellRect: CGRect(x: 0.5, y: 0, width: 0.5, height: third),
               rotationDegrees: -90,
               clockwiseIndex: 0),
        PlayerSeat(iconCenter: CGPoint(x: 11.5, y: 7),
               cellRect: CGRect(x: 0, y: 0, width: 0.5, height: third),
               rotationDegrees: 90,
               clockwiseIndex: 5),
        PlayerSeat(iconCenter: CGPoint(x: 20.5, y: 16),
               cellRect: CGRect(x: 0.5, y: third, width: 0.5, height: third),
               rotationDegrees: -90,
               clockwiseIndex: 1),
        PlayerSeat(iconCenter: CGPoint(x: 11.5, y: 16),
               cellRect: CGRect(x: 0, y: third, width: 0.5, height: third),
               rotationDegrees: 90,
               clockwiseIndex: 4),
        PlayerSeat(iconCenter: CGPoint(x: 20.5, y: 25),
               cellRect: CGRect(x: 0.5, y: 2 * third, width: 0.5, height: third),
               rotationDegrees: -90,
               clockwiseIndex: 2),
        PlayerSeat(iconCenter: CGPoint(x: 11.5, y: 25),
               cellRect: CGRect(x: 0, y: 2 * third, width: 0.5, height: third),
               rotationDegrees: 90,
               clockwiseIndex: 3),
      ]

    case .sixB:
      // SVG: 6-row grid. The full-width end seats use one row each; the two
      // split middle bands use two rows each so opposing ± controls do not
      // collide at their shared edge.
      let sixth: CGFloat = 1.0 / 6.0
      let third: CGFloat = 1.0 / 3.0
      return [
        PlayerSeat(iconCenter: CGPoint(x: 20.5, y: 12),
               cellRect: CGRect(x: 0.5, y: sixth, width: 0.5, height: third),
               rotationDegrees: -90,
               clockwiseIndex: 1),
        PlayerSeat(iconCenter: CGPoint(x: 11.5, y: 12),
               cellRect: CGRect(x: 0, y: sixth, width: 0.5, height: third),
               rotationDegrees: 90,
               clockwiseIndex: 5),
        PlayerSeat(iconCenter: CGPoint(x: 20.5, y: 20),
               cellRect: CGRect(x: 0.5, y: 0.5, width: 0.5, height: third),
               rotationDegrees: -90,
               clockwiseIndex: 2),
        PlayerSeat(iconCenter: CGPoint(x: 11.5, y: 20),
               cellRect: CGRect(x: 0, y: 0.5, width: 0.5, height: third),
               rotationDegrees: 90,
               clockwiseIndex: 4),
        PlayerSeat(iconCenter: CGPoint(x: 16, y: 28),
               cellRect: CGRect(x: 0, y: 5 * sixth, width: 1, height: sixth),
               rotationDegrees: 0,
               clockwiseIndex: 3),
        PlayerSeat(iconCenter: CGPoint(x: 16, y: 4),
               cellRect: CGRect(x: 0, y: 0, width: 1, height: sixth),
               rotationDegrees: 180,
               clockwiseIndex: 0),
      ]
    }
  }

  /// Display order for the player-count selector (2 columns × 4 rows).
  /// Reading order: row 1 = 2-player, 3-player; row 2 = 4-a, 4-b; etc.
  static let selectorOrder: [PlayerLayout] = [
    .two,   .three,
    .fourA, .fourB,
    .fiveA, .fiveB,
    .sixA,  .sixB,
  ]
}

/// Shared spatial rhythm. Layout geometry starts on a 4pt base grid and uses
/// 20pt as its visible major step: 18pt board dots occupy a 20pt pitch, icons
/// are 20pt, and the fixed edit band is five major steps. Seat rectangles
/// remain normalized fractions so they scale with the playable board on every
/// device and meet without gaps at shared edges.
enum LayoutGrid {
  static let baseUnit: CGFloat = 4
  static let majorStep: CGFloat = 20
}

/// Global content insets for the playable area. Both values sit on the 4pt
/// base grid. Every screen uses this frame instead of deriving its own safe
/// area, so normalized seat edges project consistently across the app.
enum BoardInsets {
  static let topBottom = 13 * LayoutGrid.baseUnit
  static let leftRight = 2 * LayoutGrid.baseUnit
}
