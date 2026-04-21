import UIKit

enum NumberPadKey {
    case digit(Int)
    case backspace
    case confirm
}

class NumberPadView: UIView {
    var onKey: ((NumberPadKey) -> Void)?

    private var buttons: [UIButton] = []
    private let keys: [[NumberPadKey]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.backspace, .digit(0), .confirm],
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildButtons()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildButtons()
    }

    private func buildButtons() {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        for row in keys {
            for key in row {
                let btn = UIButton()
                btn.titleLabel?.font = .systemFont(ofSize: 22, weight: .medium)
                btn.setTitleColor(.white, for: .normal)
                btn.tintColor = .white

                switch key {
                case .digit(let d):
                    btn.setTitle("\(d)", for: .normal)
                case .backspace:
                    btn.setImage(UIImage(systemName: "xmark", withConfiguration: symbolConfig), for: .normal)
                case .confirm:
                    btn.setImage(UIImage(systemName: "checkmark", withConfiguration: symbolConfig), for: .normal)
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

    override func layoutSubviews() {
        super.layoutSubviews()
        let cols = 3, rows = 4
        let spacing: CGFloat = 10
        let cellW = (bounds.width - CGFloat(cols - 1) * spacing) / CGFloat(cols)
        let cellH = (bounds.height - CGFloat(rows - 1) * spacing) / CGFloat(rows)

        for (i, btn) in buttons.enumerated() {
            let r = i / cols, c = i % cols
            btn.frame = CGRect(
                x: CGFloat(c) * (cellW + spacing),
                y: CGFloat(r) * (cellH + spacing),
                width: cellW, height: cellH
            )
        }
    }
}
