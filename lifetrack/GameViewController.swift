import UIKit

class GameViewController: UIViewController {
  private var currentLayout: PlayerLayout = .fourA
  private var players: [Player] = []
  private var editingIndex: Int?

  private let gameBoardView = GameBoardView()
  private let toolbarView = UIView()
  private let gridButton = UIButton()
  private let fontButton = UIButton()
  private let overlayView = LifeInputOverlay()
  private let layoutSelectorView = LayoutSelectorView()
  private let screenSkeletonView = UIView()
  private let screenEdgeShape = CAShapeLayer()

  private var showsGridSkeleton = false
  /// Index into `DotFont.allStyles` for the active dot font.
  private var fontIndex = DotFont.allStyles.firstIndex { $0.id == DotFontSettings.current.id } ?? 0

  override var prefersStatusBarHidden: Bool { true }
  override var prefersHomeIndicatorAutoHidden: Bool { true }

  override func loadView() {
    let rootView = GameInteractionView()
    rootView.onInteraction = { [weak self] in
      self?.gameBoardView.revealFirstPlayerSelection()
    }
    view = rootView
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black

    setupGameBoard()
    setupToolbar()
    setupOverlay()
    setupLayoutSelector()
    setupScreenSkeleton()
    resetPlayers(layout: currentLayout)
  }

  // MARK: - Setup

  private func setupGameBoard() {
    gameBoardView.onEditRequested = { [weak self] index, rotation in
      self?.presentOverlay(forPlayer: index, rotation: rotation)
    }
    gameBoardView.onLifeChanged = { [weak self] index, newLife in
      self?.players[index].lifeTotal = newLife
    }
    gameBoardView.onCommanderModeRequested = { [weak self] recipientIndex in
      guard let self else { return }
      self.gameBoardView.enterCommanderMode(
        recipientIndex: recipientIndex,
        players: self.players
      )
    }
    gameBoardView.onCommanderModeExitRequested = { [weak self] in
      guard let self else { return }
      self.gameBoardView.exitCommanderMode(players: self.players)
    }
    gameBoardView.onCommanderDamageChanged = { [weak self] index, opponentId, delta in
      guard let self else { return }
      let current = self.players[index].commanderDamage[opponentId] ?? 0
      let next = max(0, current + delta)
      let applied = next - current
      guard applied != 0 else { return }
      self.players[index].commanderDamage[opponentId] = next
      self.gameBoardView.setCommanderDamage(cellIndex: index, opponentId: opponentId, value: next)
      // Commander damage is combat damage — knock the same amount off the
      // recipient's life total (and roll the dots in that direction).
      self.players[index].lifeTotal -= applied
      self.gameBoardView.updatePlayer(
        at: index,
        lifeTotal: self.players[index].lifeTotal,
        direction: applied > 0 ? .decreasing : .increasing,
        animated: true,
        shakes: false
      )
    }
    gameBoardView.onResetRequested = { [weak self] in
      self?.handleSwipeReset()
    }
    gameBoardView.onFirstPlayerSweepActiveChanged = { [weak self] isActive in
      self?.setFirstPlayerSweepChromeHidden(isActive)
    }
    view.addSubview(gameBoardView)
  }

  private func setFirstPlayerSweepChromeHidden(_ hidden: Bool) {
    toolbarView.accessibilityElementsHidden = hidden
    screenSkeletonView.accessibilityElementsHidden = hidden

    if hidden {
      toolbarView.layer.removeAllAnimations()
      screenSkeletonView.layer.removeAllAnimations()
      toolbarView.alpha = 0
      screenSkeletonView.alpha = 0
      return
    }

    UIView.animate(
      withDuration: 0.22,
      delay: 0,
      options: [.beginFromCurrentState, .allowUserInteraction]
    ) {
      self.toolbarView.alpha = 1
      self.screenSkeletonView.alpha = 1
    }
  }

  private func handleSwipeReset() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.9)
    // Clear the board to empty and reveal the layout selector. The next
    // game starts when the user taps a layout in the selector.
    players = []
    gameBoardView.configure(layout: currentLayout, players: [])
    showLayoutSelector(animated: true)
  }

  private func setupToolbar() {
    gridButton.isAccessibilityElement = true
    gridButton.accessibilityLabel = "Grid skeleton"
    updateGridButtonAppearance()
    gridButton.addAction(UIAction { [weak self] _ in
      self?.gameBoardView.revealFirstPlayerSelection()
      self?.toggleGridSkeleton()
    }, for: .touchUpInside)
    toolbarView.addSubview(gridButton)

    fontButton.isAccessibilityElement = true
    fontButton.accessibilityLabel = "Dot font"
    updateFontButtonAppearance()
    fontButton.addAction(UIAction { [weak self] _ in
      self?.gameBoardView.revealFirstPlayerSelection()
      self?.cycleFont()
    }, for: .touchUpInside)
    toolbarView.addSubview(fontButton)

    view.addSubview(toolbarView)
  }

  private func setupOverlay() {
    overlayView.isHidden = true
    overlayView.onDismiss = { [weak self] result in
      self?.dismissOverlay(result: result)
    }
    view.addSubview(overlayView)
  }

  private func setupLayoutSelector() {
    layoutSelectorView.isHidden = true
    layoutSelectorView.alpha = 0
    layoutSelectorView.onSelect = { [weak self] layout in
      self?.startGame(with: layout)
    }
    view.addSubview(layoutSelectorView)
  }

  private func setupScreenSkeleton() {
    screenSkeletonView.isUserInteractionEnabled = false
    screenSkeletonView.isHidden = true

    screenEdgeShape.fillColor = UIColor.clear.cgColor
    screenEdgeShape.strokeColor = UIColor.systemGreen.withAlphaComponent(0.9).cgColor
    screenEdgeShape.lineWidth = 1
    screenSkeletonView.layer.addSublayer(screenEdgeShape)

    view.addSubview(screenSkeletonView)
  }

  // MARK: - Layout

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    let topInset = BoardInsets.topBottom
    let sideInset = BoardInsets.leftRight

    gameBoardView.frame = CGRect(
      x: sideInset,
      y: topInset,
      width: view.bounds.width - sideInset * 2,
      height: view.bounds.height - topInset * 2
    )

    // Settings button anchors in the bottom safe-area band, right-aligned.
    toolbarView.frame = CGRect(
      x: 0,
      y: view.bounds.height - topInset,
      width: view.bounds.width,
      height: topInset
    )
    layoutToolbarButtons()

    overlayView.frame = view.bounds
    layoutSelectorView.frame = view.bounds
    updateScreenSkeleton()
  }

  private func layoutToolbarButtons() {
    let pad: CGFloat = 16
    let btnSize: CGFloat = 36
    let gap: CGFloat = 8
    let y = (toolbarView.bounds.height - btnSize) / 2
    gridButton.frame = CGRect(
      x: toolbarView.bounds.width - pad - btnSize,
      y: y, width: btnSize, height: btnSize
    )
    fontButton.frame = CGRect(
      x: gridButton.frame.minX - gap - btnSize,
      y: y, width: btnSize, height: btnSize
    )
  }

  // MARK: - Grid skeleton

  private func toggleGridSkeleton() {
    showsGridSkeleton.toggle()
    gameBoardView.showsGridSkeleton = showsGridSkeleton
    screenSkeletonView.isHidden = !showsGridSkeleton
    updateScreenSkeleton()
    updateGridButtonAppearance()
  }

  private func updateScreenSkeleton() {
    screenSkeletonView.frame = view.bounds
    screenEdgeShape.frame = screenSkeletonView.bounds
    screenEdgeShape.path = UIBezierPath(
      rect: screenSkeletonView.bounds.insetBy(dx: 0.5, dy: 0.5)
    ).cgPath
    view.bringSubviewToFront(screenSkeletonView)
  }

  private func updateGridButtonAppearance() {
    let symbol = showsGridSkeleton ? "square.grid.2x2.fill" : "square.grid.2x2"
    gridButton.setImage(UIImage(systemName: symbol), for: .normal)
    gridButton.tintColor = showsGridSkeleton ? .systemGreen : .gray
    gridButton.accessibilityValue = showsGridSkeleton ? "On" : "Off"
  }

  // MARK: - Dot font

  /// Advance to the next dot font in `DotFont.allStyles`. Assigning
  /// `DotFontSettings.current` posts `didChange`, which the board and overlay
  /// observe to rebuild at the new glyph dimensions.
  private func cycleFont() {
    fontIndex = (fontIndex + 1) % DotFont.allStyles.count
    DotFontSettings.current = DotFont.allStyles[fontIndex]
    updateFontButtonAppearance()
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }

  private func updateFontButtonAppearance() {
    fontButton.setImage(UIImage(systemName: "textformat.size"), for: .normal)
    fontButton.tintColor = .gray
  }

  // MARK: - State

  private func resetPlayers(layout: PlayerLayout) {
    currentLayout = layout
    let startingLife = layout == .two ? 20 : Player.defaultLife
    players = (0..<layout.count).map { Player(id: $0, lifeTotal: startingLife) }
    gameBoardView.configure(layout: layout, players: players)
  }

  private func startGame(with layout: PlayerLayout) {
    resetPlayers(layout: layout)
    // Establish the dimmed starting state before the transparent selector
    // fades, then begin the lighthouse sweep once the board is fully visible.
    gameBoardView.prepareFirstPlayerSelection()
    hideLayoutSelector(animated: true) { [weak self] in
      self?.gameBoardView.playFirstPlayerSelection()
    }
  }

  private func showLayoutSelector(animated: Bool) {
    view.bringSubviewToFront(layoutSelectorView)
    view.bringSubviewToFront(screenSkeletonView)
    layoutSelectorView.isHidden = false
    toolbarView.isUserInteractionEnabled = false
    if animated {
      UIView.animate(withDuration: 0.25) {
        self.layoutSelectorView.alpha = 1
        self.toolbarView.alpha = 0
      }
    } else {
      layoutSelectorView.alpha = 1
      toolbarView.alpha = 0
    }
  }

  private func hideLayoutSelector(animated: Bool, completion: (() -> Void)? = nil) {
    toolbarView.isUserInteractionEnabled = true
    view.bringSubviewToFront(screenSkeletonView)
    let finish = {
      self.layoutSelectorView.isHidden = true
      completion?()
    }
    if animated {
      UIView.animate(withDuration: 0.25, animations: {
        self.layoutSelectorView.alpha = 0
        self.toolbarView.alpha = 1
      }, completion: { _ in finish() })
    } else {
      layoutSelectorView.alpha = 0
      toolbarView.alpha = 1
      finish()
    }
  }

  // MARK: - Overlay

  private func presentOverlay(forPlayer index: Int, rotation: CGFloat) {
    guard let cell = gameBoardView.cellView(at: index) else { return }

    editingIndex = index

    let cellDotView = cell.dotNumberView
    let cellVisualCenter = view.convert(
      CGPoint(x: cellDotView.bounds.midX, y: cellDotView.bounds.midY),
      from: cellDotView
    )
    let cellDotSize = cellDotView.actualDotSize

    gameBoardView.setEditing(index: index)

    let player = players[index]
    overlayView.showsGridSkeleton = showsGridSkeleton
    overlayView.prepare(
      lifeTotal: player.lifeTotal,
      commanderDamage: player.commanderDamage,
      seatColors: player.seatColors,
      colorSeed: player.id,
      rotation: rotation
    )

    let overlayCenter = overlayView.convert(cellVisualCenter, from: view)
    overlayView.prepareDotNumberViewHero(
      visualCenter: overlayCenter,
      sourceDotSize: cellDotSize
    )
    overlayView.animateDotNumberViewHeroToFinal()

    UIView.animate(
      withDuration: 0.45, delay: 0,
      usingSpringWithDamping: 0.85, initialSpringVelocity: 0,
      options: .curveEaseOut
    ) {
      self.overlayView.presentChrome()
      self.toolbarView.alpha = 0
    }
  }

  private func dismissOverlay(result: LifeInputResult) {
    guard let index = editingIndex,
        let cell = gameBoardView.cellView(at: index) else { return }

    players[index].lifeTotal = result.lifeTotal
    players[index].commanderDamage = result.commanderDamage
    players[index].seatColors = result.seatColors
    gameBoardView.updatePlayer(at: index, lifeTotal: result.lifeTotal)
    gameBoardView.updateSeatColors(
      at: index,
      colors: result.seatColors,
      seed: players[index].id
    )
    editingIndex = nil

    let cellDotView = cell.dotNumberView
    let cellVisualCenter = view.convert(
      CGPoint(x: cellDotView.bounds.midX, y: cellDotView.bounds.midY),
      from: cellDotView
    )
    let cellDotSize = cellDotView.actualDotSize
    let overlayCenter = overlayView.convert(cellVisualCenter, from: view)
    overlayView.animateDotNumberViewHeroToSource(
      visualCenter: overlayCenter,
      sourceDotSize: cellDotSize
    )

    UIView.animate(
      withDuration: LifeInputOverlay.dotHeroAnimationDuration,
      delay: 0,
      usingSpringWithDamping: 0.9, initialSpringVelocity: 0,
      options: .curveEaseInOut,
      animations: {
        self.gameBoardView.setAllAlphas(1)
        self.overlayView.dismissChrome()
        self.toolbarView.alpha = 1
      },
      completion: { _ in
        cell.isBeingEdited = false
        self.overlayView.finishDismiss()
        self.overlayView.resetDotNumberViewToFinal()
      }
    )
  }
}

private final class GameInteractionView: UIView {
  var onInteraction: (() -> Void)?

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    if event != nil {
      onInteraction?()
    }
    return super.hitTest(point, with: event)
  }
}
