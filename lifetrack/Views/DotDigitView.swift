import UIKit

class DotDigitView: UIView {
    private var dotViews: [UIView] = []
    private var currentDigit: Int?

    private static let animationDuration: TimeInterval = 0.3

    /// Dot corner radius as a fraction of dot size, so roundness stays constant
    /// as dots scale (board at 18pt vs. the larger life-input overlay dots).
    /// Tuned to match the original 8pt radius at the 18pt board dot size.
    private static let cornerRadiusRatio: CGFloat = 8.0 / 18.0

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
            dot.layer.cornerRadius = dotSize * Self.cornerRadiusRatio
            dot.layer.cornerCurve = .continuous
            dot.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
            dot.alpha = 0
            addSubview(dot)
            dotViews.append(dot)
        }

        let totalW = CGFloat(DotPatterns.columns) * dotSize + CGFloat(DotPatterns.columns - 1) * spacing
        let totalH = CGFloat(DotPatterns.rows) * dotSize + CGFloat(DotPatterns.rows - 1) * spacing
        bounds.size = CGSize(width: totalW, height: totalH)
    }

    /// Animated changes — including rapid taps — play the staggered spring roll.
    /// The springs use `.beginFromCurrentState`, so a tap landing mid-roll just
    /// retargets the dots toward the latest digit from wherever they are, keeping
    /// the roll alive without trailing behind.
    func setDigit(_ digit: Int, direction: ChangeDirection?, animated: Bool) {
        let pattern = DotPatterns.pattern(for: digit)
        // If the font changed since `configure`, our dot views are stale (wrong
        // count). Bail — a relayout will rebuild and repaint at the new size.
        guard pattern.count == dotViews.count else { return }
        let oldPattern: [Bool]? = currentDigit.map { DotPatterns.pattern(for: $0) }
        currentDigit = digit

        // Snap straight to the digit (no spring) only for non-animated sets, e.g.
        // a relayout that just needs to paint the current value.
        if !animated {
            for (i, dot) in dotViews.enumerated() {
                dot.layer.removeAllAnimations()
                let active = pattern[i]
                dot.transform = active ? .identity : CGAffineTransform(scaleX: 0.01, y: 0.01)
                dot.alpha = active ? 1 : 0
            }
            return
        }

        // Play the staggered spring roll, animating only the dots that change.
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
        guard pattern.count == dotViews.count else { return }
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
        guard pattern.count == dotViews.count else { return }
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
