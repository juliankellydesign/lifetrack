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
    @State private var changeDirection: ChangeDirection?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.gray.opacity(0.4), lineWidth: 1)
                )

            // Size the dot display for the rotated coordinate space, then rotate
            GeometryReader { geo in
                let inset: CGFloat = 24
                let swapped = abs(Int(rotation.degrees)) == 90
                let contentW = (swapped ? geo.size.height : geo.size.width) - inset * 2
                let contentH = (swapped ? geo.size.width : geo.size.height) - inset * 2

                DotNumberView(number: lifeTotal, direction: changeDirection)
                    .frame(width: contentW, height: contentH)
                    .rotationEffect(rotation)
                    .frame(width: geo.size.width, height: geo.size.height)
            }

            // Full-cell tap overlay — maps screen tap position to
            // the player's left (decrement) / right (increment) based on rotation
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let increment: Bool
                        let deg = Int(rotation.degrees)
                        switch deg {
                        case 90:
                            increment = location.y > geo.size.height / 2
                        case -90:
                            increment = location.y < geo.size.height / 2
                        case 180, -180:
                            increment = location.x < geo.size.width / 2
                        default:
                            increment = location.x > geo.size.width / 2
                        }
                        changeDirection = increment ? .increasing : .decreasing
                        lifeTotal += increment ? 1 : -1
                    }
            }
        }
    }
}
