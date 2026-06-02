import UIKit

class GameBoardView: UIView {
    private var cellViews: [PlayerCellView] = []
    var onEditRequested: ((Int, CGFloat) -> Void)?
    var onLifeChanged: ((Int, Int) -> Void)?
    /// Fires when a swipe-to-reset gesture is committed. The caller is expected to
    /// rebuild player state; the wipe-in animation is driven by `playWipeIn()`.
    var onResetRequested: (() -> Void)?

    private static let contentInset: CGFloat = PlayerCellView.contentInset
    private static let gap: CGFloat = BoardInsets.interCellGap

    /// Width over which the leading edge of the swipe blends from "natural" to "wiped".
    private static let sweepFeather: CGFloat = 60

    private struct Slot {
        let frame: CGRect
        let rotationDegrees: CGFloat
    }

    private var currentSlots: [Slot] = []
    private(set) var layout: PlayerLayout = .fourA

    private let resetPanGesture = UIPanGestureRecognizer()
    private var sweepStartLocation: CGPoint = .zero
    private var sweepAxisIsHorizontal: Bool = true
    private var sweepDirection: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupResetGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupResetGesture()
    }

    private func setupResetGesture() {
        resetPanGesture.addTarget(self, action: #selector(handleResetSwipe(_:)))
        resetPanGesture.minimumNumberOfTouches = 1
        resetPanGesture.maximumNumberOfTouches = 1
        addGestureRecognizer(resetPanGesture)
    }

    func configure(layout: PlayerLayout, players: [Player]) {
        self.layout = layout
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
        applyPlayerBadges(from: players)
        setNeedsLayout()
    }

    /// Refresh every cell's badge bar (commander damage + counters) from the
    /// current `players` array. Each cell shows damage for all *other* players
    /// in stable id order, plus counters drawn from that cell's own player.
    func applyPlayerBadges(from players: [Player]) {
        for (i, player) in players.enumerated() where i < cellViews.count {
            let opponents = players.filter { $0.id != player.id }.sorted(by: { $0.id < $1.id })
            cellViews[i].setBadges(
                layout: layout,
                opponentIds: opponents.map { $0.id },
                damages: opponents.map { player.damage(from: $0.id) },
                counters: player.counters
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
        let slots = layoutSlots(for: layout, in: bounds.size)
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
            let dotH = contentH - PlayerCellView.badgeRowHeight(forContentHeight: contentH)
            return DotNumberView.dotSize(fitting: CGSize(width: contentW, height: dotH))
        }.min() ?? 0
    }

    // MARK: - Swipe-to-reset

    @objc private func handleResetSwipe(_ pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began:
            let v = pan.velocity(in: self)
            sweepAxisIsHorizontal = abs(v.x) >= abs(v.y)
            let dir: CGFloat = sweepAxisIsHorizontal
                ? (v.x >= 0 ? 1 : -1)
                : (v.y >= 0 ? 1 : -1)
            sweepDirection = dir
            sweepStartLocation = pan.location(in: self)
            applySweep(currentLocation: pan.location(in: self))
        case .changed:
            applySweep(currentLocation: pan.location(in: self))
        case .ended:
            let translation = pan.translation(in: self)
            let velocity = pan.velocity(in: self)
            let span = sweepAxisIsHorizontal ? bounds.width : bounds.height
            let progressed = sweepAxisIsHorizontal ? abs(translation.x) : abs(translation.y)
            let speed = sweepAxisIsHorizontal ? abs(velocity.x) : abs(velocity.y)
            let shouldCommit = progressed > span * 0.5 || speed > 800
            if shouldCommit {
                commitWipe()
            } else {
                rollbackWipe()
            }
        case .cancelled, .failed:
            rollbackWipe()
        default:
            break
        }
    }

    private func applySweep(currentLocation: CGPoint) {
        let edge = sweepAxisIsHorizontal ? currentLocation.x : currentLocation.y
        for cell in cellViews {
            cell.applySweep(
                in: self,
                axisIsHorizontal: sweepAxisIsHorizontal,
                leadingEdge: edge,
                direction: sweepDirection,
                feather: Self.sweepFeather
            )
        }
    }

    private func commitWipe() {
        let span = sweepAxisIsHorizontal ? bounds.width : bounds.height
        let endEdge: CGFloat = sweepDirection > 0
            ? span + Self.sweepFeather
            : -Self.sweepFeather
        UIView.animate(withDuration: 0.25, delay: 0,
                       options: [.beginFromCurrentState, .curveEaseOut],
                       animations: {
            for cell in self.cellViews {
                cell.applySweep(
                    in: self,
                    axisIsHorizontal: self.sweepAxisIsHorizontal,
                    leadingEdge: endEdge,
                    direction: self.sweepDirection,
                    feather: Self.sweepFeather
                )
            }
        }, completion: { _ in
            self.onResetRequested?()
        })
    }

    private func rollbackWipe() {
        UIView.animate(withDuration: 0.3, delay: 0,
                       usingSpringWithDamping: 0.85, initialSpringVelocity: 0,
                       options: [.beginFromCurrentState]) {
            for cell in self.cellViews {
                cell.resetSweep(animated: false)
            }
        }
    }

    /// Animate the freshly-rebuilt cells in using the same staggered dot roll
    /// the life total plays on increment — each digit fills in bottom-up from
    /// blank. Cells fire in `PlayerSeat.clockwiseIndex` order with a 100ms
    /// stagger between each. Call after `configure(with:)` rebuilds cells in
    /// response to `onResetRequested`.
    func playWipeIn() {
        layoutIfNeeded()
        for cell in cellViews {
            cell.snapToOff()
        }
        let seats = layout.seats
        // asyncAfter (even at delay 0) also gives the snap a runloop to commit
        // before the first spring starts.
        for (i, cell) in cellViews.enumerated() where i < seats.count {
            let step = seats[i].clockwiseIndex
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.1) {
                cell.resetSweep(animated: true)
            }
        }
    }

    /// Project each seat's unit-square `cellRect` into the board frame, insetting
    /// any edge that doesn't touch the board boundary by half the inter-cell gap.
    /// This way different layouts (clean grids, diamond, mixed) all get
    /// consistent gutters automatically.
    private func layoutSlots(for layout: PlayerLayout, in size: CGSize) -> [Slot] {
        let halfGap = Self.gap / 2
        let w = size.width
        let h = size.height
        let eps: CGFloat = 0.0001

        return layout.seats.map { seat in
            let r = seat.cellRect
            let leftEdgeAtBoundary = r.minX < eps
            let rightEdgeAtBoundary = r.maxX > 1 - eps
            let topEdgeAtBoundary = r.minY < eps
            let bottomEdgeAtBoundary = r.maxY > 1 - eps

            let xMin = r.minX * w + (leftEdgeAtBoundary ? 0 : halfGap)
            let xMax = r.maxX * w - (rightEdgeAtBoundary ? 0 : halfGap)
            let yMin = r.minY * h + (topEdgeAtBoundary ? 0 : halfGap)
            let yMax = r.maxY * h - (bottomEdgeAtBoundary ? 0 : halfGap)

            return Slot(
                frame: CGRect(x: xMin, y: yMin, width: xMax - xMin, height: yMax - yMin),
                rotationDegrees: seat.rotationDegrees
            )
        }
    }
}
