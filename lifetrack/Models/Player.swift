import Foundation

struct Player {
  let id: Int
  var lifeTotal: Int
  var commanderDamage: [Int: Int] = [:]
  var seatColors: Set<SeatColor> = [.colorless]
  var poisonCounters: Int = 0

  static let defaultLife = 40
  static let lethalCommanderDamage = 21
  static let lethalPoisonCounters = 10

  var hasLethalCommanderDamage: Bool {
    commanderDamage.values.contains { $0 >= Self.lethalCommanderDamage }
  }

  func damage(from opponentId: Int) -> Int {
    commanderDamage[opponentId] ?? 0
  }
}
