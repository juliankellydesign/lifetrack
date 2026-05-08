import CoreGraphics
import Foundation

/// One seat in a `PlayerLayout`. Seats are ordered the same as the dots in the
/// matching SVG file in `Resources/PlayerLayouts/` so seat index == player id.
///
/// - `iconCenter`: dot center in the 32×32 icon viewbox; used by
///   `PlayerLayoutIconView` for both the selector grid and commander-damage badges.
/// - `cellRect`: the cell's rectangle in unit-square (0…1) board coordinates.
///   `GameBoardView` projects this into the board's frame and applies inter-cell
///   gutters automatically (any edge `> 0` or `< 1` gets a half-gap inset).
/// - `rotationDegrees`: how the cell's content is rotated so the player at this
///   seat reads the screen right-side-up. 0 = bottom-edge player, 180 = top,
///   90 = left, -90 = right.
/// - `clockwiseIndex`: position in the clockwise-from-12-o'clock stagger used
///   by `GameBoardView.playWipeIn()`. 0 fires first, then `1`, then `2`, etc.
///   Hand-tuned per layout so the roll-in walks "around the table" in the
///   physical order players sit, regardless of seat-id (SVG) order.
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
/// equals the SVG `cx, cy` verbatim, which is also exactly where that player's
/// cell lives on the real game board. The picker icons therefore line up
/// pixel-for-pixel with the actual seating arrangement they describe.
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
            // Three horizontal bands; middle band split between left and right players.
            let third: CGFloat = 1.0 / 3.0
            return [
                PlayerSeat(iconCenter: CGPoint(x: 10, y: 16),
                           cellRect: CGRect(x: 0, y: third, width: 0.5, height: third),
                           rotationDegrees: 90,
                           clockwiseIndex: 3),
                PlayerSeat(iconCenter: CGPoint(x: 16, y: 22),
                           cellRect: CGRect(x: 0, y: 2 * third, width: 1, height: third),
                           rotationDegrees: 0,
                           clockwiseIndex: 2),
                PlayerSeat(iconCenter: CGPoint(x: 16, y: 10),
                           cellRect: CGRect(x: 0, y: 0, width: 1, height: third),
                           rotationDegrees: 180,
                           clockwiseIndex: 0),
                PlayerSeat(iconCenter: CGPoint(x: 22, y: 16),
                           cellRect: CGRect(x: 0.5, y: third, width: 0.5, height: third),
                           rotationDegrees: -90,
                           clockwiseIndex: 1),
            ]

        case .fiveA:
            // SVG: 4 side-edge players in a 2×2 cluster (rows y=8 and y=17,
            // cols x=11.6 left and x=20.5 right) + 1 bottom-edge player at
            // (16, 25). Cells form a 2×2 grid in the top 2/3 of the board with
            // a full-width bottom strip, but the *players* sit on the left and
            // right sides of the table (rot ±90), not the top edge.
            let third: CGFloat = 1.0 / 3.0
            return [
                PlayerSeat(iconCenter: CGPoint(x: 20.5, y: 8),
                           cellRect: CGRect(x: 0.5, y: 0, width: 0.5, height: third),
                           rotationDegrees: -90,
                           clockwiseIndex: 0),
                PlayerSeat(iconCenter: CGPoint(x: 11.6, y: 8),
                           cellRect: CGRect(x: 0, y: 0, width: 0.5, height: third),
                           rotationDegrees: 90,
                           clockwiseIndex: 4),
                PlayerSeat(iconCenter: CGPoint(x: 20.5, y: 17),
                           cellRect: CGRect(x: 0.5, y: third, width: 0.5, height: third),
                           rotationDegrees: -90,
                           clockwiseIndex: 1),
                PlayerSeat(iconCenter: CGPoint(x: 11.6, y: 17),
                           cellRect: CGRect(x: 0, y: third, width: 0.5, height: third),
                           rotationDegrees: 90,
                           clockwiseIndex: 3),
                PlayerSeat(iconCenter: CGPoint(x: 16, y: 25),
                           cellRect: CGRect(x: 0, y: 2 * third, width: 1, height: third),
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
            // SVG: 4 horizontal bands of 1/4 height each.
            //   band 1 (y=3.5):   1 full-width top-edge cell
            //   band 2 (y=11.5):  2 cells (left + right edge players)
            //   band 3 (y=20.5):  2 cells (left + right edge players)
            //   band 4 (y=28.5):  1 full-width bottom-edge cell
            return [
                PlayerSeat(iconCenter: CGPoint(x: 20.5, y: 11.5),
                           cellRect: CGRect(x: 0.5, y: 0.25, width: 0.5, height: 0.25),
                           rotationDegrees: -90,
                           clockwiseIndex: 1),
                PlayerSeat(iconCenter: CGPoint(x: 11.5, y: 11.5),
                           cellRect: CGRect(x: 0, y: 0.25, width: 0.5, height: 0.25),
                           rotationDegrees: 90,
                           clockwiseIndex: 5),
                PlayerSeat(iconCenter: CGPoint(x: 20.5, y: 20.5),
                           cellRect: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.25),
                           rotationDegrees: -90,
                           clockwiseIndex: 2),
                PlayerSeat(iconCenter: CGPoint(x: 11.5, y: 20.5),
                           cellRect: CGRect(x: 0, y: 0.5, width: 0.5, height: 0.25),
                           rotationDegrees: 90,
                           clockwiseIndex: 4),
                PlayerSeat(iconCenter: CGPoint(x: 16, y: 28.5),
                           cellRect: CGRect(x: 0, y: 0.75, width: 1, height: 0.25),
                           rotationDegrees: 0,
                           clockwiseIndex: 3),
                PlayerSeat(iconCenter: CGPoint(x: 16, y: 3.5),
                           cellRect: CGRect(x: 0, y: 0, width: 1, height: 0.25),
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

/// Global content insets for the playable area. Replaces the old
/// `view.safeAreaInsets.top` usage so every screen — game board, layout
/// selector, life input overlay — agrees on a single safe-area system.
enum BoardInsets {
    static let topBottom: CGFloat = 52
    static let leftRight: CGFloat = 8
    static let interCellGap: CGFloat = 20
}
