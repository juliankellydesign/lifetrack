import UIKit

/// Full-screen sheet that lets the player pick how many players are at the
/// table and which seating layout to use. Shown after a swipe-to-reset and on
/// first launch (after the default 4-player game) when the user wants to pick
/// a different layout.
///
/// Geometry (per design spec):
///   - 8pt safe area on the left and right of the screen
///   - 52pt safe area on the top and bottom of the screen
///   - 2 columns × 4 rows of buttons
///   - Each button is `(screenWidth - 16) / 4` wide and `(screenHeight - 104) / 6` tall
///   - The button grid is centered, leaving a 1/4-wide gutter on each side and
///     a 1/6-tall gutter above and below.
class LayoutSelectorView: UIView {
    var onSelect: ((PlayerLayout) -> Void)?

    private struct Cell {
        let layout: PlayerLayout
        let button: UIControl
        let icon: PlayerLayoutIconView
    }

    private var cells: [Cell] = []

    private static let columns = 2
    private static let rows = 4
    private static let iconSize: CGFloat = 48

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        buildCells()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        buildCells()
    }

    private func buildCells() {
        for layout in PlayerLayout.selectorOrder {
            let button = UIControl()
            button.backgroundColor = .clear

            let icon = PlayerLayoutIconView(layout: layout)
            icon.isUserInteractionEnabled = false
            button.addSubview(icon)

            button.addAction(UIAction { [weak self] _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
                self?.onSelect?(layout)
            }, for: .touchUpInside)

            // Press feedback: subtle scale-down on the icon only. Scaling the
            // *button* would shrink its hit area, kick the finger outside,
            // fire touchDragExit, and flutter — so we leave the tap target at
            // full size and animate the icon instead.
            button.addAction(UIAction { [weak icon] _ in
                UIView.animate(withDuration: 0.12, delay: 0,
                               usingSpringWithDamping: 0.9, initialSpringVelocity: 0,
                               options: [.allowUserInteraction, .beginFromCurrentState]) {
                    icon?.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                }
            }, for: [.touchDown, .touchDragEnter])
            button.addAction(UIAction { [weak icon] _ in
                UIView.animate(withDuration: 0.2, delay: 0,
                               usingSpringWithDamping: 0.7, initialSpringVelocity: 0,
                               options: [.allowUserInteraction, .beginFromCurrentState]) {
                    icon?.transform = .identity
                }
            }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

            addSubview(button)
            cells.append(Cell(layout: layout, button: button, icon: icon))
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard cells.count == Self.columns * Self.rows else { return }

        let availableW = bounds.width - BoardInsets.leftRight * 2
        let availableH = bounds.height - BoardInsets.topBottom * 2

        let cellW = availableW / 4
        let cellH = availableH / 6

        let totalW = cellW * CGFloat(Self.columns)
        let totalH = cellH * CGFloat(Self.rows)

        let originX = BoardInsets.leftRight + (availableW - totalW) / 2
        let originY = BoardInsets.topBottom + (availableH - totalH) / 2

        for (i, cell) in cells.enumerated() {
            let col = i % Self.columns
            let row = i / Self.columns
            let frame = CGRect(
                x: originX + CGFloat(col) * cellW,
                y: originY + CGFloat(row) * cellH,
                width: cellW,
                height: cellH
            )
            cell.button.frame = frame
            // The icon is a fixed 48pt square centered inside the (larger)
            // tap-target button so the visible mark stays consistent across
            // device sizes while the touch area fills its grid cell.
            let s = Self.iconSize
            cell.icon.frame = CGRect(
                x: (frame.width - s) / 2,
                y: (frame.height - s) / 2,
                width: s,
                height: s
            )
        }
    }
}
