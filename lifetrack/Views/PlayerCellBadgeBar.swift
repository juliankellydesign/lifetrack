import UIKit

/// Main-cell footer containing the commander-mode entry button and any nonzero
/// life counters. Commander damage itself is edited in the board-wide focused
/// mode, never inline in this row.
class PlayerCellBadgeBar: UIView {
  private(set) var counterBadges: [LifeCounterBadge] = []
  let commanderButton = UIButton(type: .custom)

  var onCommanderRequested: (() -> Void)?

  private static let badgeSpacing: CGFloat = 18
  private static let buttonWidth: CGFloat = 124
  private static let buttonHeight: CGFloat = 32

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupCommanderButton()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupCommanderButton()
  }

  private func setupCommanderButton() {
    let style = Typography.commanderButton
    commanderButton.setAttributedTitle(
      NSAttributedString(
        string: "COMMANDER",
        attributes: [
          .font: style.uiFont,
          .foregroundColor: UIColor.white.withAlphaComponent(0.65),
          .kern: 0.8,
        ]
      ),
      for: .normal
    )
    commanderButton.layer.borderWidth = 1
    commanderButton.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
    commanderButton.layer.cornerCurve = .continuous
    commanderButton.accessibilityLabel = "Commander damage"
    commanderButton.accessibilityHint = "Shows damage dealt by each opposing commander"
    commanderButton.addAction(UIAction { [weak self] _ in
      self?.onCommanderRequested?()
    }, for: .touchUpInside)
    addSubview(commanderButton)
  }

  func configure(counters: [LifeCounter: Int]) {
    counterBadges.forEach { $0.removeFromSuperview() }
    counterBadges.removeAll()

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
    let h = bounds.height
    let widths = counterBadges.map { $0.intrinsicWidth(forHeight: h) }
    let visibleCount = widths.filter { $0 > 0 }.count
    let counterWidth = widths.reduce(0, +)
      + CGFloat(max(visibleCount - 1, 0)) * Self.badgeSpacing
    let hasCounters = counterWidth > 0
    let totalW = Self.buttonWidth + (hasCounters ? Self.badgeSpacing + counterWidth : 0)
    var x = max(0, (bounds.width - totalW) / 2)

    let buttonH = min(Self.buttonHeight, h)
    commanderButton.frame = CGRect(
      x: x,
      y: (h - buttonH) / 2,
      width: Self.buttonWidth,
      height: buttonH
    )
    commanderButton.layer.cornerRadius = buttonH / 2
    x += Self.buttonWidth + (hasCounters ? Self.badgeSpacing : 0)

    for (i, badge) in counterBadges.enumerated() {
      let w = widths[i]
      badge.frame = CGRect(x: x, y: 0, width: w, height: h)
      if w > 0 {
        x += w + Self.badgeSpacing
      }
    }
  }

  /// The full footer band enters commander mode, keeping the target generous
  /// even when the visible capsule is compact.
  func commanderTapRect() -> CGRect {
    bounds
  }
}
