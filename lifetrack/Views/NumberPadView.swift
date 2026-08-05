import UIKit

enum NumberPadKey {
  case digit(Int)
  case cancel
  case confirm
}

class NumberPadView: UIView {
  var onKey: ((NumberPadKey) -> Void)?

  /// Key-button frames in this view's own coordinate space, after layout.
  /// Used by the grid-skeleton debug overlay to outline each key.
  var keyFrames: [CGRect] { buttons.map { $0.frame } }

  private var buttons: [UIButton] = []
  private let keys: [[NumberPadKey]] = [
    [.digit(1), .digit(2), .digit(3)],
    [.digit(4), .digit(5), .digit(6)],
    [.digit(7), .digit(8), .digit(9)],
    [.cancel, .digit(0), .confirm],
  ]

  static let actionIconSize: CGFloat = 32

  static let rowSpacing: CGFloat = 10
  static let columnSpacing: CGFloat = 0

  override init(frame: CGRect) {
    super.init(frame: frame)
    buildButtons()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    buildButtons()
  }

  private static func sizedActionIcon(named: String) -> UIImage? {
    guard let image = UIImage(named: named) else { return nil }
    let size = CGSize(width: actionIconSize, height: actionIconSize)
    let renderer = UIGraphicsImageRenderer(size: size)
    let resized = renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
    return resized.withRenderingMode(.alwaysTemplate)
  }

  private func buildButtons() {
    for row in keys {
      for key in row {
        let button = UIButton()
        button.tintColor = .white

        switch key {
        case .digit(let digit):
          button.setAttributedTitle(Self.digitTitle("\(digit)"), for: .normal)
          button.accessibilityLabel = "\(digit)"
        case .cancel:
          button.setImage(
            Self.sizedActionIcon(named: "icon-delete"),
            for: .normal
          )
          button.adjustsImageWhenHighlighted = false
          button.imageView?.contentMode = .center
          button.accessibilityLabel = "Cancel editing"
          button.accessibilityIdentifier = "edit-cancel"
        case .confirm:
          button.setImage(
            Self.sizedActionIcon(named: "icon-checkmark"),
            for: .normal
          )
          button.adjustsImageWhenHighlighted = false
          button.imageView?.contentMode = .center
          button.accessibilityLabel = "Done"
          button.accessibilityIdentifier = "edit-done"
        }

        let captured = key
        button.addAction(UIAction { [weak self] _ in
          self?.onKey?(captured)
        }, for: .touchUpInside)

        button.addAction(UIAction { _ in
          AppSoundPlayer.shared.play(.button)
          UIView.animate(
            withDuration: 0.15,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0,
            options: []
          ) {
            button.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
          }
        }, for: .touchDown)

        let release = UIAction { _ in
          UIView.animate(
            withDuration: 0.15,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0,
            options: []
          ) {
            button.transform = .identity
          }
        }
        button.addAction(release, for: .touchUpInside)
        button.addAction(release, for: .touchUpOutside)
        button.addAction(release, for: .touchCancel)

        addSubview(button)
        buttons.append(button)
      }
    }
  }

  private static func digitTitle(_ string: String) -> NSAttributedString {
    let digit = Typography.keypadDigit
    let style = NSMutableParagraphStyle()
    style.minimumLineHeight = digit.lineHeight
    style.maximumLineHeight = digit.lineHeight
    style.alignment = .center
    return NSAttributedString(
      string: string,
      attributes: [
        .font: digit.uiFont,
        .foregroundColor: UIColor.white,
        .paragraphStyle: style,
      ]
    )
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let columns = 3
    let rows = 4
    let cellWidth =
      (bounds.width - CGFloat(columns - 1) * Self.columnSpacing)
      / CGFloat(columns)
    let cellHeight =
      (bounds.height - CGFloat(rows - 1) * Self.rowSpacing)
      / CGFloat(rows)

    for (index, button) in buttons.enumerated() {
      let row = index / columns
      let column = index % columns
      button.frame = CGRect(
        x: CGFloat(column) * (cellWidth + Self.columnSpacing),
        y: CGFloat(row) * (cellHeight + Self.rowSpacing),
        width: cellWidth,
        height: cellHeight
      )
    }
  }
}
