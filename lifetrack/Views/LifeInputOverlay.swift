import UIKit

class LifeInputOverlay: UIView {
    var onDismiss: ((Int) -> Void)?

    private let contentContainer = UIView()
    let dotNumberView = DotNumberView()
    let numberPadView = NumberPadView()

    private var inputText = ""
    private var currentLifeTotal: Int = 0
    private(set) var rotation: CGFloat = 0
    private var direction: ChangeDirection?
    private var finalDotCenter: CGPoint = .zero

    private var displayNumber: Int {
        if inputText.isEmpty { return currentLifeTotal }
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
        contentContainer.addSubview(dotNumberView)
        numberPadView.onKey = { [weak self] key in self?.handleKey(key) }
        contentContainer.addSubview(numberPadView)
    }

    /// Configure state and lay out without animating; caller drives the transition.
    func prepare(lifeTotal: Int, rotation: CGFloat) {
        currentLifeTotal = lifeTotal
        self.rotation = rotation
        inputText = ""
        direction = nil
        isHidden = false
        alpha = 1
        backgroundColor = UIColor.black.withAlphaComponent(0)
        numberPadView.alpha = 0

        dotNumberView.transform = .identity
        setNeedsLayout()
        layoutIfNeeded()

        finalDotCenter = dotNumberView.center
        dotNumberView.updateNumber(lifeTotal, direction: nil, animated: false)
    }

    /// Position the overlay's dotNumberView so its rendered dots match a source dot pattern visually.
    /// Uses uniform scale (so dots stay circular) and center alignment (since each dot pattern is
    /// centered in its own dotNumberView bounds).
    func placeDotNumberView(visualCenter: CGPoint, sourceDotSize: CGFloat) {
        let local = contentContainerLocal(for: visualCenter)
        let ovlDotSize = dotNumberView.actualDotSize
        let s = ovlDotSize > 0 ? sourceDotSize / ovlDotSize : 1

        dotNumberView.center = local
        dotNumberView.transform = CGAffineTransform(scaleX: s, y: s)
    }

    /// Reset the dotNumberView to its laid-out position with identity transform.
    /// Does not relayout (which would corrupt bounds while transform is non-identity).
    func resetDotNumberViewToFinal() {
        dotNumberView.transform = .identity
        dotNumberView.center = finalDotCenter
    }

    /// Settle background to black and reveal the keypad. Call inside an animation block.
    func presentChrome() {
        backgroundColor = .black
        numberPadView.alpha = 1
    }

    /// Fade chrome away. Call inside an animation block.
    func dismissChrome() {
        backgroundColor = UIColor.black.withAlphaComponent(0)
        numberPadView.alpha = 0
    }

    func finishDismiss() {
        alpha = 0
        isHidden = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !isHidden else { return }

        let isHorizontal = abs(Int(rotation)) == 90
        let rotRad = rotation * .pi / 180
        let contentW = isHorizontal ? bounds.height : bounds.width
        let contentH = isHorizontal ? bounds.width : bounds.height

        contentContainer.transform = .identity
        contentContainer.bounds = CGRect(x: 0, y: 0, width: contentW, height: contentH)
        contentContainer.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)

        if isHorizontal {
            let padW = contentW * 0.38
            let dotW = contentW - padW

            dotNumberView.frame = CGRect(x: 24, y: 24, width: dotW - 48, height: contentH - 48)
            numberPadView.frame = CGRect(x: dotW + 16, y: 16, width: padW - 32, height: contentH - 32)
        } else {
            let padH = contentH * 0.45
            let dotH = contentH - padH

            dotNumberView.frame = CGRect(x: 24, y: 24, width: contentW - 48, height: dotH - 48)
            numberPadView.frame = CGRect(x: 24, y: dotH, width: contentW - 48, height: padH - 64)
        }

        contentContainer.transform = CGAffineTransform(rotationAngle: rotRad)
    }

    // MARK: - Coordinate helpers

    /// Convert a point in this overlay's coordinate space to contentContainer's local (unrotated) coords.
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

    // MARK: - Input

    private func handleKey(_ key: NumberPadKey) {
        let oldNumber = displayNumber
        switch key {
        case .digit(let d):
            if inputText.count < 4 {
                inputText += "\(d)"
            }
        case .backspace:
            if inputText.isEmpty {
                let s = String(currentLifeTotal)
                inputText = String(s.dropLast())
            } else {
                inputText.removeLast()
            }
        case .confirm:
            if !inputText.isEmpty, let value = Int(inputText) {
                currentLifeTotal = value
            }
            onDismiss?(currentLifeTotal)
            return
        }
        let newNumber = displayNumber
        if newNumber != oldNumber {
            direction = newNumber > oldNumber ? .increasing : .decreasing
        }
        dotNumberView.updateNumber(displayNumber, direction: direction, animated: true)
    }
}
