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
    var onEditRequested: (() -> Void)? = nil
    var isBeingEdited: Bool = false
    var dotNamespace: Namespace.ID? = nil
    var playerId: Int = 0
    @State private var changeDirection: ChangeDirection?
    @State private var tiltAngle: Double = 0
    @State private var repeatTimer: Timer?
    @State private var centerHoldTimer: Timer?

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

                if !isBeingEdited {
                    dotContent(contentW: contentW, contentH: contentH, geoSize: geo.size)
                }
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
                        guard repeatTimer == nil && centerHoldTimer == nil else { return }
                        let zone = tapZone(at: value.startLocation, in: geo.size)
                        switch zone {
                        case .left:
                            tiltAngle = -7
                            applyChange(increment: false)
                            repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                                applyChange(increment: false)
                            }
                        case .right:
                            tiltAngle = 7
                            applyChange(increment: true)
                            repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                                applyChange(increment: true)
                            }
                        case .center:
                            centerHoldTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                onEditRequested?()
                                centerHoldTimer = nil
                            }
                        }
                    }
                    .onEnded { _ in
                        repeatTimer?.invalidate()
                        repeatTimer = nil
                        centerHoldTimer?.invalidate()
                        centerHoldTimer = nil
                        tiltAngle = 0
                    }
            )
        }
    }

    // Maps screen touch position to the player's left-to-right axis (0 = left, 1 = right)
    private func playerFraction(at location: CGPoint, in size: CGSize) -> CGFloat {
        let deg = Int(rotation.degrees)
        switch deg {
        case 90:    return location.y / size.height
        case -90:   return 1 - (location.y / size.height)
        case 180, -180: return 1 - (location.x / size.width)
        default:    return location.x / size.width
        }
    }

    private enum TapZone { case left, center, right }

    private func tapZone(at location: CGPoint, in size: CGSize) -> TapZone {
        let f = playerFraction(at: location, in: size)
        if f < 1.0 / 3.0 { return .left }
        if f > 2.0 / 3.0 { return .right }
        return .center
    }

    @ViewBuilder
    private func dotContent(contentW: CGFloat, contentH: CGFloat, geoSize: CGSize) -> some View {
        let dots = DotNumberView(number: lifeTotal, direction: changeDirection, maxDotSize: maxDotSize)
            .frame(width: contentW, height: contentH)
            .rotationEffect(rotation)
            .frame(width: geoSize.width, height: geoSize.height)

        if let ns = dotNamespace {
            dots.matchedGeometryEffect(id: playerId, in: ns)
        } else {
            dots
        }
    }

    private func applyChange(increment: Bool) {
        changeDirection = increment ? .increasing : .decreasing
        lifeTotal += increment ? 1 : -1
    }
}
