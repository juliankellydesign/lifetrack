import UIKit
import SwiftUI

/// Counter badge for one of the four secondary life-side counters
/// (poison / energy / rad / experience).
class LifeCounterBadge: CounterBadge {
    let kind: LifeCounter

    init(kind: LifeCounter) {
        self.kind = kind
        super.init(iconView: Self.makeIconView(for: kind))
        dimsIconWhenInactive = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func valueDidChange() {
        valueModel.tintColor = (kind == .poison && value >= 10)
            ? Color(red: 1, green: 0.35, blue: 0.35)
            : .white
    }

    private static func makeIconView(for kind: LifeCounter) -> UIView {
        AssetIcon(named: "icon-\(kind.rawValue)")
    }
}

/// Wraps a UIImageView with a template-rendered asset that fills its bounds.
private final class AssetIcon: UIView {
    private let imageView = UIImageView()

    init(named: String) {
        super.init(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: named)?.withRenderingMode(.alwaysOriginal)
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }
}
