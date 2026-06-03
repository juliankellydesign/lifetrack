import UIKit

enum NumberPadKey {
    case digit(Int)
    case backspace
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
        [.confirm, .digit(0), .backspace],
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildButtons()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildButtons()
    }

    private static let actionIconSize: CGFloat = 32

    static let rowSpacing: CGFloat = 10
    static let columnSpacing: CGFloat = 0

    private static func sizedActionIcon(named: String) -> UIImage? {
        guard let img = UIImage(named: named) else { return nil }
        let size = CGSize(width: actionIconSize, height: actionIconSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.withRenderingMode(.alwaysTemplate)
    }

    private func buildButtons() {
        for row in keys {
            for key in row {
                let btn = UIButton()
                btn.tintColor = .white

                switch key {
                case .digit(let d):
                    btn.setAttributedTitle(Self.digitTitle("\(d)"), for: .normal)
                case .backspace:
                    btn.setImage(Self.sizedActionIcon(named: "icon-delete"), for: .normal)
                    btn.imageView?.contentMode = .center
                case .confirm:
                    btn.setImage(Self.sizedActionIcon(named: "icon-checkmark"), for: .normal)
                    btn.imageView?.contentMode = .center
                }

                let captured = key
                btn.addAction(UIAction { [weak self] _ in self?.onKey?(captured) }, for: .touchUpInside)

                btn.addAction(UIAction { _ in
                    UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 1.0,
                                   initialSpringVelocity: 0, options: []) {
                        btn.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
                    }
                }, for: .touchDown)

                let release = UIAction { _ in
                    UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 1.0,
                                   initialSpringVelocity: 0, options: []) {
                        btn.transform = .identity
                    }
                }
                btn.addAction(release, for: .touchUpInside)
                btn.addAction(release, for: .touchUpOutside)
                btn.addAction(release, for: .touchCancel)

                addSubview(btn)
                buttons.append(btn)
            }
        }
    }

    private static func digitTitle(_ s: String) -> NSAttributedString {
        let digit = Typography.keypadDigit
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = digit.lineHeight
        style.maximumLineHeight = digit.lineHeight
        style.alignment = .center
        return NSAttributedString(
            string: s,
            attributes: [
                .font: digit.uiFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: style,
            ]
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let cols = 3, rows = 4
        let cellW = (bounds.width - CGFloat(cols - 1) * Self.columnSpacing) / CGFloat(cols)
        let cellH = (bounds.height - CGFloat(rows - 1) * Self.rowSpacing) / CGFloat(rows)

        for (i, btn) in buttons.enumerated() {
            let r = i / cols, c = i % cols
            btn.frame = CGRect(
                x: CGFloat(c) * (cellW + Self.columnSpacing),
                y: CGFloat(r) * (cellH + Self.rowSpacing),
                width: cellW, height: cellH
            )
        }
    }
}
