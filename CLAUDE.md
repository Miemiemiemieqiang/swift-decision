# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

「快定」(SwiftDecision) — an iOS app that kills decision fatigue: the user types something they're agonizing over, an LLM returns a single actionable verdict (not a pros/cons analysis), and the user "seals" it so they stop ruminating. SwiftUI + SwiftData, iOS 17+, single app target, no external dependencies and no test target.

All user-facing text is Chinese; keep new UI strings in the same voice (terse, anti-overthinking, e.g. 「帮我定」「就这么定」).

## Build Commands

There is no Package.swift; build through the Xcode project. The `build/` directory at repo root is derived data — never edit or read it.

```sh
# Build for simulator (pick any device from `xcrun simctl list devices available`)
xcodebuild -project SwiftDecision.xcodeproj -scheme SwiftDecision \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build build

# Run in simulator after building
xcrun simctl boot "iPhone 17" || true
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/SwiftDecision.app
xcrun simctl launch booted com.miemieqiang.SwiftDecision
```

There are no tests or linters configured. New source files must also be registered in `SwiftDecision.xcodeproj/project.pbxproj` (the project does not use file-system-synchronized groups).

## Architecture

The core flow spans three layers:

1. **`Views/HomeView.swift`** takes the question, calls `LLMService.decide()`, and presents the result as a sheet (`PendingVerdict` is just an `Identifiable` wrapper for sheet presentation).
2. **`Services/LLMService.swift`** is the heart of the app. It calls any OpenAI-compatible `/chat/completions` endpoint with a Chinese system prompt that forces the model to return a single JSON object (`Verdict`: verdict ≤8 chars, one-line reason, expandable detail, `trivial` flag for coin-flip cases). `extractJSON` defensively strips markdown fences/prose around the JSON. The `anotherAngleFrom:` parameter implements the "换个角度" retry, which is deliberately limited to **one** retry in `VerdictCardView` — that limit is a product decision (preventing re-rumination), not a technical one.
3. **`Views/VerdictCardView.swift`** shows the verdict; "sealing" converts the transient `Verdict` (Decodable API struct) into a persisted `Decision` (`@Model`, SwiftData) — these are intentionally separate types. `HistoryView` is read-only by design except for thumbs-up/down feedback (`Decision.feedback`: 0/1/-1).

Configuration is split by sensitivity: base URL and model name live in `UserDefaults` (`LLMConfig`), the API key lives in the Keychain (`Services/KeychainHelper.swift`). Requests go directly from device to the user-configured endpoint; there is no backend — preserve that property (it's promised in the Settings footer).
