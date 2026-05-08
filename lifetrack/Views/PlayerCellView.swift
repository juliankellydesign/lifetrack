import UIKit

class PlayerCellView: UIView {
    static let contentInset: CGFloat = 12

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
        }
    }

    private let contentContainer = UIView()
    let dotNumberView = DotNumberView()
    let badgeBar = PlayerCellBadgeBar()

    private var changeDirection: ChangeDirection?
    private var repeatTimer: Timer?
    private var centerHoldTimer: Timer?
    private var isTouching = false
    private var pendingTapIncrement: Bool?
    private var didStartRepeating = false

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
        opponentIds: [Int],
        playerCount: Int,
        damages: [Int],
        counters: [LifeCounter: Int]
    ) {
        badgeBar.iconRotation = rotation
        badgeBar.configure(
            opponentIds: opponentIds,
            playerCount: playerCount,
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
            applyTilt(angle: -7)
            scheduleBulkRepeat(increment: false)
        case .right:
            applyTilt(angle: 7)
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
        endTouch(committingTap: true)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouch(committingTap: false)
    }

    private func scheduleBulkRepeat(increment: Bool) {
        pendingTapIncrement = increment
        didStartRepeating = false
        repeatTimer = Timer.scheduledTimer(withTimeInterval: Self.holdActivationDelay,
                                           repeats: false) { [weak self] _ in
            self?.beginBulkRepeat(increment: increment)
        }
    }

    private func beginBulkRepeat(increment: Bool) {
        didStartRepeating = true
        applyChange(increment: increment, magnitude: Self.bulkChangeMagnitude, bulk: true)
        repeatTimer = Timer.scheduledTimer(withTimeInterval: Self.repeatInterval,
                                           repeats: true) { [weak self] _ in
            self?.applyChange(increment: increment,
                              magnitude: Self.bulkChangeMagnitude,
                              bulk: true)
        }
    }

    private func endTouch(committingTap: Bool) {
        repeatTimer?.invalidate()
        repeatTimer = nil
        centerHoldTimer?.invalidate()
        centerHoldTimer = nil

        if committingTap, !didStartRepeating, let increment = pendingTapIncrement {
            applyChange(increment: increment, magnitude: 1, bulk: false)
        }

        pendingTapIncrement = nil
        didStartRepeating = false
        isTouching = false
        applyTilt(angle: 0)
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
        onLifeChanged?(lifeTotal)
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

        let badgeCenter = reference.convert(
            CGPoint(x: badgeBar.bounds.midX, y: badgeBar.bounds.midY),
            from: badgeBar
        )
        let bPos = axisIsHorizontal ? badgeCenter.x : badgeCenter.y
        let bSigned = (leadingEdge - bPos) * direction
        let bProgress = max(0, min(1, bSigned / feather))
        badgeBar.alpha = 1 - bProgress
    }

    func resetSweep(animated: Bool) {
        dotNumberView.resetSweep(animated: animated)
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0,
                           usingSpringWithDamping: 0.9, initialSpringVelocity: 0,
                           options: .beginFromCurrentState) {
                self.badgeBar.alpha = 1
            }
        } else {
            badgeBar.alpha = 1
        }
    }

    private func applyTilt(angle: CGFloat) {
        let radians = angle * .pi / 180
        let rotRad = rotation * .pi / 180

        var t = CATransform3DIdentity
        t.m34 = -1.0 / 500
        t = CATransform3DRotate(t, radians, -sin(rotRad), cos(rotRad), 0)

        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 1.0,
                       initialSpringVelocity: 0, options: []) {
            self.layer.transform = t
        }
    }
}
