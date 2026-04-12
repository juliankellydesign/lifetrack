# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lifetrack is a SwiftUI multi-platform app (iOS, macOS, xrOS) targeting Apple platform version 26.1. Bundle ID: `jfk.lifetrack`.

## Build & Run

This is an Xcode project (no SPM package resolution needed currently). Build and run via:

```bash
# Open in Xcode
open lifetrack.xcodeproj

# Build from command line
xcodebuild -project lifetrack.xcodeproj -scheme lifetrack -destination 'platform=iOS Simulator,name=iPhone' build

# Run tests (when test targets exist)
xcodebuild -project lifetrack.xcodeproj -scheme lifetrack -destination 'platform=iOS Simulator,name=iPhone' test
```

No test targets are configured yet.

## Architecture

Standard SwiftUI app structure:
- `lifetrack/lifetrackApp.swift` — App entry point (`@main`), defines the `WindowGroup` scene
- `lifetrack/ContentView.swift` — Root view
- `lifetrack/Assets.xcassets/` — App icons and color assets

The project is freshly scaffolded with no external dependencies or third-party frameworks.
