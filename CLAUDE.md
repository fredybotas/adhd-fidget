# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
bash build.sh        # compile + bundle + ad-hoc codesign
open FidgetBall.app  # launch
```

No Xcode project. Pure `swiftc` multi-file compilation targeting macOS 14+. Adding a new source file requires adding it to the `swiftc` invocation in `build.sh`. Adding a new framework requires `-framework Name` there too.

## Architecture

Single-process menu bar app (`LSUIElement=YES`, no dock icon).

**Data flow:** `BallSettings.shared` is the single source of truth for all tunable values. It reads/writes `UserDefaults` and posts `BallSettings.changed` on every mutation. `BallView` observes this notification and calls `resetRope()` to rebuild the particle chain with new values.

**Overlay window:** `AppDelegate` owns an `NSPanel` (`.borderless`, `.nonactivatingPanel`, `.floating`) that covers the full screen. The panel is created once and reused — `orderFront`/`orderOut` show/hide it. Anchor point is derived from the status bar button's screen position via `button.convert(button.bounds, to: nil)` + `win.convertToScreen()` (not `button.frame`).

**Physics (`BallView`):** Verlet integration particle chain. `parts[0]` is pinned to the anchor. Each tick: integrate velocity with damping+gravity → satisfy distance constraints 10× → draw. Rope "snaps" (transitions to free-ball mode) when throw speed exceeds `breakSpeed` or drag distance exceeds `ropeLength * breakRatio`. Free-ball mode uses simple Euler integration with screen-edge bouncing.

**Click-through:** `hitTest` returns `nil` for points outside `ballRadius + 12px` so the overlay doesn't intercept clicks on the desktop or other apps.

**Global hotkey (`HotkeyManager`):** Carbon `RegisterEventHotKey` — works system-wide without Accessibility permission. One hotkey slot (ID 1 = toggle show/hide). The Carbon event handler callback must be a non-capturing closure (references only `HotkeyManager.shared`, a type property). Shortcut key code + modifiers stored in `UserDefaults` via `BallSettings`.

**Settings window:** `SettingsWindowController` is a singleton (`NSWindowController`). It rebuilds its entire view hierarchy on each `show()` call by calling `buildUI()`. Action targets (sliders, color wells, shortcut recorders) are heap-allocated helper objects stored in `retained: [AnyObject]` to prevent deallocation. `ShortcutRecorder` uses `NSEvent.addLocalMonitorForEvents` (local, not global) to capture key combos while the settings window is front.
