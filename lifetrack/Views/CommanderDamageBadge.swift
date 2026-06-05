import UIKit
import SwiftUI

/// Counter badge for commander damage. Shows the host layout's seat dots with
/// the source opponent's dot at full opacity and the rest dimmed, so the player
/// can see which opponent's commander is dealing the damage.
class CommanderDamageBadge: CounterBadge {
    let opponentSeatIndex: Int
    private let layoutIcon: PlayerLayoutIconView

    init(opponentSeatIndex: Int, layout: PlayerLayout) {
        self.opponentSeatIndex = opponentSeatIndex
        let icon = PlayerLayoutIconView(
            layout: layout,
            highlightedSeatIndex: opponentSeatIndex
        )
        self.layoutIcon = icon
        super.init(iconView: icon)
        dimsIconWhenInactive = false
        // Commander damage is always shown — a dim `+` marks an opponent who
        // hasn't dealt any yet, so the seat slot never disappears.
        showsInlinePlusWhenZero = true
        // Tappable straight from the player cell (no overlay needed): each tap
        // bumps the damage up. The ± editor in the life-input overlay takes over
        // when `showsAdjustControls` is set there.
        inlineTapIncrements = true
    }

    var boardRotation: CGFloat {
        get { layoutIcon.boardRotation }
        set { layoutIcon.boardRotation = newValue }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    /// Maintain old API name so existing call sites compile unchanged.
    var damage: Int { value }

    func setDamage(_ newValue: Int, animated: Bool) {
        setValue(newValue, animated: animated)
    }

    override func valueDidChange() {
        valueModel.tintColor = (value >= Player.lethalCommanderDamage)
            ? Color(red: 1, green: 0.35, blue: 0.35)
            : .white
    }
}
