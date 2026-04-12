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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                GameBoardView(players: $players)

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
            }
        }
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .onAppear { resetPlayers() }
    }

    private func resetPlayers() {
        players = (0..<playerCount).map { Player(id: $0, lifeTotal: Player.defaultLife) }
    }
}

#Preview {
    ContentView()
}
