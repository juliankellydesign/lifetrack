import UIKit
import SwiftUI

/// Central typography tokens — the single source of truth for Karl-based text
/// styles, the way `BoardInsets` is for spacing. Sizes and line heights sit on
/// the 4pt grid (units of 20 where a value reads as a deliberate "step").
///
/// Don't declare ad-hoc font sizes/line heights in views. Add a `Style` here and
/// pull `Typography.<name>` from it. Each `Style` vends both a UIKit `UIFont`
/// (labels, attributed strings, text measurement) and a SwiftUI `Font` (hosted
/// `Text`), so the same token drives both rendering paths.
///
/// The dot-matrix life total is a *different* system — it's a bitmap font, not
/// Karl — and is sized by `DotNumberView`/`GameBoardView`, not here.
enum Typography {
  /// One text style: face + size + line height. Every style applies tabular
  /// figures so numeric advances stay stable everywhere in the app.
  struct Style {
    /// A `Karl.*` font name (e.g. `Karl.medium`).
    let face: String
    let size: CGFloat
    let lineHeight: CGFloat

    /// UIKit font — for `UILabel`, attributed strings, and text measurement.
    var uiFont: UIFont {
      Karl.monospacedDigit(face, size: size)
    }

    /// SwiftUI font — for hosted `Text` (e.g. the rolling badge numeral).
    var swiftUIFont: Font {
      Font.custom(face, size: size).monospacedDigit()
    }
  }

  /// Number-pad digit keys (0–9) in the life-input overlay.
  static let keypadDigit = Style(
    face: Karl.medium, size: 32, lineHeight: 36
  )

  /// Transient net-change readout next to a life total (e.g. "+5" / "−3").
  /// Tabular figures so the rolling digits keep a stable width.
  static let lifeDelta = Style(
    face: Karl.medium, size: 28, lineHeight: 32
  )
}
