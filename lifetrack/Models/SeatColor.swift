import UIKit

enum SeatColor: String, CaseIterable, Hashable {
  case colorless
  case white
  case blue
  case black
  case red
  case green

  var accessibilityName: String {
    rawValue.capitalized
  }

  var swatchColor: UIColor {
    variedColor(seed: 0, includesVariance: false)
  }

  func variedColor(seed: Int, includesVariance: Bool = true) -> UIColor {
    if self == .colorless {
      return .white
    }
    return Self.sRGBColor(
      variedComponents(seed: seed, includesVariance: includesVariance)
    )
  }

  /// Follow the shortest OKLCH hue arc when it crosses only selected mana
  /// landmarks. If that arc would pass through a deselected mana color, route
  /// through the achromatic center instead.
  func interpolatedColor(
    toward other: SeatColor,
    selectedColors: Set<SeatColor>,
    seed: Int,
    amount: CGFloat
  ) -> UIColor {
    guard self != .colorless, other != .colorless else {
      return variedColor(seed: seed)
    }
    let source = variedComponents(seed: seed, includesVariance: true)
    let destination = other.variedComponents(
      seed: seed &+ 65_537,
      includesVariance: true
    )
    let progress = min(1, max(0, amount))
    let components: OKLCHComponents
    if crossesDeselectedManaColor(
      toward: other,
      selectedColors: selectedColors
    ) {
      let neutralLightness = (source.lightness + destination.lightness) / 2
      if progress < 0.5 {
        let localProgress = progress * 2
        components = OKLCHComponents(
          lightness: Self.interpolate(
            source.lightness,
            neutralLightness,
            amount: localProgress
          ),
          chroma: source.chroma * (1 - localProgress),
          hue: source.hue
        )
      } else {
        let localProgress = (progress - 0.5) * 2
        components = OKLCHComponents(
          lightness: Self.interpolate(
            neutralLightness,
            destination.lightness,
            amount: localProgress
          ),
          chroma: destination.chroma * localProgress,
          hue: destination.hue
        )
      }
    } else {
      let hueDistance = Self.shortestHueDistance(
        from: source.hue,
        to: destination.hue
      )
      components = OKLCHComponents(
        lightness: Self.interpolate(
          source.lightness,
          destination.lightness,
          amount: progress
        ),
        chroma: Self.interpolate(
          source.chroma,
          destination.chroma,
          amount: progress
        ),
        hue: source.hue + hueDistance * progress
      )
    }
    return Self.sRGBColor(components)
  }

  private func crossesDeselectedManaColor(
    toward other: SeatColor,
    selectedColors: Set<SeatColor>
  ) -> Bool {
    let startHue = oklch.hue
    let endHue = other.oklch.hue
    let totalDistance = Self.shortestHueDistance(
      from: startHue,
      to: endHue
    )
    let epsilon: CGFloat = 0.001

    return Self.allCases.contains { candidate in
      guard candidate != .colorless,
          candidate != self,
          candidate != other,
          !selectedColors.contains(candidate) else { return false }
      let candidateDistance = Self.shortestHueDistance(
        from: startHue,
        to: candidate.oklch.hue
      )
      if totalDistance > 0 {
        return candidateDistance > epsilon
          && candidateDistance < totalDistance - epsilon
      }
      return candidateDistance < -epsilon
        && candidateDistance > totalDistance + epsilon
    }
  }

  private static func shortestHueDistance(
    from start: CGFloat,
    to end: CGFloat
  ) -> CGFloat {
    var distance = (end - start).truncatingRemainder(dividingBy: 360)
    if distance > 180 {
      distance -= 360
    } else if distance < -180 {
      distance += 360
    }
    return distance
  }

  private func variedComponents(
    seed: Int,
    includesVariance: Bool
  ) -> OKLCHComponents {
    let components = oklch
    let lightnessNoise = includesVariance ? Self.noise(seed: seed, channel: 0) : 0
    let chromaNoise = includesVariance ? Self.noise(seed: seed, channel: 1) : 0
    let hueNoise = includesVariance ? Self.noise(seed: seed, channel: 2) : 0
    return OKLCHComponents(
      lightness: components.lightness + lightnessNoise * 0.035,
      chroma: components.chroma * (1 + chromaNoise * 0.08),
      hue: components.hue + hueNoise * 5
    )
  }

  private var oklch: OKLCHComponents {
    switch self {
    case .colorless:
      return OKLCHComponents(lightness: 1, chroma: 0, hue: 0)
    case .white:
      return OKLCHComponents(lightness: 0.79, chroma: 0.13, hue: 96)
    case .blue:
      return OKLCHComponents(lightness: 0.72, chroma: 0.15, hue: 245)
    case .black:
      return OKLCHComponents(lightness: 0.64, chroma: 0.13, hue: 305)
    case .red:
      return OKLCHComponents(lightness: 0.67, chroma: 0.22, hue: 28)
    case .green:
      return OKLCHComponents(lightness: 0.72, chroma: 0.18, hue: 145)
    }
  }

  private static func noise(seed: Int, channel: Int) -> CGFloat {
    var value = UInt64(bitPattern: Int64(seed))
    value &+= UInt64(channel + 1) &* 0x9E3779B97F4A7C15
    value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
    value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
    value ^= value >> 31
    let unit = CGFloat(value & 0xFFFF) / CGFloat(0xFFFF)
    return unit * 2 - 1
  }

  private static func sRGBColor(_ color: OKLCHComponents) -> UIColor {
    let radians = color.hue * .pi / 180
    let lightness = min(1, max(0, color.lightness))
    var chroma = max(0, color.chroma)
    var linear = linearRGB(
      lightness: lightness,
      chroma: chroma,
      hueRadians: radians
    )

    for _ in 0..<14 where !isInGamut(linear) {
      chroma *= 0.88
      linear = linearRGB(
        lightness: lightness,
        chroma: chroma,
        hueRadians: radians
      )
    }

    return UIColor(
      red: gammaEncode(linear.red),
      green: gammaEncode(linear.green),
      blue: gammaEncode(linear.blue),
      alpha: 1
    )
  }

  private static func linearRGB(
    lightness: CGFloat,
    chroma: CGFloat,
    hueRadians: CGFloat
  ) -> RGBComponents {
    let a = chroma * cos(hueRadians)
    let b = chroma * sin(hueRadians)
    let lRoot = lightness + 0.396_337_777_4 * a + 0.215_803_757_3 * b
    let mRoot = lightness - 0.105_561_345_8 * a - 0.063_854_172_8 * b
    let sRoot = lightness - 0.089_484_177_5 * a - 1.291_485_548 * b
    let l = lRoot * lRoot * lRoot
    let m = mRoot * mRoot * mRoot
    let s = sRoot * sRoot * sRoot

    return RGBComponents(
      red: 4.076_741_662_1 * l - 3.307_711_591_3 * m + 0.230_969_929_2 * s,
      green: -1.268_438_004_6 * l + 2.609_757_401_1 * m - 0.341_319_396_5 * s,
      blue: -0.004_196_086_3 * l - 0.703_418_614_7 * m + 1.707_614_701 * s
    )
  }

  private static func isInGamut(_ color: RGBComponents) -> Bool {
    color.red >= 0 && color.red <= 1
      && color.green >= 0 && color.green <= 1
      && color.blue >= 0 && color.blue <= 1
  }

  private static func gammaEncode(_ component: CGFloat) -> CGFloat {
    let clamped = min(1, max(0, component))
    if clamped <= 0.003_130_8 {
      return 12.92 * clamped
    }
    return 1.055 * pow(clamped, 1 / 2.4) - 0.055
  }

  private static func interpolate(
    _ start: CGFloat,
    _ end: CGFloat,
    amount: CGFloat
  ) -> CGFloat {
    start + (end - start) * amount
  }
}

private struct OKLCHComponents {
  var lightness: CGFloat
  var chroma: CGFloat
  var hue: CGFloat
}

private struct RGBComponents {
  var red: CGFloat
  var green: CGFloat
  var blue: CGFloat
}
