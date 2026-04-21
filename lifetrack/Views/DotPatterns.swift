import Foundation

enum ChangeDirection {
    case increasing, decreasing

    func delay(forRow row: Int) -> Double {
        let interval = 0.035
        switch self {
        case .decreasing: return Double(row) * interval
        case .increasing: return Double(DotPatterns.rows - 1 - row) * interval
        }
    }
}

enum DotPatterns {
    static let columns = 5
    static let rows = 7

    private static let raw: [[Int]] = [
        // 0
        [0,1,1,1,0,
         1,0,0,0,1,
         1,0,0,0,1,
         1,0,0,0,1,
         1,0,0,0,1,
         1,0,0,0,1,
         0,1,1,1,0],
        // 1
        [0,0,1,0,0,
         0,1,1,0,0,
         0,0,1,0,0,
         0,0,1,0,0,
         0,0,1,0,0,
         0,0,1,0,0,
         0,1,1,1,0],
        // 2
        [0,1,1,1,0,
         1,0,0,0,1,
         0,0,0,0,1,
         0,0,1,1,0,
         0,1,0,0,0,
         1,0,0,0,0,
         1,1,1,1,1],
        // 3
        [0,1,1,1,0,
         1,0,0,0,1,
         0,0,0,0,1,
         0,0,1,1,0,
         0,0,0,0,1,
         1,0,0,0,1,
         0,1,1,1,0],
        // 4
        [0,0,0,1,0,
         0,0,1,1,0,
         0,1,0,1,0,
         1,0,0,1,0,
         1,1,1,1,1,
         0,0,0,1,0,
         0,0,0,1,0],
        // 5
        [1,1,1,1,1,
         1,0,0,0,0,
         1,1,1,1,0,
         0,0,0,0,1,
         0,0,0,0,1,
         1,0,0,0,1,
         0,1,1,1,0],
        // 6
        [0,0,1,1,0,
         0,1,0,0,0,
         1,0,0,0,0,
         1,1,1,1,0,
         1,0,0,0,1,
         1,0,0,0,1,
         0,1,1,1,0],
        // 7
        [1,1,1,1,1,
         0,0,0,0,1,
         0,0,0,1,0,
         0,0,1,0,0,
         0,0,1,0,0,
         0,0,1,0,0,
         0,0,1,0,0],
        // 8
        [0,1,1,1,0,
         1,0,0,0,1,
         1,0,0,0,1,
         0,1,1,1,0,
         1,0,0,0,1,
         1,0,0,0,1,
         0,1,1,1,0],
        // 9
        [0,1,1,1,0,
         1,0,0,0,1,
         1,0,0,0,1,
         0,1,1,1,1,
         0,0,0,0,1,
         0,0,0,1,0,
         0,1,1,0,0],
    ]

    private static let rawMinus: [Int] = [
        0,0,0,0,0,
        0,0,0,0,0,
        0,0,0,0,0,
        0,1,1,1,0,
        0,0,0,0,0,
        0,0,0,0,0,
        0,0,0,0,0
    ]

    static let digits: [[Bool]] = raw.map { $0.map { $0 == 1 } }
    static let minus: [Bool] = rawMinus.map { $0 == 1 }

    static func pattern(for digit: Int) -> [Bool] {
        guard digit >= 0, digit <= 9 else { return minus }
        return digits[digit]
    }
}
