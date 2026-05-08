import Foundation

enum LifeCounter: String, CaseIterable {
    case poison, energy, rad, experience
}

struct Player {
    let id: Int
    var lifeTotal: Int
    var commanderDamage: [Int: Int] = [:]
    var counters: [LifeCounter: Int] = [:]

    static let defaultLife = 40
    static let lethalCommanderDamage = 21

    func damage(from opponentId: Int) -> Int {
        commanderDamage[opponentId] ?? 0
    }

    func counter(_ kind: LifeCounter) -> Int {
        counters[kind] ?? 0
    }
}
