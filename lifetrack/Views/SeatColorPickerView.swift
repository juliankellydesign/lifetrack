import UIKit

final class SeatColorPickerView: UIView {
  static let preferredHeight: CGFloat = 44

  var onSelectionChanged: ((Set<SeatColor>) -> Void)?

  private var selectedColors: Set<SeatColor> = [.colorless]
  private var buttons: [SeatColorSwatchButton] = []
  private var dotSize: CGFloat = 28

  func setDotSize(_ dotSize: CGFloat) {
    guard dotSize > 0, self.dotSize != dotSize else { return }
    self.dotSize = dotSize
    setNeedsLayout()
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  func prepare(colors: Set<SeatColor>) {
    selectedColors = colors.isEmpty ? [.colorless] : colors
    updateAppearance(animated: false)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let gap = dotSize
    let count = CGFloat(buttons.count)
    let totalWidth = count * dotSize + max(0, count - 1) * gap
    var x = (bounds.width - totalWidth) / 2
    let buttonHeight = max(Self.preferredHeight, dotSize + 6)
    for button in buttons {
      button.dotSize = dotSize
      button.bounds = CGRect(
        x: 0,
        y: 0,
        width: dotSize + gap,
        height: buttonHeight
      )
      button.center = CGPoint(
        x: x + dotSize / 2,
        y: bounds.midY
      )
      x += dotSize + gap
    }
  }

  private func setup() {
    isAccessibilityElement = false
    for (index, color) in SeatColor.allCases.enumerated() {
      let button = SeatColorSwatchButton(type: .custom)
      button.tag = index
      button.swatchColor = color.swatchColor
      button.isAccessibilityElement = true
      button.accessibilityLabel = "\(color.accessibilityName) seat color"
      button.accessibilityIdentifier = "seat-color-\(color.rawValue)"
      button.addTarget(self, action: #selector(handleSwatchTap(_:)), for: .touchUpInside)
      addSubview(button)
      buttons.append(button)
    }
    updateAppearance(animated: false)
  }

  @objc private func handleSwatchTap(_ sender: UIButton) {
    guard SeatColor.allCases.indices.contains(sender.tag) else { return }
    let color = SeatColor.allCases[sender.tag]

    if color == .colorless {
      selectedColors = [.colorless]
    } else {
      selectedColors.remove(.colorless)
      if selectedColors.contains(color) {
        selectedColors.remove(color)
      } else {
        selectedColors.insert(color)
      }
      if selectedColors.isEmpty {
        selectedColors = [.colorless]
      }
    }

    updateAppearance(animated: true)
    UISelectionFeedbackGenerator().selectionChanged()
    onSelectionChanged?(selectedColors)
  }

  private func updateAppearance(animated: Bool) {
    let changes = {
      for (index, button) in self.buttons.enumerated() {
        let color = SeatColor.allCases[index]
        let isSelected = self.selectedColors.contains(color)
        button.setSelectedAppearance(isSelected)
        button.accessibilityValue = isSelected ? "Selected" : "Not selected"
        button.accessibilityTraits = isSelected ? [.button, .selected] : .button
      }
    }

    if animated {
      UIView.animate(
        springDuration: 0.28,
        bounce: 0.24,
        options: [.allowUserInteraction, .beginFromCurrentState],
        animations: changes
      )
    } else {
      changes()
    }
  }
}

private final class SeatColorSwatchButton: UIButton {
  var dotSize: CGFloat = 28 {
    didSet { setNeedsLayout() }
  }
  var swatchColor: UIColor = .white {
    didSet { chipView.backgroundColor = swatchColor }
  }

  private let chipView = UIView()
  private let selectionOutlineView = UIView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let chipFrame = CGRect(
      x: bounds.midX - dotSize / 2,
      y: bounds.midY - dotSize / 2,
      width: dotSize,
      height: dotSize
    )
    chipView.frame = chipFrame
    chipView.layer.cornerRadius = DotDigitView.cornerRadius(forDotSize: dotSize)

    // UIView borders draw inward. Expanding by 3pt leaves a 1pt clear gap
    // followed by the requested 2pt white outline.
    selectionOutlineView.frame = chipFrame.insetBy(dx: -3, dy: -3)
    selectionOutlineView.layer.cornerRadius =
      DotDigitView.cornerRadius(forDotSize: dotSize) + 3
  }

  func setSelectedAppearance(_ isSelected: Bool) {
    chipView.alpha = isSelected ? 1 : 0.38
    selectionOutlineView.alpha = isSelected ? 1 : 0
  }

  private func setup() {
    isExclusiveTouch = true
    chipView.isUserInteractionEnabled = false
    chipView.layer.cornerCurve = .continuous
    addSubview(chipView)

    selectionOutlineView.isUserInteractionEnabled = false
    selectionOutlineView.backgroundColor = .clear
    selectionOutlineView.layer.cornerCurve = .continuous
    selectionOutlineView.layer.borderWidth = 2
    selectionOutlineView.layer.borderColor = UIColor.white.cgColor
    addSubview(selectionOutlineView)
  }
}
