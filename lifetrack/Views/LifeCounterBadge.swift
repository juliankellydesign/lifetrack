import UIKit

/// Counter badge for one of the four secondary life-side counters
/// (poison / energy / rad / experience).
class LifeCounterBadge: CounterBadge {
    let kind: LifeCounter

    init(kind: LifeCounter) {
        self.kind = kind
        super.init(iconView: Self.makeIconView(for: kind))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private static func makeIconView(for kind: LifeCounter) -> UIView {
        AssetIcon(named: "icon-\(kind.rawValue)")
    }
}

/// Wraps a UIImageView with a template-rendered asset that fills its bounds.
private final class AssetIcon: UIView {
    private let imageView = UIImageView()

    init(named: String) {
        super.init(frame: .zero)
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: named)?.withRenderingMode(.alwaysTemplate)
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }
}
