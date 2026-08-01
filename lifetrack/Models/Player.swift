import Foundation

struct Player {
  let id: Int
  var lifeTotal: Int
  var commanderDamage: [Int: Int] = [:]
  var seatColors: Set<SeatColor> = [.colorless]

  static let defaultLife = 40
  static let lethalCommanderDamage = 21

  func damage(from opponentId: Int) -> Int {
    commanderDamage[opponentId] ?? 0
  }
}
