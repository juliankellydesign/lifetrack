import UIKit

/// Full-screen sheet that lets the player pick how many players are at the
/// table and which seating layout to use. Shown after a committed
/// swipe-to-reset; first launch goes directly to the default 4-player game.
///
/// Geometry (per design spec):
///   - 8pt safe area on the left and right of the screen
///   - 52pt safe area on the top and bottom of the screen
///   - 2 columns × 4 rows of buttons
///   - Each button is `(screenWidth - 16) / 4` wide and `(screenHeight - 104) / 6` tall
///   - The button grid is centered, leaving a 1/4-wide gutter on each side and
///     a 1/6-tall gutter above and below.
class LayoutSelectorView: UIView {
  var onSelect: ((PlayerLayout) -> Void)?

  var showsGridSkeleton = false {
    didSet {
      guard showsGridSkeleton != oldValue else { return }
      setNeedsLayout()
    }
  }

  private struct Cell {
    var layout: PlayerLayout
    var button: UIControl
    var icon: PlayerLayoutIconView
  }

  private var cells: [Cell] = []
  private let debugRegionShape = CAShapeLayer()
  private let debugTapShape = CAShapeLayer()

  private static let columns = 2
  private static let rows = 4
  private static let iconSize: CGFloat = 48

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .black
    buildCells()
    setupDebugSkeleton()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    backgroundColor = .black
    buildCells()
    setupDebugSkeleton()
  }

  private func buildCells() {
    for layout in PlayerLayout.selectorOrder {
      let button = UIControl()
      button.backgroundColor = .clear

      let icon = PlayerLayoutIconView(layout: layout)
      icon.isUserInteractionEnabled = false
      button.addSubview(icon)

      button.addAction(UIAction { [weak self] _ in
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
        self?.onSelect?(layout)
      }, for: .touchUpInside)

      // Press feedback scales only the icon. The button keeps its full grid-cell
      // hit area, preventing touch-drag exit flutter around its edges.
      button.addAction(UIAction { [weak icon] _ in
        AppSoundPlayer.shared.play(.button)
        UIView.animate(
          withDuration: 0.12,
          delay: 0,
          usingSpringWithDamping: 0.9,
          initialSpringVelocity: 0,
          options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
          icon?.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
      }, for: [.touchDown, .touchDragEnter])

      button.addAction(UIAction { [weak icon] _ in
        UIView.animate(
          withDuration: 0.2,
          delay: 0,
          usingSpringWithDamping: 0.7,
          initialSpringVelocity: 0,
          options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
          icon?.transform = .identity
        }
      }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])

      addSubview(button)
      cells.append(Cell(layout: layout, button: button, icon: icon))
    }
  }

  private func setupDebugSkeleton() {
    debugRegionShape.fillColor = UIColor.clear.cgColor
    debugRegionShape.strokeColor = UIColor.systemGreen.withAlphaComponent(0.9).cgColor
    debugRegionShape.lineWidth = 1
    debugRegionShape.zPosition = 998
    layer.addSublayer(debugRegionShape)

    debugTapShape.fillColor = UIColor.clear.cgColor
    debugTapShape.strokeColor = UIColor.systemOrange.withAlphaComponent(0.9).cgColor
    debugTapShape.lineWidth = 1
    debugTapShape.zPosition = 999
    layer.addSublayer(debugTapShape)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard cells.count == Self.columns * Self.rows else { return }

    let availableW = bounds.width - BoardInsets.leftRight * 2
    let availableH = bounds.height - BoardInsets.topBottom * 2

    let cellW = availableW / 4
    let cellH = availableH / 6

    let totalW = cellW * CGFloat(Self.columns)
    let totalH = cellH * CGFloat(Self.rows)

    let originX = BoardInsets.leftRight + (availableW - totalW) / 2
    let originY = BoardInsets.topBottom + (availableH - totalH) / 2

    for (i, cell) in cells.enumerated() {
      let col = i % Self.columns
      let row = i / Self.columns
      let frame = CGRect(
        x: originX + CGFloat(col) * cellW,
        y: originY + CGFloat(row) * cellH,
        width: cellW,
        height: cellH
      )
      cell.button.frame = frame
      let iconSize = Self.iconSize
      cell.icon.frame = CGRect(
        x: (frame.width - iconSize) / 2,
        y: (frame.height - iconSize) / 2,
        width: iconSize,
        height: iconSize
      )
    }

    updateDebugSkeleton()
  }

  private func updateDebugSkeleton() {
    debugRegionShape.frame = bounds
    debugTapShape.frame = bounds

    guard showsGridSkeleton else {
      debugRegionShape.path = nil
      debugTapShape.path = nil
      return
    }

    let playableRect = bounds.insetBy(
      dx: BoardInsets.leftRight,
      dy: BoardInsets.topBottom
    )
    debugRegionShape.path = UIBezierPath(rect: playableRect).cgPath

    let tapPath = UIBezierPath()
    for cell in cells {
      tapPath.append(UIBezierPath(rect: cell.button.frame))
    }
    debugTapShape.path = tapPath.cgPath
  }
}
