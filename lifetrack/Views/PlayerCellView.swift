import SwiftUI

enum ChangeDirection {
    case increasing, decreasing

    func delay(forRow row: Int) -> Double {
        let interval = 0.035
        switch self {
        case .decreasing: return Double(row) * interval
        case .increasing: return Double(DotPatterns.rows - 1 - row) * interval
        }
    }
}

struct PlayerCellView: View {
    @Binding var lifeTotal: Int
    let rotation: Angle
    var maxDotSize: CGFloat? = nil
    @State private var changeDirection: ChangeDirection?
    @State private var tiltAngle: Double = 0
    @State private var repeatTimer: Timer?

    var body: some View {
        GeometryReader { geo in
            let inset: CGFloat = 24
            let swapped = abs(Int(rotation.degrees)) == 90
            let contentW = (swapped ? geo.size.height : geo.size.width) - inset * 2
            let contentH = (swapped ? geo.size.width : geo.size.height) - inset * 2

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.gray.opacity(0.4), lineWidth: 1)
                    )

                DotNumberView(number: lifeTotal, direction: changeDirection, maxDotSize: maxDotSize)
                    .frame(width: contentW, height: contentH)
                    .rotationEffect(rotation)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .rotation3DEffect(
                .degrees(tiltAngle),
                axis: (x: -sin(rotation.radians), y: cos(rotation.radians), z: 0),
                perspective: 0.3
            )
            .animation(.spring(duration: 0.2), value: tiltAngle)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard repeatTimer == nil else { return }
                        let increment = isIncrement(at: value.startLocation, in: geo.size)
                        tiltAngle = (increment ? 1.0 : -1.0) * 7
                        applyChange(increment: increment)
                        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                            applyChange(increment: increment)
                        }
                    }
                    .onEnded { _ in
                        repeatTimer?.invalidate()
                        repeatTimer = nil
                        tiltAngle = 0
                    }
            )
        }
    }

    private func isIncrement(at location: CGPoint, in size: CGSize) -> Bool {
        let deg = Int(rotation.degrees)
        switch deg {
        case 90: return location.y > size.height / 2
        case -90: return location.y < size.height / 2
        case 180, -180: return location.x < size.width / 2
        default: return location.x > size.width / 2
        }
    }

    private func applyChange(increment: Bool) {
        changeDirection = increment ? .increasing : .decreasing
        lifeTotal += increment ? 1 : -1
    }
}
