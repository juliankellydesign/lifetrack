import UIKit
import SwiftUI

/// Observable model the badge mutates to drive SwiftUI's numericText transition.
/// Critical: the SwiftUI view must read these properties directly so SwiftUI
/// runs the change inside its own update cycle — rebuilding `rootView` from
/// outside skips the transition.
@Observable
private final class DamageModel {
    var value: Int = 0
    var fontSize: CGFloat = 16
    var lethal: Bool = false
}

private struct RollingDamageText: View {
    let model: DamageModel

    var body: some View {
        Text(verbatim: "\(model.value)")
            .font(.system(size: model.fontSize, weight: .semibold).monospacedDigit())
            .foregroundStyle(model.lethal ? Color(red: 1, green: 0.35, blue: 0.35) : .white)
            .contentTransition(.numericText(value: Double(model.value)))
            .animation(.snappy(duration: 0.28), value: model.value)
    }
}

/// Icon + numeric damage value for a single opponent, with `+`/`−` touch
/// targets stacked above and below in interactive mode. Tapping the top half
/// adds 1, bottom half subtracts 1; both support hold-to-repeat. When damage
/// is 0 the numeral is hidden — only the icon shows.
class CommanderDamageBadge: UIView {
    let opponentId: Int

    private let iconView: CommanderIconView
    private let damageModel = DamageModel()
    private let numberHost: UIHostingController<RollingDamageText>
    private let plusGlyph = UILabel()
    private let minusGlyph = UILabel()

    private(set) var damage: Int = 0

    /// Sets the damage value. When animated, the numeral re-renders inside a
    /// `withAnimation` block so SwiftUI's `.contentTransition(.numericText)`
    /// rolls individual digits up/down based on the value delta.
    func setDamage(_ newValue: Int, animated: Bool) {
        let oldValue = damage
        damage = newValue
        applyDamageDisplay(animated: animated, didChange: newValue != oldValue)
        setNeedsLayout()
        superview?.setNeedsLayout()
    }

    var onAdjust: ((Int) -> Void)?

    var showsAdjustControls: Bool = false {
        didSet {
            plusGlyph.isHidden = !showsAdjustControls
            minusGlyph.isHidden = !showsAdjustControls
            isUserInteractionEnabled = showsAdjustControls
            setNeedsLayout()
        }
    }

    private static let iconLabelGap: CGFloat = 4
    private static let glyphHeightRatio: CGFloat = 0.22
    private static let middleHeightRatio: CGFloat = 0.50
    private static let numeralFontRatio: CGFloat = 0.78
    private static let longPressDelay: TimeInterval = 0.35
    private static let repeatInterval: TimeInterval = 0.12
    private static let hitInsets = UIEdgeInsets(top: -6, left: -10, bottom: -6, right: -10)

    private static let haptic = UIImpactFeedbackGenerator(style: .light)

    private var repeatTimer: Timer?
    private var activeDelta: Int = 0
    private var isTouching = false

    init(opponentId: Int, playerCount: Int) {
        self.opponentId = opponentId
        self.iconView = CommanderIconView(playerCount: playerCount, highlightedIndex: opponentId)
        self.numberHost = UIHostingController(
            rootView: RollingDamageText(model: damageModel)
        )
        super.init(frame: .zero)

        plusGlyph.text = "+"
        minusGlyph.text = "−"
        for g in [plusGlyph, minusGlyph] {
            g.textAlignment = .center
            g.textColor = UIColor.white.withAlphaComponent(0.45)
            g.isHidden = true
            addSubview(g)
        }

        addSubview(iconView)
        numberHost.view.backgroundColor = .clear
        numberHost.view.isUserInteractionEnabled = false
        numberHost.view.alpha = 0
        addSubview(numberHost.view)

        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height
        let glyphH = showsAdjustControls ? h * Self.glyphHeightRatio : 0
        let middleH = showsAdjustControls
            ? h * Self.middleHeightRatio
            : h
        let middleY = (h - middleH) / 2

        let iconW = middleH
        let centerX = bounds.midX

        if damage == 0 {
            iconView.frame = CGRect(
                x: centerX - iconW / 2,
                y: middleY,
                width: iconW, height: middleH
            )
            numberHost.view.frame = .zero
        } else {
            let textW = numeralWidth(forHeight: middleH, value: damage)
            let totalW = iconW + Self.iconLabelGap + textW
            let originX = centerX - totalW / 2
            iconView.frame = CGRect(x: originX, y: middleY, width: iconW, height: middleH)
            numberHost.view.frame = CGRect(
                x: originX + iconW + Self.iconLabelGap,
                y: middleY,
                width: textW, height: middleH
            )
        }

        if showsAdjustControls {
            plusGlyph.frame = CGRect(x: 0, y: 0, width: bounds.width, height: glyphH)
            minusGlyph.frame = CGRect(x: 0, y: h - glyphH, width: bounds.width, height: glyphH)
            let glyphFont = UIFont.systemFont(ofSize: glyphH * 0.95, weight: .medium)
            plusGlyph.font = glyphFont
            minusGlyph.font = glyphFont
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.inset(by: Self.hitInsets).contains(point)
    }

    func intrinsicWidth(forHeight height: CGFloat) -> CGFloat {
        let middleH = showsAdjustControls
            ? height * Self.middleHeightRatio
            : height
        let iconW = middleH
        if damage == 0 {
            return iconW
        }
        return iconW + Self.iconLabelGap + numeralWidth(forHeight: middleH, value: damage)
    }

    private func numeralWidth(forHeight h: CGFloat, value: Int) -> CGFloat {
        let font = UIFont.monospacedDigitSystemFont(
            ofSize: h * Self.numeralFontRatio, weight: .semibold
        )
        let s = "\(value)" as NSString
        return ceil(s.size(withAttributes: [.font: font]).width)
    }

    private func applyDamageDisplay(animated: Bool, didChange: Bool) {
        damageModel.lethal = damage >= Player.lethalCommanderDamage

        if damage == 0 {
            UIView.animate(withDuration: animated ? 0.18 : 0) {
                self.numberHost.view.alpha = 0
            }
            // Update the model after fade so it doesn't snap visibly to 0.
            damageModel.value = 0
            return
        }

        // Layout pass first so font size is correct before SwiftUI animates.
        layoutIfNeeded()

        let middleH = showsAdjustControls
            ? bounds.height * Self.middleHeightRatio
            : bounds.height
        damageModel.fontSize = middleH * Self.numeralFontRatio

        // Mutating model.value inside the SwiftUI view's tracked properties
        // triggers `.contentTransition(.numericText)` via the `.animation`
        // modifier scoped to `model.value`.
        damageModel.value = damage

        if numberHost.view.alpha == 0 {
            UIView.animate(withDuration: animated ? 0.18 : 0) {
                self.numberHost.view.alpha = 1
            }
        }
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isTouching, let touch = touches.first else { return }
        isTouching = true
        activeDelta = touch.location(in: self).y < bounds.midY ? +1 : -1
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
        guard delta > 0 || damage > 0 else { return }
        Self.haptic.impactOccurred(intensity: 0.55)
        onAdjust?(delta)
    }

    private func animateGlyph(forDelta delta: Int, pressed: Bool) {
        let glyph = delta > 0 ? plusGlyph : minusGlyph
        UIView.animate(withDuration: 0.12, delay: 0, options: [.beginFromCurrentState]) {
            glyph.textColor = pressed
                ? .white
                : UIColor.white.withAlphaComponent(0.45)
            glyph.transform = pressed
                ? CGAffineTransform(scaleX: 1.25, y: 1.25)
                : .identity
        }
    }
}
