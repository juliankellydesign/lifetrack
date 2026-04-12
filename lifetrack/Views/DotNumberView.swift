import SwiftUI

struct DotNumberView: View {
    let number: Int
    var direction: ChangeDirection? = nil

    // Digit values to render, e.g. 40 → [4, 0], -3 → [-1, 3]
    // -1 represents the minus sign
    private var digitValues: [Int] {
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

    var body: some View {
        GeometryReader { geo in
            let digits = digitValues
            let count = CGFloat(digits.count)
            let spacingRatio: CGFloat = 0.25
            let gapRatio: CGFloat = 1.2

            // Solve for dot size from available space
            let cols = count * CGFloat(DotPatterns.columns)
                + count * CGFloat(DotPatterns.columns - 1) * spacingRatio
                + (count - 1) * gapRatio
            let rows = CGFloat(DotPatterns.rows)
                + CGFloat(DotPatterns.rows - 1) * spacingRatio

            let dotSize = min(geo.size.width / cols, geo.size.height / rows)
            let dotSpacing = dotSize * spacingRatio
            let digitGap = dotSize * gapRatio

            let digitWidth = CGFloat(DotPatterns.columns) * dotSize
                + CGFloat(DotPatterns.columns - 1) * dotSpacing
            let totalWidth = count * digitWidth + (count - 1) * digitGap
            let totalHeight = CGFloat(DotPatterns.rows) * dotSize
                + CGFloat(DotPatterns.rows - 1) * dotSpacing

            HStack(spacing: digitGap) {
                ForEach(Array(digits.enumerated()), id: \.offset) { _, digit in
                    DotDigitView(digit: digit, dotSize: dotSize, spacing: dotSpacing, direction: direction)
                }
            }
            .frame(width: totalWidth, height: totalHeight)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}
