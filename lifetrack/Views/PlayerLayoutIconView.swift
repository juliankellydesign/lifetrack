import UIKit

/// Renders the seat dots of a `PlayerLayout` in a square viewbox. Used in two places:
///
/// 1. The post-reset layout selector — every dot drawn at full opacity to advertise
///    the seating arrangement.
/// 2. Commander damage badges — exactly one dot (`highlightedSeatIndex`) at full
///    opacity, the rest dimmed to 0.2, so the player can see which opponent's
///    commander is dealing damage.
///
/// `boardRotation` lets the icon counter-rotate so the highlighted dot keeps
/// pointing at the real opponent regardless of how the host cell is rotated.
class PlayerLayoutIconView: UIView {
    /// Dimmed alpha for non-highlighted dots. Matches the rest of the app's
    /// "grayed out" convention.
    private static let dimAlpha: CGFloat = 0.2

    /// SVG dots have radius 3 in a 32-unit viewbox. Keeping that ratio in sync
    /// makes the inline icon match the SVGs in the source folder pixel-for-pixel.
    private static let dotRadiusInViewbox: CGFloat = 3

    let layout: PlayerLayout

    /// When non-nil, only this seat renders at full opacity; others go to `dimAlpha`.
    /// When nil (selector usage), every dot is rendered at full opacity.
    var highlightedSeatIndex: Int? {
        didSet { applyHighlight() }
    }

    /// Counter-rotation that keeps dots aligned to the real board. The host
    /// cell rotates +R; this view rotates -R so the highlighted dot still
    /// points at the actual opponent's seat.
    var boardRotation: CGFloat = 0 {
        didSet { transform = CGAffineTransform(rotationAngle: -boardRotation * .pi / 180) }
    }

    private var dotViews: [UIView] = []

    init(layout: PlayerLayout, highlightedSeatIndex: Int? = nil) {
        self.layout = layout
        self.highlightedSeatIndex = highlightedSeatIndex
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false

        for _ in layout.seats {
            let dot = UIView()
            dot.backgroundColor = .white
            addSubview(dot)
            dotViews.append(dot)
        }
        applyHighlight()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let viewbox = PlayerLayout.iconViewbox
        let side = min(bounds.width, bounds.height)
        let scale = side / viewbox
        let offsetX = (bounds.width - side) / 2
        let offsetY = (bounds.height - side) / 2

        let dotDiameter = Self.dotRadiusInViewbox * 2 * scale

        for (i, seat) in layout.seats.enumerated() where i < dotViews.count {
            let dot = dotViews[i]
            dot.frame = CGRect(
                x: offsetX + (seat.iconCenter.x - Self.dotRadiusInViewbox) * scale,
                y: offsetY + (seat.iconCenter.y - Self.dotRadiusInViewbox) * scale,
                width: dotDiameter, height: dotDiameter
            )
            dot.layer.cornerRadius = dotDiameter / 2
        }
    }

    private func applyHighlight() {
        for (i, dot) in dotViews.enumerated() {
            if let h = highlightedSeatIndex {
                dot.alpha = (i == h) ? 1.0 : Self.dimAlpha
            } else {
                dot.alpha = 1.0
            }
        }
    }
}
