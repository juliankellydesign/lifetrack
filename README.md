# Lifetrack

A life counter for **Magic: The Gathering**, built for iOS/iPadOS 26.1.

The phone sits flat in the middle of the table. Each player gets a wedge of the screen, oriented so their life total reads right-side-up from where they're sitting. Tap the left or right side of your area to subtract or add. Hold to repeat. Hold the center to type in an exact number.

Supports 2–6 players. Portrait-locked, full-screen, status bar hidden, idle timer disabled so the screen never sleeps mid-game.

## Planned: Commander support

Commander (EDH) is a multiplayer MTG format with two rules that change what a life tracker has to do:

1. **Players start at 40 life** instead of 20.
2. **Commander damage**: if a single opponent's commander deals 21 or more combat damage to you over the game, you lose — regardless of your current life total.

This means each player needs to track, separately, how much combat damage they've taken from *each* opposing commander. In a 4-player pod that's 3 counters per player; in a 6-player pod, 5 counters per player. Partner commanders (two commanders on one player) need their damage tracked independently.

To add:

- Mode toggle: Standard (20 life) / Commander (40 life)
- Per-player commander-damage matrix, accessible from each player's cell
- Auto-eliminate a player when any single commander-damage counter reaches 21
- Optional: poison counters (lose at 10), since EDH games often involve infect/toxic

## Build

```bash
xcodebuild -project lifetrack.xcodeproj -scheme lifetrack \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

xcrun simctl install booted <path-to-.app>
xcrun simctl launch booted jfk.lifetrack
```

Bundle ID: `jfk.lifetrack`. No external dependencies.
