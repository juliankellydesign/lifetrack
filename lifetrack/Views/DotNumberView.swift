import UIKit

class DotNumberView: UIView {
    private var digitViews: [DotDigitView] = []
    private(set) var number: Int = 0
    var maxDotSize: CGFloat?

    private static let spacingRatio: CGFloat = 0.25

    private var lastLayoutSize: CGSize = .zero
    private var lastMaxDotSize: CGFloat?
    private var lastFontID: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        observeFontChanges()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        observeFontChanges()
    }

    private func observeFontChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fontDidChange),
            name: DotFontSettings.didChange,
            object: nil
        )
    }

    @objc private func fontDidChange() {
        lastLayoutSize = .zero
        lastFontID = nil
        setNeedsLayout()
    }

    static func dotSize(fitting size: CGSize, digitCount: Int = 2) -> CGFloat {
        let count = CGFloat(digitCount)
        let cols = count * CGFloat(DotPatterns.columns)
            + count * CGFloat(DotPatterns.columns - 1) * spacingRatio
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
        let fontID = DotFontSettings.current.id
        if bounds.size != lastLayoutSize || maxDotSize != lastMaxDotSize || fontID != lastFontID {
            lastLayoutSize = bounds.size
            lastMaxDotSize = maxDotSize
            lastFontID = fontID
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

        let digitW = CGFloat(DotPatterns.columns) * dotSz + CGFloat(DotPatterns.columns - 1) * spc
        let digitH = CGFloat(DotPatterns.rows) * dotSz + CGFloat(DotPatterns.rows - 1) * spc
        let totalW = CGFloat(digits.count) * digitW

        var x = (bounds.width - totalW) / 2
        let y = (bounds.height - digitH) / 2

        for _ in digits {
            let dv = DotDigitView()
            dv.configure(dotSize: dotSz, spacing: spc)
            dv.frame = CGRect(x: x, y: y, width: dv.contentWidth, height: dv.contentHeight)
            addSubview(dv)
            digitViews.append(dv)
            x += digitW
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
        let rows = CGFloat(DotPatterns.rows)
            + CGFloat(DotPatterns.rows - 1) * Self.spacingRatio
        return min(bounds.width / cols, bounds.height / rows, maxDotSize ?? .infinity)
    }

    func applySweep(
        in reference: UIView,
        axisIsHorizontal: Bool,
        leadingEdge: CGFloat,
        direction: CGFloat,
        feather: CGFloat
    ) {
        for dv in digitViews {
            dv.applySweep(
                in: reference,
                axisIsHorizontal: axisIsHorizontal,
                leadingEdge: leadingEdge,
                direction: direction,
                feather: feather
            )
        }
    }

    func resetSweep(animated: Bool) {
        for dv in digitViews {
            dv.resetSweep(animated: animated)
        }
    }

    func snapToOff() {
        for dv in digitViews {
            dv.snapToOff()
        }
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
