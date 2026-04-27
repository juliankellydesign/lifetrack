import UIKit

class GameBoardView: UIView {
    private var cellViews: [PlayerCellView] = []
    var onEditRequested: ((Int, CGFloat) -> Void)?
    var onLifeChanged: ((Int, Int) -> Void)?

    private static let contentInset: CGFloat = PlayerCellView.contentInset
    private static let gap: CGFloat = 20

    private struct Slot {
        let frame: CGRect
        let rotationDegrees: CGFloat
    }

    private var currentSlots: [Slot] = []

    func configure(with players: [Player]) {
        cellViews.forEach { $0.removeFromSuperview() }
        cellViews.removeAll()

        for (i, player) in players.enumerated() {
            let cell = PlayerCellView()
            cell.setLifeTotal(player.lifeTotal, direction: nil, animated: false)
            let idx = i
            cell.onEditRequested = { [weak self] in
                guard let self, idx < self.currentSlots.count else { return }
                self.onEditRequested?(idx, self.currentSlots[idx].rotationDegrees)
            }
            cell.onLifeChanged = { [weak self] newLife in
                self?.onLifeChanged?(idx, newLife)
            }
            addSubview(cell)
            cellViews.append(cell)
        }
        applyCommanderDamage(from: players)
        setNeedsLayout()
    }

    /// Refresh every cell's badge row from the current `players` array.
    /// Each cell shows badges for all *other* players in stable id order.
    func applyCommanderDamage(from players: [Player]) {
        for (i, player) in players.enumerated() where i < cellViews.count {
            let opponents = players.filter { $0.id != player.id }.sorted(by: { $0.id < $1.id })
            cellViews[i].setCommanderDamage(
                opponentIds: opponents.map { $0.id },
                playerCount: players.count,
                damages: opponents.map { player.damage(from: $0.id) }
            )
        }
    }

    func updatePlayer(at index: Int, lifeTotal: Int, direction: ChangeDirection? = nil, animated: Bool = false) {
        guard index < cellViews.count else { return }
        cellViews[index].setLifeTotal(lifeTotal, direction: direction, animated: animated)
    }

    func setEditing(index: Int?) {
        for (i, cell) in cellViews.enumerated() {
            cell.isBeingEdited = (i == index)
        }
        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseInOut) {
            for (i, cell) in self.cellViews.enumerated() {
                cell.alpha = (index == nil || i == index) ? 1 : 0
            }
        }
    }

    /// Set every cell's alpha. Call inside an animation block to animate.
    func setAllAlphas(_ alpha: CGFloat) {
        for cell in cellViews {
            cell.alpha = alpha
        }
    }

    func cellView(at index: Int) -> PlayerCellView? {
        guard index >= 0 && index < cellViews.count else { return nil }
        return cellViews[index]
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let slots = layoutSlots(for: cellViews.count, in: bounds.size)
        currentSlots = slots
        let uniformDotSize = Self.uniformDotSize(for: slots)

        for (i, cell) in cellViews.enumerated() {
            guard i < slots.count else { break }
            let slot = slots[i]
            cell.rotation = slot.rotationDegrees
            cell.maxDotSize = uniformDotSize
            cell.frame = slot.frame
        }
    }

    private static func uniformDotSize(for slots: [Slot]) -> CGFloat {
        slots.map { slot in
            let swapped = abs(Int(slot.rotationDegrees)) == 90
            let contentW = (swapped ? slot.frame.height : slot.frame.width) - contentInset * 2
            let contentH = (swapped ? slot.frame.width : slot.frame.height) - contentInset * 2
            let badgeRowH = PlayerCellView.damageRowHeight(forContentHeight: contentH)
            let dotH = contentH - badgeRowH
            return DotNumberView.dotSize(fitting: CGSize(width: contentW, height: dotH))
        }.min() ?? 0
    }

    private func layoutSlots(for count: Int, in size: CGSize) -> [Slot] {
        let pad = Self.gap
        let w = size.width
        let h = size.height
        let halfW = (w - pad) / 2

        switch count {
        case 2:
            let rowH = (h - pad) / 2
            return [
                Slot(frame: CGRect(x: 0, y: 0, width: w, height: rowH), rotationDegrees: 180),
                Slot(frame: CGRect(x: 0, y: rowH + pad, width: w, height: rowH), rotationDegrees: 0),
            ]
        case 3:
            let rowH = (h - pad) / 2
            return [
                Slot(frame: CGRect(x: 0, y: 0, width: halfW, height: rowH), rotationDegrees: 90),
                Slot(frame: CGRect(x: halfW + pad, y: 0, width: halfW, height: rowH), rotationDegrees: -90),
                Slot(frame: CGRect(x: 0, y: rowH + pad, width: w, height: rowH), rotationDegrees: 0),
            ]
        case 4:
            let rowH = (h - pad) / 2
            return [
                Slot(frame: CGRect(x: 0, y: 0, width: halfW, height: rowH), rotationDegrees: 90),
                Slot(frame: CGRect(x: halfW + pad, y: 0, width: halfW, height: rowH), rotationDegrees: -90),
                Slot(frame: CGRect(x: 0, y: rowH + pad, width: halfW, height: rowH), rotationDegrees: 90),
                Slot(frame: CGRect(x: halfW + pad, y: rowH + pad, width: halfW, height: rowH), rotationDegrees: -90),
            ]
        case 5:
            let rowH = (h - 2 * pad) / 3
            return [
                Slot(frame: CGRect(x: 0, y: 0, width: halfW, height: rowH), rotationDegrees: 90),
                Slot(frame: CGRect(x: halfW + pad, y: 0, width: halfW, height: rowH), rotationDegrees: -90),
                Slot(frame: CGRect(x: 0, y: rowH + pad, width: halfW, height: rowH), rotationDegrees: 90),
                Slot(frame: CGRect(x: halfW + pad, y: rowH + pad, width: halfW, height: rowH), rotationDegrees: -90),
                Slot(frame: CGRect(x: 0, y: 2 * (rowH + pad), width: w, height: rowH), rotationDegrees: 0),
            ]
        case 6:
            let rowH = (h - 3 * pad) / 4
            return [
                Slot(frame: CGRect(x: 0, y: 0, width: w, height: rowH), rotationDegrees: 180),
                Slot(frame: CGRect(x: 0, y: rowH + pad, width: halfW, height: rowH), rotationDegrees: 90),
                Slot(frame: CGRect(x: halfW + pad, y: rowH + pad, width: halfW, height: rowH), rotationDegrees: -90),
                Slot(frame: CGRect(x: 0, y: 2 * (rowH + pad), width: halfW, height: rowH), rotationDegrees: 90),
                Slot(frame: CGRect(x: halfW + pad, y: 2 * (rowH + pad), width: halfW, height: rowH), rotationDegrees: -90),
                Slot(frame: CGRect(x: 0, y: 3 * (rowH + pad), width: w, height: rowH), rotationDegrees: 0),
            ]
        default:
            return []
        }
    }
}
