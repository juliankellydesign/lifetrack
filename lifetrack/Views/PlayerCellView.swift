import UIKit
import SwiftUI

class PlayerCellView: UIView {
  /// Horizontal content margin (left/right in the player's reading frame).
  static let contentInset: CGFloat = 12
  /// Top/bottom content margin in the player's reading frame.
  static let verticalInset: CGFloat = 8
  /// Width of the center interaction zone, centered on the number: 5 dots on
  /// the 20pt grid (18pt dot + padding). A tap opens commander damage, while a
  /// hold opens exact life input. The ± zones fill the rest of the cell.
  static let editZoneWidth: CGFloat = 100

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
    didSet { setNeedsLayout() }
  }
  var maxDotSize: CGFloat? {
    didSet { dotNumberView.maxDotSize = maxDotSize }
  }
  var onEditRequested: (() -> Void)?
  var onLifeChanged: ((Int) -> Void)?
  var onCommanderModeRequested: (() -> Void)?
  var onCommanderModeExitRequested: (() -> Void)?
  var onCommanderDamageAdjust: ((_ delta: Int) -> Void)?
  var isBeingEdited: Bool = false {
    didSet {
      dotNumberView.isHidden = isBeingEdited
      minusIcon.isHidden = isBeingEdited
      plusIcon.isHidden = isBeingEdited
      deltaView.isHidden = isBeingEdited
      if isBeingEdited { cancelDeltaSession() }
    }
  }

  private let contentContainer = UIView()
  private let numberPressContainer = UIView()
  let dotNumberView = DotNumberView()
  private let minusIcon = UIImageView()
  private let plusIcon = UIImageView()
  /// The net-change readout uses a hosted SwiftUI `numericText` transition.
  /// `deltaView` is the hosting controller's view; `deltaModel.value` holds the
  /// current magnitude.
  private let deltaModel = RollingValueModel()
  private lazy var deltaHost = UIHostingController(rootView: RollingNumberText(model: deltaModel))
  private var deltaView: UIView { deltaHost.view }
  private var sessionDelta = 0
  private var deltaIdleTimer: Timer?

  private var changeDirection: ChangeDirection?
  private var repeatTimer: Timer?
  private var centerHoldTimer: Timer?
  private var isTouching = false
  private var didActivateCenterHold = false

  private static let holdActivationDelay: TimeInterval = 0.5
  private static let repeatInterval: TimeInterval = 0.35
  private static let bulkChangeMagnitude = 10
  private static let pressedNumberScale: CGFloat = 0.95

  private static let lifeChangeHaptic = UIImpactFeedbackGenerator(style: .light)
  private static let bulkChangeHaptic = UIImpactFeedbackGenerator(style: .medium)
  private static let editActivationHaptic = UIImpactFeedbackGenerator(style: .medium)

  private enum TapZone { case left, center, right }
  private enum DisplayMode {
    case life
    case commanderSource
    case commanderRecipient
  }
  private var displayMode: DisplayMode = .life

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
    contentContainer.addSubview(numberPressContainer)
    numberPressContainer.addSubview(dotNumberView)
    configureAdjustIcon(minusIcon, named: "IconMinus")
    configureAdjustIcon(plusIcon, named: "IconPlus")

    deltaModel.font = Typography.lifeDelta.swiftUIFont
    deltaModel.lineHeight = Typography.lifeDelta.lineHeight
    deltaModel.tintColor = .white
    deltaView.backgroundColor = .clear
    deltaView.isUserInteractionEnabled = false
    deltaView.alpha = 0
    contentContainer.addSubview(deltaView)
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

    // Player's reading frame: horizontal extent uses the 12pt side margin,
    // vertical extent the 8pt top/bottom margin.
    let swapped = abs(Int(rotation)) == 90
    let contentW = (swapped ? bounds.height : bounds.width) - Self.contentInset * 2
    let contentH = (swapped ? bounds.width : bounds.height) - Self.verticalInset * 2

    UIView.performWithoutAnimation {
      contentContainer.transform = .identity
      contentContainer.bounds = CGRect(x: 0, y: 0, width: contentW, height: contentH)
      contentContainer.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
      numberPressContainer.bounds = contentContainer.bounds
      numberPressContainer.center = CGPoint(
        x: contentContainer.bounds.midX,
        y: contentContainer.bounds.midY
      )
    }

    dotNumberView.frame = numberPressContainer.bounds

    // ± icons flank the rendered number (minus left, plus right), vertically
    // centered on it, with a fixed 20pt gap — placed in the rotated content
    // frame so they read correctly from each player's seat.
    let numRect = dotNumberView.numberContentRect
      .offsetBy(dx: dotNumberView.frame.minX, dy: dotNumberView.frame.minY)
    let iconSize = Self.adjustIconSize
    let gap = Self.adjustIconSpacing
    let iconY = numRect.midY - iconSize / 2

    // The net-change readout reads as "<sign-icon><magnitude>": the sign is the
    // existing ± icon, the rolling label is just the digits next to it. Width
    // is measured from the Karl font (the hosted SwiftUI text fills the frame).
    let dH = Typography.lifeDelta.lineHeight
    let dW = deltaMagnitudeWidth()
    let dGap = Self.deltaSpacing
    let labelY = numRect.midY - dH / 2

    // Plus icon never moves — a positive readout slots in outboard (to its right).
    plusIcon.frame = CGRect(x: numRect.maxX + gap, y: iconY,
                width: iconSize, height: iconSize)

    if sessionDelta < 0 {
      // Negative: the digits go between the minus icon and the number, so the
      // minus icon slides left to open that room (animated by registerDelta).
      let labelX = numRect.minX - gap - dW
      deltaView.frame = CGRect(x: labelX, y: labelY, width: dW, height: dH)
      minusIcon.frame = CGRect(x: labelX - dGap - iconSize, y: iconY,
                   width: iconSize, height: iconSize)
    } else {
      minusIcon.frame = CGRect(x: numRect.minX - gap - iconSize, y: iconY,
                   width: iconSize, height: iconSize)
      deltaView.frame = CGRect(x: plusIcon.frame.maxX + dGap, y: labelY,
                   width: dW, height: dH)
    }

    // Value changes animate a layout pass for the temporary delta readout.
    // Keep the parent orientation out of that transaction so 180-degree
    // seats do not interpolate through an unintended flip.
    UIView.performWithoutAnimation {
      contentContainer.transform = CGAffineTransform(rotationAngle: rotation * .pi / 180)
    }
  }

  func setLifeTotal(
    _ value: Int,
    direction: ChangeDirection?,
    animated: Bool,
    shakes: Bool = true
  ) {
    let magnitude = abs(value - lifeTotal)
    lifeTotal = value
    changeDirection = direction
    dotNumberView.updateNumber(value, direction: direction, animated: animated)
    if animated, shakes, magnitude > 0 {
      dotNumberView.shakeForChange(magnitude: magnitude)
    }
    updateCommanderAccessibility()
  }

  func setSeatColors(_ colors: Set<SeatColor>, seed: Int, animated: Bool) {
    dotNumberView.setSeatColors(colors, seed: seed, animated: animated)
  }

  func shakeFirstPlayerLanding() {
    dotNumberView.shakeForFirstPlayerLanding()
  }

  func applyFirstPlayerBeam(
    in reference: UIView,
    origin: CGPoint,
    from startAngle: CGFloat,
    to endAngle: CGFloat,
    beamHalfWidth: CGFloat,
    dimAlpha: CGFloat,
    dimScale: CGFloat,
    peakScale: CGFloat
  ) {
    dotNumberView.applyClockwiseBeam(
      in: reference,
      origin: origin,
      from: startAngle,
      to: endAngle,
      beamHalfWidth: beamHalfWidth,
      dimAlpha: dimAlpha,
      dimScale: dimScale,
      peakScale: peakScale
    )
  }

  func setFirstPlayerEmphasis(
    alpha: CGFloat,
    scale: CGFloat,
    animated: Bool,
    duration: TimeInterval,
    usesSpring: Bool = true
  ) {
    dotNumberView.setFirstPlayerEmphasis(
      alpha: alpha,
      scale: scale,
      animated: animated,
      duration: duration,
      usesSpring: usesSpring
    )
  }

  func setFirstPlayerChromeVisible(_ visible: Bool, animated: Bool) {
    if !visible {
      cancelDeltaSession()
    }
    let changes = {
      self.minusIcon.alpha = visible ? Self.adjustIconAlpha : 0
      self.plusIcon.alpha = visible ? Self.adjustIconAlpha : 0
      self.deltaView.alpha = 0
    }

    if animated {
      UIView.animate(
        withDuration: 0.22,
        delay: 0,
        usingSpringWithDamping: 0.9,
        initialSpringVelocity: 0,
        options: [.beginFromCurrentState, .allowUserInteraction],
        animations: changes
      )
    } else {
      changes()
    }
  }

  func prepareLifeDisplay(_ value: Int, rotation: CGFloat) {
    displayMode = .life
    self.rotation = rotation
    lifeTotal = value
    dotNumberView.alpha = 1
    dotNumberView.isAccessibilityElement = true
    dotNumberView.accessibilityIdentifier = "life-total"
    dotNumberView.accessibilityHint =
      "Tap the center for commander damage. Hold the center to edit life total."
    dotNumberView.accessibilityCustomActions = [
      UIAccessibilityCustomAction(name: "Commander damage") { [weak self] _ in
        self?.onCommanderModeRequested?()
        return true
      },
      UIAccessibilityCustomAction(name: "Edit life total") { [weak self] _ in
        self?.onEditRequested?()
        return true
      },
    ]
    minusIcon.isHidden = false
    plusIcon.isHidden = false
    dotNumberView.updateNumber(value, direction: nil, animated: false)
    updateCommanderAccessibility()
    setNeedsLayout()
    layoutIfNeeded()
  }

  func prepareCommanderSourceDisplay(
    _ damage: Int,
    sourcePlayerNumber: Int,
    viewerRotation: CGFloat
  ) {
    displayMode = .commanderSource
    rotation = viewerRotation
    lifeTotal = damage
    dotNumberView.alpha = 1
    dotNumberView.isAccessibilityElement = true
    dotNumberView.accessibilityIdentifier = "commander-source-\(sourcePlayerNumber)"
    dotNumberView.accessibilityHint = "Adjusts commander damage to the selected player"
    dotNumberView.accessibilityCustomActions = [
      UIAccessibilityCustomAction(name: "Increase") { [weak self] _ in
        self?.applyChange(increment: true, magnitude: 1, bulk: false)
        return true
      },
      UIAccessibilityCustomAction(name: "Decrease") { [weak self] _ in
        self?.applyChange(increment: false, magnitude: 1, bulk: false)
        return true
      },
    ]
    minusIcon.isHidden = false
    plusIcon.isHidden = false
    cancelDeltaSession()
    dotNumberView.updateNumber(damage, direction: nil, animated: false)
    dotNumberView.accessibilityLabel = "Player \(sourcePlayerNumber) commander damage, \(damage)"
    setNeedsLayout()
    layoutIfNeeded()
  }

  func prepareCommanderRecipientDisplay(_ life: Int, viewerRotation: CGFloat) {
    displayMode = .commanderRecipient
    rotation = viewerRotation
    lifeTotal = life
    dotNumberView.alpha = Self.adjustIconAlpha
    dotNumberView.isAccessibilityElement = true
    dotNumberView.accessibilityIdentifier = "commander-recipient"
    dotNumberView.accessibilityHint = "Tap to exit commander damage mode"
    dotNumberView.accessibilityCustomActions = [
      UIAccessibilityCustomAction(name: "Exit commander damage") { [weak self] _ in
        self?.onCommanderModeExitRequested?()
        return true
      },
    ]
    minusIcon.isHidden = true
    plusIcon.isHidden = true
    cancelDeltaSession()
    dotNumberView.updateNumber(life, direction: nil, animated: false)
    dotNumberView.accessibilityLabel = "Life total, \(life)"
    setNeedsLayout()
    layoutIfNeeded()
  }

  @discardableResult
  func animateRippleOut(
    in reference: UIView,
    origin: CGPoint,
    maximumDistance: CGFloat,
    reversed: Bool
  ) -> UIView {
    cancelDeltaSession()
    let outgoingNumber = makeTransitionNumber(in: reference)
    dotNumberView.snapToOff()
    outgoingNumber.animateRippleOut(
      in: reference,
      origin: origin,
      maximumDistance: maximumDistance,
      reversed: reversed
    )
    UIView.animate(
      withDuration: 0.3,
      delay: 0,
      options: [.beginFromCurrentState, .allowUserInteraction]
    ) {
      self.minusIcon.alpha = 0
      self.plusIcon.alpha = 0
    }
    return outgoingNumber
  }

  private func makeTransitionNumber(in reference: UIView) -> DotNumberView {
    layoutIfNeeded()

    let outgoingNumber = DotNumberView()
    outgoingNumber.bounds = dotNumberView.bounds
    outgoingNumber.maxDotSize = dotNumberView.maxDotSize
    outgoingNumber.setSeatColors(
      dotNumberView.seatColors,
      seed: dotNumberView.colorSeed,
      animated: false
    )
    outgoingNumber.updateNumber(
      dotNumberView.number,
      direction: nil,
      animated: false
    )
    outgoingNumber.layoutIfNeeded()
    outgoingNumber.alpha = dotNumberView.alpha

    let sourceCenter = CGPoint(
      x: dotNumberView.bounds.midX,
      y: dotNumberView.bounds.midY
    )
    let center = reference.convert(sourceCenter, from: dotNumberView)
    let xAxis = reference.convert(
      CGPoint(x: sourceCenter.x + 1, y: sourceCenter.y),
      from: dotNumberView
    )
    let yAxis = reference.convert(
      CGPoint(x: sourceCenter.x, y: sourceCenter.y + 1),
      from: dotNumberView
    )

    outgoingNumber.center = center
    outgoingNumber.transform = CGAffineTransform(
      a: xAxis.x - center.x,
      b: xAxis.y - center.y,
      c: yAxis.x - center.x,
      d: yAxis.y - center.y,
      tx: 0,
      ty: 0
    )
    outgoingNumber.isUserInteractionEnabled = false
    reference.addSubview(outgoingNumber)
    return outgoingNumber
  }

  func animateRecipientFocus() {
    cancelDeltaSession()
    UIView.animate(
      withDuration: 0.3,
      delay: 0,
      options: [.beginFromCurrentState, .allowUserInteraction]
    ) {
      self.dotNumberView.alpha = Self.adjustIconAlpha
      self.minusIcon.alpha = 0
      self.plusIcon.alpha = 0
    }
  }

  func animateRecipientRestore() {
    dotNumberView.alpha = Self.adjustIconAlpha
    minusIcon.alpha = 0
    plusIcon.alpha = 0
    UIView.animate(
      withDuration: 0.3,
      delay: 0,
      options: [.beginFromCurrentState, .allowUserInteraction]
    ) {
      self.dotNumberView.alpha = 1
      self.minusIcon.alpha = Self.adjustIconAlpha
      self.plusIcon.alpha = Self.adjustIconAlpha
    }
  }

  func snapDotsToOff() {
    dotNumberView.snapToOff()
  }

  func animateRippleIn(
    in reference: UIView,
    origin: CGPoint,
    maximumDistance: CGFloat,
    reversed: Bool
  ) {
    dotNumberView.animateRippleIn(
      in: reference,
      origin: origin,
      maximumDistance: maximumDistance,
      reversed: reversed
    )
    UIView.animate(
      withDuration: 0.3,
      delay: 0,
      options: [.beginFromCurrentState, .allowUserInteraction]
    ) {
      if self.displayMode != .commanderRecipient {
        self.minusIcon.alpha = Self.adjustIconAlpha
        self.plusIcon.alpha = Self.adjustIconAlpha
      }
    }
  }

  /// The full cell interaction region in `view` coordinates.
  func lifeTapAreaRect(in view: UIView) -> CGRect {
    layoutIfNeeded()
    return convert(lifeTapAreaRectInBounds(), to: view)
  }

  // MARK: - Touch handling

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard !isTouching, let touch = touches.first else { return }
    isTouching = true
    didActivateCenterHold = false
    setNumberPressed(true)
    let loc = touch.location(in: self)
    if displayMode == .commanderRecipient {
      if tapZone(at: loc) == .center {
        onCommanderModeExitRequested?()
      }
      endTouch()
      return
    }
    let zone = tapZone(at: loc)

    switch zone {
    case .left:
      // Commit ±1 on touch-down so rapid tapping responds to each strike, not
      // each lift. A held press then escalates to the ±10 repeat after
      // holdActivationDelay.
      applyChange(increment: false, magnitude: 1, bulk: false)
      scheduleBulkRepeat(increment: false)
    case .right:
      applyChange(increment: true, magnitude: 1, bulk: false)
      scheduleBulkRepeat(increment: true)
    case .center:
      guard displayMode == .life else {
        endTouch()
        return
      }
      centerHoldTimer = Timer.scheduledTimer(
        withTimeInterval: Self.holdActivationDelay,
        repeats: false
      ) { [weak self] _ in
        guard let self else { return }
        self.didActivateCenterHold = true
        Self.editActivationHaptic.impactOccurred(intensity: 0.9)
        self.onEditRequested?()
        self.centerHoldTimer = nil
      }
    }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    if displayMode == .life, !didActivateCenterHold, let touch = touches.first,
       tapZone(at: touch.location(in: self)) == .center {
      onCommanderModeRequested?()
    }
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
    setNumberPressed(false)
    isTouching = false
    didActivateCenterHold = false
  }

  private func setNumberPressed(_ isPressed: Bool) {
    let scale = isPressed ? Self.pressedNumberScale : 1
    if isPressed {
      UIView.animate(
        withDuration: 0.12,
        delay: 0,
        options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]
      ) {
        self.numberPressContainer.transform = CGAffineTransform(scaleX: scale, y: scale)
      }
    } else {
      UIView.animate(
        withDuration: 0.24,
        delay: 0,
        usingSpringWithDamping: 0.72,
        initialSpringVelocity: 0,
        options: [.allowUserInteraction, .beginFromCurrentState]
      ) {
        self.numberPressContainer.transform = .identity
      }
    }
  }

  // MARK: - Helpers

  private func lifeTapAreaRectInBounds() -> CGRect {
    bounds
  }

  private func playerFraction(at location: CGPoint) -> CGFloat {
    let deg = Int(rotation)
    switch deg {
    case 90:       return location.y / bounds.height
    case -90:      return 1 - (location.y / bounds.height)
    case 180, -180: return 1 - (location.x / bounds.width)
    default:       return location.x / bounds.width
    }
  }

  /// The center interaction zone is a fixed `editZoneWidth`-wide band centered
  /// on the number; the ± zones stretch to fill the rest of the cell.
  private func tapZone(at location: CGPoint) -> TapZone {
    let swapped = abs(Int(rotation)) == 90
    let axisPos = swapped ? location.y : location.x
    let axisLen = swapped ? bounds.height : bounds.width
    let half = min(Self.editZoneWidth, axisLen) / 2
    if abs(axisPos - axisLen / 2) <= half { return .center }
    // Outside the center band, player orientation decides which side is ±.
    return playerFraction(at: location) < 0.5 ? .left : .right
  }

  private func applyChange(increment: Bool, magnitude: Int, bulk: Bool) {
    changeDirection = increment ? .increasing : .decreasing
    let requested = increment ? magnitude : -magnitude
    if displayMode == .commanderSource {
      let next = max(0, lifeTotal + requested)
      let applied = next - lifeTotal
      guard applied != 0 else { return }
      lifeTotal = next
      dotNumberView.updateNumber(lifeTotal, direction: changeDirection, animated: true)
      let netDelta = registerDelta(applied)
      dotNumberView.shakeForChange(
        magnitude: abs(netDelta),
        origin: adjustmentRippleOrigin(increment: increment)
      )
      onCommanderDamageAdjust?(applied)
    } else {
      lifeTotal += requested
      dotNumberView.updateNumber(lifeTotal, direction: changeDirection, animated: true)
      let netDelta = registerDelta(requested)
      dotNumberView.shakeForChange(
        magnitude: abs(netDelta),
        origin: adjustmentRippleOrigin(increment: increment)
      )
      onLifeChanged?(lifeTotal)
    }
    if bulk {
      Self.bulkChangeHaptic.impactOccurred(intensity: 0.85)
    } else {
      Self.lifeChangeHaptic.impactOccurred(intensity: 0.55)
    }
  }

  private func adjustmentRippleOrigin(increment: Bool) -> CGPoint {
    let icon = increment ? plusIcon : minusIcon
    return dotNumberView.convert(icon.center, from: contentContainer)
  }

  private func updateCommanderAccessibility() {
    switch displayMode {
    case .life:
      dotNumberView.accessibilityLabel = "Life total, \(lifeTotal)"
    case .commanderSource:
      let playerNumber = dotNumberView.accessibilityIdentifier?
        .split(separator: "-")
        .last
        .flatMap { Int($0) } ?? 0
      dotNumberView.accessibilityLabel =
        "Player \(playerNumber) commander damage, \(lifeTotal)"
    case .commanderRecipient:
      dotNumberView.accessibilityLabel = "Life total, \(lifeTotal)"
    }
  }

  // MARK: - Net-change readout

  /// Accumulate a life change into the running session delta, surface the
  /// magnitude next to the active side's icon, brighten that icon, and (re)arm
  /// the idle fade. The minus icon slides over (animated) to make room.
  @discardableResult
  private func registerDelta(_ amount: Int) -> Int {
    sessionDelta += amount
    // Net zero — nothing to show; fade the session out as if it had idled.
    guard sessionDelta != 0 else {
      endDeltaSession()
      return 0
    }

    // Drive the magnitude through the model so the digits roll (numericText).
    deltaModel.value = abs(sessionDelta)
    let positive = sessionDelta > 0
    setNeedsLayout()
    UIView.animate(withDuration: 0.2, delay: 0,
             usingSpringWithDamping: 0.85, initialSpringVelocity: 0,
             options: [.beginFromCurrentState, .allowUserInteraction]) {
      self.layoutIfNeeded()
      self.deltaView.alpha = 1
      self.plusIcon.alpha = positive ? 1 : Self.adjustIconAlpha
      self.minusIcon.alpha = positive ? Self.adjustIconAlpha : 1
    }
    scheduleDeltaIdle()
    return sessionDelta
  }

  /// Width of the current magnitude, measured from the Karl `lifeDelta` font so
  /// the hosted rolling text can be framed before it lays out. Zero when idle.
  private func deltaMagnitudeWidth() -> CGFloat {
    guard sessionDelta != 0 else { return 0 }
    let s = "\(abs(sessionDelta))" as NSString
    return ceil(s.size(withAttributes: [.font: Typography.lifeDelta.uiFont]).width)
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
    let frozen = deltaView.frame
    sessionDelta = 0
    setNeedsLayout()
    UIView.animate(
      withDuration: 0.4,
      delay: 0,
      options: [.beginFromCurrentState, .allowUserInteraction]
    ) {
      self.layoutIfNeeded()          // minus icon glides back to resting
      self.deltaView.frame = frozen  // …but the readout stays put while fading
      self.deltaView.alpha = 0
      self.minusIcon.alpha = Self.adjustIconAlpha
      self.plusIcon.alpha = Self.adjustIconAlpha
    }
  }

  /// Tear down the session immediately (no animation) — for edit/reset.
  private func cancelDeltaSession() {
    deltaIdleTimer?.invalidate()
    deltaIdleTimer = nil
    sessionDelta = 0
    deltaModel.value = 0
    deltaView.alpha = 0
    minusIcon.alpha = Self.adjustIconAlpha
    plusIcon.alpha = Self.adjustIconAlpha
    setNeedsLayout()
  }

  // MARK: - Swipe-to-reset sweep

  /// Apply the reset-swipe positional fade to this cell's dots and controls.
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

    minusIcon.alpha = Self.adjustIconAlpha * (1 - progress(for: minusIcon))
    plusIcon.alpha = Self.adjustIconAlpha * (1 - progress(for: plusIcon))
    if sessionDelta != 0 {
      deltaView.alpha = 1 - progress(for: deltaView)
    }
  }

  func resetSweep(animated: Bool) {
    dotNumberView.resetSweep(animated: animated)
    if animated {
      UIView.animate(withDuration: 0.3, delay: 0,
               usingSpringWithDamping: 0.9, initialSpringVelocity: 0,
               options: .beginFromCurrentState) {
        self.minusIcon.alpha = Self.adjustIconAlpha
        self.plusIcon.alpha = Self.adjustIconAlpha
      }
    } else {
      minusIcon.alpha = Self.adjustIconAlpha
      plusIcon.alpha = Self.adjustIconAlpha
    }
  }

}
