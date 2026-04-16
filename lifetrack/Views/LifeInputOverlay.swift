import SwiftUI

struct LifeInputOverlay: View {
    let isPresented: Bool
    @Binding var lifeTotal: Int
    let rotation: Angle
    let onDismiss: () -> Void
    var dotNamespace: Namespace.ID? = nil
    var matchId: Int = 0

    @State private var inputText = ""
    @State private var direction: ChangeDirection? = nil

    private var displayNumber: Int {
        if inputText.isEmpty { return lifeTotal }
        return Int(inputText) ?? 0
    }

    private var isHorizontal: Bool {
        abs(Int(rotation.degrees)) == 90
    }

    var body: some View {
        GeometryReader { geo in
            let swapped = isHorizontal
            let contentW = swapped ? geo.size.height : geo.size.width
            let contentH = swapped ? geo.size.width : geo.size.height

            Group {
                if isHorizontal {
                    HStack(spacing: 0) {
                        dotSlot
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        NumberPadView(onKey: handleKey)
                            .padding(16)
                            .frame(width: contentW * 0.38)
                            .opacity(isPresented ? 1 : 0)
                    }
                } else {
                    VStack(spacing: 0) {
                        dotSlot
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        NumberPadView(onKey: handleKey)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                            .frame(height: contentH * 0.45)
                            .opacity(isPresented ? 1 : 0)
                    }
                }
            }
            .frame(width: contentW, height: contentH)
            .rotationEffect(rotation)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color.black.opacity(isPresented ? 1 : 0))
        .allowsHitTesting(isPresented)
        .onChange(of: isPresented) { _, newValue in
            if newValue {
                inputText = ""
                direction = nil
            }
        }
    }

    @ViewBuilder
    private var dotSlot: some View {
        if isPresented {
            overlayDots
                .padding(24)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var overlayDots: some View {
        let dots = DotNumberView(number: displayNumber, direction: direction, animateEntrance: false)
        if let ns = dotNamespace {
            dots.matchedGeometryEffect(id: matchId, in: ns)
        } else {
            dots
        }
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
        case .confirm:
            if !inputText.isEmpty, let value = Int(inputText) {
                lifeTotal = value
            }
            onDismiss()
        }
        let newNumber = displayNumber
        if newNumber != oldNumber {
            direction = newNumber > oldNumber ? .increasing : .decreasing
        }
    }
}
