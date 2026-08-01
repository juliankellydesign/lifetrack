import UIKit

class GameBoardView: UIView {
  private var cellViews: [PlayerCellView] = []
  var onEditRequested: ((Int, CGFloat) -> Void)?
  var onLifeChanged: ((Int, Int) -> Void)?
  var onCommanderModeRequested: ((Int) -> Void)?
  var onCommanderModeExitRequested: (() -> Void)?
  /// Recipient index, source player id, and applied damage delta.
  var onCommanderDamageChanged: ((Int, Int, Int) -> Void)?
  /// Fires when a swipe-to-reset gesture is committed. The caller is expected to
  /// rebuild player state and start the first-player selection animation.
  var onResetRequested: (() -> Void)?
  /// Reports whether the lighthouse itself is actively sweeping so
  /// controller-owned chrome can disappear without disabling its hit targets.
  var onFirstPlayerSweepActiveChanged: ((Bool) -> Void)?

  private static let gap: CGFloat = BoardInsets.interCellGap

  /// Target dot diameter for the on-board life totals. Cells render at this
  /// size unless a cell is too small to fit it, in which case every cell
  /// shrinks together (see `layoutSubviews`).
  private static let targetDotSize: CGFloat = 18

  /// Width over which the leading edge of the swipe blends from "natural" to "wiped".
  private static let sweepFeather: CGFloat = 60
  private static let firstPlayerDimAlpha: CGFloat = 0
  private static let firstPlayerDimScale: CGFloat = 0.01
  private static let firstPlayerPeakScale: CGFloat = 1
  private static let firstPlayerFadeDuration: TimeInterval = 3
  private static let firstPlayerSweepDuration: TimeInterval = 4.2
  private static let firstPlayerSweepTurns: CGFloat = 8
  private static let firstPlayerSweepAccelerationExponent: CGFloat = 2.15
  private static let firstPlayerBeamHalfWidth: CGFloat = 0.32

  private enum FirstPlayerAnimationPhase {
    case idle
    case sweeping
    case fading
  }

  private struct Slot {
    let frame: CGRect
    let rotationDegrees: CGFloat
  }

  private var currentSlots: [Slot] = []
  private(set) var layout: PlayerLayout = .fourA
  private(set) var commanderRecipientIndex: Int?
  private var commanderTransitionGeneration = 0
  private var commanderTransitionOverlays: [UIView] = []
  private var firstPlayerAnimationPhase: FirstPlayerAnimationPhase = .idle
  private var firstPlayerAnimationGeneration = 0
  private let firstPlayerSelectionFeedback = UISelectionFeedbackGenerator()
  private var firstPlayerSweepDisplayLink: CADisplayLink?
  private var firstPlayerSweepDisplayLinkTarget: FirstPlayerDisplayLinkTarget?
  private var firstPlayerSweepStartTime: CFTimeInterval?
  private var firstPlayerSweepStartAngle: CGFloat = 0
  private var firstPlayerSweepEndAngle: CGFloat = 0
  private var firstPlayerSweepPreviousAngle: CGFloat = 0
  private var firstPlayerSweepWinner = 0
  private var firstPlayerSweepGeneration = 0
  private var firstPlayerLastHapticCell: Int?

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
    // Center taps commit on touch-up. Deliver touch-up immediately when this
    // pan fails; a real swipe still cancels the cell touch via
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
    stopFirstPlayerSweepDisplayLink()
    firstPlayerAnimationGeneration += 1
    firstPlayerAnimationPhase = .idle
    self.layout = layout
    commanderRecipientIndex = nil
    resetPanGesture.isEnabled = true
    cellViews.forEach { $0.removeFromSuperview() }
    cellViews.removeAll()

    for (i, player) in players.enumerated() {
      let cell = PlayerCellView()
      cell.setSeatColors(player.seatColors, seed: player.id, animated: false)
      cell.setLifeTotal(player.lifeTotal, direction: nil, animated: false)
      let idx = i
      cell.onEditRequested = { [weak self] in
        guard let self, idx < self.currentSlots.count else { return }
        self.revealFirstPlayerSelection()
        self.onEditRequested?(idx, self.currentSlots[idx].rotationDegrees)
      }
      cell.onLifeChanged = { [weak self] newLife in
        self?.revealFirstPlayerSelection()
        self?.onLifeChanged?(idx, newLife)
      }
      cell.onCommanderModeRequested = { [weak self] in
        self?.revealFirstPlayerSelection()
        self?.onCommanderModeRequested?(idx)
      }
      cell.onCommanderModeExitRequested = { [weak self] in
        self?.onCommanderModeExitRequested?()
      }
      cell.onCommanderDamageAdjust = { [weak self] delta in
        guard let self, let recipient = self.commanderRecipientIndex else { return }
        self.onCommanderDamageChanged?(recipient, player.id, delta)
      }
      addSubview(cell)
      cellViews.append(cell)
    }
    setNeedsLayout()
  }

  func updatePlayer(
    at index: Int,
    lifeTotal: Int,
    direction: ChangeDirection? = nil,
    animated: Bool = false,
    shakes: Bool = true
  ) {
    guard index < cellViews.count else { return }
    cellViews[index].setLifeTotal(
      lifeTotal,
      direction: direction,
      animated: animated,
      shakes: shakes
    )
  }

  func updateSeatColors(at index: Int, colors: Set<SeatColor>, seed: Int) {
    guard cellViews.indices.contains(index) else { return }
    cellViews[index].setSeatColors(colors, seed: seed, animated: true)
  }

  /// Update the source damage total while focused commander mode is active.
  func setCommanderDamage(cellIndex: Int, opponentId: Int, value: Int) {
    guard commanderRecipientIndex == cellIndex,
        let sourceIndex = cellViews.indices.first(where: { $0 == opponentId }),
        sourceIndex != cellIndex else { return }
    let direction: ChangeDirection = value >= cellViews[sourceIndex].lifeTotal
      ? .increasing
      : .decreasing
    cellViews[sourceIndex].setLifeTotal(
      value,
      direction: direction,
      animated: true
    )
  }

  func enterCommanderMode(recipientIndex: Int, players: [Player]) {
    guard commanderRecipientIndex == nil,
        players.indices.contains(recipientIndex),
        cellViews.indices.contains(recipientIndex) else { return }
    commanderRecipientIndex = recipientIndex
    resetPanGesture.isEnabled = false
    transitionCommanderMode(recipientIndex: recipientIndex, players: players, entering: true)
  }

  func exitCommanderMode(players: [Player]) {
    guard let recipientIndex = commanderRecipientIndex,
        players.indices.contains(recipientIndex) else { return }
    transitionCommanderMode(recipientIndex: recipientIndex, players: players, entering: false)
  }

  private func transitionCommanderMode(
    recipientIndex: Int,
    players: [Player],
    entering: Bool
  ) {
    layoutIfNeeded()
    guard let recipientCell = cellView(at: recipientIndex) else { return }
    commanderTransitionGeneration += 1
    let generation = commanderTransitionGeneration
    commanderTransitionOverlays.forEach { $0.removeFromSuperview() }
    commanderTransitionOverlays.removeAll()
    let origin = convert(
      CGPoint(
        x: recipientCell.dotNumberView.bounds.midX,
        y: recipientCell.dotNumberView.bounds.midY
      ),
      from: recipientCell.dotNumberView
    )
    let corners = [
      CGPoint(x: bounds.minX, y: bounds.minY),
      CGPoint(x: bounds.maxX, y: bounds.minY),
      CGPoint(x: bounds.minX, y: bounds.maxY),
      CGPoint(x: bounds.maxX, y: bounds.maxY),
    ]
    let maximumDistance = corners.map {
      hypot($0.x - origin.x, $0.y - origin.y)
    }.max() ?? 1

    for (index, cell) in cellViews.enumerated() {
      cell.isUserInteractionEnabled = false
      if index == recipientIndex {
        if entering {
          cell.animateRecipientFocus()
        }
      } else {
        let overlay = cell.animateRippleOut(
          in: self,
          origin: origin,
          maximumDistance: maximumDistance,
          reversed: !entering
        )
        commanderTransitionOverlays.append(overlay)
      }
    }

    let phaseDuration =
      DotDigitView.rippleWaveDuration + DotDigitView.animationDuration
    let overlapDelay = DotDigitView.rippleWaveDuration / 2
    DispatchQueue.main.asyncAfter(deadline: .now() + overlapDelay) { [weak self] in
      guard let self, generation == self.commanderTransitionGeneration else { return }
      let viewerRotation = self.layout.seats[recipientIndex].rotationDegrees

      for (index, cell) in self.cellViews.enumerated() where players.indices.contains(index) {
        if entering {
          if index == recipientIndex {
            cell.prepareCommanderRecipientDisplay(
              players[index].lifeTotal,
              viewerRotation: viewerRotation
            )
          } else {
            cell.prepareCommanderSourceDisplay(
              players[recipientIndex].damage(from: players[index].id),
              sourcePlayerNumber: index + 1,
              viewerRotation: viewerRotation
            )
          }
        } else {
          cell.prepareLifeDisplay(
            players[index].lifeTotal,
            rotation: self.layout.seats[index].rotationDegrees
          )
        }
        if index != recipientIndex {
          cell.snapDotsToOff()
        }
      }

      for (index, cell) in self.cellViews.enumerated() {
        if index == recipientIndex {
          if !entering {
            cell.animateRecipientRestore()
          }
        } else {
          cell.animateRippleIn(
            in: self,
            origin: origin,
            maximumDistance: maximumDistance,
            reversed: !entering
          )
        }
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + phaseDuration) { [weak self] in
        guard let self, generation == self.commanderTransitionGeneration else { return }
        self.commanderTransitionOverlays.forEach { $0.removeFromSuperview() }
        self.commanderTransitionOverlays.removeAll()
        if !entering {
          self.commanderRecipientIndex = nil
          self.resetPanGesture.isEnabled = true
        }
        self.cellViews.forEach { $0.isUserInteractionEnabled = true }
        self.setNeedsLayout()
      }
    }
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
      let rotation = commanderRecipientIndex.map {
        layout.seats[$0].rotationDegrees
      } ?? slot.rotationDegrees
      cell.rotation = rotation
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

    // Tap targets tile each cell with no gaps/overlap. The center interaction
    // zone is a fixed `editZoneWidth` band centered on the number; the ± zones
    // fill the rest.
    // Split along the player's left→right axis — 0°/180° split horizontally
    // (vertical dividers); ±90° split vertically — matching `tapZone`.
    let tapPath = UIBezierPath()
    let editHalf = PlayerCellView.editZoneWidth / 2
    for (i, slot) in slots.enumerated() where i < cellViews.count {
      let cell = cellViews[i]
      let numRect = cell.lifeTapAreaRect(in: self)
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
    }
    tapZoneShape.path = tapPath.cgPath
  }

  private static func uniformDotSize(for slots: [Slot]) -> CGFloat {
    slots.map { slot in
      let swapped = abs(Int(slot.rotationDegrees)) == 90
      let contentW = (swapped ? slot.frame.height : slot.frame.width) - PlayerCellView.contentInset * 2
      let contentH = (swapped ? slot.frame.width : slot.frame.height) - PlayerCellView.verticalInset * 2
      return DotNumberView.dotSize(fitting: CGSize(width: contentW, height: contentH))
    }.min() ?? 0
  }

  // MARK: - Swipe-to-reset

  @objc private func handleResetSwipe(_ pan: UIPanGestureRecognizer) {
    switch pan.state {
    case .began:
      revealFirstPlayerSelection()
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

  /// Establish the hidden-beam starting state before the layout selector fades.
  func prepareFirstPlayerSelection() {
    guard !cellViews.isEmpty else { return }
    layoutIfNeeded()
    stopFirstPlayerSweepDisplayLink()
    firstPlayerAnimationGeneration += 1
    firstPlayerAnimationPhase = .sweeping
    skeletonView.alpha = 0
    for cell in cellViews {
      cell.setFirstPlayerChromeVisible(false, animated: false)
      cell.setFirstPlayerEmphasis(
        alpha: Self.firstPlayerDimAlpha,
        scale: Self.firstPlayerDimScale,
        animated: false,
        duration: 0
      )
    }
  }

  /// Sweep an imaginary clockwise beam through every active life-total dot,
  /// accelerating until it stops on a randomly selected starting player.
  func playFirstPlayerSelection() {
    guard firstPlayerAnimationPhase == .sweeping,
        !cellViews.isEmpty else { return }

    let generation = firstPlayerAnimationGeneration
    guard let winner = cellViews.indices.randomElement(),
        currentSlots.indices.contains(winner) else { return }

    if UIAccessibility.isReduceMotionEnabled {
      landFirstPlayer(winner, generation: generation)
      return
    }

    onFirstPlayerSweepActiveChanged?(true)
    let origin = CGPoint(x: bounds.midX, y: bounds.midY)
    let winnerCenter = CGPoint(
      x: currentSlots[winner].frame.midX,
      y: currentSlots[winner].frame.midY
    )
    let fullTurn = CGFloat.pi * 2
    let startAngle = CGFloat.pi * 1.5
    var winnerAngle = atan2(
      winnerCenter.y - origin.y,
      winnerCenter.x - origin.x
    )
    if winnerAngle < 0 {
      winnerAngle += fullTurn
    }
    let finalPartialTurn =
      (winnerAngle - startAngle + fullTurn).truncatingRemainder(
        dividingBy: fullTurn
      )

    firstPlayerSweepStartTime = nil
    firstPlayerSweepStartAngle = startAngle
    firstPlayerSweepEndAngle =
      startAngle + Self.firstPlayerSweepTurns * fullTurn + finalPartialTurn
    firstPlayerSweepPreviousAngle = startAngle
    firstPlayerSweepWinner = winner
    firstPlayerSweepGeneration = generation
    firstPlayerLastHapticCell = nil
    firstPlayerSelectionFeedback.prepare()

    let target = FirstPlayerDisplayLinkTarget(owner: self)
    let displayLink = CADisplayLink(target: target, selector: #selector(target.tick(_:)))
    displayLink.preferredFrameRateRange = CAFrameRateRange(
      minimum: 60,
      maximum: 120,
      preferred: 120
    )
    firstPlayerSweepDisplayLinkTarget = target
    firstPlayerSweepDisplayLink = displayLink
    displayLink.add(to: .main, forMode: .common)
  }

  /// End the sweep/fade immediately without consuming the interaction that
  /// requested it.
  func revealFirstPlayerSelection() {
    guard firstPlayerAnimationPhase != .idle else { return }
    stopFirstPlayerSweepDisplayLink()
    firstPlayerAnimationGeneration += 1
    firstPlayerAnimationPhase = .idle

    for cell in cellViews {
      cell.setFirstPlayerChromeVisible(true, animated: true)
      cell.setFirstPlayerEmphasis(
        alpha: 1,
        scale: 1,
        animated: true,
        duration: 0.22
      )
    }
    restoreFirstPlayerBoardChrome()
  }

  fileprivate func updateFirstPlayerSweep(_ displayLink: CADisplayLink) {
    guard firstPlayerAnimationPhase == .sweeping,
        firstPlayerSweepGeneration == firstPlayerAnimationGeneration else {
      stopFirstPlayerSweepDisplayLink()
      return
    }

    if firstPlayerSweepStartTime == nil {
      firstPlayerSweepStartTime = displayLink.timestamp
    }
    let elapsed = displayLink.timestamp - (firstPlayerSweepStartTime ?? 0)
    let progress = min(1, elapsed / Self.firstPlayerSweepDuration)
    let acceleratedProgress = CGFloat(
      pow(progress, Self.firstPlayerSweepAccelerationExponent)
    )
    let angle = firstPlayerSweepStartAngle
      + (firstPlayerSweepEndAngle - firstPlayerSweepStartAngle)
      * acceleratedProgress
    let origin = CGPoint(x: bounds.midX, y: bounds.midY)

    for cell in cellViews {
      cell.applyFirstPlayerBeam(
        in: self,
        origin: origin,
        from: firstPlayerSweepPreviousAngle,
        to: angle,
        beamHalfWidth: Self.firstPlayerBeamHalfWidth,
        dimAlpha: Self.firstPlayerDimAlpha,
        dimScale: Self.firstPlayerDimScale,
        peakScale: Self.firstPlayerPeakScale
      )
    }
    updateFirstPlayerSweepHaptic(for: angle, origin: origin)
    firstPlayerSweepPreviousAngle = angle

    guard progress >= 1 else { return }
    let winner = firstPlayerSweepWinner
    let generation = firstPlayerSweepGeneration
    stopFirstPlayerSweepDisplayLink()
    landFirstPlayer(winner, generation: generation)
  }

  private func updateFirstPlayerSweepHaptic(
    for angle: CGFloat,
    origin: CGPoint
  ) {
    guard !currentSlots.isEmpty else { return }
    let fullTurn = CGFloat.pi * 2
    let beamAngle = angle.truncatingRemainder(dividingBy: fullTurn)
    let nearestCell = currentSlots.indices.min { lhs, rhs in
      let lhsCenter = CGPoint(
        x: currentSlots[lhs].frame.midX,
        y: currentSlots[lhs].frame.midY
      )
      let rhsCenter = CGPoint(
        x: currentSlots[rhs].frame.midX,
        y: currentSlots[rhs].frame.midY
      )
      let lhsAngle = atan2(lhsCenter.y - origin.y, lhsCenter.x - origin.x)
      let rhsAngle = atan2(rhsCenter.y - origin.y, rhsCenter.x - origin.x)
      let lhsDistance = abs(atan2(
        sin(lhsAngle - beamAngle),
        cos(lhsAngle - beamAngle)
      ))
      let rhsDistance = abs(atan2(
        sin(rhsAngle - beamAngle),
        cos(rhsAngle - beamAngle)
      ))
      return lhsDistance < rhsDistance
    }

    guard nearestCell != firstPlayerLastHapticCell else { return }
    firstPlayerLastHapticCell = nearestCell
    firstPlayerSelectionFeedback.selectionChanged()
  }

  private func stopFirstPlayerSweepDisplayLink() {
    firstPlayerSweepDisplayLink?.invalidate()
    firstPlayerSweepDisplayLink = nil
    firstPlayerSweepDisplayLinkTarget = nil
    firstPlayerSweepStartTime = nil
  }

  private func landFirstPlayer(_ winner: Int, generation: Int) {
    guard generation == firstPlayerAnimationGeneration,
        cellViews.indices.contains(winner) else { return }
    firstPlayerAnimationPhase = .fading

    for (index, cell) in cellViews.enumerated() {
      cell.setFirstPlayerChromeVisible(true, animated: true)
      let isWinner = index == winner
      cell.setFirstPlayerEmphasis(
        alpha: isWinner ? 1 : Self.firstPlayerDimAlpha,
        scale: isWinner ? 1.12 : Self.firstPlayerDimScale,
        animated: true,
        duration: 0.14
      )
    }
    cellViews[winner].shakeFirstPlayerLanding()
    restoreFirstPlayerBoardChrome()

    UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.9)
    UIAccessibility.post(
      notification: .announcement,
      argument: "Player \(winner + 1) goes first"
    )

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
      guard let self,
          generation == self.firstPlayerAnimationGeneration,
          self.firstPlayerAnimationPhase == .fading else { return }

      for cell in self.cellViews {
        cell.setFirstPlayerEmphasis(
          alpha: 1,
          scale: 1,
          animated: true,
          duration: Self.firstPlayerFadeDuration,
          usesSpring: false
        )
      }
      DispatchQueue.main.asyncAfter(
        deadline: .now() + Self.firstPlayerFadeDuration
      ) { [weak self] in
        guard let self,
            generation == self.firstPlayerAnimationGeneration else { return }
        self.firstPlayerAnimationPhase = .idle
      }
    }
  }

  private func restoreFirstPlayerBoardChrome() {
    onFirstPlayerSweepActiveChanged?(false)
    UIView.animate(
      withDuration: 0.22,
      delay: 0,
      options: [.beginFromCurrentState, .allowUserInteraction]
    ) {
      self.skeletonView.alpha = 1
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

  deinit {
    stopFirstPlayerSweepDisplayLink()
  }
}

private final class FirstPlayerDisplayLinkTarget {
  weak var owner: GameBoardView?

  init(owner: GameBoardView) {
    self.owner = owner
  }

  @objc func tick(_ displayLink: CADisplayLink) {
    owner?.updateFirstPlayerSweep(displayLink)
  }
}
