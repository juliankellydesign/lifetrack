import UIKit

/// Full-screen sheet that lets the player pick how many players are at the
/// table and which seating layout to use. Shown on first launch and after a
/// committed swipe-to-reset.
///
/// Geometry (per design spec):
///   - 8pt safe area on the left and right of the screen
///   - 52pt safe area on the top and bottom of the screen
///   - 2 columns × 4 rows of buttons
///   - Each button is `(screenWidth - 16) / 4` wide and `(screenHeight - 104) / 6` tall
///   - The button grid is centered, leaving a 1/4-wide gutter on each side and
///     a 1/6-tall gutter above and below.
class LayoutSelectorView: UIView {
  var onSelect: ((PlayerLayout) -> Void)?
  var onCancel: (() -> Void)?

  var allowsCancellation = false {
    didSet {
      guard allowsCancellation != oldValue else { return }
      cancelButton.isHidden = !allowsCancellation
      cancelButton.isAccessibilityElement = allowsCancellation
      setNeedsLayout()
    }
  }

  var showsGridSkeleton = false {
    didSet {
      guard showsGridSkeleton != oldValue else { return }
      setNeedsLayout()
    }
  }

  private struct Cell {
    var layout: PlayerLayout
    var button: UIControl
    var icon: PlayerLayoutIconView
  }

  private struct Instruction {
    var text: String
    var holdDuration: TimeInterval
  }

  private var cells: [Cell] = []
  private let cancelButton = UIButton(type: .custom)
  private let instructionButton = UIButton(type: .custom)
  private let debugRegionShape = CAShapeLayer()
  private let debugTapShape = CAShapeLayer()
  private var instructionTimer: Timer?
  private var instructionGeneration = 0
  private var instructionIndex: Int?
  private var instructionIsTransitioning = false

  private static let columns = 2
  private static let rows = 4
  private static let iconSize: CGFloat = 48
  private static let instructionFadeDuration: TimeInterval = 0.3
  private static let instructions = [
    Instruction(text: "Tap to assign commander damage", holdDuration: 3),
    Instruction(text: "Tap and hold to manually edit", holdDuration: 3),
    Instruction(text: "Swipe from anywhere to reset", holdDuration: 3),
    Instruction(text: "Have fun", holdDuration: 5)
  ]

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .black
    buildCells()
    setupCancelButton()
    setupInstructionButton()
    setupDebugSkeleton()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    backgroundColor = .black
    buildCells()
    setupCancelButton()
    setupInstructionButton()
    setupDebugSkeleton()
  }

  private func setupCancelButton() {
    cancelButton.setImage(
      Self.sizedActionIcon(named: "icon-delete", size: 32),
      for: .normal
    )
    cancelButton.tintColor = .white
    cancelButton.imageView?.contentMode = .center
    cancelButton.isHidden = true
    cancelButton.isAccessibilityElement = false
    cancelButton.accessibilityLabel = "Cancel reset"
    cancelButton.accessibilityIdentifier = "reset-cancel"
    cancelButton.addAction(UIAction { _ in
      AppSoundPlayer.shared.play(.button)
    }, for: .touchDown)
    cancelButton.addAction(UIAction { [weak self] _ in
      self?.onCancel?()
    }, for: .touchUpInside)

    cancelButton.addAction(UIAction { [weak cancelButton] _ in
      UIView.animate(
        withDuration: 0.15,
        delay: 0,
        usingSpringWithDamping: 1,
        initialSpringVelocity: 0,
        options: [.allowUserInteraction, .beginFromCurrentState]
      ) {
        cancelButton?.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
      }
    }, for: .touchDown)

    cancelButton.addAction(UIAction { [weak cancelButton] _ in
      UIView.animate(
        withDuration: 0.15,
        delay: 0,
        usingSpringWithDamping: 1,
        initialSpringVelocity: 0,
        options: [.allowUserInteraction, .beginFromCurrentState]
      ) {
        cancelButton?.transform = .identity
      }
    }, for: [.touchUpInside, .touchUpOutside, .touchCancel])
    addSubview(cancelButton)
  }

  private static func sizedActionIcon(named name: String, size: CGFloat) -> UIImage? {
    guard let image = UIImage(named: name) else { return nil }
    let targetSize = CGSize(width: size, height: size)
    let renderer = UIGraphicsImageRenderer(size: targetSize)
    let resized = renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
    return resized.withRenderingMode(.alwaysTemplate)
  }

  private func buildCells() {
    for layout in PlayerLayout.selectorOrder {
      let button = UIControl()
      button.backgroundColor = .clear
      button.isAccessibilityElement = true
      button.accessibilityTraits = .button
      button.accessibilityLabel = Self.accessibilityLabel(for: layout)
      button.accessibilityIdentifier = "player-layout-\(layout.rawValue)"

      let icon = PlayerLayoutIconView(layout: layout)
      icon.isUserInteractionEnabled = false
      button.addSubview(icon)

      button.addAction(UIAction { [weak self] _ in
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
        self?.onSelect?(layout)
      }, for: .touchUpInside)

      // Press feedback scales only the icon. The button keeps its full grid-cell
      // hit area, preventing touch-drag exit flutter around its edges.
      button.addAction(UIAction { [weak icon] _ in
        AppSoundPlayer.shared.play(.button)
        UIView.animate(
          withDuration: 0.12,
          delay: 0,
          usingSpringWithDamping: 0.9,
          initialSpringVelocity: 0,
          options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
          icon?.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
      }, for: [.touchDown, .touchDragEnter])

      button.addAction(UIAction { [weak icon] _ in
        UIView.animate(
          withDuration: 0.2,
          delay: 0,
          usingSpringWithDamping: 0.7,
          initialSpringVelocity: 0,
          options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
          icon?.transform = .identity
        }
      }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

      addSubview(button)
      cells.append(Cell(layout: layout, button: button, icon: icon))
    }
  }

  private static func accessibilityLabel(for layout: PlayerLayout) -> String {
    switch layout {
    case .two, .three:
      return "\(layout.count) players"
    case .fourA, .fiveA, .sixA:
      return "\(layout.count) players, layout A"
    case .fourB, .fiveB, .sixB:
      return "\(layout.count) players, layout B"
    }
  }

  private func setupInstructionButton() {
    instructionButton.titleLabel?.font = Typography.gameplayTip.uiFont
    instructionButton.titleLabel?.lineBreakMode = .byClipping
    instructionButton.setTitleColor(
      UIColor.white.withAlphaComponent(0.3),
      for: .normal
    )
    instructionButton.alpha = 0
    instructionButton.accessibilityHint = "Shows the next gameplay tip"
    instructionButton.addAction(UIAction { [weak self] _ in
      self?.advanceInstruction()
    }, for: .touchUpInside)
    addSubview(instructionButton)
  }

  func startInstructions() {
    stopInstructions()
    instructionIndex = 0
    instructionButton.isAccessibilityElement = true
    instructionButton.setTitle(Self.instructions[0].text, for: .normal)
    instructionButton.alpha = 0
    let generation = instructionGeneration
    UIView.animate(
      withDuration: Self.instructionFadeDuration,
      delay: 0,
      options: [.beginFromCurrentState, .allowUserInteraction]
    ) {
      self.instructionButton.alpha = 1
    } completion: { [weak self] finished in
      guard let self,
          finished,
          generation == self.instructionGeneration else { return }
      self.scheduleInstructionAdvance(generation: generation)
    }
  }

  func stopInstructions() {
    instructionGeneration += 1
    instructionTimer?.invalidate()
    instructionTimer = nil
    instructionIndex = nil
    instructionIsTransitioning = false
    instructionButton.isAccessibilityElement = false
    instructionButton.layer.removeAllAnimations()
    instructionButton.alpha = 0
  }

  private func scheduleInstructionAdvance(generation: Int) {
    guard let instructionIndex,
        Self.instructions.indices.contains(instructionIndex) else { return }
    instructionTimer?.invalidate()
    instructionTimer = Timer.scheduledTimer(
      withTimeInterval: Self.instructions[instructionIndex].holdDuration,
      repeats: false
    ) { [weak self] _ in
      guard let self,
          generation == self.instructionGeneration else { return }
      self.advanceInstruction()
    }
  }

  private func advanceInstruction() {
    guard let instructionIndex, !instructionIsTransitioning else { return }
    instructionIsTransitioning = true
    instructionTimer?.invalidate()
    instructionTimer = nil
    let generation = instructionGeneration
    let nextIndex = instructionIndex + 1

    UIView.animate(
      withDuration: Self.instructionFadeDuration,
      delay: 0,
      options: [.beginFromCurrentState, .allowUserInteraction]
    ) {
      self.instructionButton.alpha = 0
    } completion: { [weak self] finished in
      guard let self,
          finished,
          generation == self.instructionGeneration else { return }
      guard Self.instructions.indices.contains(nextIndex) else {
        self.instructionIndex = nil
        self.instructionIsTransitioning = false
        self.instructionButton.isAccessibilityElement = false
        return
      }

      self.instructionIndex = nextIndex
      self.instructionButton.setTitle(
        Self.instructions[nextIndex].text,
        for: .normal
      )
      UIView.animate(
        withDuration: Self.instructionFadeDuration,
        delay: 0,
        options: [.beginFromCurrentState, .allowUserInteraction]
      ) {
        self.instructionButton.alpha = 1
      } completion: { [weak self] finished in
        guard let self,
            finished,
            generation == self.instructionGeneration else { return }
        self.instructionIsTransitioning = false
        self.scheduleInstructionAdvance(generation: generation)
      }
    }
  }

  private func setupDebugSkeleton() {
    debugRegionShape.fillColor = UIColor.clear.cgColor
    debugRegionShape.strokeColor = UIColor.systemGreen.withAlphaComponent(0.9).cgColor
    debugRegionShape.lineWidth = 1
    debugRegionShape.zPosition = 998
    layer.addSublayer(debugRegionShape)

    debugTapShape.fillColor = UIColor.clear.cgColor
    debugTapShape.strokeColor = UIColor.systemOrange.withAlphaComponent(0.9).cgColor
    debugTapShape.lineWidth = 1
    debugTapShape.zPosition = 999
    layer.addSublayer(debugTapShape)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard cells.count == Self.columns * Self.rows else { return }

    let availableW = bounds.width - BoardInsets.leftRight * 2
    let availableH = bounds.height - BoardInsets.topBottom * 2

    let cellW = availableW / 4
    let cellH = availableH / 6

    let totalW = cellW * CGFloat(Self.columns)
    let totalH = cellH * CGFloat(Self.rows)

    let originX = BoardInsets.leftRight + (availableW - totalW) / 2
    let originY = BoardInsets.topBottom + (availableH - totalH) / 2

    let cancelTargetSize: CGFloat = 60
    let upperGutterCenterY = (BoardInsets.topBottom + originY) / 2
    cancelButton.frame = CGRect(
      x: (bounds.width - cancelTargetSize) / 2,
      y: upperGutterCenterY - cancelTargetSize / 2,
      width: cancelTargetSize,
      height: cancelTargetSize
    )

    for (i, cell) in cells.enumerated() {
      let col = i % Self.columns
      let row = i / Self.columns
      let frame = CGRect(
        x: originX + CGFloat(col) * cellW,
        y: originY + CGFloat(row) * cellH,
        width: cellW,
        height: cellH
      )
      cell.button.frame = frame
      let iconSize = Self.iconSize
      cell.icon.frame = CGRect(
        x: (frame.width - iconSize) / 2,
        y: (frame.height - iconSize) / 2,
        width: iconSize,
        height: iconSize
      )
    }

    let gridBottom = originY + totalH
    let playableBottom = bounds.height - BoardInsets.topBottom
    let instructionHeight = Typography.gameplayTip.lineHeight
    instructionButton.frame = CGRect(
      x: BoardInsets.leftRight,
      y: (gridBottom + playableBottom - instructionHeight) / 2,
      width: availableW,
      height: instructionHeight
    )

    updateDebugSkeleton()
  }

  private func updateDebugSkeleton() {
    debugRegionShape.frame = bounds
    debugTapShape.frame = bounds

    guard showsGridSkeleton else {
      debugRegionShape.path = nil
      debugTapShape.path = nil
      return
    }

    let playableRect = bounds.insetBy(
      dx: BoardInsets.leftRight,
      dy: BoardInsets.topBottom
    )
    debugRegionShape.path = UIBezierPath(rect: playableRect).cgPath

    let tapPath = UIBezierPath()
    for cell in cells {
      tapPath.append(UIBezierPath(rect: cell.button.frame))
    }
    if allowsCancellation {
      tapPath.append(UIBezierPath(rect: cancelButton.frame))
    }
    debugTapShape.path = tapPath.cgPath
  }
}
