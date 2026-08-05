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
Export compliance: the app does not use non-exempt encryption; generated
Info.plists set `ITSAppUsesNonExemptEncryption` to `NO`.

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
- Focused commander-damage mode rotates only commander-source damage totals
  toward the selected recipient. Life totals keep their normal seat rotations,
  including while they ripple out and while the recipient remains visible.

When adding layout, gesture, or badge behavior, route orientation through the
rotated content coordinate space, `PlayerLayoutIconView`'s rotation handling,
and `PlayerSeat.rotationDegrees` instead of comparing raw screen coordinates.

## Current User Experience

- The app starts a 4-player `fourA` game by default.
- The launch screen, app window, and game board use a solid black background.
- Two-player games start at 20 life; all other layouts start at 40.
- Tap a player's minus/plus region for life -1/+1, registered on touch-down.
  Each target spans the full player-cell height, is at least the 20pt icon plus
  20pt inline padding on both sides, and expands outward to the cell edge when
  more space is available.
- Applied increments play `ns_button_1`; applied decrements play `ns_button_2`.
  Keypad keys, seat-color chips, layout choices, and debug-toolbar buttons play
  `ns_button_3` on touch-down. Sounds use an ambient audio session, respect the
  silent switch, and mix with other audio.
- Every programmatic adjustment-icon visibility change uses the same 0.16-second transition:
  minus and plus fade while scaling between 50% and 100%. This applies to edit
  mode, commander transitions, and first-player selection. Reset swipes use the
  interactive version of the same coupled fade-and-scale profile.
- Lighthouse landing plays `tonehigh` with the selected-player shake. Commander
  ripple entry and exit play `short`; exact-life editor entry and exit play
  `long`. Commander and edit entry cues play two semitones above their source
  WAVs; their exit cues play at the original pitch. Entering the post-reset
  player/layout chooser plays `tonelow`.
- During the lighthouse sweep, each revolution is divided into one evenly
  spaced `ns_button_5` beat per active seat. This regular angular rhythm ignores
  irregular seat geometry while naturally compressing in time as the beam
  accelerates; pitch rises from -600 toward +1200 cents along the same easing
  curve. Active sweep voices stop immediately before the landing sound.
- Hold a side after 0.5s to repeat in +/-10 steps every 0.35s. The immediate
  touch-down +/-1 combines with a compensating first hold step of +/-9, so the
  initial held change totals exactly +/-10 rather than +/-11.
- Life totals at 0 or below dim to 30% opacity. A decrement hold that begins
  above 0 stops at exactly 0; a fresh gesture may cross below 0 and continue.
- Life totals also dim to 30% opacity when a player reaches 10 poison counters,
  matching the defeated appearance for zero life or lethal commander damage.
- Tap anywhere within a rendered life total to enter commander-damage mode with
  that player as the recipient.
- Hold anywhere within the rendered life total for 0.5s to open exact life input.
- Exact life input includes six OKLCH dot-shaped seat-color chips above the life total:
  colorless, white, blue, black, red, and green. Colorless is exclusive; one
  through five mana colors can be combined, and the choice stays with that
  player for the current game. The colorless picker chip uses pure RGB white at
  the app's 30% dimmed opacity; colorless life dots remain full white. White
  mana is a deep, saturated cream-yellow; and black mana is a light muted
  purple.
- Exact life input also includes a poison-counter control below the life total,
  aligned with the keypad's bottom row in side-player layouts. At zero it shows
  the poison icon and the standard dimmed plus icon; after the first
  increment it also reveals a dimmed minus icon and a Karl rolling count.
  In the editor, the poison icon is 32pt to match the keypad action icons and
  its rolling count uses the 32pt keypad numeral style. When a nonzero poison
  count enters or leaves the editor, the compact on-board badge and editor
  control each use the shared 0.16-second fade-and-scale profile between 50%
  and 100% at their stationary positions; poison does not travel between them.
  Cancel first restores the saved poison count so the returning badge always
  matches the unchanged game state.
  Saving commits poison with the other edit-session changes, while canceling
  discards it. Players with one or more poison counters show the same compact
  poison icon and count below their normal on-board life total.
- The exact-life keypad ends with ×, 0, and a checkmark. The checkmark (or
  tapping the life total) commits the pending life and seat-color changes. ×
  exits edit mode and discards every change made during that editing session.
  When canceling after typing, the pending number dissolves out while the saved
  number dissolves back in and travels through the editor-to-board dot hero.
  The × and checkmark scale up on press without changing opacity.
- Swipe across the board to reset. A committed reset wipes cells off, shows the
  layout selector, then starts a clockwise lighthouse sweep after selection.
- The lighthouse beam rotates clockwise from the board center, flashing each
  active life-total dot individually as it crosses it, accelerates, and lands
  on a random starting player.
- While the beam is sweeping, every non-dot element is fully invisible:
  adjustment icons, toolbar controls, and debug skeletons.
  A root interaction layer remains active so any touch can fast-forward the
  animation without reaching those controls.
- The chosen player's life stays bright while every other life total begins
  fully invisible and fades from zero to full opacity over three seconds. A
  screen interaction completes that fade with a short spring and is consumed.
- Entering commander mode sends a radial dot ripple from the recipient's life
  total. Every other cell becomes the damage dealt by that source player to the
  recipient, starts at zero, and rotates to face the recipient. The outgoing
  life totals retain their normal seat rotations throughout ripple-out.
- Source damage totals use the board's normal left/right -/+ controls and repeat
  behavior. Each applied damage point also subtracts one recipient life; reducing
  damage restores the same amount of life.
- Commander-damage totals at the lethal 21-point threshold or above dim to 30%
  opacity, and the recipient's normal life total remains dim after leaving
  commander mode. An increment hold that begins below 21 stops at exactly 21;
  a fresh gesture may cross 21 and continue.
- VoiceOver marks a life total as defeated when it is at or below 0 or the
  player has lethal commander damage or 10 poison counters, and marks
  commander-source totals at or above 21 as lethal.
- The recipient's live life total stays visible at 30% opacity without adjust
  controls. Tap the rendered number to exit with the reverse radial ripple.
- Commander damage is assigned only in focused commander mode, not in the exact
  life input overlay.
- The bottom-right debug toolbar has two buttons: dot-font cycle and layout
  grid/tap targets. It remains visible and functional on the board, layout
  selector, and exact-life editor, but still hides during the lighthouse sweep.
- The dot-font cycle advances through tall, narrow, normal, wide, xwide, and
  xxwide bitmap styles. Their exact grids are tall 3 by 7, narrow 3 by 5,
  normal 4 by 5, wide 5 by 5, xwide 6 by 5, and xxwide 7 by 5.
- New 5- and 6-player games default to the narrow 3 by 5 dot font. New 2- through
  4-player games default to the wide 5 by 5 dot font. Cycling the font on the
  layout selector overrides that default for the next game; the toolbar can
  also cycle fonts on the board and in the exact-life editor.
- Digit-count changes relayout the editable number immediately and relayout its
  board cell and adjustment controls when editing closes. Every value uses the
  game's active dot font, regardless of its number of digits.
- The first keypad press dissolves every dot of the existing life total while
  the replacement digit dissolves in. Later presses animate retained leading
  digits smoothly into their newly fitted positions and sizes. Replaced and
  appended digits cross-dissolve at dot level, coupling opacity with scale and
  stable per-dot timing variation.
- The layout-debug toggle draws a translucent blue 20pt rhythm grid and green
  border at the physical screen edges on every screen. It also draws green
  layout-region outlines and orange tap targets for board cells, selector
  buttons, life-editor controls, and keypad keys. Board orange geometry divides
  each cell into full-height decrement, rendered-number, and increment targets.

## Source Layout

Entry point and root controller:

- `lifetrack/AppDelegate.swift` - `@main`, registers the Karl fonts, disables
  the idle timer, and provides the scene configuration.
- `lifetrack/SceneDelegate.swift` - creates the black `UIWindow`, installs
  `GameViewController`, forces dark appearance, and prepares app audio.
- `lifetrack/LaunchScreen.storyboard` - supplies the explicit solid-black
  launch screen selected by `UILaunchStoryboardName`.
- `lifetrack/GameViewController.swift` - owns active `PlayerLayout`, player
  state, editing state, toolbar, reset flow, `GameBoardView`,
  `LifeInputOverlay`, `LayoutSelectorView`, and the root screen-edge skeleton
  border shown in grid mode.
- `lifetrack/AppSoundPlayer.swift` - preloads the bundled interaction WAVs and
  plays them through a shared `AVAudioEngine` with overlapping, independently
  pitch-adjustable voices.

Models:

- `lifetrack/Models/Player.swift` - `Player`, default life 40, lethal commander
  damage 21, lethal poison 10, and the player's selected seat colors.
- `lifetrack/Models/SeatColor.swift` - the six seat-color choices, their OKLCH
  coordinates, deterministic per-dot variance, neutral-center interpolation,
  gamut fitting, and sRGB output.
- `lifetrack/Models/PlayerLayout.swift` - all layout variants, `PlayerSeat`,
  `BoardInsets`, and selector display order.
- `playercounts/*.svg` - canonical source artwork for schematic seat dots. When
  changing a seating icon, update the SVG first, then its Swift `iconCenter`
  data. Actual board geometry remains independently defined by `cellRect`.

Main board and cell views:

- `lifetrack/Views/GameBoardView.swift` - projects `cellRect` to adjoining board
  slots, computes uniform board dot size, owns reset swipe,
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
- `lifetrack/Views/PoisonCounterView.swift` - reusable poison icon/count badge
  and the edit-mode decrement/increment control; its count uses the shared
  SwiftUI rolling-number transition, with `Typography.keypadDigit` in the
  editor and `Typography.lifeDelta` on the board. It also owns the stationary
  fade-and-scale visibility profile shared by editor transitions and reset.
- `lifetrack/Views/SeatColorPickerView.swift` - the six accessible dot-shaped
  chips used to choose an exclusive colorless seat or any mana-color mix.
- `lifetrack/Views/NumberPadView.swift` - 3 by 4 number pad (`1...9`, cancel
  `×`, `0`, done checkmark) and key frames for overlay skeleton drawing.
  Tapping the life total also confirms/dismisses the overlay.
- `lifetrack/Views/LayoutSelectorView.swift` - full-screen 2-column by 4-row
  selector for all player-count/layout variants.

Dot and typography systems:

- `lifetrack/Views/DotPatterns.swift` - bitmap dot-font catalog, active font
  setting, `ChangeDirection`, and row-stagger timing.
- `lifetrack/Views/DotDigitView.swift` - one digit as animated UIKit dot views,
  including deterministic OKLCH color assignment, per-dot edit heroes,
  lighthouse-beam projection, and additive organic shake.
- `lifetrack/Views/DotNumberView.swift` - number splitting, dot-size fitting,
  digit layout, global font-change rebuilds, and sweep/reset forwarding.
- `lifetrack/Views/RollingNumberText.swift` - hosted SwiftUI rolling numeric
  text used by the transient life-delta readout.
- `lifetrack/Views/Karl.swift` - bundled Karl font factories.
- `lifetrack/Views/Typography.swift` - central Karl text tokens for the keypad
  and rolling numeric readouts. Every typography token applies tabular figures
  in both its UIKit and SwiftUI forms; do not add a proportional-numeral opt-out.

Assets/resources:

- Selected WAVs under `scorebordsounds/` are bundled interaction sounds:
  `ns_button_1`,
  `ns_button_2`, and `ns_button_3` cover increment, decrement, and standard
  buttons; `ns_button_5` provides the seat-count lighthouse rhythm; and
  `tonehigh`, `tonelow`, `short`, and `long` cover lighthouse landing, reset
  chooser entry, commander transitions, and edit transitions. `ns_button_4`
  exists as an unused source file and is not included in the app target.
- `IconPlus.svg`, `IconMinus.svg`, `IconCheckmark.svg`, `IconCross.svg`, and
  `IconPoison.svg` at the repository root are the canonical source artwork for
  the board adjustment controls, exact-life done/cancel controls, and poison
  badge. Their asset-catalog copies keep the existing runtime names `IconPlus`,
  `IconMinus`, `icon-checkmark`, `icon-delete`, and `icon-poison` respectively.
- `appicon.icon` - canonical Icon Composer source used for the Home Screen,
  TestFlight, and App Store icon. Its `Assets/toplayer.png` is the 1024 by 1024
  white dot-matrix `40` rendered in the app's default wide font. Keep the synced
  copy under `lifetrack/Assets.xcassets/appicon` identical.
- `lifetrack/Assets.xcassets/IconPlus.imageset` and
  `lifetrack/Assets.xcassets/IconMinus.imageset` - shared app-wide +/- glyphs.
- `lifetrack/Assets.xcassets/icon-*.imageset` - remaining action icons.
  `icon-poison` renders at 32pt in the editor and 20pt in the compact on-board
  badge.
- `lifetrack/Resources/Fonts` - Karl font files.

## Layout System

The spatial system has two coordinated layers:

- A 4pt base unit governs fixed measurements. The physical playable board uses
  8pt side insets and 52pt top/bottom insets. The visible major rhythm is five
  base units, or 20pt. Board dots target 18pt on a 20pt pitch; adjustment icons,
  icon spacing, icon target padding, and the debug grid use that same 20pt step.
- `PlayerLayout.cellRect` defines responsive seat geometry in normalized 0...1
  board coordinates. `GameBoardView` projects those fractions into the playable
  board on each screen size. Adjacent rectangles share their normalized edge
  with no inter-seat gutter, so both their visible regions and tap targets meet
  exactly. Fractions may vary by layout (halves, thirds, fifths, or sixths)
  while all fixed padding and visual rhythm stay on the shared point grid.

The debug overlay exposes both layers: blue lines show the physical 20pt rhythm,
green lines show screen/layout regions, and orange lines show actual tap targets.
`LayoutGrid` and `BoardInsets` in `PlayerLayout.swift` are the canonical fixed
constants; normalized `cellRect` values are the canonical responsive grid.

The supported layouts are:

- `two` - top and bottom.
- `three` - two left-edge players plus one full-height right-edge player.
- `fourA` - 2 by 2 corners.
- `fourB` - equal-area diamond layout with quarter-height full-width top/bottom
  seats and a half-height middle band split between the side seats.
- `fiveA` - a 5-row grid with two-row split upper/middle bands and a one-row
  full-width bottom seat.
- `fiveB` - three left-edge thirds plus two right-edge halves.
- `sixA` - 3 by 2 grid.
- `sixB` - a 6-row grid with one-row full-width top/bottom bands and two-row
  split middle bands, giving the side seats enough height to separate their
  adjustment controls. Its selector artwork places seat rows at evenly spaced
  y positions 4, 12, 20, and 28 in the 32-unit icon viewbox.

The board normally targets 18pt life dots. `GameBoardView.uniformDotSize(for:)`
asks each slot how large a two-digit value can fit after accounting for rotation,
the full-height adjustment regions, and `verticalInset`. Every cell then receives
the minimum fitting size, capped at 18pt, so board dots stay uniform. Individual
numbers scale down further when their digit count needs more room between the
minimum-width adjustment targets. The input overlay caps its editable life-total
dots at 28pt so the number stays prominent without overwhelming the keypad.

The seat-color chips use that same live dot size and corner-radius ratio. Their
row spans exactly the rendered width of a two-digit value in the default wide
5 by 5 font, matching the outer edges of the default `40` life total. In
side-player input layouts, their centerline matches the first keypad row while
the life total occupies the remaining three-row band. Selection adds a 2pt
white outline outside a 1pt clear gap without changing chip geometry.

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

Important touch behavior:

- The life-total interaction zone matches the rendered number's width and spans
  the full player-cell height. A tap enters commander mode; a 0.5-second hold
  opens exact life input.
- Each adjustment target spans the full player-cell height, reserves at least
  60pt of player-facing width for its 20pt icon and 20pt inline padding, and
  expands from the number to the corresponding cell edge when space allows.
- Number fitting reserves both minimum adjustment widths and scales the life
  total down when needed, so no adjustment target extends beyond its cell.
- Targets are defined in the player's rotated content coordinate space, so
  their visual and interactive geometry stays aligned for every seat rotation.
- Center taps commit on touch-up, so a reset swipe beginning over the number
  cancels the tap instead of entering commander mode.
- A nonzero poison badge uses the open space below the rendered life total in
  player reading space without moving or rescaling the life total. The badge
  rotates with the player's normal seat orientation.

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
  expands center-out; exit reverses the timing and collapses edge-in. On exit,
  focused recipient orientation clears at that midpoint before the incoming
  life totals appear, so they return to their normal seat rotations during the
  transition instead of after it. Rotation belongs to the displayed content:
  outgoing and recipient life totals retain their seat angles, while only
  commander-source damage adopts the recipient-facing angle.
- `.decreasing` rolls top-to-bottom; `.increasing` rolls bottom-to-top.
- Animated changes use `.beginFromCurrentState`, so rapid taps retarget the
  current animation instead of queueing delayed rolls.
- Reset swipe fades and scales dots, adjustment controls, and poison badges by
  position against a moving edge.
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
- A touch during the first-player sweep is consumed and fast-forwards to the
  already chosen seat through the normal landing, preserving its shake, heavy
  haptic, and announcement. Before that landing begins, the skip path normalizes
  the winner's dot transforms to the same natural-scale handoff produced by a
  completed sweep; the shake animation itself is unchanged. A touch during the
  following fade is also consumed and completes the reveal. Neither touch
  activates an underlying game or toolbar control.
- Player controls, toolbar chrome, and debug skeletons snap invisible when the
  lighthouse starts and return as soon as it lands. The minus and plus controls
  use their shared fade-and-scale visibility transition in both directions.
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
  in views. All app numerals use tabular figures: Karl-based numbers inherit
  them from `Typography.Style`, while dot-matrix totals are fixed-cell by design.

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
