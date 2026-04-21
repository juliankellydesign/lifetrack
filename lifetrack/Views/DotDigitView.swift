import UIKit

class DotDigitView: UIView {
    private var dotViews: [UIView] = []
    private var currentDigit: Int?

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

    func setDigit(_ digit: Int, direction: ChangeDirection?, animated: Bool) {
        let pattern = DotPatterns.pattern(for: digit)
        let oldPattern: [Bool]? = currentDigit.map { DotPatterns.pattern(for: $0) }
        currentDigit = digit

        for i in 0..<dotViews.count {
            let isActive = pattern[i]
            let wasActive = oldPattern?[i] ?? false

            if oldPattern != nil && wasActive == isActive { continue }

            let row = i / DotPatterns.columns
            let delay = animated ? (direction?.delay(forRow: row) ?? 0) : 0
            let scale: CGAffineTransform = isActive ? .identity : CGAffineTransform(scaleX: 0.01, y: 0.01)
            let alpha: CGFloat = isActive ? 1.0 : 0.0

            if animated {
                UIView.animate(withDuration: 0.3, delay: delay, usingSpringWithDamping: 0.7,
                               initialSpringVelocity: 0, options: .beginFromCurrentState) {
                    self.dotViews[i].transform = scale
                    self.dotViews[i].alpha = alpha
                }
            } else {
                dotViews[i].transform = scale
                dotViews[i].alpha = alpha
            }
        }
    }

    var contentWidth: CGFloat { bounds.width }
    var contentHeight: CGFloat { bounds.height }
}
