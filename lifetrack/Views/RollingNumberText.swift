import SwiftUI

@Observable
final class RollingValueModel {
  var value: Int = 0
  var font: Font = Typography.lifeDelta.swiftUIFont
  var lineHeight: CGFloat = Typography.lifeDelta.lineHeight
  var tintColor: Color = .white
}

struct RollingNumberText: View {
  var model: RollingValueModel

  var body: some View {
    Text(verbatim: "\(model.value)")
      .font(model.font)
      .foregroundStyle(model.tintColor)
      .frame(height: model.lineHeight)
      .contentTransition(.numericText(value: Double(model.value)))
      .animation(.snappy(duration: 0.28), value: model.value)
  }
}
