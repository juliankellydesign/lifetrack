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
    /// One text style: face + size + line height, with monospaced-digit figures
    /// applied where digits roll in place (badges, life input) so advances stay
    /// stable as the number changes.
    struct Style {
        /// A `Karl.*` font name (e.g. `Karl.medium`).
        let face: String
        let size: CGFloat
        let lineHeight: CGFloat
        let monospacedDigits: Bool

        /// UIKit font — for `UILabel`, attributed strings, and text measurement.
        var uiFont: UIFont {
            monospacedDigits
                ? Karl.monospacedDigit(face, size: size)
                : Karl.font(face, size: size)
        }

        /// SwiftUI font — for hosted `Text` (e.g. the rolling badge numeral).
        var swiftUIFont: Font {
            let base = Font.custom(face, size: size)
            return monospacedDigits ? base.monospacedDigit() : base
        }
    }

    /// Number-pad digit keys (0–9) in the life-input overlay.
    static let keypadDigit = Style(
        face: Karl.medium, size: 32, lineHeight: 36, monospacedDigits: false
    )

    /// Badge numeral as it sits inline on a player-cell badge (read-only).
    static let badgeInlineValue = Style(
        face: Karl.medium, size: 24, lineHeight: 28, monospacedDigits: true
    )

    /// Badge numeral in the life-input overlay (interactive, one step larger).
    static let badgeInputValue = Style(
        face: Karl.medium, size: 28, lineHeight: 32, monospacedDigits: true
    )

    /// Transient net-change readout next to a life total (e.g. "+5" / "−3").
    static let lifeDelta = Style(
        face: Karl.medium, size: 28, lineHeight: 32, monospacedDigits: false
    )
}
