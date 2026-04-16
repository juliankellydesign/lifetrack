import SwiftUI

struct GameBoardView: View {
    @Binding var players: [Player]
    var onEditRequested: ((Int, Angle) -> Void)? = nil
    var editingIndex: Int? = nil
    var dotNamespace: Namespace.ID? = nil

    private static let contentInset: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let layout = layoutForPlayerCount(players.count, in: geo.size)
            let uniformDotSize = Self.uniformDotSize(for: layout)

            ZStack {
                ForEach(layout.indices, id: \.self) { i in
                    let slot = layout[i]
                    PlayerCellView(
                        lifeTotal: $players[i].lifeTotal,
                        rotation: slot.rotation,
                        maxDotSize: uniformDotSize,
                        onEditRequested: { onEditRequested?(i, slot.rotation) },
                        isBeingEdited: editingIndex == i,
                        dotNamespace: dotNamespace,
                        playerId: i
                    )
                    .frame(width: slot.frame.width, height: slot.frame.height)
                    .position(x: slot.frame.midX, y: slot.frame.midY)
                }
            }
        }
    }

    // Find the smallest dot size any cell would produce, so all cells match.
    private static func uniformDotSize(for layout: [Slot]) -> CGFloat {
        layout.map { slot in
            let swapped = abs(Int(slot.rotation.degrees)) == 90
            let contentW = (swapped ? slot.frame.height : slot.frame.width) - contentInset * 2
            let contentH = (swapped ? slot.frame.width : slot.frame.height) - contentInset * 2
            return DotNumberView.dotSize(fitting: CGSize(width: contentW, height: contentH))
        }.min() ?? 0
    }

    // MARK: - Layout

    private struct Slot {
        let frame: CGRect
        let rotation: Angle
    }

    private func layoutForPlayerCount(_ count: Int, in size: CGSize) -> [Slot] {
        let pad: CGFloat = 6
        let w = size.width
        let h = size.height
        let halfW = (w - pad) / 2

        switch count {
        case 2:
            // Two full-width rows
            let rowH = (h - pad) / 2
            return [
                Slot(frame: CGRect(x: 0, y: 0, width: w, height: rowH),
                     rotation: .degrees(180)),
                Slot(frame: CGRect(x: 0, y: rowH + pad, width: w, height: rowH),
                     rotation: .zero),
            ]

        case 3:
            // Top row: two side-by-side, bottom row: one full
            let rowH = (h - pad) / 2
            return [
                Slot(frame: CGRect(x: 0, y: 0, width: halfW, height: rowH),
                     rotation: .degrees(90)),
                Slot(frame: CGRect(x: halfW + pad, y: 0, width: halfW, height: rowH),
                     rotation: .degrees(-90)),
                Slot(frame: CGRect(x: 0, y: rowH + pad, width: w, height: rowH),
                     rotation: .zero),
            ]

        case 4:
            // Two rows of two
            let rowH = (h - pad) / 2
            return [
                Slot(frame: CGRect(x: 0, y: 0, width: halfW, height: rowH),
                     rotation: .degrees(90)),
                Slot(frame: CGRect(x: halfW + pad, y: 0, width: halfW, height: rowH),
                     rotation: .degrees(-90)),
                Slot(frame: CGRect(x: 0, y: rowH + pad, width: halfW, height: rowH),
                     rotation: .degrees(90)),
                Slot(frame: CGRect(x: halfW + pad, y: rowH + pad, width: halfW, height: rowH),
                     rotation: .degrees(-90)),
            ]

        case 5:
            // Top: one full, middle: two, bottom: two
            let rowH = (h - 2 * pad) / 3
            return [
                Slot(frame: CGRect(x: 0, y: 0, width: w, height: rowH),
                     rotation: .degrees(180)),
                Slot(frame: CGRect(x: 0, y: rowH + pad, width: halfW, height: rowH),
                     rotation: .degrees(90)),
                Slot(frame: CGRect(x: halfW + pad, y: rowH + pad, width: halfW, height: rowH),
                     rotation: .degrees(-90)),
                Slot(frame: CGRect(x: 0, y: 2 * (rowH + pad), width: halfW, height: rowH),
                     rotation: .degrees(90)),
                Slot(frame: CGRect(x: halfW + pad, y: 2 * (rowH + pad), width: halfW, height: rowH),
                     rotation: .degrees(-90)),
            ]

        case 6:
            // Top: one full, two middle rows of two, bottom: one full
            let rowH = (h - 3 * pad) / 4
            return [
                Slot(frame: CGRect(x: 0, y: 0, width: w, height: rowH),
                     rotation: .degrees(180)),
                Slot(frame: CGRect(x: 0, y: rowH + pad, width: halfW, height: rowH),
                     rotation: .degrees(90)),
                Slot(frame: CGRect(x: halfW + pad, y: rowH + pad, width: halfW, height: rowH),
                     rotation: .degrees(-90)),
                Slot(frame: CGRect(x: 0, y: 2 * (rowH + pad), width: halfW, height: rowH),
                     rotation: .degrees(90)),
                Slot(frame: CGRect(x: halfW + pad, y: 2 * (rowH + pad), width: halfW, height: rowH),
                     rotation: .degrees(-90)),
                Slot(frame: CGRect(x: 0, y: 3 * (rowH + pad), width: w, height: rowH),
                     rotation: .zero),
            ]

        default:
            return []
        }
    }
}
