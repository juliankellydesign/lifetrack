import UIKit

class DotDigitView: UIView {
  private var dotViews: [UIView] = []
  private var font = DotFontSettings.current
  /// One stable random phase per dot. It is regenerated only when the digit
  /// grid is rebuilt, avoiding frame-to-frame flicker and runtime noise work.
  private var dotTimingNoise: [CGFloat] = []
  private var currentDigit: Int?
  private var seatColors: [SeatColor] = [.colorless]
  private var colorSeed = 0

  static let animationDuration: TimeInterval = 0.3
  static let rippleWaveDuration: TimeInterval = 0.32
  /// Stable jitter is always 15% of the effect's own phase or delay span, so
  /// noise has consistent visual weight across different animation systems.
  private static let animationNoiseFraction: CGFloat = 0.15
  private static let editHeroDuration: TimeInterval = 0.48
  private static let editHeroMaximumDelay: TimeInterval = 0.16
  static let editHeroTotalDuration =
    editHeroDuration + editHeroMaximumDelay
  private static let keypadDissolveDuration: TimeInterval = 0.22
  private static let keypadDissolveMaximumDelay: TimeInterval = 0.07
  private static let keypadDissolveOutDuration: TimeInterval = 0.3

  /// Dot corner radius as a fraction of dot size, so roundness stays constant
  /// as dots scale (board at 18pt vs. the larger life-input overlay dots).
  /// Tuned to match the original 8pt radius at the 18pt board dot size.
  private static let cornerRadiusRatio: CGFloat = 8.0 / 18.0

  static func cornerRadius(forDotSize dotSize: CGFloat) -> CGFloat {
    dotSize * cornerRadiusRatio
  }

  func configure(font: DotFont, dotSize: CGFloat, spacing: CGFloat) {
    self.font = font
    dotViews.forEach { $0.removeFromSuperview() }
    dotViews.removeAll()
    dotTimingNoise.removeAll()
    currentDigit = nil

    let step = dotSize + spacing
    for i in 0..<(font.rows * font.columns) {
      let row = i / font.columns
      let col = i % font.columns

      let dot = UIView(frame: CGRect(
        x: CGFloat(col) * step,
        y: CGFloat(row) * step,
        width: dotSize,
        height: dotSize
      ))
      dot.backgroundColor = .white
      dot.layer.cornerRadius = Self.cornerRadius(forDotSize: dotSize)
      dot.layer.cornerCurve = .continuous
      dot.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
      dot.alpha = 0
      addSubview(dot)
      dotViews.append(dot)
      dotTimingNoise.append(CGFloat.random(in: -1...1))
    }

    let totalW = CGFloat(font.columns) * dotSize
      + CGFloat(font.columns - 1) * spacing
    let totalH = CGFloat(font.rows) * dotSize
      + CGFloat(font.rows - 1) * spacing
    bounds.size = CGSize(width: totalW, height: totalH)
  }

  func setSeatColors(_ colors: [SeatColor], seed: Int, animated: Bool) {
    seatColors = colors.isEmpty ? [.colorless] : colors
    colorSeed = seed
    let selectedColorSet = Set(seatColors)

    for (index, dot) in dotViews.enumerated() {
      let mixedSeed = stableColorSeed(for: index)
      let unsignedSeed = UInt(bitPattern: mixedSeed)
      let paletteIndex = Int(
        unsignedSeed % UInt(seatColors.count)
      )
      let targetColor: UIColor
      if seatColors.count > 1 {
        let secondaryOffset = 1 + Int(
          (unsignedSeed >> 8) % UInt(seatColors.count - 1)
        )
        let secondaryIndex = (paletteIndex + secondaryOffset) % seatColors.count
        let blendUnit = CGFloat((unsignedSeed >> 16) & 0xFFFF)
          / CGFloat(0xFFFF)
        let blendAmount = 0.10 + blendUnit * 0.35
        targetColor = seatColors[paletteIndex].interpolatedColor(
          toward: seatColors[secondaryIndex],
          selectedColors: selectedColorSet,
          seed: mixedSeed,
          amount: blendAmount
        )
      } else {
        targetColor = seatColors[paletteIndex].variedColor(seed: mixedSeed)
      }
      if animated {
        let delay = TimeInterval(abs(mixedSeed % 7)) * 0.008
        UIView.animate(
          withDuration: 0.28,
          delay: delay,
          options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut]
        ) {
          dot.backgroundColor = targetColor
        }
      } else {
        dot.backgroundColor = targetColor
      }
    }
  }

  private func stableColorSeed(for dotIndex: Int) -> Int {
    var value = UInt64(bitPattern: Int64(colorSeed &+ dotIndex &* 9_173))
    value &+= 0x9E3779B97F4A7C15
    value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
    value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
    value ^= value >> 31
    return Int(truncatingIfNeeded: value)
  }

  /// Animated changes — including rapid taps — play the staggered spring roll.
  /// The springs use `.beginFromCurrentState`, so a tap landing mid-roll just
  /// retargets the dots toward the latest digit from wherever they are, keeping
  /// the roll alive without trailing behind.
  func setDigit(_ digit: Int, direction: ChangeDirection?, animated: Bool) {
    let pattern = font.pattern(for: digit)
    // If the font changed since `configure`, our dot views are stale (wrong
    // count). Bail — a relayout will rebuild and repaint at the new size.
    guard pattern.count == dotViews.count,
        dotTimingNoise.count == dotViews.count else { return }
    let oldPattern: [Bool]? = currentDigit.map { font.pattern(for: $0) }
    currentDigit = digit

    // Snap straight to the digit (no spring) only for non-animated sets, e.g.
    // a relayout that just needs to paint the current value.
    if !animated {
      for (i, dot) in dotViews.enumerated() {
        dot.layer.removeAllAnimations()
        let active = pattern[i]
        dot.transform = active ? .identity : CGAffineTransform(scaleX: 0.01, y: 0.01)
        dot.alpha = active ? 1 : 0
      }
      return
    }

    // Play the staggered spring roll, animating only the dots that change.
    for i in 0..<dotViews.count {
      let isActive = pattern[i]
      let wasActive = oldPattern?[i] ?? false

      if oldPattern != nil && wasActive == isActive { continue }

      let row = i / font.columns
      let delay = direction?.delay(forRow: row, rowCount: font.rows) ?? 0
      let scale: CGAffineTransform = isActive ? .identity : CGAffineTransform(scaleX: 0.01, y: 0.01)
      let alpha: CGFloat = isActive ? 1.0 : 0.0

      UIView.animate(withDuration: Self.animationDuration, delay: delay, usingSpringWithDamping: 0.7,
               initialSpringVelocity: 0, options: .beginFromCurrentState) {
        self.dotViews[i].transform = scale
        self.dotViews[i].alpha = alpha
      }
    }
  }

  /// Seed a rebuilt, retained keypad digit from the exact visual state of its
  /// predecessor. This keeps rapid typing continuous even when the previous
  /// digit is still finishing its own dissolve.
  func prepareKeypadRetainedAppearance(from source: DotDigitView) {
    guard dotViews.count == source.dotViews.count else { return }
    for index in dotViews.indices {
      let sourceLayer = source.dotViews[index].layer.presentation()
        ?? source.dotViews[index].layer
      let alpha = CGFloat(sourceLayer.opacity)
      let scale = (sourceLayer.value(forKeyPath: "transform.scale.x") as? NSNumber)
        .map { CGFloat(truncating: $0) }
        ?? 1
      dotViews[index].layer.removeAllAnimations()
      dotViews[index].alpha = alpha
      dotViews[index].transform = CGAffineTransform(scaleX: scale, y: scale)
    }
  }

  /// Hide the active dots before a keypad digit appears. The paired animation
  /// uses the same coupled opacity/scale profile as the app's other dot reveals.
  func prepareKeypadDissolveIn() {
    guard let currentDigit else { return }
    let pattern = font.pattern(for: currentDigit)
    guard pattern.count == dotViews.count else { return }
    for index in dotViews.indices where pattern[index] {
      dotViews[index].layer.removeAllAnimations()
      dotViews[index].alpha = 0
      dotViews[index].transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
    }
  }

  func animateKeypadDissolveIn() {
    animateKeypadDissolve(appearing: true)
  }

  func animateKeypadDissolveOut(completion: @escaping () -> Void) {
    guard let currentDigit else {
      completion()
      return
    }
    let pattern = font.pattern(for: currentDigit)
    guard pattern.count == dotViews.count,
      dotTimingNoise.count == dotViews.count else {
      completion()
      return
    }

    for index in dotViews.indices where pattern[index] {
      let dot = dotViews[index]
      let presentation = dot.layer.presentation() ?? dot.layer
      let fromOpacity = presentation.opacity
      let fromScale = presentation.value(forKeyPath: "transform.scale.x")
        as? NSNumber ?? 1
      let unitNoise = (dotTimingNoise[index] + 1) / 2
      let delay = TimeInterval(unitNoise) * Self.keypadDissolveMaximumDelay

      CATransaction.begin()
      CATransaction.setDisableActions(true)
      dot.alpha = 0
      dot.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
      CATransaction.commit()

      let opacity = CABasicAnimation(keyPath: "opacity")
      opacity.fromValue = fromOpacity
      opacity.toValue = 0
      let scale = CABasicAnimation(keyPath: "transform.scale")
      scale.fromValue = fromScale
      scale.toValue = 0.01
      let group = CAAnimationGroup()
      group.animations = [opacity, scale]
      group.duration = Self.keypadDissolveOutDuration
      group.beginTime = dot.layer.convertTime(CACurrentMediaTime(), from: nil) + delay
      group.fillMode = .backwards
      group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      dot.layer.add(group, forKey: "keypad-dissolve-out")
    }

    DispatchQueue.main.asyncAfter(
      deadline: .now()
        + Self.keypadDissolveOutDuration
        + Self.keypadDissolveMaximumDelay
    ) {
      completion()
    }
  }

  private func animateKeypadDissolve(appearing: Bool) {
    guard let currentDigit else { return }
    let pattern = font.pattern(for: currentDigit)
    guard pattern.count == dotViews.count,
      dotTimingNoise.count == dotViews.count else { return }

    for index in dotViews.indices where pattern[index] {
      let unitNoise = (dotTimingNoise[index] + 1) / 2
      let delay = TimeInterval(unitNoise) * Self.keypadDissolveMaximumDelay
      UIView.animate(
        withDuration: Self.keypadDissolveDuration,
        delay: delay,
        options: [
          .beginFromCurrentState,
          .allowUserInteraction,
          .curveEaseInOut
        ]
      ) {
        self.dotViews[index].alpha = appearing ? 1 : 0
        let scale: CGFloat = appearing ? 1 : 0.01
        self.dotViews[index].transform = CGAffineTransform(
          scaleX: scale,
          y: scale
        )
      }
    }
  }

  var contentWidth: CGFloat { bounds.width }
  var contentHeight: CGFloat { bounds.height }

  func activeDotCenters(in reference: UIView) -> [CGPoint] {
    guard let digit = currentDigit else { return [] }
    let pattern = font.pattern(for: digit)
    guard pattern.count == dotViews.count else { return [] }

    return dotViews.enumerated().compactMap { index, dot in
      guard pattern[index] else { return nil }
      return reference.convert(dot.center, from: self)
    }
  }

  /// Place each active dot where the smaller source pattern painted it while
  /// keeping the final editor layout as the model geometry.
  func prepareEditHero(
    in reference: UIView,
    sourceCenter: CGPoint,
    destinationCenter: CGPoint,
    sourceScale: CGFloat
  ) {
    guard let digit = currentDigit else { return }
    let pattern = font.pattern(for: digit)
    guard pattern.count == dotViews.count else { return }

    for (index, dot) in dotViews.enumerated() {
      dot.layer.removeAllAnimations()
      guard pattern[index] else {
        dot.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        dot.alpha = 0
        continue
      }

      let destination = reference.convert(dot.center, from: self)
      let source = CGPoint(
        x: sourceCenter.x
          + (destination.x - destinationCenter.x) * sourceScale,
        y: sourceCenter.y
          + (destination.y - destinationCenter.y) * sourceScale
      )
      dot.transform = CGAffineTransform(
        a: sourceScale,
        b: 0,
        c: 0,
        d: sourceScale,
        tx: source.x - destination.x,
        ty: source.y - destination.y
      )
      dot.alpha = 1
    }
  }

  /// Pull the leading edge toward the editor first, then let the remaining dots
  /// follow like a stretched slinky. Stable per-dot noise loosens the wave
  /// without changing its direction.
  func animateEditHero(
    in reference: UIView,
    direction: CGPoint,
    minimumProjection: CGFloat,
    maximumProjection: CGFloat
  ) {
    guard let digit = currentDigit else { return }
    let pattern = font.pattern(for: digit)
    guard pattern.count == dotViews.count,
        dotTimingNoise.count == dotViews.count else { return }
    let projectionSpan = max(0.001, maximumProjection - minimumProjection)

    for (index, dot) in dotViews.enumerated() where pattern[index] {
      let center = reference.convert(dot.center, from: self)
      let delay = editHeroDelay(
        for: center,
        direction: direction,
        projectionSpan: projectionSpan,
        maximumProjection: maximumProjection,
        timingNoise: dotTimingNoise[index]
      )

      UIView.animate(
        withDuration: Self.editHeroDuration,
        delay: delay,
        usingSpringWithDamping: 0.72,
        initialSpringVelocity: 0,
        options: [.beginFromCurrentState, .allowUserInteraction]
      ) {
        dot.transform = .identity
        dot.alpha = 1
      }
    }
  }

  /// Reverse the same slinky wave toward the smaller board pattern. Because
  /// `direction` points back toward the source, the projection ordering flips
  /// naturally: the dots nearest that direction leave first.
  func animateEditHeroToSource(
    in reference: UIView,
    sourceCenter: CGPoint,
    editorCenter: CGPoint,
    sourceScale: CGFloat,
    direction: CGPoint,
    minimumProjection: CGFloat,
    maximumProjection: CGFloat
  ) {
    guard let digit = currentDigit else { return }
    let pattern = font.pattern(for: digit)
    guard pattern.count == dotViews.count,
        dotTimingNoise.count == dotViews.count else { return }
    let projectionSpan = max(0.001, maximumProjection - minimumProjection)

    for (index, dot) in dotViews.enumerated() where pattern[index] {
      let editorPosition = reference.convert(dot.center, from: self)
      let sourcePosition = CGPoint(
        x: sourceCenter.x
          + (editorPosition.x - editorCenter.x) * sourceScale,
        y: sourceCenter.y
          + (editorPosition.y - editorCenter.y) * sourceScale
      )
      let delay = editHeroDelay(
        for: editorPosition,
        direction: direction,
        projectionSpan: projectionSpan,
        maximumProjection: maximumProjection,
        timingNoise: dotTimingNoise[index]
      )
      let targetTransform = CGAffineTransform(
        a: sourceScale,
        b: 0,
        c: 0,
        d: sourceScale,
        tx: sourcePosition.x - editorPosition.x,
        ty: sourcePosition.y - editorPosition.y
      )

      UIView.animate(
        withDuration: Self.editHeroDuration,
        delay: delay,
        usingSpringWithDamping: 0.72,
        initialSpringVelocity: 0,
        options: [.beginFromCurrentState, .allowUserInteraction]
      ) {
        dot.transform = targetTransform
        dot.alpha = 1
      }
    }
  }

  private func editHeroDelay(
    for center: CGPoint,
    direction: CGPoint,
    projectionSpan: CGFloat,
    maximumProjection: CGFloat,
    timingNoise: CGFloat
  ) -> TimeInterval {
    let projection = center.x * direction.x + center.y * direction.y
    let trailingFraction = (maximumProjection - projection) / projectionSpan
    let timingNoiseRange =
      Self.editHeroMaximumDelay * TimeInterval(Self.animationNoiseFraction)
    let noisyDelay =
      TimeInterval(trailingFraction) * Self.editHeroMaximumDelay
      + TimeInterval(timingNoise) * timingNoiseRange
    return max(0, min(Self.editHeroMaximumDelay, noisyDelay))
  }

  func finishEditHero() {
    dotViews.forEach { $0.layer.removeAllAnimations() }
    resetSweep(animated: false)
  }

  /// Apply an additive, spring-shaped shake to each visible dot independently.
  /// A nil animation key allows repeated calls to coexist on the render server,
  /// so rapid life changes physically stack instead of replacing one another.
  func shake(normalizedIntensity: CGFloat) {
    guard !UIAccessibility.isReduceMotionEnabled,
        let digit = currentDigit else { return }
    let pattern = font.pattern(for: digit)
    guard pattern.count == dotViews.count else { return }

    let intensity = max(0, min(1, normalizedIntensity))
    let dotSize = dotViews.first?.bounds.width ?? 18
    let amplitude = dotSize * (0.035 + intensity * 0.28)
    let envelopes: [CGFloat] = [0, 1, -0.72, 0.48, -0.29, 0.14, 0]
    let keyTimes = [0, 0.13, 0.3, 0.48, 0.66, 0.83, 1]
      .map(NSNumber.init(value:))

    func makeShakeAnimation(
      amplitude: CGFloat,
      maximumDelay: TimeInterval
    ) -> CAKeyframeAnimation {
      let baseAngle = CGFloat.random(in: 0..<(CGFloat.pi * 2))
      let offsets = envelopes.enumerated().map { step, envelope in
        let angleJitter = CGFloat(step) * CGFloat.random(in: -0.16...0.16)
        let angle = baseAngle + angleJitter
        let distance = amplitude * envelope
        return NSValue(cgPoint: CGPoint(
          x: cos(angle) * distance,
          y: sin(angle) * distance
        ))
      }

      let animation = CAKeyframeAnimation(keyPath: "position")
      animation.values = offsets
      animation.keyTimes = keyTimes
      animation.duration = 0.36 + TimeInterval(intensity) * 0.14
      animation.beginTime =
        CACurrentMediaTime() + TimeInterval.random(in: 0...maximumDelay)
      animation.timingFunctions = Array(
        repeating: CAMediaTimingFunction(name: .easeInEaseOut),
        count: offsets.count - 1
      )
      animation.isAdditive = true
      animation.isRemovedOnCompletion = true
      return animation
    }

    // A quieter coherent motion underneath the independent dots gives each
    // digit a little shared weight without turning the number into a rigid
    // block. This animation also uses a nil key, so repeated taps stack.
    layer.add(
      makeShakeAnimation(amplitude: amplitude * 0.5, maximumDelay: 0.008),
      forKey: nil
    )

    for (index, dot) in dotViews.enumerated() where pattern[index] {
      dot.layer.add(
        makeShakeAnimation(amplitude: amplitude, maximumDelay: 0.018),
        forKey: nil
      )
    }
  }

  /// Send a directional shake across this digit from an external control.
  /// Position animations are additive, so repeated taps can overlap without
  /// moving the model-layer geometry or fighting the digit-roll transforms.
  func rippleShake(
    normalizedIntensity: CGFloat,
    in reference: UIView,
    origin: CGPoint,
    maximumDistance: CGFloat
  ) {
    guard !UIAccessibility.isReduceMotionEnabled,
        let digit = currentDigit else { return }
    let pattern = font.pattern(for: digit)
    guard pattern.count == dotViews.count,
        dotTimingNoise.count == dotViews.count else { return }

    let intensity = max(0, min(1, normalizedIntensity))
    let dotSize = dotViews.first?.bounds.width ?? 18
    // Keep the organic ±1 shake restrained while giving the button-origin
    // pressure wave enough travel to read as an outward displacement.
    let displacementAmplitude = dotSize * (0.15 + intensity * 0.32)
    let waveDuration: TimeInterval = 0.12

    for (index, dot) in dotViews.enumerated() where pattern[index] {
      let center = reference.convert(
        CGPoint(x: dot.bounds.midX, y: dot.bounds.midY),
        from: dot
      )
      let localOrigin = convert(origin, from: reference)
      let distance = hypot(center.x - origin.x, center.y - origin.y)
      let delayFraction = maximumDistance > 0
        ? min(1, distance / maximumDistance)
        : 0
      let delay = max(
        0,
        TimeInterval(delayFraction) * waveDuration
          + TimeInterval(dotTimingNoise[index])
          * waveDuration
          * TimeInterval(Self.animationNoiseFraction)
      )
      let direction = unitDirection(
        from: localOrigin,
        to: dot.center,
        fallbackPhase: dotTimingNoise[index]
      )
      let jitteredAmplitude = displacementAmplitude
        * (1 + dotTimingNoise[index] * Self.animationNoiseFraction)
      dot.layer.add(
        directionalPositionAnimation(
          direction: direction,
          amplitude: jitteredAmplitude,
          duration: 0.34 + TimeInterval(intensity) * 0.12,
          delay: delay,
          organicPhase: dotTimingNoise[index]
        ),
        forKey: nil
      )
    }
  }

  /// Apply a positional sweep fade. For each dot, we compute how far past
  /// the swipe's leading edge it sits, in `reference` coordinates, then
  /// linearly interpolate from its natural state (alpha 1 / scale 1 if
  /// active) to the "off" state (alpha 0 / scale 0.01) over `feather` pts.
  func applySweep(
    in reference: UIView,
    axisIsHorizontal: Bool,
    leadingEdge: CGFloat,
    direction: CGFloat,
    feather: CGFloat
  ) {
    guard let digit = currentDigit else { return }
    let pattern = font.pattern(for: digit)
    guard pattern.count == dotViews.count,
        dotTimingNoise.count == dotViews.count else { return }
    for (i, dot) in dotViews.enumerated() {
      let p = reference.convert(
        CGPoint(x: dot.bounds.midX, y: dot.bounds.midY),
        from: dot
      )
      let pos = axisIsHorizontal ? p.x : p.y
      let signed = (leadingEdge - pos) * direction
      let progress = max(0, min(1, signed / feather))

      let active = pattern[i]
      let baseScale: CGFloat = active ? 1 : 0.01
      let scale = baseScale + (0.01 - baseScale) * progress
      let alpha: CGFloat = (active ? 1 : 0) * (1 - progress)
      dot.transform = CGAffineTransform(scaleX: scale, y: scale)
      dot.alpha = alpha
    }
  }

  /// Illuminate active dots with a soft clockwise beam. The beam widens by the
  /// angle traveled during this display frame, creating motion blur that keeps
  /// dots from being skipped as the sweep accelerates. A quintic falloff keeps
  /// both sides smooth while driving opacity and scale from the same intensity.
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
    guard let digit = currentDigit else { return }
    let pattern = font.pattern(for: digit)
    guard pattern.count == dotViews.count,
        dotTimingNoise.count == dotViews.count else { return }
    let fullTurn = CGFloat.pi * 2

    for (i, dot) in dotViews.enumerated() {
      guard pattern[i] else {
        dot.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        dot.alpha = 0
        continue
      }

      let center = reference.convert(
        CGPoint(x: dot.bounds.midX, y: dot.bounds.midY),
        from: dot
      )
      var dotAngle = atan2(center.y - origin.y, center.x - origin.x)
      dotAngle +=
        dotTimingNoise[i] * beamHalfWidth * Self.animationNoiseFraction
      if dotAngle < 0 {
        dotAngle += fullTurn
      } else if dotAngle >= fullTurn {
        dotAngle -= fullTurn
      }

      let traveledAngle = max(0, endAngle - startAngle)
      let beamCenter = (startAngle + endAngle) / 2
      let unwrappedDotAngle =
        dotAngle + round((beamCenter - dotAngle) / fullTurn) * fullTurn
      let angularDistance = abs(unwrappedDotAngle - beamCenter)
      let effectiveHalfWidth = beamHalfWidth + traveledAngle
      let proximity = max(0, 1 - angularDistance / effectiveHalfWidth)
      let intensity =
        proximity * proximity * proximity
        * (proximity * (proximity * 6 - 15) + 10)
      let alpha = dimAlpha + (1 - dimAlpha) * intensity
      let scale = dimScale + (peakScale - dimScale) * intensity

      dot.transform = CGAffineTransform(scaleX: scale, y: scale)
      dot.alpha = alpha
    }
  }

  /// Apply a uniform first-player emphasis to each active dot. This is kept at
  /// dot level so landing and touch-to-reveal can retarget an in-flight beam
  /// without briefly flashing the number as one rectangular view.
  func setFirstPlayerEmphasis(
    alpha: CGFloat,
    scale: CGFloat,
    animated: Bool,
    duration: TimeInterval,
    usesSpring: Bool = true
  ) {
    guard let digit = currentDigit else { return }
    let pattern = font.pattern(for: digit)
    guard pattern.count == dotViews.count else { return }

    for (i, dot) in dotViews.enumerated() {
      let isActive = pattern[i]
      let targetAlpha: CGFloat = isActive ? alpha : 0
      let targetScale = isActive ? scale : 0.01
      let changes = {
        dot.transform = CGAffineTransform(
          scaleX: targetScale,
          y: targetScale
        )
        dot.alpha = targetAlpha
      }

      if animated {
        if usesSpring {
          UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: changes
          )
        } else {
          UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [
              .beginFromCurrentState,
              .allowUserInteraction,
              .curveEaseInOut
            ],
            animations: changes
          )
        }
      } else {
        dot.layer.removeAllAnimations()
        changes()
      }
    }
  }

  /// Snap every dot to the off state (scale 0.01, alpha 0). Pair with
  /// `resetSweep(animated: true)` to play a digit roll-in from blank.
  func snapToOff() {
    for dot in dotViews {
      dot.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
      dot.alpha = 0
    }
  }

  func animateRippleOut(
    in reference: UIView,
    origin: CGPoint,
    maximumDistance: CGFloat,
    reversed: Bool
  ) {
    guard let digit = currentDigit else { return }
    let pattern = font.pattern(for: digit)
    guard pattern.count == dotViews.count,
        dotTimingNoise.count == dotViews.count else { return }

    for (i, dot) in dotViews.enumerated() where pattern[i] {
      let delay = rippleDelay(
        for: dot,
        in: reference,
        origin: origin,
        maximumDistance: maximumDistance,
        reversed: reversed,
        timingNoise: dotTimingNoise[i]
      )
      addRippleDisplacement(
        to: dot,
        in: reference,
        origin: origin,
        delay: delay,
        reversed: reversed,
        timingNoise: dotTimingNoise[i]
      )
      UIView.animate(
        withDuration: Self.animationDuration,
        delay: delay,
        usingSpringWithDamping: 0.7,
        initialSpringVelocity: 0,
        options: .beginFromCurrentState
      ) {
        dot.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        dot.alpha = 0
      }
    }
  }

  func animateRippleIn(
    in reference: UIView,
    origin: CGPoint,
    maximumDistance: CGFloat,
    reversed: Bool
  ) {
    guard let digit = currentDigit else { return }
    let pattern = font.pattern(for: digit)
    guard pattern.count == dotViews.count,
        dotTimingNoise.count == dotViews.count else { return }

    for (i, dot) in dotViews.enumerated() where pattern[i] {
      let delay = rippleDelay(
        for: dot,
        in: reference,
        origin: origin,
        maximumDistance: maximumDistance,
        reversed: reversed,
        timingNoise: dotTimingNoise[i]
      )
      addRippleDisplacement(
        to: dot,
        in: reference,
        origin: origin,
        delay: delay,
        reversed: reversed,
        timingNoise: dotTimingNoise[i]
      )
      UIView.animate(
        withDuration: Self.animationDuration,
        delay: delay,
        usingSpringWithDamping: 0.7,
        initialSpringVelocity: 0,
        options: .beginFromCurrentState
      ) {
        dot.transform = .identity
        dot.alpha = 1
      }
    }
  }

  private func rippleDelay(
    for dot: UIView,
    in reference: UIView,
    origin: CGPoint,
    maximumDistance: CGFloat,
    reversed: Bool,
    timingNoise: CGFloat
  ) -> TimeInterval {
    let center = reference.convert(
      CGPoint(x: dot.bounds.midX, y: dot.bounds.midY),
      from: dot
    )
    let distance = hypot(center.x - origin.x, center.y - origin.y)
    let fraction = maximumDistance > 0 ? min(1, distance / maximumDistance) : 0
    let delayFraction = reversed ? 1 - fraction : fraction
    let baseDelay = TimeInterval(delayFraction) * Self.rippleWaveDuration
    return max(
      0,
      min(
        Self.rippleWaveDuration,
        baseDelay
          + TimeInterval(timingNoise)
          * Self.rippleWaveDuration
          * TimeInterval(Self.animationNoiseFraction)
      )
    )
  }

  private func addRippleDisplacement(
    to dot: UIView,
    in reference: UIView,
    origin: CGPoint,
    delay: TimeInterval,
    reversed: Bool,
    timingNoise: CGFloat
  ) {
    guard !UIAccessibility.isReduceMotionEnabled else { return }
    let localOrigin = convert(origin, from: reference)
    let outwardDirection = unitDirection(
      from: localOrigin,
      to: dot.center,
      fallbackPhase: timingNoise
    )
    let direction = reversed
      ? CGPoint(x: -outwardDirection.x, y: -outwardDirection.y)
      : outwardDirection
    dot.layer.add(
      directionalPositionAnimation(
        direction: direction,
        amplitude: dot.bounds.width * 0.65,
        duration: Self.animationDuration + 0.12,
        delay: delay,
        organicPhase: timingNoise
      ),
      forKey: nil
    )
  }

  private func unitDirection(
    from origin: CGPoint,
    to destination: CGPoint,
    fallbackPhase: CGFloat
  ) -> CGPoint {
    let dx = destination.x - origin.x
    let dy = destination.y - origin.y
    let distance = hypot(dx, dy)
    guard distance > 0.001 else {
      let angle = (fallbackPhase + 1) * .pi
      return CGPoint(x: cos(angle), y: sin(angle))
    }
    return CGPoint(x: dx / distance, y: dy / distance)
  }

  private func directionalPositionAnimation(
    direction: CGPoint,
    amplitude: CGFloat,
    duration: TimeInterval,
    delay: TimeInterval,
    organicPhase: CGFloat
  ) -> CAKeyframeAnimation {
    let perpendicular = CGPoint(x: -direction.y, y: direction.x)
    let sideMotion = organicPhase * amplitude * 0.12
    let envelopes: [CGFloat] = [0, 0.2, 1, 0.42, -0.12, 0]
    let sideEnvelopes: [CGFloat] = [0, 0.35, 1, -0.45, 0.2, 0]
    var offsets: [NSValue] = []
    for index in envelopes.indices {
      let radialDistance = amplitude * envelopes[index]
      let sideDistance = sideMotion * sideEnvelopes[index]
      let x = direction.x * radialDistance
        + perpendicular.x * sideDistance
      let y = direction.y * radialDistance
        + perpendicular.y * sideDistance
      offsets.append(NSValue(cgPoint: CGPoint(x: x, y: y)))
    }

    let animation = CAKeyframeAnimation(keyPath: "position")
    animation.values = offsets
    animation.keyTimes = [0, 0.1, 0.28, 0.52, 0.76, 1]
      .map(NSNumber.init(value:))
    animation.duration = duration
    animation.beginTime = CACurrentMediaTime() + delay
    animation.timingFunctions = Array(
      repeating: CAMediaTimingFunction(name: .easeInEaseOut),
      count: offsets.count - 1
    )
    animation.isAdditive = true
    animation.isRemovedOnCompletion = true
    return animation
  }

  /// Restore dots to their natural state for the current digit. Forces every
  /// dot back (unlike `setDigit`, which skips dots whose pattern is unchanged).
  func resetSweep(animated: Bool) {
    guard let digit = currentDigit else { return }
    let pattern = font.pattern(for: digit)
    guard pattern.count == dotViews.count else { return }
    for (i, dot) in dotViews.enumerated() {
      let active = pattern[i]
      let scale: CGAffineTransform = active ? .identity : CGAffineTransform(scaleX: 0.01, y: 0.01)
      let alpha: CGFloat = active ? 1 : 0
      if animated {
        let row = i / font.columns
        let delay = ChangeDirection.increasing.delay(
          forRow: row,
          rowCount: font.rows
        )
        UIView.animate(withDuration: 0.3, delay: delay,
                 usingSpringWithDamping: 0.7, initialSpringVelocity: 0,
                 options: .beginFromCurrentState) {
          dot.transform = scale
          dot.alpha = alpha
        }
      } else {
        dot.transform = scale
        dot.alpha = alpha
      }
    }
  }
}
