# Installation

Espresso requires **macOS 14 (Sonoma) or later**, Apple silicon or Intel.

## From a release

1. Download the latest `Espresso-x.y.z.zip` from the [Releases](https://github.com/cmxau/espresso/releases) page.
2. Unzip it and drag `Espresso.app` to `/Applications`.
3. Open it. A cup appears in the menu bar and a one-time welcome window is shown.

### "Espresso can't be opened" on first run

Releases are currently signed ad hoc (no Apple Developer ID / notarization), so Gatekeeper may block a
browser-downloaded copy. Either:

- Right-click `Espresso.app` → **Open** → **Open**, or
- Clear the quarantine flag: `xattr -dr com.apple.quarantine /Applications/Espresso.app`

Updates installed by the in-app updater are not affected, they don't carry the quarantine flag.

## From source

You only need the Xcode Command Line Tools (`xcode-select --install`):

```sh
git clone https://github.com/cmxau/espresso.git
cd espresso
./scripts/build.sh
cp -R build/Espresso.app /Applications/
```

Full Xcode is optional: run `xcodegen` (see `project.yml`) to generate `Espresso.xcodeproj`.

## Permissions

| Feature | What macOS / Espresso asks for |
|---|---|
| Keep awake, shortcut, power rules | Nothing |
| Allow Notifications | The standard notification permission prompt |
| Launch at Login | Appears under System Settings → General → Login Items |
| Keep Awake with Lid Closed | Your admin password **once**, see below |

### Lid-closed mode and the sudoers rule

Keeping a MacBook awake with the lid closed needs `pmset disablesleep`, which requires root. The first time you
turn this on, Espresso asks for your admin password and installs `/etc/sudoers.d/espresso`, a rule that lets your
user run **only** these two commands without a password:

```
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -a disablesleep 1
```

If you decline, the option switches itself back off. Espresso restores normal sleep when you deactivate it or quit.
If the app is ever force-killed while lid mode is on, run `sudo pmset -a disablesleep 0`.

## Updating

Open **About** → **Check Now**, or enable *Check for updates automatically* (once a day) and
*Install updates automatically*. Updates come from GitHub Releases; see [releasing.md](releasing.md).

## Uninstalling

```sh
pkill -x Espresso
rm -rf /Applications/Espresso.app
defaults delete com.cmxau.espresso            # settings
sudo rm -f /etc/sudoers.d/espresso            # only if you used lid-closed mode
sudo pmset -a disablesleep 0                  # only if lid-closed mode was left on
```

Also remove it from System Settings → General → Login Items if you enabled *Launch at Login*.
