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

    private var showsGridSkeleton = false
    /// Index into `DotFont.allStyles` for the active dot font.
    private var fontIndex = DotFont.allStyles.firstIndex { $0.id == DotFontSettings.current.id } ?? 0

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupGameBoard()
        setupToolbar()
        setupOverlay()
        setupLayoutSelector()
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
        gameBoardView.onResetRequested = { [weak self] in
            self?.handleSwipeReset()
        }
        view.addSubview(gameBoardView)
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
        updateGridButtonAppearance()
        gridButton.addAction(UIAction { [weak self] _ in
            self?.toggleGridSkeleton()
        }, for: .touchUpInside)
        toolbarView.addSubview(gridButton)

        updateFontButtonAppearance()
        fontButton.addAction(UIAction { [weak self] _ in
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
        updateGridButtonAppearance()
    }

    private func updateGridButtonAppearance() {
        let symbol = showsGridSkeleton ? "square.grid.2x2.fill" : "square.grid.2x2"
        gridButton.setImage(UIImage(systemName: symbol), for: .normal)
        gridButton.tintColor = showsGridSkeleton ? .systemGreen : .gray
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
        players = (0..<layout.count).map { Player(id: $0, lifeTotal: Player.defaultLife) }
        gameBoardView.configure(layout: layout, players: players)
    }

    private func startGame(with layout: PlayerLayout) {
        resetPlayers(layout: layout)
        // Push the freshly-built cells off-screen *now*, before the selector
        // starts fading. Otherwise they paint at full opacity behind the
        // transparent selector for the duration of the fade, then snap off
        // when the wipe begins — a visible "flash" of the new numbers.
        gameBoardView.playWipeIn()
        hideLayoutSelector(animated: true)
    }

    private func showLayoutSelector(animated: Bool) {
        view.bringSubviewToFront(layoutSelectorView)
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
        let opponents = players.filter { $0.id != player.id }.sorted(by: { $0.id < $1.id })
        overlayView.showsGridSkeleton = showsGridSkeleton
        overlayView.prepare(
            lifeTotal: player.lifeTotal,
            commanderDamage: player.commanderDamage,
            counters: player.counters,
            opponentIds: opponents.map { $0.id },
            layout: currentLayout,
            rotation: rotation
        )

        let overlayCenter = overlayView.convert(cellVisualCenter, from: view)
        overlayView.placeDotNumberView(visualCenter: overlayCenter, sourceDotSize: cellDotSize)

        UIView.animate(
            withDuration: 0.45, delay: 0,
            usingSpringWithDamping: 0.85, initialSpringVelocity: 0,
            options: .curveEaseOut
        ) {
            self.overlayView.resetDotNumberViewToFinal()
            self.overlayView.presentChrome()
            self.toolbarView.alpha = 0
        }
    }

    private func dismissOverlay(result: LifeInputResult) {
        guard let index = editingIndex,
              let cell = gameBoardView.cellView(at: index) else { return }

        players[index].lifeTotal = result.lifeTotal
        players[index].commanderDamage = result.commanderDamage
        players[index].counters = result.counters
        gameBoardView.updatePlayer(at: index, lifeTotal: result.lifeTotal)
        gameBoardView.applyPlayerBadges(from: players)
        editingIndex = nil

        // Make the badge bar visible-but-transparent so it can fade in
        // alongside the overlay dismissal instead of snapping in at the end.
        cell.badgeBar.isHidden = false
        cell.badgeBar.alpha = 0

        let cellDotView = cell.dotNumberView
        let cellVisualCenter = view.convert(
            CGPoint(x: cellDotView.bounds.midX, y: cellDotView.bounds.midY),
            from: cellDotView
        )
        let cellDotSize = cellDotView.actualDotSize
        let overlayCenter = overlayView.convert(cellVisualCenter, from: view)

        UIView.animate(
            withDuration: 0.4, delay: 0,
            usingSpringWithDamping: 0.9, initialSpringVelocity: 0,
            options: .curveEaseInOut,
            animations: {
                self.gameBoardView.setAllAlphas(1)
                cell.badgeBar.alpha = 1
                self.overlayView.placeDotNumberView(visualCenter: overlayCenter, sourceDotSize: cellDotSize)
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
