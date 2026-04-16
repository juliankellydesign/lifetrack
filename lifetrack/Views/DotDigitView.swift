import SwiftUI

struct DotDigitView: View {
    let digit: Int
    let dotSize: CGFloat
    let spacing: CGFloat
    var direction: ChangeDirection? = nil
    var animateEntrance: Bool = true

    var body: some View {
        let pattern = DotPatterns.pattern(for: digit)
        let step = dotSize + spacing

        ZStack(alignment: .topLeading) {
            ForEach(0..<DotPatterns.rows * DotPatterns.columns, id: \.self) { i in
                let row = i / DotPatterns.columns
                let col = i % DotPatterns.columns
                let isActive = pattern[i]

                DotView(
                    isActive: isActive,
                    size: dotSize,
                    delay: direction?.delay(forRow: row) ?? 0,
                    animateEntrance: animateEntrance
                )
                .offset(
                    x: CGFloat(col) * step,
                    y: CGFloat(row) * step
                )
            }
        }
        .frame(
            width: CGFloat(DotPatterns.columns) * dotSize + CGFloat(DotPatterns.columns - 1) * spacing,
            height: CGFloat(DotPatterns.rows) * dotSize + CGFloat(DotPatterns.rows - 1) * spacing,
            alignment: .topLeading
        )
    }
}

// Individual dot with its own animation state, so each dot can
// animate independently with a per-row delay.
private struct DotView: View {
    let isActive: Bool
    let size: CGFloat
    let delay: Double
    var animateEntrance: Bool = true

    @State private var isShowing = false

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: size, height: size)
            .scaleEffect(isShowing ? 1.0 : 0.01)
            .opacity(isShowing ? 1.0 : 0.0)
            .onAppear {
                if animateEntrance {
                    withAnimation(.spring(duration: 0.3, bounce: 0.3).delay(delay)) {
                        isShowing = isActive
                    }
                } else {
                    isShowing = isActive
                }
            }
            .onChange(of: isActive) { _, newValue in
                withAnimation(.spring(duration: 0.3, bounce: 0.3).delay(delay)) {
                    isShowing = newValue
                }
            }
    }
}
