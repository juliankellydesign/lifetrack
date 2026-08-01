import UIKit

struct LifeInputResult {
  var lifeTotal: Int
  var commanderDamage: [Int: Int]
  var seatColors: Set<SeatColor>
}

class LifeInputOverlay: UIView {
  static let dotHeroAnimationDuration = DotNumberView.editHeroTotalDuration

  var onDismiss: ((LifeInputResult) -> Void)?

  private let contentContainer = UIView()
  let dotNumberView = DotNumberView()
  private let colorPickerView = SeatColorPickerView()
  let numberPadView = NumberPadView()

  /// Debug overlay: when true, strokes the usable content area plus every
  /// laid-out region (life number and number pad) and each number-pad key.
  /// Mirrors `GameBoardView.showsGridSkeleton`.
  var showsGridSkeleton = false {
    didSet {
      guard showsGridSkeleton != oldValue else { return }
      setNeedsLayout()
    }
  }
  private let skeletonShape = CAShapeLayer()

  /// Padding from the safe-area edges of the screen to the input view's content.
  private static let horizontalEdgePadding: CGFloat = 0   // safe area already covers this in landscape
  private static let verticalEdgePadding: CGFloat = 8
  /// Keeps the editable life total prominent without letting its dots dominate
  /// the keypad on larger cells or displays.
  private static let maxLifeDotSize: CGFloat = 28

  private var inputText = ""
  private var lifeTotal: Int = 0
  private var commanderDamage: [Int: Int] = [:]
  private var seatColors: Set<SeatColor> = [.colorless]
  private var colorSeed = 0
  private(set) var rotation: CGFloat = 0
  private var direction: ChangeDirection?
  private var finalDotCenter: CGPoint = .zero

  private var displayNumber: Int {
    if inputText.isEmpty { return lifeTotal }
    return Int(inputText) ?? 0
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  private func setup() {
    backgroundColor = UIColor.black.withAlphaComponent(0)
    alpha = 0

    addSubview(contentContainer)
    dotNumberView.maxDotSize = Self.maxLifeDotSize
    dotNumberView.isUserInteractionEnabled = true
    let dotTap = UITapGestureRecognizer(target: self, action: #selector(handleLifeTotalTap))
    dotNumberView.addGestureRecognizer(dotTap)
    contentContainer.addSubview(dotNumberView)
    colorPickerView.onSelectionChanged = { [weak self] colors in
      guard let self else { return }
      self.seatColors = colors
      self.dotNumberView.setSeatColors(colors, seed: self.colorSeed, animated: true)
    }
    contentContainer.addSubview(colorPickerView)
    numberPadView.onKey = { [weak self] key in self?.handleKey(key) }
    contentContainer.addSubview(numberPadView)

    skeletonShape.fillColor = UIColor.clear.cgColor
    skeletonShape.strokeColor = UIColor.systemGreen.withAlphaComponent(0.9).cgColor
    skeletonShape.lineWidth = 1
    skeletonShape.zPosition = 999 // keep on top of the region subviews
    contentContainer.layer.addSublayer(skeletonShape)

  }

  /// Configure state and lay out without animating; caller drives the transition.
  func prepare(
    lifeTotal: Int,
    commanderDamage: [Int: Int],
    seatColors: Set<SeatColor>,
    colorSeed: Int,
    rotation: CGFloat
  ) {
    self.lifeTotal = lifeTotal
    self.commanderDamage = commanderDamage
    self.seatColors = seatColors.isEmpty ? [.colorless] : seatColors
    self.colorSeed = colorSeed
    self.rotation = rotation
    inputText = ""
    direction = nil
    isHidden = false
    alpha = 1
    backgroundColor = UIColor.black.withAlphaComponent(0)
    numberPadView.alpha = 0
    colorPickerView.alpha = 0
    colorPickerView.prepare(colors: self.seatColors)
    dotNumberView.setSeatColors(self.seatColors, seed: colorSeed, animated: false)

    dotNumberView.finishEditHero()
    dotNumberView.transform = .identity
    setNeedsLayout()
    layoutIfNeeded()

    finalDotCenter = dotNumberView.center
    dotNumberView.updateNumber(lifeTotal, direction: nil, animated: false)
  }

  /// Seed the editor's final dot layout from the board number without moving
  /// the number view itself. Individual dots own the directional transition.
  func prepareDotNumberViewHero(
    visualCenter: CGPoint,
    sourceDotSize: CGFloat
  ) {
    resetDotNumberViewToFinal()
    dotNumberView.layoutIfNeeded()
    let sourceCenterInContainer = contentContainerLocal(for: visualCenter)
    let sourceCenterInNumber = dotNumberView.convert(
      sourceCenterInContainer,
      from: contentContainer
    )
    dotNumberView.prepareEditHero(
      from: sourceCenterInNumber,
      sourceDotSize: sourceDotSize
    )
  }

  func animateDotNumberViewHeroToFinal() {
    dotNumberView.animateEditHeroToFinal()
  }

  func animateDotNumberViewHeroToSource(
    visualCenter: CGPoint,
    sourceDotSize: CGFloat
  ) {
    resetDotNumberViewToFinal()
    let sourceCenterInContainer = contentContainerLocal(for: visualCenter)
    let sourceCenterInNumber = dotNumberView.convert(
      sourceCenterInContainer,
      from: contentContainer
    )
    dotNumberView.animateEditHeroToSource(
      at: sourceCenterInNumber,
      sourceDotSize: sourceDotSize
    )
  }

  /// Reset the dotNumberView to its laid-out position with identity transform.
  func resetDotNumberViewToFinal() {
    dotNumberView.transform = .identity
    dotNumberView.center = finalDotCenter
  }

  /// Settle background to black and reveal the keypad. Call inside an animation block.
  func presentChrome() {
    backgroundColor = .black
    numberPadView.alpha = 1
    colorPickerView.alpha = 1
  }

  /// Fade chrome away. Call inside an animation block.
  func dismissChrome() {
    backgroundColor = UIColor.black.withAlphaComponent(0)
    numberPadView.alpha = 0
    colorPickerView.alpha = 0
  }

  func finishDismiss() {
    dotNumberView.finishEditHero()
    alpha = 0
    isHidden = true
  }

  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard !isHidden else { return }

    let insets = safeAreaInsets
    let safeW = bounds.width - insets.left - insets.right
    let safeH = bounds.height - insets.top - insets.bottom

    let isHorizontal = abs(Int(rotation)) == 90
    let rotRad = rotation * .pi / 180
    let contentW = isHorizontal ? safeH : safeW
    let contentH = isHorizontal ? safeW : safeH

    contentContainer.transform = .identity
    contentContainer.bounds = CGRect(x: 0, y: 0, width: contentW, height: contentH)
    contentContainer.center = CGPoint(
      x: insets.left + safeW / 2,
      y: insets.top + safeH / 2
    )

    let hPad = Self.horizontalEdgePadding
    let vPad = Self.verticalEdgePadding
    let usableW = contentW - hPad * 2
    let usableH = contentH - vPad * 2

    // The overlay uses the same slot-first mental model as the board: a left
    // editing surface and a right keypad. The life number fills the entire left
    // column; commander damage has its own board-wide mode. The dot-number hero
    // animation still converges on `dotNumberView`'s final frame here.
    let padRows: CGFloat = 4
    let padRowSpacing: CGFloat = NumberPadView.rowSpacing

    if isHorizontal {
      // Number pad on the right: each key is square, sized to fit the
      // available height. The pad's full width is 3 × key height, leaving
      // the rest of the row for the life column on the left.
      let padH = usableH
      let padCellH = (padH - (padRows - 1) * padRowSpacing) / padRows
      let padColW = padCellH * CGFloat(3)
      let lifeColW = usableW - padColW
      let pickerBandHeight = padCellH

      dotNumberView.frame = CGRect(
        x: hPad, y: vPad + pickerBandHeight + padRowSpacing,
        width: lifeColW,
        height: padH - pickerBandHeight - padRowSpacing
      )
      colorPickerView.frame = CGRect(
        x: hPad, y: vPad,
        width: lifeColW, height: pickerBandHeight
      )
      numberPadView.frame = CGRect(
        x: hPad + lifeColW, y: vPad,
        width: padColW, height: padH
      )
      colorPickerView.setDotSize(dotNumberView.actualDotSize)
    } else {
      // Portrait fallback: stack life column above keypad.
      let padH = contentH * 0.45
      let lifeH = usableH - padH
      let pickerBandHeight = SeatColorPickerView.preferredHeight

      dotNumberView.frame = CGRect(
        x: hPad, y: vPad + pickerBandHeight,
        width: usableW, height: lifeH - pickerBandHeight
      )
      colorPickerView.frame = CGRect(
        x: hPad, y: vPad,
        width: usableW, height: pickerBandHeight
      )
      numberPadView.frame = CGRect(
        x: hPad, y: vPad + lifeH,
        width: usableW, height: padH
      )
      colorPickerView.setDotSize(dotNumberView.actualDotSize)
    }

    contentContainer.transform = CGAffineTransform(rotationAngle: rotRad)

    updateSkeleton()
  }

  /// Redraw (or clear) the grid-skeleton overlay. Drawn in `contentContainer`'s
  /// coordinate space — since the shape layer lives inside `contentContainer`,
  /// the container's rotation transform carries the outlines along for free.
  private func updateSkeleton() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    skeletonShape.frame = contentContainer.bounds

    guard showsGridSkeleton else {
      skeletonShape.path = nil
      CATransaction.commit()
      return
    }

    numberPadView.layoutIfNeeded()
    let path = UIBezierPath()
    path.append(UIBezierPath(rect: contentContainer.bounds.insetBy(dx: 0.5, dy: 0.5)))
    for region in [colorPickerView.frame, dotNumberView.frame, numberPadView.frame] {
      path.append(UIBezierPath(rect: region))
    }
    let padOrigin = numberPadView.frame.origin
    for key in numberPadView.keyFrames {
      path.append(UIBezierPath(rect: key.offsetBy(dx: padOrigin.x, dy: padOrigin.y)))
    }
    skeletonShape.path = path.cgPath
    CATransaction.commit()
  }

  private func clamp(_ x: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
    Swift.max(lo, Swift.min(hi, x))
  }

  // MARK: - Coordinate helpers

  private func contentContainerLocal(for point: CGPoint) -> CGPoint {
    let dx = point.x - contentContainer.center.x
    let dy = point.y - contentContainer.center.y
    let rotRad = -rotation * .pi / 180
    let cosR = cos(rotRad)
    let sinR = sin(rotRad)
    let lx = dx * cosR - dy * sinR + contentContainer.bounds.midX
    let ly = dx * sinR + dy * cosR + contentContainer.bounds.midY
    return CGPoint(x: lx, y: ly)
  }

  // MARK: - Numpad input (life only)

  @objc private func handleLifeTotalTap() {
    handleKey(.confirm)
  }

  private func handleKey(_ key: NumberPadKey) {
    let oldNumber = displayNumber
    switch key {
    case .digit(let d):
      if inputText.count < 4 {
        inputText += "\(d)"
      }
    case .backspace:
      if inputText.isEmpty {
        let s = String(lifeTotal)
        inputText = String(s.dropLast())
      } else {
        inputText.removeLast()
      }
    case .clear:
      inputText = ""
    case .confirm:
      if !inputText.isEmpty, let value = Int(inputText) {
        lifeTotal = value
      }
      onDismiss?(LifeInputResult(
        lifeTotal: lifeTotal,
        commanderDamage: commanderDamage,
        seatColors: seatColors
      ))
      return
    }
    let newNumber = displayNumber
    if newNumber != oldNumber {
      direction = newNumber > oldNumber ? .increasing : .decreasing
    }
    dotNumberView.updateNumber(newNumber, direction: direction, animated: true)
  }
}
