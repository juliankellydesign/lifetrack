import UIKit

/// Horizontal row of CommanderDamageBadges, one per opponent. Lays badges out
/// centered with consistent spacing.
class CommanderDamageRowView: UIView {
    private(set) var badges: [CommanderDamageBadge] = []
    /// Called when the user adjusts a badge by a delta (+1 from tap, -1 from long-press).
    var onAdjustDamage: ((_ opponentId: Int, _ delta: Int) -> Void)?

    /// Vertical fraction of available cell content height to allocate to this row.
    static let heightFraction: CGFloat = 0.13
    static let minHeight: CGFloat = 18
    static let maxHeight: CGFloat = 36
    private static let badgeSpacing: CGFloat = 12

    /// Configures the row to display badges for the given opponents.
    /// - Parameters:
    ///   - opponentIds: stable IDs (e.g., player.id) of opponents in display order.
    ///   - playerCount: total players in the game; the icon shows this many dots.
    ///   - damages: current damage value for each opponent.
    func configure(opponentIds: [Int], playerCount: Int, damages: [Int]) {
        badges.forEach { $0.removeFromSuperview() }
        badges.removeAll()

        for (i, oppId) in opponentIds.enumerated() {
            let badge = CommanderDamageBadge(opponentId: oppId, playerCount: playerCount)
            badge.setDamage(i < damages.count ? damages[i] : 0, animated: false)
            badge.onAdjust = { [weak self] delta in
                self?.onAdjustDamage?(oppId, delta)
            }
            addSubview(badge)
            badges.append(badge)
        }
        setNeedsLayout()
    }

    func setDamage(_ damage: Int, forOpponent opponentId: Int) {
        guard let badge = badges.first(where: { $0.opponentId == opponentId }) else { return }
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
        let totalW = widths.reduce(0, +) + CGFloat(badges.count - 1) * Self.badgeSpacing
        var x = (bounds.width - totalW) / 2
        for (i, badge) in badges.enumerated() {
            badge.frame = CGRect(x: x, y: 0, width: widths[i], height: h)
            x += widths[i] + Self.badgeSpacing
        }
    }

}
