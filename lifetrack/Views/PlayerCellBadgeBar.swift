import UIKit

/// Single horizontal row used in the main player cell that holds both the
/// commander damage badges and the life-counter badges. Hidden (zero-value)
/// badges collapse to no width so the visible set stays centered as one group.
class PlayerCellBadgeBar: UIView {
    private(set) var damageBadges: [CommanderDamageBadge] = []
    private(set) var counterBadges: [LifeCounterBadge] = []

    /// Called when a commander-damage badge is tapped in the cell (always +1).
    var onAdjustDamage: ((_ opponentId: Int, _ delta: Int) -> Void)?

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
            badge.onAdjust = { [weak self] delta in
                self?.onAdjustDamage?(oppId, delta)
            }
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

    /// Targeted update of one commander badge (animated), used after an inline tap
    /// instead of rebuilding the whole bar.
    func setDamage(_ value: Int, forOpponent opponentId: Int) {
        guard let badge = damageBadges.first(where: { $0.opponentSeatIndex == opponentId }) else { return }
        badge.setDamage(value, animated: true)
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

    /// Tap-target rects for the commander badges, in the bar's own coordinate
    /// space. They **tile** the band — no gaps, overlap, or margin: each spans
    /// from the midpoint with its left neighbour to the midpoint with its right
    /// neighbour, the outer two reaching the bar edges (or stopping at the first
    /// visible counter badge on the right). Full bar height. The visible badge
    /// content stays centered inside each; only the hit area fills the row.
    func commanderTapRects() -> [CGRect] {
        guard !damageBadges.isEmpty else { return [] }
        let h = bounds.height
        // Don't swallow the counter badges' space — stop at the leftmost visible one.
        let counterLeft = counterBadges
            .filter { $0.intrinsicWidth(forHeight: h) > 0 }
            .map { $0.frame.minX }
            .min()
        let rightLimit = counterLeft ?? bounds.width
        let centers = damageBadges.map { $0.frame.midX }
        return damageBadges.indices.map { i in
            let left = i == 0 ? 0 : (centers[i - 1] + centers[i]) / 2
            let right = i == damageBadges.count - 1 ? rightLimit : (centers[i] + centers[i + 1]) / 2
            return CGRect(x: left, y: 0, width: max(0, right - left), height: h)
        }
    }

    /// The commander badge whose tiled tap rect contains `p` (bar coords), if any.
    func commanderBadge(atBarPoint p: CGPoint) -> CommanderDamageBadge? {
        for (i, rect) in commanderTapRects().enumerated() where rect.contains(p) {
            return damageBadges[i]
        }
        return nil
    }
}
