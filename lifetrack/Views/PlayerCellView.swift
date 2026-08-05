import UIKit
import SwiftUI

class PlayerCellView: UIView {
  /// Horizontal content margin (left/right in the player's reading frame).
  static let contentInset: CGFloat = 12
  /// Top/bottom content margin in the player's reading frame.
  static let verticalInset: CGFloat = 8

  /// ± adjust-direction icons flanking the life total (minus on the player's
  /// left, plus on the right). Part of the 4pt grid / units-of-20 system:
  /// 20×20 icons, 20pt gap from the digits, dimmed to 30% opacity.
  private static let adjustIconSize: CGFloat = 20
  private static let adjustIconSpacing: CGFloat = 20
  private static let adjustTargetPadding: CGFloat = 20
  static let minimumAdjustmentTargetWidth =
    adjustIconSize + adjustTargetPadding * 2
  private static let adjustIconAlpha: CGFloat = 0.3
  private static let adjustIconHiddenScale: CGFloat = 0.5
  private static let adjustIconVisibilityDuration: TimeInterval = 0.16

  /// Transient net-change readout. Each tap (and ±10 hold tick) accumulates
  /// into `sessionDelta`; the magnitude is shown next to the active side's ±
  /// icon (the icon *is* the sign) and the whole session fades out after
  /// `deltaIdleTimeout` of no further input. Net-signed, so +7 then −2 reads
  /// as a "+5" next to the plus icon. `deltaSpacing` is the tight gap between
  /// the sign icon and its digits.
  private static let deltaIdleTimeout: TimeInterval = 1.4
  private static let deltaSpacing: CGFloat = 8

  private(set) var lifeTotal: Int = Player.defaultLife
  private var poisonCounters = 0
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
      guard isBeingEdited != oldValue else { return }
      dotNumberView.isHidden = isBeingEdited
      deltaView.isHidden = isBeingEdited
      if isBeingEdited {
        setPoisonBadgeVisible(false, animated: true)
      } else if poisonCounterView.isHidden {
        setPoisonBadgeVisible(true, animated: true)
      }
      if isBeingEdited { cancelDeltaSession() }
      setAdjustmentIconsVisible(!isBeingEdited, animated: true)
    }
  }

  private let contentContainer = UIView()
  private let numberPressContainer = UIView()
  let dotNumberView = DotNumberView()
  private let minusIcon = UIImageView()
  private let plusIcon = UIImageView()
  private let poisonCounterView = PoisonCounterView()
  private var adjustmentIconsVisible = true
  private var firstPlayerChromeVisible = true
  /// The net-change readout uses a hosted SwiftUI `numericText` transition.
  /// `deltaView` is the hosting controller's view; `deltaModel.value` holds the
  /// current magnitude.
  private let deltaModel = RollingValueModel()
  private lazy var deltaHost = UIHostingController(rootView: RollingNumberText(model: deltaModel))
  private var deltaView: UIView { deltaHost.view }
  private var sessionDelta = 0
  private var deltaIdleTimer: Timer?

  private var changeDirection: ChangeDirection?
  private var hasLethalCommanderDamage = false
  private var repeatTimer: Timer?
  private var centerHoldTimer: Timer?
  private var isTouching = false
  private var activeTapZone: TapZone?
  private var didActivateCenterHold = false
  /// A threshold this particular hold session may approach but not cross.
  /// It is chosen on touch-down, so a fresh gesture that begins at or beyond
  /// the threshold remains free to keep changing the value.
  private var repeatBoundary: Int?

  private static let holdActivationDelay: TimeInterval = 0.5
  private static let repeatInterval: TimeInterval = 0.35
  private static let bulkChangeMagnitude = 10
  /// The touch-down already applies one point, so the first hold step supplies
  /// the remaining nine before subsequent repeats continue in tens.
  private static let firstBulkChangeMagnitude = bulkChangeMagnitude - 1
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
    poisonCounterView.prepare(value: 0, isInteractive: false)
    poisonCounterView.isHidden = true
    contentContainer.addSubview(poisonCounterView)

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

    // Reserve enough player-facing width for both padded adjustment targets.
    // The number gets the remaining centered area and scales down within it
    // when a dense layout or extra digit would otherwise push a target beyond
    // the cell boundary.
    let readingWidth = contentW + Self.contentInset * 2
    let numberWidth = max(
      1,
      readingWidth - Self.minimumAdjustmentTargetWidth * 2
    )
    dotNumberView.frame = CGRect(
      x: contentContainer.bounds.midX - numberWidth / 2,
      y: contentContainer.bounds.minY,
      width: numberWidth,
      height: contentH
    )
    dotNumberView.layoutIfNeeded()

    // ± icons flank the rendered number (minus left, plus right), vertically
    // centered on it, with a fixed 20pt gap — placed in the rotated content
    // frame so they read correctly from each player's seat.
    let numRect = dotNumberView.numberContentRect
      .offsetBy(dx: dotNumberView.frame.minX, dy: dotNumberView.frame.minY)
    poisonCounterView.frame = CGRect(
      x: contentContainer.bounds.midX - numberWidth / 2,
      y: numRect.maxY,
      width: numberWidth,
      height: max(0, contentContainer.bounds.maxY - numRect.maxY)
    )
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
    let plusX = numRect.maxX + gap
    placeAdjustmentIcon(plusIcon, x: plusX, y: iconY)

    if sessionDelta < 0 {
      // Negative: the digits go between the minus icon and the number, so the
      // minus icon slides left to open that room (animated by registerDelta).
      let labelX = numRect.minX - gap - dW
      deltaView.frame = CGRect(x: labelX, y: labelY, width: dW, height: dH)
      placeAdjustmentIcon(
        minusIcon,
        x: labelX - dGap - iconSize,
        y: iconY
      )
    } else {
      placeAdjustmentIcon(
        minusIcon,
        x: numRect.minX - gap - iconSize,
        y: iconY
      )
      deltaView.frame = CGRect(x: plusX + iconSize + dGap, y: labelY,
                   width: dW, height: dH)
    }

    // Value changes animate a layout pass for the temporary delta readout.
    // Keep the parent orientation out of that transaction so 180-degree
    // seats do not interpolate through an unintended flip.
    UIView.performWithoutAnimation {
      contentContainer.transform = CGAffineTransform(rotationAngle: rotation * .pi / 180)
    }
  }

  private func placeAdjustmentIcon(_ icon: UIImageView, x: CGFloat, y: CGFloat) {
    let size = Self.adjustIconSize
    icon.bounds = CGRect(x: 0, y: 0, width: size, height: size)
    icon.center = CGPoint(x: x + size / 2, y: y + size / 2)
  }

  func setLifeTotal(
    _ value: Int,
    direction: ChangeDirection?,
    animated: Bool,
    shakes: Bool = true,
    hasLethalCommanderDamage: Bool? = nil
  ) {
    if let hasLethalCommanderDamage {
      self.hasLethalCommanderDamage = hasLethalCommanderDamage
    }
    let magnitude = abs(value - lifeTotal)
    lifeTotal = value
    changeDirection = direction
    dotNumberView.updateNumber(value, direction: direction, animated: animated)
    setNeedsLayout()
    updateThresholdAppearance(animated: animated)
    if animated, shakes, magnitude > 0 {
      dotNumberView.shakeForChange(magnitude: magnitude)
    }
    updateCommanderAccessibility()
  }

  func setSeatColors(_ colors: Set<SeatColor>, seed: Int, animated: Bool) {
    dotNumberView.setSeatColors(colors, seed: seed, animated: animated)
  }

  func setPoisonCounters(_ value: Int, animated: Bool) {
    poisonCounters = max(0, value)
    poisonCounterView.prepare(value: poisonCounters, isInteractive: false)
    poisonCounterView.setVisible(
      showsPoisonBadge && !isBeingEdited && firstPlayerChromeVisible,
      animated: false
    )
    setNeedsLayout()
    updateThresholdAppearance(animated: animated)
    updateCommanderAccessibility()
    if animated {
      UIView.animate(
        withDuration: 0.2,
        delay: 0,
        usingSpringWithDamping: 0.85,
        initialSpringVelocity: 0,
        options: [.beginFromCurrentState, .allowUserInteraction]
      ) {
        self.layoutIfNeeded()
      }
    }
  }

  func revealPoisonBadgeAfterEditing() {
    setPoisonBadgeVisible(true, animated: true)
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
    firstPlayerChromeVisible = visible
    if !visible {
      cancelDeltaSession()
    }
    deltaView.alpha = 0
    poisonCounterView.setVisible(
      visible && showsPoisonBadge && !isBeingEdited,
      animated: animated
    )
    setAdjustmentIconsVisible(visible, animated: animated)
  }

  func setAdjustmentChromeVisible(_ visible: Bool, animated: Bool) {
    if !visible {
      cancelDeltaSession()
    }
    setAdjustmentIconsVisible(visible, animated: animated)
  }

  func prepareLifeDisplay(
    _ value: Int,
    hasLethalCommanderDamage: Bool,
    rotation: CGFloat
  ) {
    displayMode = .life
    self.rotation = rotation
    lifeTotal = value
    self.hasLethalCommanderDamage = hasLethalCommanderDamage
    poisonCounterView.setVisible(
      showsPoisonBadge && !isBeingEdited && firstPlayerChromeVisible,
      animated: false
    )
    updateThresholdAppearance(animated: false)
    dotNumberView.isAccessibilityElement = true
    dotNumberView.accessibilityIdentifier = "life-total"
    dotNumberView.accessibilityHint =
      "Tap for commander damage. Hold to edit life total."
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
    poisonCounterView.isHidden = true
    rotation = viewerRotation
    lifeTotal = damage
    updateThresholdAppearance(animated: false)
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
    cancelDeltaSession()
    dotNumberView.updateNumber(damage, direction: nil, animated: false)
    dotNumberView.accessibilityLabel = "Player \(sourcePlayerNumber) commander damage, \(damage)"
    setNeedsLayout()
    layoutIfNeeded()
  }

  func prepareCommanderRecipientDisplay(_ life: Int, viewerRotation: CGFloat) {
    displayMode = .commanderRecipient
    poisonCounterView.isHidden = true
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
    setAdjustmentIconsVisible(false, animated: true)
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
    setAdjustmentIconsVisible(false, animated: true)
    UIView.animate(
      withDuration: 0.3,
      delay: 0,
      options: [.beginFromCurrentState, .allowUserInteraction]
    ) {
      self.dotNumberView.alpha = Self.adjustIconAlpha
    }
  }

  func animateRecipientRestore() {
    dotNumberView.alpha = Self.adjustIconAlpha
    setAdjustmentIconsVisible(true, animated: true)
    UIView.animate(
      withDuration: 0.3,
      delay: 0,
      options: [.beginFromCurrentState, .allowUserInteraction]
    ) {
      self.dotNumberView.alpha = self.thresholdAlpha
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
    if displayMode != .commanderRecipient {
      setAdjustmentIconsVisible(true, animated: true)
    }
  }

  /// Active full-height interaction regions in `view` coordinates. The center
  /// matches the rendered number's width; the ± regions fill outward to the
  /// player cell edges without exceeding them.
  func interactionAreaRects(in view: UIView) -> [CGRect] {
    layoutIfNeeded()
    let zones: [TapZone]
    switch displayMode {
    case .life:
      zones = [.left, .center, .right]
    case .commanderSource:
      zones = [.left, .right]
    case .commanderRecipient:
      zones = [.center]
    }
    return zones.map { convert(interactionRect(for: $0), from: contentContainer) }
      .map { convert($0, to: view) }
  }

  // MARK: - Touch handling

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard !isTouching, let touch = touches.first,
        let zone = tapZone(at: touch.location(in: self)) else { return }
    isTouching = true
    activeTapZone = zone
    didActivateCenterHold = false
    setNumberPressed(true)
    if displayMode == .commanderRecipient {
      if zone == .center {
        onCommanderModeExitRequested?()
      }
      endTouch()
      return
    }

    switch zone {
    case .left:
      // Commit ±1 on touch-down so rapid tapping responds to each strike, not
      // each lift. A held press then escalates to the ±10 repeat after
      // holdActivationDelay.
      repeatBoundary = displayMode == .life && lifeTotal > 0 ? 0 : nil
      applyChange(increment: false, magnitude: 1, bulk: false)
      scheduleBulkRepeat(increment: false)
    case .right:
      repeatBoundary = displayMode == .commanderSource
        && lifeTotal < Player.lethalCommanderDamage
        ? Player.lethalCommanderDamage
        : nil
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
    if displayMode == .life, activeTapZone == .center,
        !didActivateCenterHold, let touch = touches.first,
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
    let reachedBoundary = applyChange(
      increment: increment,
      magnitude: Self.firstBulkChangeMagnitude,
      bulk: true
    )
    guard !reachedBoundary else {
      repeatTimer = nil
      return
    }
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
    activeTapZone = nil
    didActivateCenterHold = false
    repeatBoundary = nil
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

  private func tapZone(at location: CGPoint) -> TapZone? {
    let contentLocation = contentContainer.convert(location, from: self)
    let candidateZones: [TapZone]
    switch displayMode {
    case .life:
      candidateZones = [.center, .left, .right]
    case .commanderSource:
      candidateZones = [.left, .right]
    case .commanderRecipient:
      candidateZones = [.center]
    }
    return candidateZones.first {
      interactionRect(for: $0).contains(contentLocation)
    }
  }

  private func interactionRect(for zone: TapZone) -> CGRect {
    let cellRect = contentContainer.bounds.insetBy(
      dx: -Self.contentInset,
      dy: -Self.verticalInset
    )
    let numberRect = dotNumberView.numberContentRect.offsetBy(
      dx: dotNumberView.frame.minX,
      dy: dotNumberView.frame.minY
    )
    switch zone {
    case .left:
      return CGRect(
        x: cellRect.minX,
        y: cellRect.minY,
        width: max(0, numberRect.minX - cellRect.minX),
        height: cellRect.height
      )
    case .center:
      return CGRect(
        x: numberRect.minX,
        y: cellRect.minY,
        width: numberRect.width,
        height: cellRect.height
      )
    case .right:
      return CGRect(
        x: numberRect.maxX,
        y: cellRect.minY,
        width: max(0, cellRect.maxX - numberRect.maxX),
        height: cellRect.height
      )
    }
  }

  @discardableResult
  private func applyChange(increment: Bool, magnitude: Int, bulk: Bool) -> Bool {
    changeDirection = increment ? .increasing : .decreasing
    var requested = increment ? magnitude : -magnitude
    if bulk, let repeatBoundary {
      let distanceToBoundary = repeatBoundary - lifeTotal
      requested = increment
        ? min(requested, distanceToBoundary)
        : max(requested, distanceToBoundary)
      if requested == 0 {
        stopBulkRepeat()
        return true
      }
    }
    if displayMode == .commanderSource {
      let next = max(0, lifeTotal + requested)
      let applied = next - lifeTotal
      guard applied != 0 else { return false }
      lifeTotal = next
      dotNumberView.updateNumber(lifeTotal, direction: changeDirection, animated: true)
      updateThresholdAppearance(animated: true)
      let netDelta = registerDelta(applied)
      dotNumberView.shakeForChange(
        magnitude: abs(netDelta),
        origin: adjustmentRippleOrigin(increment: increment)
      )
      onCommanderDamageAdjust?(applied)
    } else {
      lifeTotal += requested
      dotNumberView.updateNumber(lifeTotal, direction: changeDirection, animated: true)
      updateThresholdAppearance(animated: true)
      let netDelta = registerDelta(requested)
      dotNumberView.shakeForChange(
        magnitude: abs(netDelta),
        origin: adjustmentRippleOrigin(increment: increment)
      )
      onLifeChanged?(lifeTotal)
    }
    setNeedsLayout()
    updateCommanderAccessibility()
    if bulk {
      Self.bulkChangeHaptic.impactOccurred(intensity: 0.85)
    } else {
      Self.lifeChangeHaptic.impactOccurred(intensity: 0.55)
    }
    AppSoundPlayer.shared.play(increment ? .increment : .decrement)
    let reachedBoundary = bulk && repeatBoundary == lifeTotal
    if reachedBoundary {
      stopBulkRepeat()
    }
    return reachedBoundary
  }

  private func stopBulkRepeat() {
    repeatTimer?.invalidate()
    repeatTimer = nil
  }

  private var thresholdAlpha: CGFloat {
    switch displayMode {
    case .life:
      isDefeated ? Self.adjustIconAlpha : 1
    case .commanderSource:
      lifeTotal >= Player.lethalCommanderDamage ? Self.adjustIconAlpha : 1
    case .commanderRecipient:
      Self.adjustIconAlpha
    }
  }

  private var showsPoisonBadge: Bool {
    displayMode == .life && poisonCounters > 0
  }

  private var isDefeated: Bool {
    lifeTotal <= 0
      || hasLethalCommanderDamage
      || poisonCounters >= Player.lethalPoisonCounters
  }

  private func updateThresholdAppearance(animated: Bool) {
    let changes = { self.dotNumberView.alpha = self.thresholdAlpha }
    if animated {
      UIView.animate(
        withDuration: 0.22,
        delay: 0,
        options: [.beginFromCurrentState, .allowUserInteraction],
        animations: changes
      )
    } else {
      changes()
    }
  }

  private func adjustmentRippleOrigin(increment: Bool) -> CGPoint {
    let icon = increment ? plusIcon : minusIcon
    return dotNumberView.convert(icon.center, from: contentContainer)
  }

  private func updateCommanderAccessibility() {
    switch displayMode {
    case .life:
      let status = isDefeated ? ", defeated" : ""
      dotNumberView.accessibilityLabel = "Life total, \(lifeTotal)\(status)"
    case .commanderSource:
      let playerNumber = dotNumberView.accessibilityIdentifier?
        .split(separator: "-")
        .last
        .flatMap { Int($0) } ?? 0
      let status = lifeTotal >= Player.lethalCommanderDamage ? ", lethal" : ""
      dotNumberView.accessibilityLabel =
        "Player \(playerNumber) commander damage, \(lifeTotal)\(status)"
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
    if adjustmentIconsVisible {
      minusIcon.alpha = Self.adjustIconAlpha
      plusIcon.alpha = Self.adjustIconAlpha
    }
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

    applyAdjustmentIconVisibility(
      1 - progress(for: minusIcon),
      to: minusIcon
    )
    applyAdjustmentIconVisibility(
      1 - progress(for: plusIcon),
      to: plusIcon
    )
    if sessionDelta != 0 {
      deltaView.alpha = 1 - progress(for: deltaView)
    }
    poisonCounterView.setVisibilityProgress(
      1 - progress(for: poisonCounterView)
    )
  }

  func resetSweep(animated: Bool) {
    dotNumberView.resetSweep(animated: animated)
    setAdjustmentIconsVisible(true, animated: animated)
    poisonCounterView.setVisibilityProgress(
      firstPlayerChromeVisible && showsPoisonBadge ? 1 : 0
    )
  }

  private func setPoisonBadgeVisible(_ visible: Bool, animated: Bool) {
    poisonCounterView.setVisible(
      visible && showsPoisonBadge && firstPlayerChromeVisible,
      animated: animated
    )
  }

  private func setAdjustmentIconsVisible(_ visible: Bool, animated: Bool) {
    adjustmentIconsVisible = visible
    let changes = {
      let visibility: CGFloat = visible ? 1 : 0
      self.applyAdjustmentIconVisibility(visibility, to: self.minusIcon)
      self.applyAdjustmentIconVisibility(visibility, to: self.plusIcon)
    }

    guard animated else {
      UIView.performWithoutAnimation(changes)
      return
    }
    UIView.animate(
      withDuration: Self.adjustIconVisibilityDuration,
      delay: 0,
      options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut],
      animations: changes
    )
  }

  private func applyAdjustmentIconVisibility(
    _ visibility: CGFloat,
    to icon: UIImageView
  ) {
    let progress = min(1, max(0, visibility))
    let scale = Self.adjustIconHiddenScale
      + (1 - Self.adjustIconHiddenScale) * progress
    icon.alpha = Self.adjustIconAlpha * progress
    icon.transform = CGAffineTransform(scaleX: scale, y: scale)
  }

}
