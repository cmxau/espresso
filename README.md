# Espresso

A tiny native macOS menu bar app that keeps your Mac awake.

A cup in the menu bar shows the state: **plain cup = off**, **cup with steam = keeping your Mac awake**.
Click it for a panel with the on/off switch, a duration (15/30/45 min, 1/4/8 h, or ∞) and settings.

## Features

- Timed or infinite keep-awake (display + system, or system only)
- Keep awake with the lid closed
- Global keyboard shortcut (default `⌃⌥⌘C`, customizable, off until you enable it)
- Activate with a left click on the menu bar icon
- Launch at login, activate at launch
- Activate on power connect, deactivate on power disconnect, deactivate below 20 % battery
- Optional notifications
- Animated and/or colored menu bar icon
- Updates from GitHub Releases, optionally installed automatically

Light by design: about 12 MB of memory, ~0 % CPU, no disk writes and no network use while running
(the only request is the update check, which you can turn off). See [docs/architecture.md](docs/architecture.md#performance).

## Install

Download the latest `.zip` from [Releases](https://github.com/cmxau/espresso/releases), unzip, and move
`Espresso.app` to `/Applications`. Or build from source. Details and first-run notes: [docs/installation.md](docs/installation.md).

Requires macOS 14 or later.

## Build from source

No Xcode needed, the Command Line Tools are enough:

```sh
./scripts/build.sh && open build/Espresso.app
```

## Documentation

| | |
|---|---|
| [docs/installation.md](docs/installation.md) | Installing, first run, permissions, uninstalling |
| [docs/architecture.md](docs/architecture.md) | How the app is put together |
| [docs/contributing.md](docs/contributing.md) | Building, code conventions, filing issues and PRs |
| [docs/releasing.md](docs/releasing.md) | Cutting a release the in-app updater understands |

## Feedback

[Request a feature](https://github.com/cmxau/espresso/issues/new?template=feature_request.md) ·
[Report a bug](https://github.com/cmxau/espresso/issues/new?template=bug_report.md)

Designed and developed by [cmxau](https://github.com/cmxau).
