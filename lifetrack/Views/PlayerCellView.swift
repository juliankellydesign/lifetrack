import UIKit

class PlayerCellView: UIView {
    static let contentInset: CGFloat = 12

    /// ± adjust-direction icons flanking the life total (minus on the player's
    /// left, plus on the right). Part of the 4pt grid / units-of-20 system:
    /// 20×20 icons, 20pt gap from the digits, dimmed to 30% opacity.
    private static let adjustIconSize: CGFloat = 20
    private static let adjustIconSpacing: CGFloat = 20
    private static let adjustIconAlpha: CGFloat = 0.3

    /// Transient net-change readout. Each tap (and ±10 hold tick) accumulates
    /// into `sessionDelta`; the magnitude is shown next to the active side's ±
    /// icon (the icon *is* the sign) and the whole session fades out after
    /// `deltaIdleTimeout` of no further input. Net-signed, so +7 then −2 reads
    /// as a "+5" next to the plus icon. `deltaSpacing` is the tight gap between
    /// the sign icon and its digits.
    private static let deltaIdleTimeout: TimeInterval = 1.4
    private static let deltaSpacing: CGFloat = 8

    private(set) var lifeTotal: Int = Player.defaultLife
    var rotation: CGFloat = 0 {
        didSet { badgeBar.iconRotation = rotation }
    }
    var maxDotSize: CGFloat? {
        didSet { dotNumberView.maxDotSize = maxDotSize }
    }
    var onEditRequested: (() -> Void)?
    var onLifeChanged: ((Int) -> Void)?
    var isBeingEdited: Bool = false {
        didSet {
            dotNumberView.isHidden = isBeingEdited
            badgeBar.isHidden = isBeingEdited
            minusIcon.isHidden = isBeingEdited
            plusIcon.isHidden = isBeingEdited
            deltaLabel.isHidden = isBeingEdited
            if isBeingEdited { cancelDeltaSession() }
        }
    }

    private let contentContainer = UIView()
    let dotNumberView = DotNumberView()
    let badgeBar = PlayerCellBadgeBar()
    private let minusIcon = UIImageView()
    private let plusIcon = UIImageView()
    private let deltaLabel = UILabel()
    private var sessionDelta = 0
    private var deltaIdleTimer: Timer?

    private var changeDirection: ChangeDirection?
    private var repeatTimer: Timer?
    private var centerHoldTimer: Timer?
    private var isTouching = false

    private static let holdActivationDelay: TimeInterval = 0.5
    private static let repeatInterval: TimeInterval = 0.35
    private static let bulkChangeMagnitude = 10

    private static let lifeChangeHaptic = UIImpactFeedbackGenerator(style: .light)
    private static let bulkChangeHaptic = UIImpactFeedbackGenerator(style: .medium)
    private static let editActivationHaptic = UIImpactFeedbackGenerator(style: .medium)

    private enum TapZone { case left, center, right }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        contentContainer.isUserInteractionEnabled = false
        addSubview(contentContainer)
        contentContainer.addSubview(dotNumberView)
        contentContainer.addSubview(badgeBar)
        configureAdjustIcon(minusIcon, named: "IconMinus")
        configureAdjustIcon(plusIcon, named: "IconPlus")

        deltaLabel.font = Typography.lifeDelta.uiFont
        deltaLabel.textColor = .white
        deltaLabel.textAlignment = .center
        deltaLabel.alpha = 0
        deltaLabel.isUserInteractionEnabled = false
        contentContainer.addSubview(deltaLabel)
    }

    private func configureAdjustIcon(_ iconView: UIImageView, named: String) {
        iconView.image = UIImage(named: named)?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = .white
        iconView.alpha = Self.adjustIconAlpha
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        contentContainer.addSubview(iconView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let inset = PlayerCellView.contentInset
        let swapped = abs(Int(rotation)) == 90
        let contentW = (swapped ? bounds.height : bounds.width) - inset * 2
        let contentH = (swapped ? bounds.width : bounds.height) - inset * 2

        contentContainer.transform = .identity
        contentContainer.bounds = CGRect(x: 0, y: 0, width: contentW, height: contentH)
        contentContainer.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)

        let badgeRowH = Self.badgeRowHeight(forContentHeight: contentH)
        let dotH = contentH - badgeRowH

        dotNumberView.frame = CGRect(x: 0, y: 0, width: contentW, height: dotH)
        badgeBar.frame = CGRect(x: 0, y: dotH, width: contentW, height: badgeRowH)

        // ± icons flank the rendered number (minus left, plus right), vertically
        // centered on it, with a fixed 20pt gap — placed in the rotated content
        // frame so they read correctly from each player's seat.
        let numRect = dotNumberView.numberContentRect
            .offsetBy(dx: dotNumberView.frame.minX, dy: dotNumberView.frame.minY)
        let iconSize = Self.adjustIconSize
        let gap = Self.adjustIconSpacing
        let iconY = numRect.midY - iconSize / 2

        // The net-change readout reads as "<sign-icon><magnitude>": the sign is the
        // existing ± icon, the label is just the digits next to it.
        deltaLabel.sizeToFit()
        let dW = deltaLabel.bounds.width
        let dH = deltaLabel.bounds.height
        let dGap = Self.deltaSpacing
        let labelY = numRect.midY - dH / 2

        // Plus icon never moves — a positive readout slots in outboard (to its right).
        plusIcon.frame = CGRect(x: numRect.maxX + gap, y: iconY,
                                width: iconSize, height: iconSize)

        if sessionDelta < 0 {
            // Negative: the digits go between the minus icon and the number, so the
            // minus icon slides left to open that room (animated by registerDelta).
            let labelX = numRect.minX - gap - dW
            deltaLabel.frame = CGRect(x: labelX, y: labelY, width: dW, height: dH)
            minusIcon.frame = CGRect(x: labelX - dGap - iconSize, y: iconY,
                                     width: iconSize, height: iconSize)
        } else {
            minusIcon.frame = CGRect(x: numRect.minX - gap - iconSize, y: iconY,
                                     width: iconSize, height: iconSize)
            deltaLabel.frame = CGRect(x: plusIcon.frame.maxX + dGap, y: labelY,
                                      width: dW, height: dH)
        }

        contentContainer.transform = CGAffineTransform(rotationAngle: rotation * .pi / 180)
    }

    /// Height of the combined badge row (commander damage + counters) below the
    /// life total. Exposed statically so GameBoardView can subtract it when
    /// computing dot sizes.
    static func badgeRowHeight(forContentHeight contentH: CGFloat) -> CGFloat {
        let h = contentH * CommanderDamageRowView.heightFraction
        return min(max(h, CommanderDamageRowView.minHeight), CommanderDamageRowView.maxHeight)
    }

    func setLifeTotal(_ value: Int, direction: ChangeDirection?, animated: Bool) {
        lifeTotal = value
        changeDirection = direction
        dotNumberView.updateNumber(value, direction: direction, animated: animated)
    }

    /// Configures the combined commander-damage + counter row.
    func setBadges(
        layout: PlayerLayout,
        opponentIds: [Int],
        damages: [Int],
        counters: [LifeCounter: Int]
    ) {
        badgeBar.iconRotation = rotation
        badgeBar.configure(
            layout: layout,
            opponentIds: opponentIds,
            damages: damages,
            counters: counters
        )
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isTouching, let touch = touches.first else { return }
        isTouching = true
        let loc = touch.location(in: self)
        let zone = tapZone(at: loc)

        switch zone {
        case .left:
            // Commit ±1 on touch-down (like the badge controls) so rapid tapping
            // responds to each strike, not each lift. A held press then escalates
            // to the ±10 repeat after holdActivationDelay.
            applyChange(increment: false, magnitude: 1, bulk: false)
            scheduleBulkRepeat(increment: false)
        case .right:
            applyChange(increment: true, magnitude: 1, bulk: false)
            scheduleBulkRepeat(increment: true)
        case .center:
            centerHoldTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                Self.editActivationHaptic.impactOccurred(intensity: 0.9)
                self?.onEditRequested?()
                self?.centerHoldTimer = nil
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouch()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouch()
    }

    private func scheduleBulkRepeat(increment: Bool) {
        repeatTimer = Timer.scheduledTimer(withTimeInterval: Self.holdActivationDelay,
                                           repeats: false) { [weak self] _ in
            self?.beginBulkRepeat(increment: increment)
        }
    }

    private func beginBulkRepeat(increment: Bool) {
        applyChange(increment: increment, magnitude: Self.bulkChangeMagnitude, bulk: true)
        repeatTimer = Timer.scheduledTimer(withTimeInterval: Self.repeatInterval,
                                           repeats: true) { [weak self] _ in
            self?.applyChange(increment: increment,
                              magnitude: Self.bulkChangeMagnitude,
                              bulk: true)
        }
    }

    private func endTouch() {
        repeatTimer?.invalidate()
        repeatTimer = nil
        centerHoldTimer?.invalidate()
        centerHoldTimer = nil
        isTouching = false
    }

    // MARK: - Helpers

    private func playerFraction(at location: CGPoint) -> CGFloat {
        let deg = Int(rotation)
        switch deg {
        case 90:       return location.y / bounds.height
        case -90:      return 1 - (location.y / bounds.height)
        case 180, -180: return 1 - (location.x / bounds.width)
        default:       return location.x / bounds.width
        }
    }

    private func tapZone(at location: CGPoint) -> TapZone {
        let f = playerFraction(at: location)
        if f < 1.0 / 3.0 { return .left }
        if f > 2.0 / 3.0 { return .right }
        return .center
    }

    private func applyChange(increment: Bool, magnitude: Int, bulk: Bool) {
        changeDirection = increment ? .increasing : .decreasing
        lifeTotal += increment ? magnitude : -magnitude
        if bulk {
            Self.bulkChangeHaptic.impactOccurred(intensity: 0.85)
        } else {
            Self.lifeChangeHaptic.impactOccurred(intensity: 0.55)
        }
        dotNumberView.updateNumber(lifeTotal, direction: changeDirection, animated: true)
        registerDelta(increment ? magnitude : -magnitude)
        onLifeChanged?(lifeTotal)
    }

    // MARK: - Net-change readout

    /// Accumulate a life change into the running session delta, surface the
    /// magnitude next to the active side's icon, brighten that icon, and (re)arm
    /// the idle fade. The minus icon slides over (animated) to make room.
    private func registerDelta(_ amount: Int) {
        sessionDelta += amount
        // Net zero — nothing to show; fade the session out as if it had idled.
        guard sessionDelta != 0 else { endDeltaSession(); return }

        deltaLabel.text = "\(abs(sessionDelta))"
        let positive = sessionDelta > 0
        setNeedsLayout()
        UIView.animate(withDuration: 0.2, delay: 0,
                       usingSpringWithDamping: 0.85, initialSpringVelocity: 0,
                       options: .beginFromCurrentState) {
            self.layoutIfNeeded()
            self.deltaLabel.alpha = 1
            self.plusIcon.alpha = positive ? 1 : Self.adjustIconAlpha
            self.minusIcon.alpha = positive ? Self.adjustIconAlpha : 1
        }
        scheduleDeltaIdle()
    }

    private func scheduleDeltaIdle() {
        deltaIdleTimer?.invalidate()
        deltaIdleTimer = Timer.scheduledTimer(withTimeInterval: Self.deltaIdleTimeout,
                                              repeats: false) { [weak self] _ in
            self?.endDeltaSession()
        }
    }

    /// Fade the readout away, glide the minus icon back to its resting slot, and
    /// settle both icons to their dim alpha. The label fades in place (its frame
    /// is frozen) so it doesn't jump sides as the accumulator clears to zero.
    private func endDeltaSession() {
        deltaIdleTimer?.invalidate()
        deltaIdleTimer = nil
        let frozen = deltaLabel.frame
        sessionDelta = 0
        setNeedsLayout()
        UIView.animate(withDuration: 0.4, delay: 0, options: .beginFromCurrentState) {
            self.layoutIfNeeded()           // minus icon glides back to resting
            self.deltaLabel.frame = frozen  // …but the label stays put while fading
            self.deltaLabel.alpha = 0
            self.minusIcon.alpha = Self.adjustIconAlpha
            self.plusIcon.alpha = Self.adjustIconAlpha
        }
    }

    /// Tear down the session immediately (no animation) — for edit/reset.
    private func cancelDeltaSession() {
        deltaIdleTimer?.invalidate()
        deltaIdleTimer = nil
        sessionDelta = 0
        deltaLabel.alpha = 0
        minusIcon.alpha = Self.adjustIconAlpha
        plusIcon.alpha = Self.adjustIconAlpha
        setNeedsLayout()
    }

    // MARK: - Swipe-to-reset sweep

    /// Apply the reset-swipe positional fade to this cell's dots and badge bar.
    /// Coordinates are in `reference`'s space (typically the GameBoardView).
    func applySweep(
        in reference: UIView,
        axisIsHorizontal: Bool,
        leadingEdge: CGFloat,
        direction: CGFloat,
        feather: CGFloat
    ) {
        dotNumberView.applySweep(
            in: reference,
            axisIsHorizontal: axisIsHorizontal,
            leadingEdge: leadingEdge,
            direction: direction,
            feather: feather
        )

        func progress(for view: UIView) -> CGFloat {
            let c = reference.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), from: view)
            let pos = axisIsHorizontal ? c.x : c.y
            return max(0, min(1, ((leadingEdge - pos) * direction) / feather))
        }

        badgeBar.alpha = 1 - progress(for: badgeBar)
        minusIcon.alpha = Self.adjustIconAlpha * (1 - progress(for: minusIcon))
        plusIcon.alpha = Self.adjustIconAlpha * (1 - progress(for: plusIcon))
        if sessionDelta != 0 {
            deltaLabel.alpha = 1 - progress(for: deltaLabel)
        }
    }

    func resetSweep(animated: Bool) {
        dotNumberView.resetSweep(animated: animated)
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0,
                           usingSpringWithDamping: 0.9, initialSpringVelocity: 0,
                           options: .beginFromCurrentState) {
                self.badgeBar.alpha = 1
                self.minusIcon.alpha = Self.adjustIconAlpha
                self.plusIcon.alpha = Self.adjustIconAlpha
            }
        } else {
            badgeBar.alpha = 1
            minusIcon.alpha = Self.adjustIconAlpha
            plusIcon.alpha = Self.adjustIconAlpha
        }
    }

    /// Snap content to "off" (dots invisible, badge + icons hidden). Pair with
    /// `resetSweep(animated: true)` to play the roll-in.
    func snapToOff() {
        dotNumberView.snapToOff()
        cancelDeltaSession()
        badgeBar.alpha = 0
        minusIcon.alpha = 0
        plusIcon.alpha = 0
    }
}
