import UIKit

/// Mini diagram of the seating arrangement. One dot per player, drawn in the
/// same relative positions as the table layout. The dot at `highlightedIndex`
/// (the player whose commander is dealing the damage) is full opacity; the
/// rest are dimmed.
class CommanderIconView: UIView {
    /// Position + radius for each dot, expressed in a 24×24 viewbox so they
    /// scale uniformly when rendered at any size.
    private struct DotSpec {
        let cx: CGFloat
        let cy: CGFloat
        let r: CGFloat
    }

    private static let viewbox: CGFloat = 24
    private static let dimAlpha: CGFloat = 0.2

    let playerCount: Int
    let highlightedIndex: Int

    /// Cell rotation in degrees. The icon's dots are placed in the absolute board
    /// layout; counter-rotating by the cell's rotation keeps them aligned with the
    /// real board on screen (the highlighted dot points to where the opponent
    /// physically sits).
    var boardRotation: CGFloat = 0 {
        didSet { transform = CGAffineTransform(rotationAngle: -boardRotation * .pi / 180) }
    }

    private var dots: [UIView] = []

    init(playerCount: Int, highlightedIndex: Int) {
        self.playerCount = playerCount
        self.highlightedIndex = highlightedIndex
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false

        for i in 0..<Self.specs(forCount: playerCount).count {
            let dot = UIView()
            dot.backgroundColor = .white
            dot.alpha = (i == highlightedIndex) ? 1.0 : Self.dimAlpha
            addSubview(dot)
            dots.append(dot)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let specs = Self.specs(forCount: playerCount)
        let side = min(bounds.width, bounds.height)
        let scale = side / Self.viewbox
        let offsetX = (bounds.width - side) / 2
        let offsetY = (bounds.height - side) / 2

        for (i, dot) in dots.enumerated() where i < specs.count {
            let s = specs[i]
            let d = s.r * 2 * scale
            dot.frame = CGRect(
                x: offsetX + (s.cx - s.r) * scale,
                y: offsetY + (s.cy - s.r) * scale,
                width: d, height: d
            )
            dot.layer.cornerRadius = d / 2
        }
    }

    /// Layouts mirror GameBoardView's seat slots so a dot's index matches the
    /// player at that seat (player id == seat index).
    private static func specs(forCount n: Int) -> [DotSpec] {
        switch n {
        case 2:
            return [
                DotSpec(cx: 12, cy: 7,  r: 4),
                DotSpec(cx: 12, cy: 17, r: 4),
            ]
        case 3:
            return [
                DotSpec(cx: 7,  cy: 7,  r: 4),
                DotSpec(cx: 17, cy: 7,  r: 4),
                DotSpec(cx: 12, cy: 17, r: 4),
            ]
        case 4:
            return [
                DotSpec(cx: 7,  cy: 7,  r: 4),
                DotSpec(cx: 17, cy: 7,  r: 4),
                DotSpec(cx: 7,  cy: 17, r: 4),
                DotSpec(cx: 17, cy: 17, r: 4),
            ]
        case 5:
            return [
                DotSpec(cx: 7,  cy: 5,  r: 3.5),
                DotSpec(cx: 17, cy: 5,  r: 3.5),
                DotSpec(cx: 7,  cy: 14, r: 3.5),
                DotSpec(cx: 17, cy: 14, r: 3.5),
                DotSpec(cx: 12, cy: 21, r: 3.5),
            ]
        case 6:
            return [
                DotSpec(cx: 12, cy: 4,  r: 3),
                DotSpec(cx: 7,  cy: 10, r: 3),
                DotSpec(cx: 17, cy: 10, r: 3),
                DotSpec(cx: 7,  cy: 16, r: 3),
                DotSpec(cx: 17, cy: 16, r: 3),
                DotSpec(cx: 12, cy: 22, r: 3),
            ]
        default:
            return []
        }
    }
}
