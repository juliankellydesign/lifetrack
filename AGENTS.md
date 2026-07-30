# Lifetrack Project Guide

This is the canonical project guide for Lifetrack. Keep this file current with
the code. `CLAUDE.md` and `README.md` intentionally point here so the project has
one source of truth instead of three drifting documents.

## Documentation Rule

When a change materially affects a feature, file, interaction pattern, build
setting, or user-visible behavior, update this file in the same commit. Do not
restore separate long-form copies in `CLAUDE.md` or `README.md` unless the user
explicitly asks for that split again.

## Project Overview

Lifetrack is a Magic: The Gathering life counter for iOS and iPadOS. The device
sits face-up in the center of the table and tracks life totals for 2-6 players
seated around it. Each player's area is rotated toward that player, not toward
the device owner. The app is portrait-locked, full-screen, hides the status bar,
requires full screen, and disables idle sleep during play.

Bundle ID: `jfk.lifetrack`.
Deployment target: iOS/iPadOS 26.1.
Framework style: UIKit app, with SwiftUI hosted only where useful for rolling
numeric text.
External dependencies: none.

## Build and Run

```bash
xcodebuild -project lifetrack.xcodeproj -scheme lifetrack \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

xcrun simctl install booted <path-to-.app>
xcrun simctl launch booted jfk.lifetrack
```

There are no test targets configured. Use a simulator run for verification.

## Table Mental Model

The phone is a shared board in the middle of a real table.

- `rotationDegrees` is where the player's head points in screen space:
  `0` = south/bottom, `180` = north/top, `90` = west/left, `-90` = east/right.
- `cellRect` says where the cell paints. `rotationDegrees` says how the player
  reads it. Do not infer rotation from a cell's screen position.
- Side players read sideways, top players read upside-down from the phone's
  point of view, and each badge/gesture should respect that orientation.
- Commander-damage badges show a mini table layout with the source opponent
  highlighted and counter-rotated for the viewing player.

When adding layout, gesture, or badge behavior, route orientation through the
existing helpers (`PlayerCellView.playerFraction`, `PlayerLayoutIconView`'s
rotation handling, and `PlayerSeat.rotationDegrees`) instead of comparing raw
screen coordinates.

## Current User Experience

- The app starts a 4-player `fourA` game by default.
- Players start at 40 life.
- Tap a player's left/right side for life -1/+1, registered on touch-down.
- Hold a side after 0.5s to repeat in +/-10 steps every 0.35s.
- Hold the fixed center band over the number for 0.5s to open exact life input.
- Tap the life total in the input overlay to confirm.
- Swipe across the board to reset. A committed reset wipes cells off, shows the
  layout selector, then rolls new cells back in clockwise after selection.
- Tap a commander-damage badge in a player cell to add 1 commander damage from
  that opponent; hold it to repeat +1 ticks. Each tick also subtracts 1 life
  from the damaged player.
- In the input overlay, counters and commander damage render compactly as
  `icon + value` (or `icon + +` at zero) but remain editable: tap/hold the right
  side to increment, and tap/hold the left side to decrement once nonzero.
- Counters supported: poison, energy, rad, experience.
- Commander damage turns red at 21. Poison counters turn red at 10. Energy,
  rad, and experience counters do not have static lethal thresholds.
- The bottom-right toolbar has two buttons: dot-font cycle and grid skeleton.
- The dot-font cycle advances through tall, narrow, normal, wide, xwide, and
  xxwide bitmap styles.
- The grid skeleton draws a green border at the physical screen edges, green
  board/cell outlines, and orange region outlines. Orange follows the full tap
  geometry, not the visual content padding: life zones fill the cell outside the
  commander band, while commander badges fill the full near-edge band as columns.

## Source Layout

Entry point and root controller:

- `lifetrack/AppDelegate.swift` - `@main`, provides the scene configuration.
- `lifetrack/SceneDelegate.swift` - creates the `UIWindow`, installs
  `GameViewController`, and disables the idle timer.
- `lifetrack/GameViewController.swift` - owns active `PlayerLayout`, player
  state, editing state, toolbar, reset flow, `GameBoardView`,
  `LifeInputOverlay`, `LayoutSelectorView`, and the root screen-edge skeleton
  border shown in grid mode.

Models:

- `lifetrack/Models/Player.swift` - `Player`, `LifeCounter`, default life 40,
  lethal commander damage 21.
- `lifetrack/Models/PlayerLayout.swift` - all layout variants, `PlayerSeat`,
  `BoardInsets`, and selector display order.
- `playercounts/*.svg` - canonical source artwork for seat dots. When changing a
  seating layout, update the SVG first, then the Swift seat data.

Main board and cell views:

- `lifetrack/Views/GameBoardView.swift` - projects `cellRect` to board slots,
  applies inter-cell gutters, computes uniform board dot size, owns reset swipe,
  roll-in animation, and debug skeleton layers.
- `lifetrack/Views/PlayerCellView.swift` - one player's life area, rotated
  content container, life gestures, commander badge hit routing, +/- icons,
  transient net-change readout, sweep fade, and edit request.
- `lifetrack/Views/PlayerCellBadgeBar.swift` - 44pt near-edge badge band that
  lays out commander badges and counters; commander hit rects tile within the
  bar coordinate space.

Commander and counter badges:

- `lifetrack/Views/CommanderDamageBadge.swift` - commander badge with highlighted
  opponent layout icon, always-visible zero state, inline +1 tapping, red lethal
  color at 21.
- `lifetrack/Views/CommanderDamageRowView.swift` - commander badges in the input
  overlay with adjust controls.
- `lifetrack/Views/LifeCounterBadge.swift` and
  `lifetrack/Views/LifeCounterRowView.swift` - poison, energy, rad, and
  experience counters.
- `lifetrack/Views/CounterBadge.swift` - shared badge base, hosted SwiftUI
  `RollingCounterText`, inline display, overlay +/- editor, repeat behavior.
- `lifetrack/Views/PlayerLayoutIconView.swift` - mini seating diagram for the
  selector and commander badges.

Input and selector:

- `lifetrack/Views/LifeInputOverlay.swift` - full-screen editor with the same
  slot-first layout model as the board: a rotated content container, top-left
  counter row, two-row life-total region, bottom-left commander row, right-side
  number pad, and its own grid skeleton. Keep the dot-number hero transition:
  the overlay number starts at the originating cell's visual dot center/size and
  animates into this final grid slot.
- `lifetrack/Views/NumberPadView.swift` - 3 by 4 number pad (`1...9`, clear
  `×`, `0`, backspace) and key frames for overlay skeleton drawing. Tapping the
  life total confirms/dismisses the overlay.
- `lifetrack/Views/LayoutSelectorView.swift` - full-screen 2-column by 4-row
  selector for all player-count/layout variants.

Dot and typography systems:

- `lifetrack/Views/DotPatterns.swift` - bitmap dot-font catalog, active font
  setting, `ChangeDirection`, and row-stagger timing.
- `lifetrack/Views/DotDigitView.swift` - one digit as animated UIKit dot views.
- `lifetrack/Views/DotNumberView.swift` - number splitting, dot-size fitting,
  digit layout, font-change rebuilds, sweep/reset forwarding.
- `lifetrack/Views/Karl.swift` - bundled Karl font factories.
- `lifetrack/Views/Typography.swift` - central Karl text tokens for keypad,
  badges, and the transient life delta readout.

Assets/resources:

- `lifetrack/Assets.xcassets/IconPlus.imageset` and
  `lifetrack/Assets.xcassets/IconMinus.imageset` - shared app-wide +/- glyphs.
- `lifetrack/Assets.xcassets/icon-*.imageset` - counter and action icons. The
  life-counter icons are original-rendered white tile SVGs with black glyphs,
  not template-tinted assets.
- `lifetrack/Resources/Fonts` - Karl font files.

## Layout System

`PlayerLayout` defines each seat in normalized board coordinates. `GameBoardView`
projects those unit rects into its bounds. Any edge that is not on the board
boundary is inset by `BoardInsets.interCellGap / 2`, currently 10pt, producing a
20pt gutter between neighboring slots.

The supported layouts are:

- `two` - top and bottom.
- `three` - two left-edge players plus one full-height right-edge player.
- `fourA` - 2 by 2 corners.
- `fourB` - diamond layout.
- `fiveA` - 2 by 2 upper cluster plus one full-width bottom strip.
- `fiveB` - three left-edge thirds plus two right-edge halves.
- `sixA` - 3 by 2 grid.
- `sixB` - full-width top/bottom bands with two middle split bands.

The board normally targets 18pt life dots. `GameBoardView.uniformDotSize(for:)`
asks each slot how large a two-digit value can fit after accounting for rotation,
`PlayerCellView.contentInset`, `verticalInset`, and the 44pt badge band. Every
cell then receives the minimum fitting size, capped at 18pt, so board dots stay
uniform. The input overlay does not set `maxDotSize`, so its dots scale larger.

## Player Cell Layout and Touch

`PlayerCellView.layoutSubviews` sizes `contentContainer` in the player's reading
coordinate space. For +/-90 degree cells, width and height are swapped before
the final rotation transform is applied. The content container is centered in the
cell, then rotated.

Current content margins:

- `contentInset = 12` left/right in player reading space.
- `verticalInset = 8` top/bottom in player reading space.
- `commanderBandHeight = 44`, pinned to the player's near edge inside the
  rotated content container.
- `editZoneWidth = 100`, centered on the full cell axis for life editing.

Important touch behavior:

- Life zones are computed from full `PlayerCellView.bounds`, not the inset
  content container.
- The fixed center edit zone is centered along the player's left-to-right axis.
- The +/- zones fill the rest of the cell outside that center band.
- `playerFraction(at:)` maps a point to the player's left-to-right axis for all
  four rotations. Use it instead of direct `x` checks.
- Commander badge touches are routed through full-cell near-edge band rects that
  scale the visible `PlayerCellBadgeBar` columns out to the slot edges.

## Animation and Haptics

- Life dot changes animate with row-staggered UIKit spring animations.
- `.decreasing` rolls top-to-bottom; `.increasing` rolls bottom-to-top.
- Animated changes use `.beginFromCurrentState`, so rapid taps retarget the
  current animation instead of queueing delayed rolls.
- Reset swipe fades dots and badges by position against a moving edge.
- Reset roll-in starts from `snapToOff()` and restores cells in
  `clockwiseIndex * 100ms` order.
- Light haptic: single life ticks and badge ticks.
- Medium haptic: bulk life repeat, edit overlay activation, reset commit.

## Documentation Gotchas

- This is UIKit, not the original SwiftUI prototype. There is no
  `lifetrackApp.swift` or `ContentView.swift` in the current app.
- SwiftUI is still present through `UIHostingController` for rolling numeric text
  in badges and the transient life delta readout.
- The orange grid skeleton should share edges with the green cell slot wherever
  a tap target reaches the slot edge. A green/orange gap means either visual
  content padding is being drawn by mistake or hit geometry has regressed.
- `BoardInsets` is the global source for board/selector/overlay insets. Do not
  rederive those constants locally.
- `Typography` is the source for Karl text styles. Do not add ad-hoc font sizes
  in views.

## Verification Expectations

For code changes, build the app with the simulator command above. If the change
touches layout, gestures, reset flow, grid skeleton, or overlay presentation,
also run the app in Simulator and inspect the affected orientations/layouts.

No automated tests exist yet, so simulator verification is the current standard.

## gstack

Use the `/browse` skill from gstack for web browsing. Never use
`mcp__claude-in-chrome__*` tools.

Available gstack skills include `/office-hours`, `/plan-ceo-review`,
`/plan-eng-review`, `/plan-design-review`, `/design-consultation`,
`/design-shotgun`, `/design-html`, `/review`, `/ship`, `/land-and-deploy`,
`/canary`, `/benchmark`, `/browse`, `/connect-chrome`, `/qa`, `/qa-only`,
`/design-review`, `/setup-browser-cookies`, `/setup-deploy`, `/retro`,
`/investigate`, `/document-release`, `/codex`, `/cso`, `/autoplan`,
`/plan-devex-review`, `/devex-review`, `/careful`, `/freeze`, `/guard`,
`/unfreeze`, `/gstack-upgrade`, and `/learn`.
