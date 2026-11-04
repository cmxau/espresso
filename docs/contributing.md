# Contributing

Thanks for helping with Espresso! Bug reports, ideas and pull requests are welcome.

## Reporting bugs and requesting features

Use the issue templates: [bug report](https://github.com/cmxau/espresso/issues/new?template=bug_report.md) ·
[feature request](https://github.com/cmxau/espresso/issues/new?template=feature_request.md).
Include your macOS version, Mac model and Espresso version (About window).

## Development setup

Requirements: macOS 14+, Xcode Command Line Tools (`xcode-select --install`). Full Xcode is optional.

```sh
./scripts/build.sh              # swift build -c release + assemble build/Espresso.app (ad hoc signed)
open build/Espresso.app         # run it
pkill -x Espresso               # stop it (or use Quit in the panel)
```

Rebuild and relaunch after every change. To use Xcode, run `xcodegen` to generate `Espresso.xcodeproj` from `project.yml`.

There is no automated test suite yet. Please verify changes by running the app: toggle it on/off, check
`pmset -g assertions` shows `Espresso` while active, and exercise the settings you touched.

Useful checks:

```sh
pmset -g assertions | grep Espresso         # is it holding the Mac awake?
defaults read com.cmxau.espresso            # current settings
defaults delete com.cmxau.espresso          # reset settings (and re-show the welcome window)
```

## Project layout

See [architecture.md](architecture.md) for what each file does. In short: `Awake.swift` is behavior,
`Views.swift` is UI, `AppDelegate.swift`/`Panel.swift` are the menu bar shell.

## Conventions

- **Keep it light.** The app's selling point is near-zero CPU, memory, disk and network use. Prefer system events over
  timers, don't add dependencies, and re-measure if you touch anything that runs continuously
  (see the performance table in architecture.md).
- **Native feel.** Use system fonts, SF Symbols and standard sizes (13 pt rows, 28 pt icon circles, 300 pt panel).
- **One icon source.** Change the cup in `Cup.swift` only, then run `./scripts/make-icon.sh` to refresh `AppIcon.icns`.
- **No `@State`** for now, use `Box` (see architecture.md for why).
- **Settings:** add a property to `Prefs` (`@AppStorage`), a row in `MainView.settings`, and react to it in
  `Awake`/`AppDelegate` as needed. Defaults should be off/non-surprising.
- **Anything that changes system state** (sleep settings, sudoers, login items) must be undone on deactivate/quit
  and documented in [installation.md](installation.md).
- Keep comments to the *why*; keep functions small.

## Pull requests

1. Fork and create a branch from `main`.
2. Keep the change focused; update the docs if behavior or structure changes.
3. Confirm `./scripts/build.sh` succeeds with no errors and describe how you tested.
4. Open the PR with a short description of the problem and the approach. Screenshots help for UI changes.
