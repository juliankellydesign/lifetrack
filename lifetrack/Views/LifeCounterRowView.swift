import UIKit

/// Row of four `LifeCounterBadge`s (poison / energy / rad / experience).
/// Visually mirrors `CommanderDamageRowView` but its badge values come from a
/// single player rather than per-opponent.
class LifeCounterRowView: UIView {
    private(set) var badges: [LifeCounterBadge] = []
    var onAdjust: ((LifeCounter, Int) -> Void)?

    static let heightFraction: CGFloat = 0.13
    static let minHeight: CGFloat = CounterBadge.inputBadgeHeight
    static let maxHeight: CGFloat = CounterBadge.inputBadgeHeight
    private static let badgeSpacing: CGFloat = 36

    func configure(values: [LifeCounter: Int]) {
        badges.forEach { $0.removeFromSuperview() }
        badges.removeAll()

        for kind in LifeCounter.allCases {
            let badge = LifeCounterBadge(kind: kind)
            badge.setValue(values[kind] ?? 0, animated: false)
            badge.onAdjust = { [weak self] delta in
                self?.onAdjust?(kind, delta)
            }
            addSubview(badge)
            badges.append(badge)
        }
        setNeedsLayout()
    }

    func setValue(_ value: Int, for kind: LifeCounter) {
        guard let badge = badges.first(where: { $0.kind == kind }) else { return }
        badge.setValue(value, animated: true)
        setNeedsLayout()
    }

    func setBadgesUserInteractionEnabled(_ enabled: Bool) {
        for badge in badges {
            badge.usesCompactAdjustControls = enabled
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
        var x = max(0, (bounds.width - totalW) / 2)
        // Left-align inside the available width if it overflows.
        if totalW > bounds.width { x = 0 }
        for (i, badge) in badges.enumerated() {
            let w = widths[i]
            badge.frame = CGRect(x: x, y: 0, width: w, height: h)
            if w > 0 { x += w + Self.badgeSpacing }
        }
    }
}
