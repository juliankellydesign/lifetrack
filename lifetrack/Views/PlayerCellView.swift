import UIKit

class PlayerCellView: UIView {
    private(set) var lifeTotal: Int = Player.defaultLife
    var rotation: CGFloat = 0
    var maxDotSize: CGFloat? {
        didSet { dotNumberView.maxDotSize = maxDotSize }
    }
    var onEditRequested: (() -> Void)?
    var onLifeChanged: ((Int) -> Void)?
    var isBeingEdited: Bool = false {
        didSet { dotNumberView.isHidden = isBeingEdited }
    }

    let dotNumberView = DotNumberView()
    private let backgroundView = UIView()
    private var changeDirection: ChangeDirection?
    private var repeatTimer: Timer?
    private var centerHoldTimer: Timer?
    private var isTouching = false

    private enum TapZone { case left, center, right }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        backgroundView.layer.cornerRadius = 12
        backgroundView.layer.borderWidth = 1
        backgroundView.layer.borderColor = UIColor.gray.withAlphaComponent(0.4).cgColor
        backgroundView.isUserInteractionEnabled = false
        addSubview(backgroundView)

        dotNumberView.isUserInteractionEnabled = false
        addSubview(dotNumberView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.frame = bounds

        let inset: CGFloat = 24
        let swapped = abs(Int(rotation)) == 90
        let contentW = (swapped ? bounds.height : bounds.width) - inset * 2
        let contentH = (swapped ? bounds.width : bounds.height) - inset * 2

        dotNumberView.transform = .identity
        dotNumberView.bounds = CGRect(x: 0, y: 0, width: contentW, height: contentH)
        dotNumberView.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        dotNumberView.transform = CGAffineTransform(rotationAngle: rotation * .pi / 180)
    }

    func setLifeTotal(_ value: Int, direction: ChangeDirection?, animated: Bool) {
        lifeTotal = value
        changeDirection = direction
        dotNumberView.updateNumber(value, direction: direction, animated: animated)
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isTouching, let touch = touches.first else { return }
        isTouching = true
        let loc = touch.location(in: self)
        let zone = tapZone(at: loc)

        switch zone {
        case .left:
            applyTilt(angle: -7)
            applyChange(increment: false)
            repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                self?.applyChange(increment: false)
            }
        case .right:
            applyTilt(angle: 7)
            applyChange(increment: true)
            repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                self?.applyChange(increment: true)
            }
        case .center:
            centerHoldTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                self?.onEditRequested?()
                self?.centerHoldTimer = nil
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouch()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouch()
    }

    private func endTouch() {
        repeatTimer?.invalidate()
        repeatTimer = nil
        centerHoldTimer?.invalidate()
        centerHoldTimer = nil
        isTouching = false
        applyTilt(angle: 0)
    }

    // MARK: - Helpers

    private func playerFraction(at location: CGPoint) -> CGFloat {
        let deg = Int(rotation)
        switch deg {
        case 90:       return location.y / bounds.height
        case -90:      return 1 - (location.y / bounds.height)
        case 180, -180: return 1 - (location.x / bounds.width)
        default:       return location.x / bounds.width
        }
    }

    private func tapZone(at location: CGPoint) -> TapZone {
        let f = playerFraction(at: location)
        if f < 1.0 / 3.0 { return .left }
        if f > 2.0 / 3.0 { return .right }
        return .center
    }

    private func applyChange(increment: Bool) {
        changeDirection = increment ? .increasing : .decreasing
        lifeTotal += increment ? 1 : -1
        dotNumberView.updateNumber(lifeTotal, direction: changeDirection, animated: true)
        onLifeChanged?(lifeTotal)
    }

    private func applyTilt(angle: CGFloat) {
        let radians = angle * .pi / 180
        let rotRad = rotation * .pi / 180

        var t = CATransform3DIdentity
        t.m34 = -1.0 / 500
        t = CATransform3DRotate(t, radians, -sin(rotRad), cos(rotRad), 0)

        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 1.0,
                       initialSpringVelocity: 0, options: []) {
            self.layer.transform = t
        }
    }
}
