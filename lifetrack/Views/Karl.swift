import UIKit
import CoreText

enum Karl {
    static let regular = "KarlST-Regular"
    static let medium = "KarlST-Medium"
    static let bold = "KarlST-Bold"
    static let black = "KarlST-Black"
    static let ultraBlack = "KarlST-UltraBlack"

    /// Registers all bundled Karl ST OTF files so `UIFont(name:size:)` can find them.
    /// Must be called once at launch before any views resolve fonts.
    static func registerFonts() {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: nil) else {
            return
        }
        for url in urls where url.lastPathComponent.hasPrefix("KarlST") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func font(_ name: String, size: CGFloat) -> UIFont {
        UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: .medium)
    }

    /// Karl with `tnum` (tabular figures) applied so digits have uniform advance width.
    static func monospacedDigit(_ name: String, size: CGFloat) -> UIFont {
        let base = font(name, size: size)
        let feature: [UIFontDescriptor.FeatureKey: Int] = [
            .type: kNumberSpacingType,
            .selector: kMonospacedNumbersSelector
        ]
        let descriptor = base.fontDescriptor.addingAttributes([
            .featureSettings: [feature]
        ])
        return UIFont(descriptor: descriptor, size: size)
    }
}
