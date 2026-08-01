import UIKit

class DotNumberView: UIView {
  static let editHeroTotalDuration = DotDigitView.editHeroTotalDuration

  private var digitViews: [DotDigitView] = []
  private(set) var number: Int = 0
  var maxDotSize: CGFloat?
  private(set) var seatColors: Set<SeatColor> = [.colorless]
  private(set) var colorSeed = 0

  /// Gap between dots, as a fraction of dot diameter. 2 / 18 gives a 2pt gap
  /// at the board's 18pt target dot size, and scales with the dot otherwise.
  private static let spacingRatio: CGFloat = 2.0 / 18.0
  /// Gap between adjacent digits, in dot-diameter units — one full dot of
  /// space, matching the blank column between digits in the reference font.
  private static let digitGapRatio: CGFloat = 1.0

  private var lastLayoutSize: CGSize = .zero
  private var lastMaxDotSize: CGFloat?
  private var lastFontID: String?
  private var editHeroDirection: CGPoint?
  private var editHeroProjectionRange: ClosedRange<CGFloat>?
  /// Font id the current `digitViews` were built against, so `updateNumber`
  /// can detect a font change and rebuild at the new glyph dimensions.
  private var builtFontID: String?

  override init(frame: CGRect) {
    super.init(frame: frame)
    observeFontChanges()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    observeFontChanges()
  }

  private func observeFontChanges() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(fontDidChange),
      name: DotFontSettings.didChange,
      object: nil
    )
  }

  @objc private func fontDidChange() {
    lastLayoutSize = .zero
    lastFontID = nil
    setNeedsLayout()
  }

  static func dotSize(fitting size: CGSize, digitCount: Int = 2) -> CGFloat {
    let count = CGFloat(digitCount)
    let cols = count * CGFloat(DotPatterns.columns)
      + count * CGFloat(DotPatterns.columns - 1) * spacingRatio
      + (count - 1) * digitGapRatio
    let rows = CGFloat(DotPatterns.rows)
      + CGFloat(DotPatterns.rows - 1) * spacingRatio
    return min(size.width / cols, size.height / rows)
  }

  func setSeatColors(_ colors: Set<SeatColor>, seed: Int, animated: Bool) {
    seatColors = colors.isEmpty ? [.colorless] : colors
    colorSeed = seed
    let orderedColors = SeatColor.allCases.filter { seatColors.contains($0) }
    for (index, digitView) in digitViews.enumerated() {
      digitView.setSeatColors(
        orderedColors,
        seed: colorSeed &+ index &* 104_729,
        animated: animated
      )
    }
  }

  func updateNumber(_ newNumber: Int, direction: ChangeDirection?, animated: Bool) {
    let oldDigits = Self.digitValues(for: number)
    let newDigits = Self.digitValues(for: newNumber)
    number = newNumber

    guard bounds.width > 0 && bounds.height > 0 else { return }

    // Rebuild when the digit count changes, when there are no views yet, or
    // when the dot font itself changed — the new font has different
    // dimensions, so the old digit views (and their dot counts) are stale.
    if oldDigits.count != newDigits.count || digitViews.isEmpty
      || builtFontID != DotFontSettings.current.id {
      buildDigitViews(for: newDigits)
    }
    applyDigits(newDigits, direction: direction, animated: animated)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard bounds.width > 0 && bounds.height > 0 else { return }
    let fontID = DotFontSettings.current.id
    if bounds.size != lastLayoutSize || maxDotSize != lastMaxDotSize || fontID != lastFontID {
      lastLayoutSize = bounds.size
      lastMaxDotSize = maxDotSize
      lastFontID = fontID
      let digits = Self.digitValues(for: number)
      buildDigitViews(for: digits)
      applyDigits(digits, direction: nil, animated: false)
    }
  }

  // MARK: - Private

  private func buildDigitViews(for digits: [Int]) {
    digitViews.forEach { $0.removeFromSuperview() }
    digitViews.removeAll()
    builtFontID = DotFontSettings.current.id

    let dotSz = computeDotSize(digitCount: digits.count)
    let spc = dotSz * Self.spacingRatio
    let digitGap = dotSz * Self.digitGapRatio

    let digitW = CGFloat(DotPatterns.columns) * dotSz + CGFloat(DotPatterns.columns - 1) * spc
    let digitH = CGFloat(DotPatterns.rows) * dotSz + CGFloat(DotPatterns.rows - 1) * spc
    let totalW = CGFloat(digits.count) * digitW + CGFloat(digits.count - 1) * digitGap

    var x = (bounds.width - totalW) / 2
    let y = (bounds.height - digitH) / 2

    let orderedColors = SeatColor.allCases.filter { seatColors.contains($0) }
    for index in digits.indices {
      let dv = DotDigitView()
      dv.configure(dotSize: dotSz, spacing: spc)
      dv.setSeatColors(
        orderedColors,
        seed: colorSeed &+ index &* 104_729,
        animated: false
      )
      dv.frame = CGRect(x: x, y: y, width: dv.contentWidth, height: dv.contentHeight)
      addSubview(dv)
      digitViews.append(dv)
      x += digitW + digitGap
    }
  }

  private func applyDigits(_ digits: [Int], direction: ChangeDirection?, animated: Bool) {
    for (i, digit) in digits.enumerated() where i < digitViews.count {
      digitViews[i].setDigit(digit, direction: direction, animated: animated)
    }
  }

  /// Match shake energy to the accumulated +/- value shown beside the number.
  /// The squared logarithmic curve gives +1 a noticeable initial kick while
  /// letting larger net changes become emphatic without growing without bound.
  func shakeForChange(magnitude: Int, origin: CGPoint? = nil) {
    guard magnitude > 0 else { return }
    let referenceMagnitude: CGFloat = 20
    let logarithmicProgress = log2(CGFloat(magnitude) + 1)
      / log2(referenceMagnitude + 1)
    let normalizedMagnitude = min(1, logarithmicProgress)
    let intensity = 0.10 + pow(normalizedMagnitude, 2) * 0.80
    guard let origin else {
      shake(normalizedIntensity: intensity)
      return
    }

    let centers = digitViews.flatMap { $0.activeDotCenters(in: self) }
    let maximumDistance = centers.map {
      hypot($0.x - origin.x, $0.y - origin.y)
    }.max() ?? 0
    for digitView in digitViews {
      digitView.rippleShake(
        normalizedIntensity: intensity,
        in: self,
        origin: origin,
        maximumDistance: maximumDistance
      )
    }
  }

  func shakeForFirstPlayerLanding() {
    shake(normalizedIntensity: 0.9)
  }

  private func shake(normalizedIntensity: CGFloat) {
    for digitView in digitViews {
      digitView.shake(normalizedIntensity: normalizedIntensity)
    }
  }

  func prepareEditHero(from sourceCenter: CGPoint, sourceDotSize: CGFloat) {
    layoutIfNeeded()
    let targetDotSize = actualDotSize
    guard targetDotSize > 0 else { return }

    let destinationCenter = CGPoint(x: bounds.midX, y: bounds.midY)
    let movement = CGPoint(
      x: destinationCenter.x - sourceCenter.x,
      y: destinationCenter.y - sourceCenter.y
    )
    let movementLength = hypot(movement.x, movement.y)
    let direction = movementLength > 0.001
      ? CGPoint(x: movement.x / movementLength, y: movement.y / movementLength)
      : CGPoint(x: 1, y: 0)
    let centers = digitViews.flatMap { $0.activeDotCenters(in: self) }
    let projections = centers.map { $0.x * direction.x + $0.y * direction.y }
    guard let minimumProjection = projections.min(),
        let maximumProjection = projections.max() else { return }

    let sourceScale = sourceDotSize / targetDotSize
    for digitView in digitViews {
      digitView.prepareEditHero(
        in: self,
        sourceCenter: sourceCenter,
        destinationCenter: destinationCenter,
        sourceScale: sourceScale
      )
    }
    editHeroDirection = direction
    editHeroProjectionRange = minimumProjection...maximumProjection
  }

  func animateEditHeroToFinal() {
    guard let editHeroDirection,
        let editHeroProjectionRange else { return }
    for digitView in digitViews {
      digitView.animateEditHero(
        in: self,
        direction: editHeroDirection,
        minimumProjection: editHeroProjectionRange.lowerBound,
        maximumProjection: editHeroProjectionRange.upperBound
      )
    }
    self.editHeroDirection = nil
    self.editHeroProjectionRange = nil
  }

  func animateEditHeroToSource(
    at sourceCenter: CGPoint,
    sourceDotSize: CGFloat
  ) {
    layoutIfNeeded()
    let editorDotSize = actualDotSize
    guard editorDotSize > 0 else { return }

    let editorCenter = CGPoint(x: bounds.midX, y: bounds.midY)
    let movement = CGPoint(
      x: sourceCenter.x - editorCenter.x,
      y: sourceCenter.y - editorCenter.y
    )
    let movementLength = hypot(movement.x, movement.y)
    let direction = movementLength > 0.001
      ? CGPoint(x: movement.x / movementLength, y: movement.y / movementLength)
      : CGPoint(x: 1, y: 0)
    let centers = digitViews.flatMap { $0.activeDotCenters(in: self) }
    let projections = centers.map { $0.x * direction.x + $0.y * direction.y }
    guard let minimumProjection = projections.min(),
        let maximumProjection = projections.max() else { return }

    let sourceScale = sourceDotSize / editorDotSize
    for digitView in digitViews {
      digitView.animateEditHeroToSource(
        in: self,
        sourceCenter: sourceCenter,
        editorCenter: editorCenter,
        sourceScale: sourceScale,
        direction: direction,
        minimumProjection: minimumProjection,
        maximumProjection: maximumProjection
      )
    }
    editHeroDirection = nil
    editHeroProjectionRange = nil
  }

  func finishEditHero() {
    for digitView in digitViews {
      digitView.finishEditHero()
    }
    editHeroDirection = nil
    editHeroProjectionRange = nil
  }

  var actualDotSize: CGFloat {
    let digits = Self.digitValues(for: number)
    return computeDotSize(digitCount: digits.count)
  }

  /// Bounding box of the rendered number within this view's bounds (digits are
  /// centered on both axes). Computed from the same layout math as
  /// `buildDigitViews`, so it's valid even before the digit subviews lay out —
  /// callers (e.g. the cell's ± icons) can position against it during layout.
  var numberContentRect: CGRect {
    guard bounds.width > 0 && bounds.height > 0 else { return .zero }
    let digits = Self.digitValues(for: number)
    let dotSz = computeDotSize(digitCount: digits.count)
    let spc = dotSz * Self.spacingRatio
    let digitGap = dotSz * Self.digitGapRatio
    let digitW = CGFloat(DotPatterns.columns) * dotSz + CGFloat(DotPatterns.columns - 1) * spc
    let digitH = CGFloat(DotPatterns.rows) * dotSz + CGFloat(DotPatterns.rows - 1) * spc
    let totalW = CGFloat(digits.count) * digitW + CGFloat(digits.count - 1) * digitGap
    let x = (bounds.width - totalW) / 2
    let y = (bounds.height - digitH) / 2
    return CGRect(x: x, y: y, width: totalW, height: digitH)
  }

  private func computeDotSize(digitCount: Int) -> CGFloat {
    let count = CGFloat(digitCount)
    let cols = count * CGFloat(DotPatterns.columns)
      + count * CGFloat(DotPatterns.columns - 1) * Self.spacingRatio
      + (count - 1) * Self.digitGapRatio
    let rows = CGFloat(DotPatterns.rows)
      + CGFloat(DotPatterns.rows - 1) * Self.spacingRatio
    return min(bounds.width / cols, bounds.height / rows, maxDotSize ?? .infinity)
  }

  func applySweep(
    in reference: UIView,
    axisIsHorizontal: Bool,
    leadingEdge: CGFloat,
    direction: CGFloat,
    feather: CGFloat
  ) {
    for dv in digitViews {
      dv.applySweep(
        in: reference,
        axisIsHorizontal: axisIsHorizontal,
        leadingEdge: leadingEdge,
        direction: direction,
        feather: feather
      )
    }
  }

  func resetSweep(animated: Bool) {
    for dv in digitViews {
      dv.resetSweep(animated: animated)
    }
  }

  func applyClockwiseBeam(
    in reference: UIView,
    origin: CGPoint,
    from startAngle: CGFloat,
    to endAngle: CGFloat,
    beamHalfWidth: CGFloat,
    dimAlpha: CGFloat,
    dimScale: CGFloat,
    peakScale: CGFloat
  ) {
    for digitView in digitViews {
      digitView.applyClockwiseBeam(
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
  }

  func setFirstPlayerEmphasis(
    alpha: CGFloat,
    scale: CGFloat,
    animated: Bool,
    duration: TimeInterval,
    usesSpring: Bool = true
  ) {
    for digitView in digitViews {
      digitView.setFirstPlayerEmphasis(
        alpha: alpha,
        scale: scale,
        animated: animated,
        duration: duration,
        usesSpring: usesSpring
      )
    }
  }

  func snapToOff() {
    for dv in digitViews {
      dv.snapToOff()
    }
  }

  func animateRippleOut(
    in reference: UIView,
    origin: CGPoint,
    maximumDistance: CGFloat,
    reversed: Bool
  ) {
    for digitView in digitViews {
      digitView.animateRippleOut(
        in: reference,
        origin: origin,
        maximumDistance: maximumDistance,
        reversed: reversed
      )
    }
  }

  func animateRippleIn(
    in reference: UIView,
    origin: CGPoint,
    maximumDistance: CGFloat,
    reversed: Bool
  ) {
    for digitView in digitViews {
      digitView.animateRippleIn(
        in: reference,
        origin: origin,
        maximumDistance: maximumDistance,
        reversed: reversed
      )
    }
  }

  static func digitValues(for number: Int) -> [Int] {
    if number == 0 { return [0] }
    var n = abs(number)
    var result: [Int] = []
    while n > 0 {
      result.insert(n % 10, at: 0)
      n /= 10
    }
    if number < 0 {
      result.insert(-1, at: 0)
    }
    return result
  }
}
