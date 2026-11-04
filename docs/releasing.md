# Releasing

The in-app updater (`Updater.swift`) reads `https://api.github.com/repos/cmxau/espresso/releases/latest`.
A release is picked up when it meets all of the following:

- The **tag** is a version such as `v1.2.0`; a leading `v` is ignored. It must be numerically **greater** than the
  running app's `CFBundleShortVersionString`.
- The release has an **asset ending in `.dmg`** whose volume contains `Espresso.app` at its top level.
- It is the latest non-draft, non-prerelease release.

## Steps

1. Bump `CFBundleShortVersionString` (and `CFBundleVersion`) in `Resources/Info.plist`.
2. Build the app and disk image: `./scripts/make-dmg.sh` (produces `build/Espresso-1.2.0.dmg`).
3. Create a GitHub release tagged `v1.2.0`, attach the `.dmg`, and write release notes
   (`gh release create v1.2.0 build/Espresso-1.2.0.dmg --title "Espresso 1.2.0" --notes-file notes.md`).

## How an update is installed

`Updater.install()` accepts only `https` asset URLs on `github.com/cmxau/espresso/releases/download/` (redirects must stay on
`github.com` / `*.githubusercontent.com`, disk image at most 50 MB). The image is mounted read-only (`hdiutil attach -nobrowse -readonly`), only `Espresso.app` is copied
out (never a symlink) with `ditto` into a fresh `0700` temp dir and the image is detached; the copy is rejected if it contains any symlink, if
`CFBundleIdentifier` is not `com.cmxau.espresso`, if the version is not newer, or if `codesign --verify --deep --strict` fails.
A constant shell script (paths passed as arguments) then waits for the app to exit, moves the old app to `Espresso.app.old`,
moves the new one in (restoring the old one on failure) and reopens it. This works when the app lives in a user-writable
location such as `/Applications` for an admin user.

## Signing

Builds are currently ad hoc signed with the hardened runtime (`codesign --options runtime --sign -`). Ad hoc signatures carry no publisher identity, so the updater can verify integrity but not authenticity. For wider distribution, sign with a Developer ID
certificate and notarize, so Gatekeeper doesn't block first launch, and consider moving to Sparkle for
signature-verified updates.
