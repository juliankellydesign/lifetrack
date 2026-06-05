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

    /// Fixed dot diameter, identical in every host (player-cell badge and
    /// life-input badge) so the indicator never changes size with the icon
    /// frame. A 2×2 seat cluster therefore spans 9 + 2 + 9 = 20pt.
    private static let dotDiameter: CGFloat = 9
    /// Gap between adjacent dots in a regular grid.
    private static let dotGap: CGFloat = 2
    /// Center-to-center spacing of seats in the source SVG viewbox — the seats
    /// sit on a 9-unit grid. Scaling that pitch up to `dotDiameter + dotGap`
    /// (11pt) is what fixes the dot size while keeping seats in their relative
    /// positions.
    private static let svgGridPitch: CGFloat = 9

    /// Selector mode (no highlight) scales the whole diagram to fill its large
    /// button, drawing dots at this viewbox radius to match the source SVG art.
    private static let selectorDotRadiusInViewbox: CGFloat = 3

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

        // Two render modes share this view:
        //   • Commander-damage badge (a seat is highlighted): dots render at a
        //     fixed diameter + gap, independent of the icon's frame, so the
        //     indicator is identical in the player cell (24pt icon) and the
        //     life-input overlay (32pt icon). Scale maps the 9-unit SVG seat
        //     pitch to an 11pt screen pitch (9pt dot + 2pt gap), so a 2×2
        //     cluster spans exactly 9 + 2 + 9 = 20pt.
        //   • Layout selector (no highlight): scale the whole diagram to fill
        //     its much larger button, drawing dots at the SVG art radius.
        let isBadge = highlightedSeatIndex != nil
        let scale: CGFloat = isBadge
            ? (Self.dotDiameter + Self.dotGap) / Self.svgGridPitch
            : min(bounds.width, bounds.height) / viewbox
        let dotDiameter = isBadge
            ? Self.dotDiameter
            : Self.selectorDotRadiusInViewbox * 2 * scale

        // Pivot the field on the viewbox center (the table center) so the
        // counter-rotation keeps the highlighted dot pointing at the real seat.
        let offsetX = bounds.midX - (viewbox / 2) * scale
        let offsetY = bounds.midY - (viewbox / 2) * scale

        for (i, seat) in layout.seats.enumerated() where i < dotViews.count {
            let dot = dotViews[i]
            dot.frame = CGRect(
                x: offsetX + seat.iconCenter.x * scale - dotDiameter / 2,
                y: offsetY + seat.iconCenter.y * scale - dotDiameter / 2,
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
