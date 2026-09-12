import UIKit

struct PlayerColorPalette {
  var colors: [SeatColor]
  var seed: Int

  init(colors: Set<SeatColor>, seed: Int) {
    let normalized = colors.isEmpty ? Set([SeatColor.colorless]) : colors
    self.colors = SeatColor.allCases.filter { normalized.contains($0) }
    self.seed = seed
  }

  init(colors: [SeatColor], seed: Int) {
    self.init(colors: Set(colors), seed: seed)
  }

  func color(at index: Int) -> UIColor {
    let mixedSeed = stableSeed(for: index)
    let unsignedSeed = UInt(bitPattern: mixedSeed)
    let paletteIndex = Int(unsignedSeed % UInt(colors.count))

    guard colors.count > 1 else {
      return colors[paletteIndex].variedColor(seed: mixedSeed)
    }

    let secondaryOffset = 1 + Int(
      (unsignedSeed >> 8) % UInt(colors.count - 1)
    )
    let secondaryIndex = (paletteIndex + secondaryOffset) % colors.count
    let blendUnit = CGFloat((unsignedSeed >> 16) & 0xFFFF) / CGFloat(0xFFFF)
    return colors[paletteIndex].interpolatedColor(
      toward: colors[secondaryIndex],
      selectedColors: Set(colors),
      seed: mixedSeed,
      amount: 0.10 + blendUnit * 0.35
    )
  }

  private func stableSeed(for index: Int) -> Int {
    var value = UInt64(bitPattern: Int64(seed &+ index &* 9_173))
    value &+= 0x9E3779B97F4A7C15
    value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
    value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
    value ^= value >> 31
    return Int(truncatingIfNeeded: value)
  }
}
