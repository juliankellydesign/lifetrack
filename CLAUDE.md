# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Keeping this file current

**You must update CLAUDE.md whenever you add or materially change a feature, file, or interaction pattern.** Treat the doc as part of the change, not an afterthought:

- Adding a new `View` / `Model` / behavior? Add it to the relevant section below.
- Changing a touch / gesture / haptic pattern? Update the description here so the next agent reads the current rules, not the stale ones.
- Renaming or removing a file? Update or delete the reference in the same commit.
- Recent PR descriptions are a good source of truth — `gh pr list --state merged --limit 5 --json number,title,body` to grab summaries when catching up.

If you ship a change without updating this file, the next agent will work from a wrong mental model. Don't make them re-discover what you already learned.

## Project Overview

Lifetrack is a Magic: The Gathering life counter iOS app. The phone sits at the center of the table and tracks life totals for 2–6 players. Portrait-locked, full-screen, no status bar. **UIKit** (rewritten from the original SwiftUI prototype), with SwiftUI hosted only where useful (e.g. `.contentTransition(.numericText)` for badge digit rolls).

Bundle ID: `jfk.lifetrack`. Targets iOS/iPadOS 26.1. No external dependencies.

## Build & Run

```bash
# Build for simulator
xcodebuild -project lifetrack.xcodeproj -scheme lifetrack \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Install and launch on booted simulator
xcrun simctl install booted <path-to-.app>
xcrun simctl launch booted jfk.lifetrack
```

No test targets configured yet. Use the simulator for verification.

## Architecture

### Entry point
- `AppDelegate.swift` — `@main`, vends a `UISceneConfiguration` for the `UIScene` lifecycle.
- `SceneDelegate.swift` — Owns the `UIWindow`, sets `GameViewController` as root, disables the idle timer so the screen stays awake.
- `GameViewController.swift` — Root controller. Manages player count, the `[Player]` array, the editing state, the bottom toolbar (player count selector, font picker, reset), the swipe-to-reset gesture, and the `LifeInputOverlay`.

### Models
- `Models/Player.swift` — `Player` struct (`id`, `lifeTotal`, `commanderDamage: [Int: Int]`, `counters: [LifeCounter: Int]`). Constants: `defaultLife = 40`, `lethalCommanderDamage = 21`. `LifeCounter` enum: `poison`, `energy`, `rad`, `experience`.

### Layout system
- `Views/GameBoardView.swift` — Arranges `PlayerCellView`s using absolute positioning (`CGRect` slots) based on player count. Computes a **uniform dot size** (min across all cells) so dots are consistent even when cell sizes differ (e.g. full-width vs half-width in 3/5-player layouts). Hosts the swipe-to-reset sweep math.
- Layouts: 2p (1+1), 3p (2+1), 4p (2+2), 5p (2+2+1), 6p (1+2+2+1). Full-width cells get 0°/180° rotation, half-width cells get ±90°.

### Player cells
- `Views/PlayerCellView.swift` — One player's life block. Composes a `DotNumberView` (life total) and a `PlayerCellBadgeBar` (commander damage + counters), rotated together to match cell orientation.
  - **Touch model**:
    - **Left / right thirds**: single tap commits ±1 on touchUp (light haptic). Holding past `holdActivationDelay` (0.5s) starts repeating ±10 every `repeatInterval` (0.35s) with a medium haptic per tick. If a hold starts repeating, the touchUp tap is suppressed.
    - **Center third**: hold 0.5s opens the number-input overlay (medium haptic on activation).
  - 3D tilt on press (7°, axis rotates with the cell so tilt always pitches "into the table" relative to the player).
  - `ChangeDirection` enum drives the staggered dot animation direction (top→bottom for decrease, bottom→top for increase).
- **Rotation-aware tap zones**: `playerFraction` maps the touch point to a 0→1 value along the player's left-to-right axis, accounting for 0°/±90°/180° rotation.

### Badges (under each life total)
- `Views/PlayerCellBadgeBar.swift` — Combined row of commander-damage badges + counter badges along the player's near edge.
- `Views/CommanderDamageBadge.swift` / `CommanderDamageRowView.swift` — One badge per opponent. The badge icon is a mini diagram of the seating layout with the source opponent's dot at full opacity and the rest dimmed. Numeral hidden at 0; turns red at `lethalCommanderDamage` (21). Long-press editor exposes ± targets above/below for tap-to-increment with hold-to-repeat (light haptic per tick), clamped at 0.
- `Views/CommanderIconView.swift` — The mini seating diagram. Counter-rotates so the highlighted dot tracks the real opponent at the table.
- `Views/LifeCounterBadge.swift` / `LifeCounterRowView.swift` — Poison / energy / rad / experience counters; same edit affordances as commander damage.
- `Views/CounterBadge.swift` — Shared base for both badge types. Damage / counter numerals are rendered via SwiftUI `Text` hosted in UIKit using `.contentTransition(.numericText(value:))` driven by an `@Observable` model so digits roll up/down per change.

### Number input overlay
- `Views/LifeInputOverlay.swift` — Full-screen black backdrop with a hero animation that converges onto the originating cell. Content is inset inside `safeAreaInsets` (Dynamic Island + home indicator) while the backdrop paints edge-to-edge. Tap the life total to confirm and dismiss.
- `Views/NumberPadView.swift` — 50/50 numpad split, 8% white pill backgrounds at 40pt, confirm/delete keys (32pt action icons).

### Dot-matrix rendering
- `Views/DotPatterns.swift` — Static 5×7 grid patterns for digits 0-9 and minus sign, stored as `[Bool]` arrays. Multiple font variants (Classic, Chunky, Display, Mini, Karl).
- `Views/DotDigitView.swift` — Renders one digit as 35 dots positioned via offsets. Each dot animates independently with a per-row staggered delay.
- `Views/DotNumberView.swift` — Splits a number into digits, computes dot size from available space, lays out `DotDigitView`s. Accepts optional `maxDotSize` cap so all cells share a uniform dot size. Also implements `applySweep(...)` / `resetSweep(...)` for the swipe-to-reset positional fade.
- `Views/Karl.swift` — Karl typeface bundled in `Resources/Fonts/`. Switchable via the gear menu in the toolbar.

### Swipe-to-reset
- A pan gesture on `GameBoardView` projects each cell's center onto the swipe axis; dots fade and scale individually based on the finger's leading edge. At >50% travel the reset commits (medium haptic) and freshly built cells animate back in from the same direction.

### Key patterns
- **Rotation handling**: Content is sized for the rotated coordinate space (width/height swapped for ±90°), then a `CGAffineTransform` rotation is applied, then the frame is re-established. The 3D tilt axis rotates with the cell: `axis: (x: -sin(R), y: cos(R), z: 0)`.
- **Animation**: Per-dot spring animations with row-based delay. `ChangeDirection` is set in the same state transaction as the value change so dots see the correct delay.
- **Haptics**: Light impact for per-tick changes (life ±1, badge ±1). Medium impact for bulk repeats (life ±10), edit-overlay activation, and swipe-reset commit. Pre-warmed `UIImpactFeedbackGenerator`s held as static properties on `PlayerCellView`.

## gstack

Use the `/browse` skill from gstack for all web browsing. Never use `mcp__claude-in-chrome__*` tools.

Available skills: `/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, `/design-consultation`, `/design-shotgun`, `/design-html`, `/review`, `/ship`, `/land-and-deploy`, `/canary`, `/benchmark`, `/browse`, `/connect-chrome`, `/qa`, `/qa-only`, `/design-review`, `/setup-browser-cookies`, `/setup-deploy`, `/retro`, `/investigate`, `/document-release`, `/codex`, `/cso`, `/autoplan`, `/plan-devex-review`, `/devex-review`, `/careful`, `/freeze`, `/guard`, `/unfreeze`, `/gstack-upgrade`, `/learn`.
