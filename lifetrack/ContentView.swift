//
//  ContentView.swift
//  lifetrack
//
//  Created by Julian Kelly on 4/11/26.
//

import SwiftUI

struct ContentView: View {
    @State private var playerCount = 4
    @State private var players: [Player] = []
    @State private var editing: EditingInfo? = nil
    @State private var overlayPlayerIndex = 0
    @State private var overlayRotation: Angle = .zero
    @Namespace private var dotTransition

    private var overlayLifeBinding: Binding<Int> {
        guard !players.isEmpty, overlayPlayerIndex < players.count else {
            return .constant(Player.defaultLife)
        }
        return $players[overlayPlayerIndex].lifeTotal
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                GameBoardView(
                    players: $players,
                    onEditRequested: { index, rotation in
                        overlayPlayerIndex = index
                        overlayRotation = rotation
                        withAnimation(.easeInOut(duration: 0.1)) {
                            editing = EditingInfo(playerIndex: index, rotation: rotation)
                        }
                    },
                    editingIndex: editing?.playerIndex,
                    dotNamespace: dotTransition
                )

                if editing == nil {
                    // Player count selector
                    HStack(spacing: 20) {
                        ForEach(2...6, id: \.self) { count in
                            Button {
                                playerCount = count
                                resetPlayers()
                            } label: {
                                Text("\(count)")
                                    .font(.headline)
                                    .foregroundColor(count == playerCount ? .white : .gray)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(count == playerCount ? Color.white.opacity(0.2) : Color.clear)
                                    )
                            }
                        }

                        Spacer()

                        Button {
                            resetPlayers()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .transition(.opacity)
                }
            }

            LifeInputOverlay(
                isPresented: editing != nil,
                lifeTotal: overlayLifeBinding,
                rotation: overlayRotation,
                onDismiss: {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        editing = nil
                    }
                },
                dotNamespace: dotTransition,
                matchId: overlayPlayerIndex
            )
        }
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .statusBarHidden()
        .onAppear { resetPlayers() }
        .animation(.easeInOut(duration: 0.1), value: editing != nil)
    }

    private func resetPlayers() {
        players = (0..<playerCount).map { Player(id: $0, lifeTotal: Player.defaultLife) }
    }
}

private struct EditingInfo {
    let playerIndex: Int
    let rotation: Angle
}

#Preview {
    ContentView()
}
