import SwiftUI

enum NumberPadKey {
    case digit(Int)
    case backspace
    case confirm
}

struct NumberPadView: View {
    let onKey: (NumberPadKey) -> Void

    private let rows: [[NumberPadKey]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.backspace, .digit(0), .confirm],
    ]

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(0..<4, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { col in
                        let key = rows[row][col]
                        Button { onKey(key) } label: {
                            keyLabel(key)
                                .font(.title2.weight(.medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyLabel(_ key: NumberPadKey) -> some View {
        switch key {
        case .digit(let d):
            Text("\(d)")
        case .backspace:
            Image(systemName: "xmark")
        case .confirm:
            Image(systemName: "checkmark")
        }
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.25 : 1.0)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}
