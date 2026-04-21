import UIKit

class DotNumberView: UIView {
    private var digitViews: [DotDigitView] = []
    private(set) var number: Int = 0
    var maxDotSize: CGFloat?

    private static let spacingRatio: CGFloat = 0.25
    // Gap between digits = one blank dot-column (dotSize + 2·spacing), so digits
    // sit on the same grid as if rendered on a pixel screen with one blank column between.
    private static let gapRatio: CGFloat = 1 + 2 * spacingRatio

    private var lastLayoutSize: CGSize = .zero
    private var lastMaxDotSize: CGFloat?

    static func dotSize(fitting size: CGSize, digitCount: Int = 2) -> CGFloat {
        let count = CGFloat(digitCount)
        let cols = count * CGFloat(DotPatterns.columns)
            + count * CGFloat(DotPatterns.columns - 1) * spacingRatio
            + (count - 1) * gapRatio
        let rows = CGFloat(DotPatterns.rows)
            + CGFloat(DotPatterns.rows - 1) * spacingRatio
        return min(size.width / cols, size.height / rows)
    }

    func updateNumber(_ newNumber: Int, direction: ChangeDirection?, animated: Bool) {
        let oldDigits = Self.digitValues(for: number)
        let newDigits = Self.digitValues(for: newNumber)
        number = newNumber

        guard bounds.width > 0 && bounds.height > 0 else { return }

        if oldDigits.count != newDigits.count || digitViews.isEmpty {
            buildDigitViews(for: newDigits)
            applyDigits(newDigits, direction: direction, animated: animated)
        } else {
            applyDigits(newDigits, direction: direction, animated: animated)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 && bounds.height > 0 else { return }
        if bounds.size != lastLayoutSize || maxDotSize != lastMaxDotSize {
            lastLayoutSize = bounds.size
            lastMaxDotSize = maxDotSize
            let digits = Self.digitValues(for: number)
            buildDigitViews(for: digits)
            applyDigits(digits, direction: nil, animated: false)
        }
    }

    // MARK: - Private

    private func buildDigitViews(for digits: [Int]) {
        digitViews.forEach { $0.removeFromSuperview() }
        digitViews.removeAll()

        let dotSz = computeDotSize(digitCount: digits.count)
        let spc = dotSz * Self.spacingRatio
        let gap = dotSz * Self.gapRatio

        let digitW = CGFloat(DotPatterns.columns) * dotSz + CGFloat(DotPatterns.columns - 1) * spc
        let digitH = CGFloat(DotPatterns.rows) * dotSz + CGFloat(DotPatterns.rows - 1) * spc
        let totalW = CGFloat(digits.count) * digitW + CGFloat(digits.count - 1) * gap

        var x = (bounds.width - totalW) / 2
        let y = (bounds.height - digitH) / 2

        for _ in digits {
            let dv = DotDigitView()
            dv.configure(dotSize: dotSz, spacing: spc)
            dv.frame = CGRect(x: x, y: y, width: dv.contentWidth, height: dv.contentHeight)
            addSubview(dv)
            digitViews.append(dv)
            x += digitW + gap
        }
    }

    private func applyDigits(_ digits: [Int], direction: ChangeDirection?, animated: Bool) {
        for (i, digit) in digits.enumerated() where i < digitViews.count {
            digitViews[i].setDigit(digit, direction: direction, animated: animated)
        }
    }

    var actualDotSize: CGFloat {
        let digits = Self.digitValues(for: number)
        return computeDotSize(digitCount: digits.count)
    }

    private func computeDotSize(digitCount: Int) -> CGFloat {
        let count = CGFloat(digitCount)
        let cols = count * CGFloat(DotPatterns.columns)
            + count * CGFloat(DotPatterns.columns - 1) * Self.spacingRatio
            + (count - 1) * Self.gapRatio
        let rows = CGFloat(DotPatterns.rows)
            + CGFloat(DotPatterns.rows - 1) * Self.spacingRatio
        return min(bounds.width / cols, bounds.height / rows, maxDotSize ?? .infinity)
    }

    static func digitValues(for number: Int) -> [Int] {
        if number == 0 { return [0] }
        var n = abs(number)
        var result: [Int] = []
        while n > 0 {
            result.insert(n % 10, at: 0)
            n /= 10
        }
        if number < 0 {
            result.insert(-1, at: 0)
        }
        return result
    }
}
