import SwiftUI
import UIKit

final class PoisonCounterView: UIView {
  static let preferredHeight: CGFloat = 60

  var onValueChanged: ((Int) -> Void)?
  private(set) var tapTargetFrames: [CGRect] = []

  private static let iconSize: CGFloat = 20
  private static let buttonWidth: CGFloat = 60
  private static let itemSpacing: CGFloat = 8
  private static let adjustmentIconAlpha: CGFloat = 0.3
  private static let visibilityDuration: TimeInterval = 0.16

  private let poisonIconView = UIImageView()
  private let minusButton = UIButton(type: .custom)
  private let plusButton = UIButton(type: .custom)
  private let valueModel = RollingValueModel()
  private lazy var valueHost = UIHostingController(
    rootView: RollingNumberText(model: valueModel)
  )
  private var valueView: UIView { valueHost.view }
  private var isInteractive = false
  private var value = 0

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  func prepare(value: Int, isInteractive: Bool) {
    self.value = max(0, value)
    self.isInteractive = isInteractive
    valueModel.value = self.value
    minusButton.isHidden = !isInteractive || self.value == 0
    plusButton.isHidden = !isInteractive
    valueView.isHidden = self.value == 0
    updateAccessibility()
    setNeedsLayout()
  }

  func setValue(_ value: Int, animated: Bool) {
    let next = max(0, value)
    guard next != self.value else { return }
    let hadValue = self.value > 0
    self.value = next
    valueModel.value = next
    let hasValue = next > 0

    if hasValue {
      valueView.isHidden = false
    }
    if isInteractive, hasValue {
      minusButton.isHidden = false
    }
    updateAccessibility()
    setNeedsLayout()

    guard animated else {
      valueView.isHidden = !hasValue
      minusButton.isHidden = !isInteractive || !hasValue
      layoutIfNeeded()
      return
    }

    if hasValue != hadValue {
      var appearingViews: [UIView] = hasValue ? [valueView] : []
      if hasValue, isInteractive {
        appearingViews.append(minusButton)
      }
      for view in appearingViews {
        view.alpha = 0
        view.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
      }
      UIView.animate(
        withDuration: Self.visibilityDuration,
        delay: 0,
        options: [.beginFromCurrentState, .allowUserInteraction]
      ) {
        self.layoutIfNeeded()
        for view in appearingViews {
          view.alpha = view === self.minusButton
            ? Self.adjustmentIconAlpha
            : 1
          view.transform = .identity
        }
        if !hasValue {
          self.valueView.alpha = 0
          self.valueView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
          self.minusButton.alpha = 0
          self.minusButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }
      } completion: { _ in
        guard !hasValue else { return }
        self.valueView.isHidden = true
        self.minusButton.isHidden = true
        self.valueView.alpha = 1
        self.valueView.transform = .identity
        self.minusButton.alpha = Self.adjustmentIconAlpha
        self.minusButton.transform = .identity
        self.setNeedsLayout()
      }
    } else {
      UIView.animate(
        withDuration: 0.2,
        delay: 0,
        usingSpringWithDamping: 0.85,
        initialSpringVelocity: 0,
        options: [.beginFromCurrentState, .allowUserInteraction]
      ) {
        self.layoutIfNeeded()
      }
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    let countWidth = value > 0 ? measuredValueWidth() : 0
    let visibleMinusWidth = isInteractive && value > 0 ? Self.buttonWidth : 0
    let visiblePlusWidth = isInteractive ? Self.buttonWidth : 0
    var contentWidth = visibleMinusWidth + Self.iconSize + countWidth + visiblePlusWidth
    var gaps = 0
    if visibleMinusWidth > 0 { gaps += 1 }
    if countWidth > 0 { gaps += 1 }
    if visiblePlusWidth > 0 { gaps += 1 }
    contentWidth += CGFloat(gaps) * Self.itemSpacing

    var x = bounds.midX - contentWidth / 2
    let iconY = bounds.midY - Self.iconSize / 2
    let valueY = bounds.midY - Typography.lifeDelta.lineHeight / 2
    tapTargetFrames = []

    if visibleMinusWidth > 0 {
      minusButton.frame = CGRect(x: x, y: 0, width: Self.buttonWidth, height: bounds.height)
      tapTargetFrames.append(minusButton.frame)
      x += Self.buttonWidth + Self.itemSpacing
    }

    poisonIconView.frame = CGRect(
      x: x, y: iconY,
      width: Self.iconSize, height: Self.iconSize
    )
    x += Self.iconSize

    if countWidth > 0 {
      x += Self.itemSpacing
      valueView.frame = CGRect(
        x: x, y: valueY,
        width: countWidth, height: Typography.lifeDelta.lineHeight
      )
      x += countWidth
    }

    if visiblePlusWidth > 0 {
      x += Self.itemSpacing
      plusButton.frame = CGRect(x: x, y: 0, width: Self.buttonWidth, height: bounds.height)
      tapTargetFrames.append(plusButton.frame)
    }
  }

  private func setup() {
    poisonIconView.image = UIImage(named: "icon-poison")
    poisonIconView.contentMode = .scaleAspectFit
    poisonIconView.isAccessibilityElement = false
    addSubview(poisonIconView)

    configureAdjustmentButton(
      minusButton,
      imageName: "IconMinus",
      accessibilityLabel: "Decrease poison"
    )
    configureAdjustmentButton(
      plusButton,
      imageName: "IconPlus",
      accessibilityLabel: "Increase poison"
    )
    minusButton.addTarget(self, action: #selector(decrement), for: .touchDown)
    plusButton.addTarget(self, action: #selector(increment), for: .touchDown)

    valueModel.font = Typography.lifeDelta.swiftUIFont
    valueModel.lineHeight = Typography.lifeDelta.lineHeight
    valueModel.tintColor = .white
    valueView.backgroundColor = .clear
    valueView.isUserInteractionEnabled = false
    valueView.accessibilityElementsHidden = true
    addSubview(valueView)
  }

  private func configureAdjustmentButton(
    _ button: UIButton,
    imageName: String,
    accessibilityLabel: String
  ) {
    button.setImage(
      UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate),
      for: .normal
    )
    button.tintColor = .white
    button.imageView?.contentMode = .scaleAspectFit
    button.alpha = Self.adjustmentIconAlpha
    button.accessibilityLabel = accessibilityLabel
    addSubview(button)
  }

  @objc private func increment() {
    AppSoundPlayer.shared.play(.increment)
    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.55)
    setValue(value + 1, animated: true)
    onValueChanged?(value)
  }

  @objc private func decrement() {
    guard value > 0 else { return }
    AppSoundPlayer.shared.play(.decrement)
    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.55)
    setValue(value - 1, animated: true)
    onValueChanged?(value)
  }

  private func measuredValueWidth() -> CGFloat {
    let text = "\(value)" as NSString
    return ceil(text.size(withAttributes: [.font: Typography.lifeDelta.uiFont]).width)
  }

  private func updateAccessibility() {
    let countDescription = value == 1
      ? "1 poison counter"
      : "\(value) poison counters"
    accessibilityLabel = countDescription
    minusButton.accessibilityValue = countDescription
    plusButton.accessibilityValue = countDescription
    isAccessibilityElement = !isInteractive
  }
}
