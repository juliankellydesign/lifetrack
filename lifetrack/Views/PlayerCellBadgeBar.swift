import UIKit

/// Single horizontal row used in the main player cell that holds both the
/// commander damage badges and the life-counter badges. Hidden (zero-value)
/// badges collapse to no width so the visible set stays centered as one group.
class PlayerCellBadgeBar: UIView {
    private(set) var damageBadges: [CommanderDamageBadge] = []
    private(set) var counterBadges: [LifeCounterBadge] = []

    private static let badgeSpacing: CGFloat = 18

    /// Cell rotation in degrees, propagated to each commander badge so its
    /// dot icon stays oriented to the real board.
    var iconRotation: CGFloat = 0 {
        didSet { for b in damageBadges { b.boardRotation = iconRotation } }
    }

    func configure(
        layout: PlayerLayout,
        opponentIds: [Int],
        damages: [Int],
        counters: [LifeCounter: Int]
    ) {
        damageBadges.forEach { $0.removeFromSuperview() }
        counterBadges.forEach { $0.removeFromSuperview() }
        damageBadges.removeAll()
        counterBadges.removeAll()

        for (i, oppId) in opponentIds.enumerated() {
            let badge = CommanderDamageBadge(opponentSeatIndex: oppId, layout: layout)
            badge.setDamage(i < damages.count ? damages[i] : 0, animated: false)
            badge.boardRotation = iconRotation
            addSubview(badge)
            damageBadges.append(badge)
        }

        for kind in LifeCounter.allCases {
            let badge = LifeCounterBadge(kind: kind)
            badge.setValue(counters[kind] ?? 0, animated: false)
            addSubview(badge)
            counterBadges.append(badge)
        }

        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let badges: [CounterBadge] = damageBadges + counterBadges
        guard !badges.isEmpty else { return }
        let h = bounds.height
        let widths = badges.map { $0.intrinsicWidth(forHeight: h) }
        let visibleCount = widths.filter { $0 > 0 }.count
        let totalW = widths.reduce(0, +) + CGFloat(max(visibleCount - 1, 0)) * Self.badgeSpacing
        var x = max(0, (bounds.width - totalW) / 2)
        for (i, badge) in badges.enumerated() {
            let w = widths[i]
            badge.frame = CGRect(x: x, y: 0, width: w, height: h)
            if w > 0 { x += w + Self.badgeSpacing }
        }
    }
}
