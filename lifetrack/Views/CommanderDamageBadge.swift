import UIKit
import SwiftUI

/// Counter badge for commander damage. Adds lethal-threshold red coloring on top
/// of `CounterBadge`'s icon + value + ± controls.
class CommanderDamageBadge: CounterBadge {
    let opponentId: Int
    private let commanderIcon: CommanderIconView

    init(opponentId: Int, playerCount: Int) {
        self.opponentId = opponentId
        let icon = CommanderIconView(playerCount: playerCount, highlightedIndex: opponentId)
        self.commanderIcon = icon
        super.init(iconView: icon)
        dimsIconWhenInactive = false
    }

    var boardRotation: CGFloat {
        get { commanderIcon.boardRotation }
        set { commanderIcon.boardRotation = newValue }
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
