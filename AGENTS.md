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
Home Screen display name: `Scoreboard`.
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
- Focused commander-damage mode temporarily rotates every board number toward
  the selected recipient, regardless of each source cell's normal seat rotation.

When adding layout, gesture, or badge behavior, route orientation through the
existing helpers (`PlayerCellView.playerFraction`, `PlayerLayoutIconView`'s
rotation handling, and `PlayerSeat.rotationDegrees`) instead of comparing raw
screen coordinates.

## Current User Experience

- The app starts a 4-player `fourA` game by default.
- Two-player games start at 20 life; all other layouts start at 40.
- Tap a player's left/right side for life -1/+1, registered on touch-down.
- Hold a side after 0.5s to repeat in +/-10 steps every 0.35s.
- Tap the fixed center band over a life total to enter commander-damage mode
  with that player as the recipient.
- Hold the fixed center band over the number for 0.5s to open exact life input.
- Exact life input includes six OKLCH dot-shaped seat-color chips above the life total:
  colorless, white, blue, black, red, and green. Colorless is exclusive; one
  through five mana colors can be combined, and the choice stays with that
  player for the current game. Colorless is fixed pure RGB white; white mana is
  a deep, saturated cream-yellow; and black mana is a light muted purple.
- Tap the life total in the input overlay to confirm.
- Swipe across the board to reset. A committed reset wipes cells off, shows the
  layout selector, then starts a clockwise lighthouse sweep after selection.
- The lighthouse beam rotates clockwise from the board center, flashing each
  active life-total dot individually as it crosses it, accelerates, and lands
  on a random starting player.
- While the beam is sweeping, every non-dot element is fully invisible:
  adjustment icons, toolbar controls, and debug skeletons.
  Their hit regions stay active so any touch can still finish the animation.
- The chosen player's life stays bright while every other life total begins
  fully invisible and fades from zero to full opacity over three seconds. Any
  screen interaction completes that fade with a short spring without consuming
  the interaction.
- Entering commander mode sends a radial dot ripple from the recipient's life
  total. Every other cell becomes the damage dealt by that source player to the
  recipient, starts at zero, and rotates to face the recipient.
- Source damage totals use the board's normal left/right -/+ controls and repeat
  behavior. Each applied damage point also subtracts one recipient life; reducing
  damage restores the same amount of life.
- The recipient's live life total stays visible at 30% opacity without adjust
  controls. Tap its fixed center band to exit with the reverse radial ripple.
- Commander damage is assigned only in focused commander mode, not in the exact
  life input overlay.
- The bottom-right toolbar has two buttons: dot-font cycle and grid skeleton.
- The dot-font cycle advances through tall, narrow, normal, wide, xwide, and
  xxwide bitmap styles.
- The grid skeleton draws a green border at the physical screen edges, green
  board/cell outlines, and orange region outlines. Orange follows the full tap
  geometry, not the visual content padding: each cell is divided into a fixed
  center interaction band and the surrounding -/+ regions.

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

- `lifetrack/Models/Player.swift` - `Player`, default life 40, and lethal
  commander damage 21, plus the player's selected seat colors.
- `lifetrack/Models/SeatColor.swift` - the six seat-color choices, their OKLCH
  coordinates, deterministic per-dot variance, neutral-center interpolation,
  gamut fitting, and sRGB output.
- `lifetrack/Models/PlayerLayout.swift` - all layout variants, `PlayerSeat`,
  `BoardInsets`, and selector display order.
- `playercounts/*.svg` - canonical source artwork for seat dots. When changing a
  seating layout, update the SVG first, then the Swift seat data.

Main board and cell views:

- `lifetrack/Views/GameBoardView.swift` - projects `cellRect` to board slots,
  applies inter-cell gutters, computes uniform board dot size, owns reset swipe,
  focused commander mode, radial transitions, first-player selection, and debug
  skeleton layers.
- `lifetrack/Views/PlayerCellView.swift` - one player's life area, rotated
  content container, life/commander gestures, +/- icons, transient net-change
  readout, ripple/sweep fade, and edit request.
- `lifetrack/Views/PlayerLayoutIconView.swift` - mini seating diagram for the
  layout selector.

Input and selector:

- `lifetrack/Views/LifeInputOverlay.swift` - full-screen editor with the same
  slot-first layout model as the board: a rotated content container, full-height
  left-side life-total region, right-side number pad, and its own grid skeleton.
  Keep the dot-number hero transition:
  each overlay dot starts at its corresponding position in the originating
  cell's visual dot pattern and animates independently into the final grid slot;
  dismissal reverses the same per-dot motion back to the board.
- `lifetrack/Views/SeatColorPickerView.swift` - the six accessible dot-shaped
  chips used to choose an exclusive colorless seat or any mana-color mix.
- `lifetrack/Views/NumberPadView.swift` - 3 by 4 number pad (`1...9`, clear
  `×`, `0`, backspace) and key frames for overlay skeleton drawing. Tapping the
  life total confirms/dismisses the overlay.
- `lifetrack/Views/LayoutSelectorView.swift` - full-screen 2-column by 4-row
  selector for all player-count/layout variants.

Dot and typography systems:

- `lifetrack/Views/DotPatterns.swift` - bitmap dot-font catalog, active font
  setting, `ChangeDirection`, and row-stagger timing.
- `lifetrack/Views/DotDigitView.swift` - one digit as animated UIKit dot views,
  including deterministic OKLCH color assignment, per-dot edit heroes,
  lighthouse-beam projection, and additive organic shake.
- `lifetrack/Views/DotNumberView.swift` - number splitting, dot-size fitting,
  digit layout, font-change rebuilds, sweep/reset forwarding.
- `lifetrack/Views/RollingNumberText.swift` - hosted SwiftUI rolling numeric
  text used by the transient life-delta readout.
- `lifetrack/Views/Karl.swift` - bundled Karl font factories.
- `lifetrack/Views/Typography.swift` - central Karl text tokens for the keypad
  and transient life delta readout.

Assets/resources:

- `lifetrack/Assets.xcassets/IconPlus.imageset` and
  `lifetrack/Assets.xcassets/IconMinus.imageset` - shared app-wide +/- glyphs.
- `lifetrack/Assets.xcassets/icon-*.imageset` - remaining action icons.
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
`PlayerCellView.contentInset`, and `verticalInset`. Every cell then receives the
minimum fitting size, capped at 18pt, so board dots stay uniform. The input
overlay caps its editable life-total dots at 28pt so the number stays prominent
without overwhelming the keypad.

The seat-color chips use that same live dot size and corner-radius ratio, with
one empty dot-width between adjacent chips. In side-player input layouts, their
centerline matches the first keypad row while the life total occupies the
remaining three-row band. Selection adds a 2pt white outline outside a 1pt clear
gap without changing chip geometry.

Seat colors are distributed deterministically across each digit so the same
player and palette do not flicker or reshuffle during ordinary animation. Each
dot receives a small stable OKLCH lightness, chroma, and hue offset, except
colorless dots, which remain pure RGB white. Multi-color
palettes use a seeded irregular dominant-color assignment, then interpolate
each dot 10-45% toward another selected color. The shortest OKLCH hue arc keeps
its chroma when every mana-color landmark it crosses is selected, allowing
natural adjacent blends such as white-to-red through orange. If that arc would
cross a deselected mana color, interpolation routes through the achromatic
center instead; white-to-blue therefore avoids producing green. This preserves
stable in-between shades without stripes or gradients.

## Player Cell Layout and Touch

`PlayerCellView.layoutSubviews` sizes `contentContainer` in the player's reading
coordinate space. For +/-90 degree cells, width and height are swapped before
the final rotation transform is applied. The content container is centered in the
cell, then rotated.

Current content margins:

- `contentInset = 12` left/right in player reading space.
- `verticalInset = 8` top/bottom in player reading space.
- `editZoneWidth = 100`, centered on the full cell axis for commander entry and
  exact life editing.

Important touch behavior:

- Life zones are computed from full `PlayerCellView.bounds`, not the inset
  content container.
- The fixed center interaction zone is centered along the player's
  left-to-right axis. A tap enters commander mode; a 0.5-second hold opens exact
  life input.
- The +/- zones fill the rest of the cell outside that center band.
- `playerFraction(at:)` maps a point to the player's left-to-right axis for all
  four rotations. Use it instead of direct `x` checks.
- Center taps commit on touch-up, so a reset swipe beginning over the number
  cancels the tap instead of entering commander mode.

## Animation and Haptics

- Life dot changes animate with row-staggered UIKit spring animations.
- Changing a seat-color chip crossfades every dot to its new deterministic
  OKLCH palette with a few milliseconds of stable per-dot delay. Chips animate
  between dimmed and selected outlined states and provide selection haptics.
- Pressing anywhere in a player's life interaction area scales the whole dot
  number from 100% to 95% through a dedicated center-anchored wrapper, then
  springs it back on release or cancel. Keep this press transform off
  `dotNumberView` itself because life-delta updates relayout that view.
- Opening and closing exact life input use mirrored directional per-dot heroes.
  Dots on the leading edge of travel begin first, with up to 160ms of stagger
  across the pattern and up to 24ms of stable per-dot noise. Exit recalculates
  the leading edge toward the original board position, naturally flipping the
  delay order. The delayed trailing dots temporarily exaggerate spacing like a
  stretched slinky before each dot springs into place.
- Commander-mode transitions use the same 0.3-second per-dot spring as ordinary
  digit rolls, with radial delays based on distance from the recipient's number.
  As the wavefront reaches each dot, an additive position pulse briefly pushes
  it away from the recipient like a displacement map before it settles without
  changing the dot's model-layer layout. Exiting reverses that displacement,
  pulling reached dots toward the recipient as the wave collapses edge-in.
  Ripple-out delays include up to 48ms of stable per-dot timing noise so nearby
  dots do not collapse in perfectly uniform rings.
  The incoming ripple begins halfway through the outgoing wave delay (0.16
  seconds after it starts), so both number states share the midpoint. Entry
  expands center-out; exit reverses the timing and collapses edge-in.
- `.decreasing` rolls top-to-bottom; `.increasing` rolls bottom-to-top.
- Animated changes use `.beginFromCurrentState`, so rapid taps retarget the
  current animation instead of queueing delayed rolls.
- Reset swipe fades dots and adjustment controls by position against a moving
  edge.
- After layout selection, an imaginary clockwise beam rotates from the board
  center and strobes active dots individually. The beam uses a smooth quintic
  falloff with a 0.32-radian base half-width on both sides and scales dots from
  effectively 0% to 100% as it passes, matching the ripple's scale range. A
  4.2-second display-link sweep completes eight
  rotations with a 2.15-power ease-in, starting deliberately slowly and
  finishing at a moderated speed. The beam widens by the full arc traveled each
  frame so acceleration cannot skip dots. Each dot also has a stable phase
  offset up to 15% of the beam half-width (0.048 radians at the base width),
  softening uniform neighboring triggers without introducing flicker. The sweep
  then lands on a random player. Unlit dots are fully invisible, and non-winners
  fade from zero to full brightness over three seconds.
- Any touch cancels the remaining first-player sweep/fade and restores every
  life total with a short spring while allowing the original interaction.
- Player controls, toolbar chrome, and debug skeletons snap invisible when the
  lighthouse starts and return with a short spring as soon as it lands.
- The selected first player's active dots receive a strong independent-dot
  shake on landing. Life and commander-damage shake intensity follows the
  absolute accumulated value in the transient +/- readout: +/-1 starts with a
  noticeable kick, repeated changes ramp up, opposing changes ramp back down, and
  the next change restarts at minimum intensity after the readout expires. Each
  adjustment sends that shake across only its number as a directional ripple
  emanating from the visible minus or plus icon. The ripple has a separate
  minimum displacement strength, so even a restrained +/-1 shake visibly pushes
  each reached dot away from the tapped control. Each dot's displacement amount
  and wave timing use the shared stable 15%-of-effect-span jitter; the digit
  container itself does not move during adjustment ripples.
- Dot shakes use additive position keyframes with unique render-server
  animations, so repeated taps stack without interfering with the existing
  opacity and scale springs. Each digit container receives 50% of the dot
  amplitude as coherent motion beneath the organic lighthouse shake. Directional
  adjustment ripples move only individual dots.
- Lighthouse phase noise, commander ripple timing noise, and edit-hero timing
  noise all use the same stable 15%-of-effect-span rule.
- Light haptic: single life and commander-damage ticks.
- Selection haptic: each player sector crossed by the first-player beam.
- Medium haptic: bulk life repeat, edit overlay activation, reset commit.
- Heavy haptic: first-player selection landing.

## Documentation Gotchas

- This is UIKit, not the original SwiftUI prototype. There is no
  `lifetrackApp.swift` or `ContentView.swift` in the current app.
- UIKit work should follow the repository's `uikit-expert` skill in
  `.agents/skills/uikit-expert`; `skills-lock.json` records its source and the
  `.claude/skills/uikit-expert` symlink exposes the same guidance to compatible
  agents. Keep all three in sync when upgrading the skill.
- SwiftUI is still present through `UIHostingController` for the transient
  rolling life-delta readout.
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
