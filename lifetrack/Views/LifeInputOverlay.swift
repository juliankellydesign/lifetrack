import UIKit

struct LifeInputResult {
    var lifeTotal: Int
    var commanderDamage: [Int: Int]
}

class LifeInputOverlay: UIView {
    var onDismiss: ((LifeInputResult) -> Void)?

    private let contentContainer = UIView()
    let dotNumberView = DotNumberView()
    let damageRow = CommanderDamageRowView()
    let numberPadView = NumberPadView()

    private var inputText = ""
    private var lifeTotal: Int = 0
    private var commanderDamage: [Int: Int] = [:]
    private(set) var rotation: CGFloat = 0
    private var direction: ChangeDirection?
    private var finalDotCenter: CGPoint = .zero

    private var displayNumber: Int {
        if inputText.isEmpty { return lifeTotal }
        return Int(inputText) ?? 0
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = UIColor.black.withAlphaComponent(0)
        alpha = 0

        addSubview(contentContainer)
        dotNumberView.isUserInteractionEnabled = false
        contentContainer.addSubview(dotNumberView)
        contentContainer.addSubview(damageRow)
        numberPadView.onKey = { [weak self] key in self?.handleKey(key) }
        contentContainer.addSubview(numberPadView)

        damageRow.onAdjustDamage = { [weak self] opponentId, delta in
            self?.adjustDamage(forOpponent: opponentId, by: delta)
        }
    }

    /// Configure state and lay out without animating; caller drives the transition.
    func prepare(
        lifeTotal: Int,
        commanderDamage: [Int: Int],
        opponentIds: [Int],
        playerCount: Int,
        rotation: CGFloat
    ) {
        self.lifeTotal = lifeTotal
        self.commanderDamage = commanderDamage
        self.rotation = rotation
        inputText = ""
        direction = nil
        isHidden = false
        alpha = 1
        backgroundColor = UIColor.black.withAlphaComponent(0)
        numberPadView.alpha = 0
        damageRow.alpha = 0

        let damages = opponentIds.map { commanderDamage[$0] ?? 0 }
        damageRow.configure(opponentIds: opponentIds, playerCount: playerCount, damages: damages)
        damageRow.setBadgesUserInteractionEnabled(true)

        dotNumberView.transform = .identity
        setNeedsLayout()
        layoutIfNeeded()

        finalDotCenter = dotNumberView.center
        dotNumberView.updateNumber(lifeTotal, direction: nil, animated: false)
    }

    /// Position the overlay's dotNumberView so its rendered dots match a source dot pattern visually.
    func placeDotNumberView(visualCenter: CGPoint, sourceDotSize: CGFloat) {
        let local = contentContainerLocal(for: visualCenter)
        let ovlDotSize = dotNumberView.actualDotSize
        let s = ovlDotSize > 0 ? sourceDotSize / ovlDotSize : 1

        dotNumberView.center = local
        dotNumberView.transform = CGAffineTransform(scaleX: s, y: s)
    }

    /// Reset the dotNumberView to its laid-out position with identity transform.
    func resetDotNumberViewToFinal() {
        dotNumberView.transform = .identity
        dotNumberView.center = finalDotCenter
    }

    /// Settle background to black and reveal the keypad. Call inside an animation block.
    func presentChrome() {
        backgroundColor = .black
        numberPadView.alpha = 1
        damageRow.alpha = 1
    }

    /// Fade chrome away. Call inside an animation block.
    func dismissChrome() {
        backgroundColor = UIColor.black.withAlphaComponent(0)
        numberPadView.alpha = 0
        damageRow.alpha = 0
    }

    func finishDismiss() {
        alpha = 0
        isHidden = true
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !isHidden else { return }

        let insets = safeAreaInsets
        let safeW = bounds.width - insets.left - insets.right
        let safeH = bounds.height - insets.top - insets.bottom

        let isHorizontal = abs(Int(rotation)) == 90
        let rotRad = rotation * .pi / 180
        let contentW = isHorizontal ? safeH : safeW
        let contentH = isHorizontal ? safeW : safeH

        contentContainer.transform = .identity
        contentContainer.bounds = CGRect(x: 0, y: 0, width: contentW, height: contentH)
        contentContainer.center = CGPoint(
            x: insets.left + safeW / 2,
            y: insets.top + safeH / 2
        )

        let badgeRowH: CGFloat = min(max(contentH * 0.13, 56), 84)

        if isHorizontal {
            let padW = contentW * 0.38
            let dotW = contentW - padW

            let dotAreaH = contentH - badgeRowH - 32
            dotNumberView.frame = CGRect(x: 24, y: 24, width: dotW - 48, height: dotAreaH)
            damageRow.frame = CGRect(x: 24, y: 24 + dotAreaH, width: dotW - 48, height: badgeRowH)
            numberPadView.frame = CGRect(x: dotW + 16, y: 16, width: padW - 32, height: contentH - 32)
        } else {
            let padH = contentH * 0.45
            let dotH = contentH - padH

            let dotAreaH = dotH - badgeRowH - 32
            dotNumberView.frame = CGRect(x: 24, y: 24, width: contentW - 48, height: dotAreaH)
            damageRow.frame = CGRect(x: 24, y: 24 + dotAreaH, width: contentW - 48, height: badgeRowH)
            numberPadView.frame = CGRect(x: 24, y: dotH, width: contentW - 48, height: padH - 64)
        }

        contentContainer.transform = CGAffineTransform(rotationAngle: rotRad)
    }

    // MARK: - Coordinate helpers

    private func contentContainerLocal(for point: CGPoint) -> CGPoint {
        let dx = point.x - contentContainer.center.x
        let dy = point.y - contentContainer.center.y
        let rotRad = -rotation * .pi / 180
        let cosR = cos(rotRad)
        let sinR = sin(rotRad)
        let lx = dx * cosR - dy * sinR + contentContainer.bounds.midX
        let ly = dx * sinR + dy * cosR + contentContainer.bounds.midY
        return CGPoint(x: lx, y: ly)
    }

    // MARK: - Damage adjustment

    private func adjustDamage(forOpponent opponentId: Int, by delta: Int) {
        let current = commanderDamage[opponentId] ?? 0
        let next = max(0, current + delta)
        guard next != current else { return }
        commanderDamage[opponentId] = next
        damageRow.setDamage(next, forOpponent: opponentId)
    }

    // MARK: - Numpad input (life only)

    private func handleKey(_ key: NumberPadKey) {
        let oldNumber = displayNumber
        switch key {
        case .digit(let d):
            if inputText.count < 4 {
                inputText += "\(d)"
            }
        case .backspace:
            if inputText.isEmpty {
                let s = String(lifeTotal)
                inputText = String(s.dropLast())
            } else {
                inputText.removeLast()
            }
        case .confirm:
            if !inputText.isEmpty, let value = Int(inputText) {
                lifeTotal = value
            }
            onDismiss?(LifeInputResult(lifeTotal: lifeTotal, commanderDamage: commanderDamage))
            return
        }
        let newNumber = displayNumber
        if newNumber != oldNumber {
            direction = newNumber > oldNumber ? .increasing : .decreasing
        }
        dotNumberView.updateNumber(newNumber, direction: direction, animated: true)
    }
}
