import UIKit

class GameBoardView: UIView {
    private var cellViews: [PlayerCellView] = []
    var onEditRequested: ((Int, CGFloat) -> Void)?
    var onLifeChanged: ((Int, Int) -> Void)?
    /// Fires when a commander-damage badge is tapped in a cell (always +1). Args:
    /// cell index, the opponent's id, and the delta.
    var onCommanderDamageChanged: ((Int, Int, Int) -> Void)?
    /// Fires when a swipe-to-reset gesture is committed. The caller is expected to
    /// rebuild player state; the wipe-in animation is driven by `playWipeIn()`.
    var onResetRequested: (() -> Void)?

    private static let gap: CGFloat = BoardInsets.interCellGap

    /// Target dot diameter for the on-board life totals. Cells render at this
    /// size unless a cell is too small to fit it, in which case every cell
    /// shrinks together (see `layoutSubviews`). The input overlay is unaffected
    /// — it doesn't set `maxDotSize`, so its number still scales to fill.
    private static let targetDotSize: CGFloat = 18

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

    /// Debug overlay: when true, strokes every cell slot (and the board
    /// boundary) on top of the cells so the seating grid is visible. Toggled
    /// from the toolbar button.
    var showsGridSkeleton: Bool = false {
        didSet {
            guard showsGridSkeleton != oldValue else { return }
            skeletonView.isHidden = !showsGridSkeleton
            setNeedsLayout()
        }
    }
    private let skeletonView = UIView()
    private let skeletonShape = CAShapeLayer()
    /// Tap-zone overlay drawn alongside the slot outlines: the two dividers that
    /// split each cell into its left / center / right thirds, oriented along the
    /// player's axis (vertical for 0°/180° seats, horizontal for ±90°).
    private let tapZoneShape = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupResetGesture()
        setupSkeleton()
        observeFontChanges()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupResetGesture()
        setupSkeleton()
        observeFontChanges()
    }

    /// A dot-font swap changes the glyph dimensions, so the board has to
    /// recompute its uniform dot size and re-lay-out every cell.
    private func observeFontChanges() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(fontDidChange),
            name: DotFontSettings.didChange, object: nil
        )
    }

    @objc private func fontDidChange() { setNeedsLayout() }

    private func setupResetGesture() {
        resetPanGesture.addTarget(self, action: #selector(handleResetSwipe(_:)))
        resetPanGesture.minimumNumberOfTouches = 1
        resetPanGesture.maximumNumberOfTouches = 1
        // A life tap commits on touch-up. By default UIKit holds each cell's
        // `touchesEnded` until this pan recognizer resolves, which delays every
        // tap's increment (and bunches up rapid taps). Deliver touch-up
        // immediately; a real swipe still cancels the cell touch via
        // `cancelsTouchesInView`, so the gesture itself is unaffected.
        resetPanGesture.delaysTouchesEnded = false
        addGestureRecognizer(resetPanGesture)
    }

    private func setupSkeleton() {
        skeletonView.isUserInteractionEnabled = false
        skeletonView.isHidden = true
        skeletonShape.fillColor = UIColor.clear.cgColor
        skeletonShape.strokeColor = UIColor.systemGreen.withAlphaComponent(0.9).cgColor
        skeletonShape.lineWidth = 1
        skeletonView.layer.addSublayer(skeletonShape)

        tapZoneShape.fillColor = UIColor.clear.cgColor
        tapZoneShape.strokeColor = UIColor.systemOrange.withAlphaComponent(0.9).cgColor
        tapZoneShape.lineWidth = 1
        skeletonView.layer.addSublayer(tapZoneShape)

        addSubview(skeletonView)
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
            cell.onCommanderDamageAdjust = { [weak self] opponentId, delta in
                self?.onCommanderDamageChanged?(idx, opponentId, delta)
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

    /// Targeted, animated update of one commander-damage badge after an inline tap.
    func setCommanderDamage(cellIndex: Int, opponentId: Int, value: Int) {
        guard cellIndex < cellViews.count else { return }
        cellViews[cellIndex].setCommanderDamage(value, forOpponent: opponentId)
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
        // Fixed target size, but never larger than the smallest cell can fit, so
        // every cell still shares one uniform dot size.
        let dotSize = min(Self.uniformDotSize(for: slots), Self.targetDotSize)

        for (i, cell) in cellViews.enumerated() {
            guard i < slots.count else { break }
            let slot = slots[i]
            cell.rotation = slot.rotationDegrees
            cell.maxDotSize = dotSize
            cell.frame = slot.frame
        }

        updateSkeleton(slots: slots)
    }

    /// Redraw (or clear) the grid-skeleton overlay for the current slots. Kept
    /// on top of the cells so the outlines stay visible over the dot grids.
    private func updateSkeleton(slots: [Slot]) {
        skeletonView.frame = bounds
        skeletonShape.frame = bounds
        tapZoneShape.frame = bounds
        bringSubviewToFront(skeletonView)

        guard showsGridSkeleton else {
            skeletonShape.path = nil
            tapZoneShape.path = nil
            return
        }

        let path = UIBezierPath()
        path.append(UIBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)))
        for slot in slots {
            path.append(UIBezierPath(rect: slot.frame))
        }
        skeletonShape.path = path.cgPath

        // Tap targets tile each cell with no gaps/overlap: the life zones fill the
        // dot-number area (outlined), and the commander-damage badges fill the
        // band below it as contiguous columns. The center "edit" zone is a fixed
        // `editZoneWidth` band centered on the number; the ± zones fill the rest.
        // Split along the player's left→right axis — 0°/180° split horizontally
        // (vertical dividers); ±90° split vertically — matching `tapZone`.
        let tapPath = UIBezierPath()
        let editHalf = PlayerCellView.editZoneWidth / 2
        for (i, slot) in slots.enumerated() where i < cellViews.count {
            let cell = cellViews[i]
            let numRect = cell.numberAreaRect(in: self)
            tapPath.append(UIBezierPath(rect: numRect))
            let axisIsHorizontal = abs(Int(slot.rotationDegrees)) != 90
            for s in [-editHalf, editHalf] {
                if axisIsHorizontal {
                    let x = numRect.midX + s
                    tapPath.move(to: CGPoint(x: x, y: numRect.minY))
                    tapPath.addLine(to: CGPoint(x: x, y: numRect.maxY))
                } else {
                    let y = numRect.midY + s
                    tapPath.move(to: CGPoint(x: numRect.minX, y: y))
                    tapPath.addLine(to: CGPoint(x: numRect.maxX, y: y))
                }
            }
            for rect in cell.commanderHitRects(in: self) {
                tapPath.append(UIBezierPath(rect: rect))
            }
        }
        tapZoneShape.path = tapPath.cgPath
    }

    private static func uniformDotSize(for slots: [Slot]) -> CGFloat {
        slots.map { slot in
            let swapped = abs(Int(slot.rotationDegrees)) == 90
            let contentW = (swapped ? slot.frame.height : slot.frame.width) - PlayerCellView.contentInset * 2
            let contentH = (swapped ? slot.frame.width : slot.frame.height) - PlayerCellView.verticalInset * 2
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
