# Architecture

Espresso is a single Swift target (`Sources/Espresso`) with no third-party dependencies. It is an AppKit app
(menu bar accessory, `LSUIElement`) with SwiftUI used for the panel and windows.

```
main.swift ─► AppDelegate ─┬─ NSStatusItem (menu bar icon)  ◄── Icon / Cup
                           ├─ PanelController ─► MenuPanel ─► MainView (SwiftUI)
                           ├─ Awake        (sleep assertions, timer, lid mode, notifications)
                           ├─ PowerMonitor (AC / battery events)
                           ├─ HotKey       (global shortcut)
                           ├─ Windows      (About / Welcome windows)
                           └─ Updater      (GitHub Releases)
Prefs (UserDefaults) is shared by all of the above.
```

## Components

| File | Responsibility |
|---|---|
| `main.swift` | Creates `NSApplication`, sets the accessory activation policy, installs `AppDelegate`. |
| `AppDelegate.swift` | Owns the status item. Left/right click routing, icon refresh, optional 2 fps steam animation, launch behavior (activate at launch, welcome window, update schedule). Quitting calls `Awake.stop()` so lid mode is restored. |
| `Panel.swift` | The menu-style panel: a borderless `NSPanel` over an `NSVisualEffectView`, placed under the status item like system menus. Closes on resign-key or Esc, keeps its top edge fixed while content resizes, and swallows the click that dismissed it so clicking the icon closes rather than reopens. |
| `Views.swift` | All SwiftUI: `MainView` (header, Duration chips, Settings rows), `AboutView`, `WelcomeView`, `CupView`/`AppIconView`, shared row/button styles. |
| `Awake.swift` | The core. Holds `IOPMAssertion`s (`PreventUserIdleSystemSleep`, plus `PreventUserIdleDisplaySleep` unless display sleep is allowed), the single-shot expiry `Timer`, lid-closed mode, and notifications. |
| `PowerMonitor.swift` | `IOPSNotificationCreateRunLoopSource` callback; applies the activate-on-connect / deactivate-on-disconnect / below-20 % rules. |
| `HotKey.swift` | Carbon `RegisterEventHotKey`; also turns a recorded `NSEvent` into key code + modifiers + display label. |
| `Prefs.swift` | `@AppStorage`-backed settings (`UserDefaults`, domain `com.cmxau.espresso`), `Duration` and `Swatch` enums, launch-at-login via `SMAppService`. |
| `Cup.swift` | The cup icon as stroked `CGPath` centerlines. Single source for every rendering of the icon. |
| `Icon.swift` | Renders `Cup` into cached 2x bitmap `NSImage`s for the menu bar (template unless a color is set). |
| `Windows.swift` | Shows About / Welcome in plain `NSWindow`s, kept alive only while open. |
| `Updater.swift` | Checks the latest GitHub release, downloads the `.zip`, swaps the app bundle and relaunches. |

## Key design decisions

**Event-driven, no polling.** Nothing runs on an interval except the daily update check and, only when animation is
enabled, the 2 fps icon timer. Power changes arrive as run-loop events; expiry is one single-shot timer.

**Sleep prevention uses IOKit power assertions**, the same mechanism as `caffeinate`. They are released
automatically by the OS if the process dies, so a crash cannot leave the Mac stuck awake. The exception is lid-closed
mode (below).

**Lid-closed mode uses `pmset -a disablesleep`.** Assertions don't prevent clamshell sleep, so this needs root.
`Awake.pmset` first tries `sudo -n pmset …`; if that fails it installs a narrow `/etc/sudoers.d/espresso` rule once
(admin prompt via `NSAppleScript`, validated with `visudo -cf`) and retries. This setting is *not* auto-released if the
app is force-killed; see [installation.md](installation.md#lid-closed-mode-and-the-sudoers-rule).

**Own panel instead of `NSPopover`/`NSMenu`.** `NSPopover` has an arrow and `NSMenu` can't resize its custom view
reliably while open, so `PanelController` builds a borderless panel to match the system Wi-Fi / Control Center look.
The SwiftUI tree is created on open and freed on close.

**Single icon definition.** `Cup.swift` is plain Core Graphics and is also compiled by `scripts/make-icon.sh` to
generate `Resources/AppIcon.icns`, so the menu bar, windows and app icon cannot drift apart.

**`Box<T>` instead of `@State`.** `@State` is a compiler macro whose plugin ships only with full Xcode. To build with
just the Command Line Tools, views use `@StateObject private var x = Box(...)` (see top of `Views.swift`). Once Xcode
is a requirement this can be reverted to `@State`.

**Settings are the source of truth.** `Prefs` is an `ObservableObject` whose `objectWillChange` (merged with
`Awake`'s) drives `AppDelegate.refresh()`, which redraws the icon and starts/stops the animation timer.

## Data and files

- Settings: `UserDefaults`, domain `com.cmxau.espresso`.
- `/etc/sudoers.d/espresso`: only if lid-closed mode was enabled.
- No other files are written. No analytics or telemetry. The only network call is the GitHub API update check.

## Performance

Measured on Apple silicon with `proc_pid_rusage` over 30 s windows:

| State | CPU | Memory | Disk | Wakeups/s |
|---|---|---|---|---|
| Off | 0.01 % | ~11 MB | 0 | 0.2 |
| Active | 0.01 % | ~12 MB | 0 | 0.1 |
| Active + animated icon | ~1.8 % | ~12 MB | 0 | ~12 |

The animation cost is AppKit redrawing the status button on each frame (template tinting), not Espresso's drawing,
so it is off by default. There is no per-process GPU counter without root; Espresso does no GPU work of its own.
