import UIKit

class GameViewController: UIViewController {
    private var playerCount = 4
    private var players: [Player] = []
    private var editingIndex: Int?

    private let gameBoardView = GameBoardView()
    private let toolbarView = UIView()
    private var countButtons: [UIButton] = []
    private let resetButton = UIButton()
    private let settingsButton = UIButton()
    private let overlayView = LifeInputOverlay()

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupGameBoard()
        setupToolbar()
        setupOverlay()
        resetPlayers()
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
        players = (0..<playerCount).map { Player(id: $0, lifeTotal: Player.defaultLife) }
        gameBoardView.configure(with: players)
        updateToolbarAppearance()
        gameBoardView.playWipeIn()
    }

    private func setupToolbar() {
        for count in 2...6 {
            let btn = UIButton()
            btn.setTitle("\(count)", for: .normal)
            btn.titleLabel?.font = .preferredFont(forTextStyle: .headline)
            btn.layer.cornerRadius = 18
            btn.clipsToBounds = true
            let c = count
            btn.addAction(UIAction { [weak self] _ in
                self?.playerCount = c
                self?.resetPlayers()
            }, for: .touchUpInside)
            countButtons.append(btn)
            toolbarView.addSubview(btn)
        }

        resetButton.setImage(UIImage(systemName: "arrow.counterclockwise"), for: .normal)
        resetButton.tintColor = .gray
        resetButton.addAction(UIAction { [weak self] _ in
            self?.resetPlayers()
        }, for: .touchUpInside)
        toolbarView.addSubview(resetButton)

        settingsButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
        settingsButton.tintColor = .gray
        settingsButton.addAction(UIAction { [weak self] _ in
            self?.presentSettings()
        }, for: .touchUpInside)
        toolbarView.addSubview(settingsButton)

        view.addSubview(toolbarView)
    }

    private func setupOverlay() {
        overlayView.isHidden = true
        overlayView.onDismiss = { [weak self] result in
            self?.dismissOverlay(result: result)
        }
        view.addSubview(overlayView)
    }

    // MARK: - Layout

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let inset = view.safeAreaInsets.top

        gameBoardView.frame = CGRect(
            x: 0, y: inset,
            width: view.bounds.width,
            height: view.bounds.height - 2 * inset
        )

        toolbarView.frame = CGRect(
            x: 0, y: view.bounds.height - inset,
            width: view.bounds.width,
            height: inset
        )
        layoutToolbarButtons()

        overlayView.frame = view.bounds
    }

    private func layoutToolbarButtons() {
        let pad: CGFloat = 16
        let btnSize: CGFloat = 36
        let y = (toolbarView.bounds.height - btnSize) / 2
        var x = pad
        for btn in countButtons {
            btn.frame = CGRect(x: x, y: y, width: btnSize, height: btnSize)
            x += 56
        }
        resetButton.frame = CGRect(
            x: toolbarView.bounds.width - pad - btnSize,
            y: y, width: btnSize, height: btnSize
        )
        settingsButton.frame = CGRect(
            x: toolbarView.bounds.width - pad - btnSize * 2 - 8,
            y: y, width: btnSize, height: btnSize
        )
    }

    private func updateToolbarAppearance() {
        for (i, btn) in countButtons.enumerated() {
            let count = i + 2
            let selected = count == playerCount
            btn.setTitleColor(selected ? .white : .gray, for: .normal)
            btn.backgroundColor = selected ? UIColor.white.withAlphaComponent(0.2) : .clear
        }
    }

    // MARK: - Settings

    private func presentSettings() {
        let alert = UIAlertController(
            title: "Font",
            message: nil,
            preferredStyle: .actionSheet
        )
        let activeID = DotFontSettings.current.id
        for font in DotFont.allFonts {
            let mark = (font.id == activeID) ? "✓ " : "   "
            alert.addAction(UIAlertAction(title: mark + font.displayName, style: .default) { [weak self] _ in
                DotFontSettings.set(font)
                self?.gameBoardView.setNeedsLayout()
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.sourceView = settingsButton
        alert.popoverPresentationController?.sourceRect = settingsButton.bounds
        present(alert, animated: true)
    }

    // MARK: - State

    private func resetPlayers() {
        players = (0..<playerCount).map { Player(id: $0, lifeTotal: Player.defaultLife) }
        gameBoardView.configure(with: players)
        updateToolbarAppearance()
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
        overlayView.prepare(
            lifeTotal: player.lifeTotal,
            commanderDamage: player.commanderDamage,
            counters: player.counters,
            opponentIds: opponents.map { $0.id },
            playerCount: players.count,
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
