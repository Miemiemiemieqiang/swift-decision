---
name: run-swiftdecision
description: Build, run, and drive the SwiftDecision (快定) iOS app in the Simulator — launch it, tap buttons, enter text, take screenshots to verify UI changes end-to-end.
---

# Run SwiftDecision in the iOS Simulator

SwiftUI iOS app, driven programmatically via `idb` wrapped in a driver script.
All paths below are relative to the repo root. All commands here were run and verified.

```sh
DRIVER=.claude/skills/run-swiftdecision/driver.sh
```

## Prerequisites

- Xcode with an iOS 26 simulator (default device: iPhone 17; override with `SD_DEVICE`).
- idb: `brew install idb-companion` **plus** the Python CLI `pip3 install --user fb-idb`.
  The CLI lands in `~/Library/Python/3.10/bin` (not on PATH — the driver exports it itself).
- macOS Accessibility permission for your terminal — only needed for `paste` (CJK input).

## Build + launch

```sh
$DRIVER build    # xcodebuild into ./build (derived data, gitignored)
$DRIVER start    # boot sim, install app, launch; prints PID
```

## Drive it (agent path)

Coordinates are **device points** (402×874 on iPhone 17). Screenshots are 3x pixels
(1206×2622) — divide pixel coords by 3. Better: skip screenshot math and get frames
in points directly from `describe`:

```sh
$DRIVER describe          # JSON array: AXLabel, type, frame (in points) per element
$DRIVER tap 201 417       # center of the question TextField (frame x=40 y=385 w=322 h=64)
$DRIVER text "hello"      # type into focused field — ASCII ONLY
$DRIVER paste "要不要现在去健身房"   # CJK path: Mac clipboard + Cmd+V via AppleScript
$DRIVER ss [path.png]     # screenshot, prints path — LOOK at it
$DRIVER stop              # terminate the app (relaunch resets @State, clears the input)
```

Verified main flow: `tap` the TextField → `paste` a question → `tap 201 514` (帮我定) →
wait ~8s for the LLM → `ss` shows the verdict card → `tap 201 728` (就这么定) seals it →
clock toolbar button (top-left, ~(29,64)) opens History where the row appears.

**The 帮我定 button calls the real configured LLM API** (costs money, needs network).
The app must be configured first — see Gotchas.

## Run (human path)

`open -a Simulator` and click around. Same app, no superpowers.

## Gotchas

- **The app is unusable until configured in Settings** (gear icon): Base URL, API key,
  model name. The key lives in *that simulator's* keychain — erasing the sim or switching
  devices loses it. Unconfigured submits show alert「还没有配置好模型服务…」.
- **`idb ui text` has no CJK keycodes** — fails with `No keycode found for 要`. Use
  `$DRIVER paste` for Chinese. Paste needs a focused field and Accessibility permission.
- **Do not drive the Simulator with AppleScript screen coordinates.** The window moves
  between calls and the title-bar offset is hard to model — it took five attempts to hit
  one toolbar button that way. idb taps use device points and are immune to all of it.
  If you ever must use AppleScript, click AX elements, not coordinates.
- The TextField autocapitalizes the first ASCII letter (`test` → `Test`).
- `simctl io booted screenshot` prints a harmless "No display specified" note on stderr.
- New Swift files must be registered in `SwiftDecision.xcodeproj/project.pbxproj`
  (no file-system-synchronized groups).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `pip3 install fb-idb` → `SSL: CERTIFICATE_VERIFY_FAILED` | python.org Python ships without certs: `sh "/Applications/Python 3.10/Install Certificates.command"`, retry |
| `idb` → `No udid provided and there no companions` | always pass `--udid` (the driver does: `$DRIVER udid`) |
| `osascript` → error `-1719` 不允许辅助访问 | grant the terminal Accessibility in System Settings → Privacy & Security |
| `idb ui text` → `No keycode found for <char>` | non-ASCII input — use `$DRIVER paste` |

## Tests

None — the project has no test target.
