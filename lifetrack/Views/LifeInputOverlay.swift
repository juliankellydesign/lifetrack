import UIKit

struct LifeInputResult {
    var lifeTotal: Int
    var commanderDamage: [Int: Int]
    var counters: [LifeCounter: Int]
}

class LifeInputOverlay: UIView {
    var onDismiss: ((LifeInputResult) -> Void)?

    private let contentContainer = UIView()
    let dotNumberView = DotNumberView()
    let counterRow = LifeCounterRowView()
    let damageRow = CommanderDamageRowView()
    let numberPadView = NumberPadView()

    /// Debug overlay: when true, strokes the usable content area plus every
    /// laid-out region (counter row, life number, damage row, number pad) and
    /// each number-pad key. Mirrors `GameBoardView.showsGridSkeleton`; the
    /// controller pushes the current toggle state in when presenting.
    var showsGridSkeleton = false {
        didSet {
            guard showsGridSkeleton != oldValue else { return }
            setNeedsLayout()
        }
    }
    private let skeletonShape = CAShapeLayer()

    /// Padding from the safe-area edges of the screen to the input view's content.
    private static let horizontalEdgePadding: CGFloat = 0   // safe area already covers this in landscape
    private static let verticalEdgePadding: CGFloat = 8

    private var inputText = ""
    private var lifeTotal: Int = 0
    private var commanderDamage: [Int: Int] = [:]
    private var counters: [LifeCounter: Int] = [:]
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
        dotNumberView.isUserInteractionEnabled = true
        let dotTap = UITapGestureRecognizer(target: self, action: #selector(handleLifeTotalTap))
        dotNumberView.addGestureRecognizer(dotTap)
        contentContainer.addSubview(dotNumberView)
        contentContainer.addSubview(counterRow)
        contentContainer.addSubview(damageRow)
        numberPadView.onKey = { [weak self] key in self?.handleKey(key) }
        contentContainer.addSubview(numberPadView)

        skeletonShape.fillColor = UIColor.clear.cgColor
        skeletonShape.strokeColor = UIColor.systemGreen.withAlphaComponent(0.9).cgColor
        skeletonShape.lineWidth = 1
        skeletonShape.zPosition = 999 // keep on top of the region subviews
        contentContainer.layer.addSublayer(skeletonShape)

        damageRow.onAdjustDamage = { [weak self] opponentId, delta in
            self?.adjustDamage(forOpponent: opponentId, by: delta)
        }
        counterRow.onAdjust = { [weak self] kind, delta in
            self?.adjustCounter(kind, by: delta)
        }
    }

    /// Configure state and lay out without animating; caller drives the transition.
    func prepare(
        lifeTotal: Int,
        commanderDamage: [Int: Int],
        counters: [LifeCounter: Int],
        opponentIds: [Int],
        layout: PlayerLayout,
        rotation: CGFloat
    ) {
        self.lifeTotal = lifeTotal
        self.commanderDamage = commanderDamage
        self.counters = counters
        self.rotation = rotation
        inputText = ""
        direction = nil
        isHidden = false
        alpha = 1
        backgroundColor = UIColor.black.withAlphaComponent(0)
        numberPadView.alpha = 0
        damageRow.alpha = 0
        counterRow.alpha = 0

        let damages = opponentIds.map { commanderDamage[$0] ?? 0 }
        damageRow.iconRotation = rotation
        damageRow.configure(layout: layout, opponentIds: opponentIds, damages: damages)
        damageRow.setBadgesUserInteractionEnabled(true)

        counterRow.configure(values: counters)
        counterRow.setBadgesUserInteractionEnabled(true)

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
        counterRow.alpha = 1
    }

    /// Fade chrome away. Call inside an animation block.
    func dismissChrome() {
        backgroundColor = UIColor.black.withAlphaComponent(0)
        numberPadView.alpha = 0
        damageRow.alpha = 0
        counterRow.alpha = 0
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

        let hPad = Self.horizontalEdgePadding
        let vPad = Self.verticalEdgePadding
        let usableW = contentW - hPad * 2
        let usableH = contentH - vPad * 2

        // The overlay uses the same slot-first mental model as the board: a left
        // editing surface and a right keypad share four row tracks. Counters sit
        // in the top-left track, commander damage in the bottom-left track, and
        // the life number spans the two middle tracks. The dot-number hero
        // animation still converges on `dotNumberView`'s final frame here.
        let padRows: CGFloat = 4
        let padRowSpacing: CGFloat = NumberPadView.rowSpacing

        if isHorizontal {
            // Number pad on the right: each key is square, sized to fit the
            // available height. The pad's full width is 3 × key height, leaving
            // the rest of the row for the life column on the left.
            let padH = usableH
            let padCellH = (padH - (padRows - 1) * padRowSpacing) / padRows
            let padColW = padCellH * CGFloat(3)
            let lifeColW = usableW - padColW
            let rowStride = padCellH + padRowSpacing
            let counterY = vPad
            let lifeTop = vPad + rowStride
            let lifeAreaH = padCellH * 2 + padRowSpacing
            let damageY = vPad + rowStride * 3

            counterRow.frame = CGRect(
                x: hPad, y: counterY,
                width: lifeColW, height: padCellH
            )
            dotNumberView.frame = CGRect(
                x: hPad, y: lifeTop,
                width: lifeColW, height: lifeAreaH
            )
            damageRow.frame = CGRect(
                x: hPad, y: damageY,
                width: lifeColW, height: padCellH
            )
            numberPadView.frame = CGRect(
                x: hPad + lifeColW, y: vPad,
                width: padColW, height: padH
            )
        } else {
            // Portrait fallback: stack life column above keypad.
            let padH = contentH * 0.45
            let lifeH = usableH - padH
            let trackH = lifeH / 4
            let lifeAreaH = trackH * 2

            counterRow.frame = CGRect(
                x: hPad, y: vPad,
                width: usableW, height: trackH
            )
            dotNumberView.frame = CGRect(
                x: hPad, y: vPad + trackH,
                width: usableW, height: lifeAreaH
            )
            damageRow.frame = CGRect(
                x: hPad, y: vPad + trackH + lifeAreaH,
                width: usableW, height: trackH
            )
            numberPadView.frame = CGRect(
                x: hPad, y: vPad + lifeH,
                width: usableW, height: padH
            )
        }

        contentContainer.transform = CGAffineTransform(rotationAngle: rotRad)

        updateSkeleton()
    }

    /// Redraw (or clear) the grid-skeleton overlay. Drawn in `contentContainer`'s
    /// coordinate space — since the shape layer lives inside `contentContainer`,
    /// the container's rotation transform carries the outlines along for free.
    private func updateSkeleton() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        skeletonShape.frame = contentContainer.bounds

        guard showsGridSkeleton else {
            skeletonShape.path = nil
            CATransaction.commit()
            return
        }

        numberPadView.layoutIfNeeded()
        let path = UIBezierPath()
        path.append(UIBezierPath(rect: contentContainer.bounds.insetBy(dx: 0.5, dy: 0.5)))
        for region in [counterRow.frame, dotNumberView.frame, damageRow.frame, numberPadView.frame] {
            path.append(UIBezierPath(rect: region))
        }
        let padOrigin = numberPadView.frame.origin
        for key in numberPadView.keyFrames {
            path.append(UIBezierPath(rect: key.offsetBy(dx: padOrigin.x, dy: padOrigin.y)))
        }
        skeletonShape.path = path.cgPath
        CATransaction.commit()
    }

    private func clamp(_ x: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        Swift.max(lo, Swift.min(hi, x))
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

    private func adjustCounter(_ kind: LifeCounter, by delta: Int) {
        let current = counters[kind] ?? 0
        let next = max(0, current + delta)
        guard next != current else { return }
        counters[kind] = next
        counterRow.setValue(next, for: kind)
    }

    // MARK: - Numpad input (life only)

    @objc private func handleLifeTotalTap() {
        handleKey(.confirm)
    }

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
        case .clear:
            inputText = ""
        case .confirm:
            if !inputText.isEmpty, let value = Int(inputText) {
                lifeTotal = value
            }
            onDismiss?(LifeInputResult(
                lifeTotal: lifeTotal,
                commanderDamage: commanderDamage,
                counters: counters
            ))
            return
        }
        let newNumber = displayNumber
        if newNumber != oldNumber {
            direction = newNumber > oldNumber ? .increasing : .decreasing
        }
        dotNumberView.updateNumber(newNumber, direction: direction, animated: true)
    }
}
