# Lifetrack

A life counter for **Magic: The Gathering**, built for iOS/iPadOS 26.1.

The phone sits flat in the middle of the table. Each player gets a wedge of the screen, oriented so their life total reads right-side-up from where *they're* sitting — south-side players read normally, the player across the table reads upside-down (from the phone's view), side players read sideways. Tap the left or right side of your area to subtract or add. Hold to repeat. Hold the center to type in an exact number.

Supports 2–6 players. Portrait-locked, full-screen, status bar hidden, idle timer disabled so the screen never sleeps mid-game.

## Seating layouts

Lifetrack is built around a phone lying flat with people seated around its edges, so it ships multiple **seating layouts** — not just player counts. Counts of 4, 5, and 6 each have two variants tuned to how players actually sit:

- **2, 3** — single arrangement each
- **4a** corners / **4b** diamond
- **5a** / **5b**
- **6a** 3×2 grid / **6b** corners + sides

Each layout places life blocks where they paint on the board *and* rotates each one toward the player who reads it, so a block in the upper-left of the screen can still belong to someone seated on the left edge of the table.

You pick a layout from a full-screen selector — on first launch and after every reset. The app boots into 4a by default.

## Commander support

The app is Commander-first: players start at **40 life**, and it tracks the things an EDH game needs.

- **Commander damage.** Each player has a badge per opponent showing how much combat damage they've taken from that opponent's commander. The badge renders a mini seating diagram with the source opponent's seat highlighted and counter-rotated toward the viewing player, so it literally points the way you'd look to find that opponent at the table. The numeral hides at 0 and turns red at **21** (the lethal threshold). Long-press a badge to adjust it with tap-to-increment and hold-to-repeat.
- **Other counters.** Poison, energy, rad, and experience counters sit alongside the commander-damage badges, with the same long-press editing.

## Interaction

- **Adjust life.** Tap the left third of your area for −1, the right third for +1 (committed on lift, with a light haptic). Hold a side past ~0.5s to repeat in steps of 10 with a medium haptic per tick.
- **Type an exact total.** Hold the center of your area to open a full-screen number pad that animates out of your cell; tap the total to confirm.
- **Reset the game.** Swipe across the board to wipe every life total off, dot by dot, following your finger. Commit the swipe and the layout selector fades in; pick a layout and the new totals roll back in one cell at a time, clockwise around the table — the same per-tap dot animation, amplified across all seats.
- **Grid skeleton.** A toggle button in the bottom-right overlays the seating grid — the board boundary and every cell outline — on top of the totals, so you can see exactly how the current layout divides the screen. While it's on, the number-input view shows its own skeleton too (life number, counter/damage rows, and every keypad key). Tap again to hide it.

## Implementation notes

UIKit, rewritten from an original SwiftUI prototype. SwiftUI is hosted only where it earns its place — e.g. `.contentTransition(.numericText)` for rolling badge digits. Life totals are drawn as a 5×5 dot matrix, with each dot animating independently on a row-staggered spring. No external dependencies.

For the architecture, the table-centric mental model, and per-file detail, see [`CLAUDE.md`](CLAUDE.md).

## Build

```bash
xcodebuild -project lifetrack.xcodeproj -scheme lifetrack \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

xcrun simctl install booted <path-to-.app>
xcrun simctl launch booted jfk.lifetrack
```

Bundle ID: `jfk.lifetrack`. No external dependencies.
