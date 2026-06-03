import UIKit

/// Horizontal row of CommanderDamageBadges, one per opponent. Lays badges out
/// centered with consistent spacing.
class CommanderDamageRowView: UIView {
    private(set) var badges: [CommanderDamageBadge] = []
    /// Called when the user adjusts a badge by a delta (+1 from tap, -1 from long-press).
    var onAdjustDamage: ((_ opponentId: Int, _ delta: Int) -> Void)?

    /// Vertical fraction of available cell content height to allocate to this row.
    static let heightFraction: CGFloat = 0.13
    static let minHeight: CGFloat = Typography.badgeInlineValue.lineHeight
    static let maxHeight: CGFloat = 36
    private static let badgeSpacing: CGFloat = 12

    /// Rotation (in degrees) of the player cell containing this row. Propagated to
    /// each badge's commander icon so its dots stay aligned to the real board.
    var iconRotation: CGFloat = 0 {
        didSet { for badge in badges { badge.boardRotation = iconRotation } }
    }

    /// Configures the row to display badges for the given opponents.
    /// - Parameters:
    ///   - layout: the active PlayerLayout, so each commander icon shows the
    ///     correct seating diagram with the opponent's seat highlighted.
    ///   - opponentIds: stable IDs (==seat indices) of opponents in display order.
    ///   - damages: current damage value for each opponent.
    func configure(layout: PlayerLayout, opponentIds: [Int], damages: [Int]) {
        badges.forEach { $0.removeFromSuperview() }
        badges.removeAll()

        for (i, oppId) in opponentIds.enumerated() {
            let badge = CommanderDamageBadge(opponentSeatIndex: oppId, layout: layout)
            badge.setDamage(i < damages.count ? damages[i] : 0, animated: false)
            badge.boardRotation = iconRotation
            badge.onAdjust = { [weak self] delta in
                self?.onAdjustDamage?(oppId, delta)
            }
            addSubview(badge)
            badges.append(badge)
        }
        setNeedsLayout()
    }

    func setDamage(_ damage: Int, forOpponent opponentId: Int) {
        guard let badge = badges.first(where: { $0.opponentSeatIndex == opponentId }) else { return }
        badge.setDamage(damage, animated: true)
        setNeedsLayout()
    }

    func setBadgesUserInteractionEnabled(_ enabled: Bool) {
        for badge in badges {
            badge.showsAdjustControls = enabled
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !badges.isEmpty else { return }
        let h = bounds.height
        let widths = badges.map { $0.intrinsicWidth(forHeight: h) }
        let visibleCount = widths.filter { $0 > 0 }.count
        let totalW = widths.reduce(0, +) + CGFloat(max(visibleCount - 1, 0)) * Self.badgeSpacing
        var x = (bounds.width - totalW) / 2
        for (i, badge) in badges.enumerated() {
            let w = widths[i]
            badge.frame = CGRect(x: x, y: 0, width: w, height: h)
            if w > 0 { x += w + Self.badgeSpacing }
        }
    }

}
