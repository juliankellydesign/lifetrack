# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lifetrack is a Magic: The Gathering life counter iOS app. The phone sits at the center of the table and tracks life totals for 2-6 players. Portrait-locked, full-screen, no status bar.

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

No test targets configured yet. Use Xcode previews or simulator for verification.

## Architecture

### Entry point
- `lifetrackApp.swift` — `@main`, disables idle timer so screen stays awake
- `ContentView.swift` — Root view. Manages player count, player array, editing state. Houses the bottom toolbar (player count selector + reset) and the number-input overlay.

### Layout system
- `GameBoardView.swift` — Arranges `PlayerCellView`s using absolute positioning (`CGRect` slots) based on player count. Computes a **uniform dot size** (min across all cells) so dots are consistent even when cell sizes differ (e.g., full-width vs half-width in 3/5-player layouts).
- Layouts: 2p (1+1), 3p (2+1), 4p (2+2), 5p (1+2+2), 6p (1+2+2+1). Full-width cells get 0°/180° rotation, half-width cells get ±90°.

### Player cells
- `PlayerCellView.swift` — One player's life block. Contains:
  - Dot-matrix life total (via `DotNumberView`), rotated to match cell orientation
  - Tap/hold gesture: left/right thirds increment/decrement with 0.3s repeat; center third hold opens number input
  - 3D tilt on press (7° `rotation3DEffect`, axis rotates with cell orientation)
  - `ChangeDirection` enum — controls staggered dot animation direction (top→bottom for decrease, bottom→top for increase)
- **Rotation-aware tap zones**: A `playerFraction` helper maps screen touch position to a 0→1 value along the player's left-to-right axis, accounting for 0°/90°/-90°/180° rotation.

### Dot-matrix rendering (pure SwiftUI)
- `DotPatterns.swift` — Static 5×7 grid patterns for digits 0-9 and minus sign, stored as `[Bool]` arrays
- `DotDigitView.swift` — Renders one digit as 35 `Circle` views positioned via `offset`. Each dot is a `DotView` with its own `@State isShowing` that animates independently via `onChange(of: isActive)` with per-row staggered delay.
- `DotNumberView.swift` — Splits a number into digits, computes dot size from available space (via `GeometryReader`), lays out `DotDigitView`s in an `HStack`. Accepts optional `maxDotSize` cap for uniform sizing.

### Key patterns
- **Rotation handling**: Content is sized for the rotated coordinate space (width/height swapped for ±90°), then `.rotationEffect(rotation)` is applied, then `.frame()` re-establishes the cell bounds. The 3D tilt axis also rotates: `axis: (x: -sin(R), y: cos(R), z: 0)`.
- **Animation**: Per-dot spring animations with row-based delay. Direction (increasing/decreasing) is set in the same state transaction as the value change so dots see the correct delay.

## gstack

Use the `/browse` skill from gstack for all web browsing. Never use `mcp__claude-in-chrome__*` tools.

Available skills: `/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, `/design-consultation`, `/design-shotgun`, `/design-html`, `/review`, `/ship`, `/land-and-deploy`, `/canary`, `/benchmark`, `/browse`, `/connect-chrome`, `/qa`, `/qa-only`, `/design-review`, `/setup-browser-cookies`, `/setup-deploy`, `/retro`, `/investigate`, `/document-release`, `/codex`, `/cso`, `/autoplan`, `/plan-devex-review`, `/devex-review`, `/careful`, `/freeze`, `/guard`, `/unfreeze`, `/gstack-upgrade`, `/learn`.
