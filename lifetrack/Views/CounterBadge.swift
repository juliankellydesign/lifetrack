import UIKit
import SwiftUI

/// Drives SwiftUI's `numericText` transition on a single integer.
@Observable
final class CounterValueModel {
    var value: Int = 0
    var font: Font = Typography.badgeInputValue.swiftUIFont
    var lineHeight: CGFloat = Typography.badgeInputValue.lineHeight
    var tintColor: Color = .white
}

private struct RollingCounterText: View {
    let model: CounterValueModel

    var body: some View {
        Text(verbatim: "\(model.value)")
            .font(model.font)
            .foregroundStyle(model.tintColor)
            .frame(height: model.lineHeight)
            .contentTransition(.numericText(value: Double(model.value)))
            .animation(.snappy(duration: 0.28), value: model.value)
    }
}

/// Horizontal counter badge: `[−][icon][value][+]` when active, `[icon][+]` when zero.
/// Tap left half decrements, right half increments. When zero, any tap increments.
class CounterBadge: UIView {
    private let iconView: UIView
    let valueModel = CounterValueModel()
    private let numberHost: UIHostingController<RollingCounterText>
    private let plusGlyph = UIImageView(image: UIImage(named: "icon-plus")?.withRenderingMode(.alwaysTemplate))
    private let minusGlyph = UIImageView(image: UIImage(named: "icon-minus")?.withRenderingMode(.alwaysTemplate))

    private(set) var value: Int = 0

    var onAdjust: ((Int) -> Void)?

    /// When false, the badge is read-only (no glyphs, no touch). Used in player cells.
    var showsAdjustControls: Bool = false {
        didSet {
            isUserInteractionEnabled = showsAdjustControls
            backgroundColor = showsAdjustControls
                ? UIColor.white.withAlphaComponent(Self.inputPillFillAlpha)
                : .clear
            applyDisplay()
            setNeedsLayout()
        }
    }

    /// In interactive mode, dim the icon when the value is zero. Subclasses can
    /// disable this when zero is a meaningful resting state (e.g. a fresh
    /// commander damage badge for an opponent).
    var dimsIconWhenInactive: Bool = true {
        didSet { applyDisplay() }
    }

    /// Fixed sizes used when `showsAdjustControls` is true (life input view).
    static let inputIconSize: CGFloat = 32
    static let inputGlyphSize: CGFloat = 16
    static let inputGlyphSpacing: CGFloat = 4
    static let inputBadgeHeight: CGFloat = 40
    static let inputPillPadding: CGFloat = 8
    private static let inputPillFillAlpha: CGFloat = 0.08

    /// Fixed sizes used when `showsAdjustControls` is false (player cell badge bar).
    static let inlineIconSize: CGFloat = 24
    private static let inlineGap: CGFloat = 4
    private static let dimmedAlpha: CGFloat = 0.2
    private static let longPressDelay: TimeInterval = 0.35
    private static let repeatInterval: TimeInterval = 0.12
    private static let hitInsets = UIEdgeInsets(top: -6, left: -6, bottom: -6, right: -6)

    private static let haptic = UIImpactFeedbackGenerator(style: .light)

    private var repeatTimer: Timer?
    private var activeDelta: Int = 0
    private var isTouching = false

    init(iconView: UIView) {
        self.iconView = iconView
        self.numberHost = UIHostingController(
            rootView: RollingCounterText(model: valueModel)
        )
        super.init(frame: .zero)

        for g in [plusGlyph, minusGlyph] {
            g.tintColor = .white
            g.contentMode = .scaleAspectFit
            addSubview(g)
        }

        addSubview(iconView)
        numberHost.view.backgroundColor = .clear
        numberHost.view.isUserInteractionEnabled = false
        addSubview(numberHost.view)

        isUserInteractionEnabled = false
        applyDisplay()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    /// Subclass hook called whenever the value changes — override to update colors etc.
    func valueDidChange() {}

    func setValue(_ newValue: Int, animated: Bool) {
        let oldValue = value
        value = newValue
        valueDidChange()

        let changed = newValue != oldValue
        if changed {
            setNeedsLayout()
            superview?.setNeedsLayout()
        }

        let work: () -> Void = {
            self.applyDisplay()
            if changed { self.superview?.layoutIfNeeded() }
        }

        if animated && changed {
            UIView.animate(
                withDuration: 0.28, delay: 0,
                usingSpringWithDamping: 0.9, initialSpringVelocity: 0,
                options: [.beginFromCurrentState], animations: work
            )
        } else {
            work()
        }
    }

    func intrinsicWidth(forHeight h: CGFloat) -> CGFloat {
        if !showsAdjustControls {
            if value == 0 { return 0 }
            return Self.inlineIconSize + Self.inlineGap + inlineNumeralWidth(value: value)
        }
        let icon = Self.inputIconSize
        let glyph = Self.inputGlyphSize
        let gap = Self.inputGlyphSpacing
        let pad = Self.inputPillPadding
        if value == 0 {
            // [pad][icon][gap][+][pad]
            return pad + icon + gap + glyph + pad
        }
        // [pad][−][gap][icon][gap][value][gap][+][pad]
        let textW = inputNumeralWidth(value: value)
        return pad + glyph + gap + icon + gap + textW + gap + glyph + pad
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height
        if showsAdjustControls {
            layer.cornerRadius = h / 2
            layer.masksToBounds = true
        } else {
            layer.cornerRadius = 0
            layer.masksToBounds = false
        }

        if !showsAdjustControls {
            // Read-only inline display: fixed 24pt icon and value, vertically centered.
            let icon = Self.inlineIconSize
            let style = Typography.badgeInlineValue
            valueModel.font = style.swiftUIFont
            valueModel.lineHeight = style.lineHeight

            let iconY = (h - icon) / 2
            let valueY = (h - style.lineHeight) / 2

            if value == 0 {
                iconView.frame = CGRect(x: (bounds.width - icon) / 2, y: iconY, width: icon, height: icon)
                numberHost.view.frame = .zero
            } else {
                let textW = inlineNumeralWidth(value: value)
                let totalW = icon + Self.inlineGap + textW
                let originX = (bounds.width - totalW) / 2
                iconView.frame = CGRect(x: originX, y: iconY, width: icon, height: icon)
                numberHost.view.frame = CGRect(
                    x: originX + icon + Self.inlineGap, y: valueY,
                    width: textW, height: style.lineHeight
                )
            }
            minusGlyph.frame = .zero
            plusGlyph.frame = .zero
            return
        }

        // Interactive (life input view): fixed sizes.
        let icon = Self.inputIconSize
        let glyph = Self.inputGlyphSize
        let gap = Self.inputGlyphSpacing
        let style = Typography.badgeInputValue
        valueModel.font = style.swiftUIFont
        valueModel.lineHeight = style.lineHeight

        let iconY = (h - icon) / 2
        let glyphY = (h - glyph) / 2
        let valueY = (h - style.lineHeight) / 2

        if value == 0 {
            // [icon][gap][+]
            let totalW = icon + gap + glyph
            let originX = (bounds.width - totalW) / 2
            iconView.frame = CGRect(x: originX, y: iconY, width: icon, height: icon)
            plusGlyph.frame = CGRect(
                x: originX + icon + gap, y: glyphY, width: glyph, height: glyph
            )
            minusGlyph.frame = .zero
            numberHost.view.frame = .zero
        } else {
            let textW = inputNumeralWidth(value: value)
            let totalW = glyph + gap + icon + gap + textW + gap + glyph
            var x = (bounds.width - totalW) / 2
            minusGlyph.frame = CGRect(x: x, y: glyphY, width: glyph, height: glyph)
            x += glyph + gap
            iconView.frame = CGRect(x: x, y: iconY, width: icon, height: icon)
            x += icon + gap
            numberHost.view.frame = CGRect(
                x: x, y: valueY, width: textW, height: style.lineHeight
            )
            x += textW + gap
            plusGlyph.frame = CGRect(x: x, y: glyphY, width: glyph, height: glyph)
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.inset(by: Self.hitInsets).contains(point)
    }

    private func inlineNumeralWidth(value: Int) -> CGFloat {
        let s = "\(value)" as NSString
        return ceil(s.size(withAttributes: [.font: Typography.badgeInlineValue.uiFont]).width)
    }

    private func inputNumeralWidth(value: Int) -> CGFloat {
        let s = "\(value)" as NSString
        return ceil(s.size(withAttributes: [.font: Typography.badgeInputValue.uiFont]).width)
    }

    private func applyDisplay() {
        valueModel.value = value

        let active = value > 0
        // Read-only badges fully hide when zero; interactive badges dim to indicate empty.
        let inactiveIconAlpha: CGFloat = showsAdjustControls
            ? (dimsIconWhenInactive ? Self.dimmedAlpha : 1.0)
            : 0
        iconView.alpha = active ? 1.0 : inactiveIconAlpha
        numberHost.view.alpha = active ? 1 : 0
        minusGlyph.alpha = (showsAdjustControls && active) ? 1 : 0
        plusGlyph.alpha = showsAdjustControls
            ? (active ? 1.0 : Self.dimmedAlpha)
            : 0
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isTouching, let touch = touches.first else { return }
        isTouching = true
        let loc = touch.location(in: self)
        // When zero, every tap increments. Otherwise, left half decrements.
        if value == 0 {
            activeDelta = +1
        } else {
            activeDelta = loc.x < bounds.midX ? -1 : +1
        }
        adjust(by: activeDelta)
        animateGlyph(forDelta: activeDelta, pressed: true)
        scheduleRepeat()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouch()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouch()
    }

    private func endTouch() {
        repeatTimer?.invalidate()
        repeatTimer = nil
        if isTouching {
            animateGlyph(forDelta: activeDelta, pressed: false)
        }
        isTouching = false
        activeDelta = 0
    }

    private func scheduleRepeat() {
        repeatTimer = Timer.scheduledTimer(
            withTimeInterval: Self.longPressDelay, repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            self.adjust(by: self.activeDelta)
            self.repeatTimer = Timer.scheduledTimer(
                withTimeInterval: Self.repeatInterval, repeats: true
            ) { [weak self] _ in
                guard let self else { return }
                self.adjust(by: self.activeDelta)
            }
        }
    }

    private func adjust(by delta: Int) {
        guard delta > 0 || value > 0 else { return }
        Self.haptic.impactOccurred(intensity: 0.55)
        onAdjust?(delta)
    }

    private func animateGlyph(forDelta delta: Int, pressed: Bool) {
        let glyph = delta > 0 ? plusGlyph : minusGlyph
        UIView.animate(withDuration: 0.12, delay: 0, options: [.beginFromCurrentState]) {
            glyph.transform = pressed
                ? CGAffineTransform(scaleX: 1.25, y: 1.25)
                : .identity
        }
    }
}
