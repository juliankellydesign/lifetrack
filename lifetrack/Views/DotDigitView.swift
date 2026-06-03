import UIKit

class DotDigitView: UIView {
    private var dotViews: [UIView] = []
    private var currentDigit: Int?

    private static let animationDuration: TimeInterval = 0.3
    /// Wall-clock time (`CACurrentMediaTime`) until which a roll started here is
    /// still settling. An *interruptible* change arriving before this snaps
    /// straight to the new digit instead of starting another roll — so rapid
    /// taps always show the latest number. Each snap re-extends the window, so a
    /// sustained fast burst stays in snap mode until you pause longer than one
    /// roll.
    private var animatingUntil: CFTimeInterval = 0
    /// Full settle time of one roll: spring duration + the largest row delay.
    private var rollWindow: CFTimeInterval {
        Self.animationDuration + ChangeDirection.decreasing.delay(forRow: DotPatterns.rows - 1)
    }

    func configure(dotSize: CGFloat, spacing: CGFloat) {
        dotViews.forEach { $0.removeFromSuperview() }
        dotViews.removeAll()
        currentDigit = nil

        let step = dotSize + spacing
        for i in 0..<(DotPatterns.rows * DotPatterns.columns) {
            let row = i / DotPatterns.columns
            let col = i % DotPatterns.columns

            let dot = UIView(frame: CGRect(
                x: CGFloat(col) * step,
                y: CGFloat(row) * step,
                width: dotSize,
                height: dotSize
            ))
            dot.backgroundColor = .white
            dot.layer.cornerRadius = dotSize / 2
            dot.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
            dot.alpha = 0
            addSubview(dot)
            dotViews.append(dot)
        }

        let totalW = CGFloat(DotPatterns.columns) * dotSize + CGFloat(DotPatterns.columns - 1) * spacing
        let totalH = CGFloat(DotPatterns.rows) * dotSize + CGFloat(DotPatterns.rows - 1) * spacing
        bounds.size = CGSize(width: totalW, height: totalH)
    }

    /// `interruptible` (single taps) lets a change that lands while a previous
    /// roll is still settling snap straight to the new digit instead of queueing
    /// another roll — this is what keeps rapid tapping locked to the finger.
    /// Bulk ±10 repeats pass `false` so they always play the staggered roll.
    func setDigit(_ digit: Int, direction: ChangeDirection?, animated: Bool, interruptible: Bool = false) {
        let pattern = DotPatterns.pattern(for: digit)
        let oldPattern: [Bool]? = currentDigit.map { DotPatterns.pattern(for: $0) }
        currentDigit = digit

        let now = CACurrentMediaTime()
        let rollInFlight = now < animatingUntil

        // Snap straight to the *new* digit (no spring) when this isn't animated,
        // or when an interruptible change lands mid-roll. Snapping to the new
        // pattern — not finalizing the old one — is what stops the visible
        // number trailing a tap behind. Re-extend the window so the rest of a
        // fast burst keeps snapping; let it lapse for a one-off static set.
        if !animated || (interruptible && rollInFlight) {
            animatingUntil = animated ? now + rollWindow : 0
            for (i, dot) in dotViews.enumerated() {
                dot.layer.removeAllAnimations()
                let active = pattern[i]
                dot.transform = active ? .identity : CGAffineTransform(scaleX: 0.01, y: 0.01)
                dot.alpha = active ? 1 : 0
            }
            return
        }

        // Deliberate change with nothing in flight (or a bulk repeat): play the
        // staggered spring roll, animating only the dots that actually change.
        animatingUntil = now + rollWindow
        for i in 0..<dotViews.count {
            let isActive = pattern[i]
            let wasActive = oldPattern?[i] ?? false

            if oldPattern != nil && wasActive == isActive { continue }

            let row = i / DotPatterns.columns
            let delay = direction?.delay(forRow: row) ?? 0
            let scale: CGAffineTransform = isActive ? .identity : CGAffineTransform(scaleX: 0.01, y: 0.01)
            let alpha: CGFloat = isActive ? 1.0 : 0.0

            UIView.animate(withDuration: Self.animationDuration, delay: delay, usingSpringWithDamping: 0.7,
                           initialSpringVelocity: 0, options: .beginFromCurrentState) {
                self.dotViews[i].transform = scale
                self.dotViews[i].alpha = alpha
            }
        }
    }

    var contentWidth: CGFloat { bounds.width }
    var contentHeight: CGFloat { bounds.height }

    /// Apply a positional sweep fade. For each dot, we compute how far past
    /// the swipe's leading edge it sits, in `reference` coordinates, then
    /// linearly interpolate from its natural state (alpha 1 / scale 1 if
    /// active) to the "off" state (alpha 0 / scale 0.01) over `feather` pts.
    func applySweep(
        in reference: UIView,
        axisIsHorizontal: Bool,
        leadingEdge: CGFloat,
        direction: CGFloat,
        feather: CGFloat
    ) {
        guard let digit = currentDigit else { return }
        let pattern = DotPatterns.pattern(for: digit)
        for (i, dot) in dotViews.enumerated() {
            let p = reference.convert(
                CGPoint(x: dot.bounds.midX, y: dot.bounds.midY),
                from: dot
            )
            let pos = axisIsHorizontal ? p.x : p.y
            let signed = (leadingEdge - pos) * direction
            let progress = max(0, min(1, signed / feather))

            let active = pattern[i]
            let baseScale: CGFloat = active ? 1 : 0.01
            let scale = baseScale + (0.01 - baseScale) * progress
            let alpha: CGFloat = (active ? 1 : 0) * (1 - progress)
            dot.transform = CGAffineTransform(scaleX: scale, y: scale)
            dot.alpha = alpha
        }
    }

    /// Snap every dot to the off state (scale 0.01, alpha 0). Pair with
    /// `resetSweep(animated: true)` to play a digit roll-in from blank.
    func snapToOff() {
        for dot in dotViews {
            dot.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
            dot.alpha = 0
        }
    }

    /// Restore dots to their natural state for the current digit. Forces every
    /// dot back (unlike `setDigit`, which skips dots whose pattern is unchanged).
    func resetSweep(animated: Bool) {
        guard let digit = currentDigit else { return }
        let pattern = DotPatterns.pattern(for: digit)
        for (i, dot) in dotViews.enumerated() {
            let active = pattern[i]
            let scale: CGAffineTransform = active ? .identity : CGAffineTransform(scaleX: 0.01, y: 0.01)
            let alpha: CGFloat = active ? 1 : 0
            if animated {
                let row = i / DotPatterns.columns
                let delay = ChangeDirection.increasing.delay(forRow: row)
                UIView.animate(withDuration: 0.3, delay: delay,
                               usingSpringWithDamping: 0.7, initialSpringVelocity: 0,
                               options: .beginFromCurrentState) {
                    dot.transform = scale
                    dot.alpha = alpha
                }
            } else {
                dot.transform = scale
                dot.alpha = alpha
            }
        }
    }
}
