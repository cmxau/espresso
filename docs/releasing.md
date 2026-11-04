# Releasing

The in-app updater (`Updater.swift`) reads `https://api.github.com/repos/cmxau/espresso/releases/latest`.
A release is picked up when it meets all of the following:

- The **tag** is a version such as `v1.2.0`; a leading `v` is ignored. It must be numerically **greater** than the
  running app's `CFBundleShortVersionString`.
- The release has an **asset ending in `.zip`** that contains `Espresso.app` at its top level.
- It is the latest non-draft, non-prerelease release.

## Steps

1. Bump `CFBundleShortVersionString` (and `CFBundleVersion`) in `Resources/Info.plist`.
2. Build: `./scripts/build.sh`.
3. Zip the app, preserving bundle metadata:
   ```sh
   ditto -c -k --keepParent build/Espresso.app Espresso-1.2.0.zip
   ```
4. Create a GitHub release tagged `v1.2.0`, attach the zip, and write release notes.

## How an update is installed

`Updater.install()` downloads the zip, unpacks it with `ditto`, then launches a small shell script that waits for the
running app to exit, replaces the app bundle in place and reopens it. This works when the app lives in a user-writable
location such as `/Applications` for an admin user.

## Signing

Builds are currently ad hoc signed (`codesign --sign -`). For wider distribution, sign with a Developer ID
certificate and notarize, so Gatekeeper doesn't block first launch, and consider moving to Sparkle for
signature-verified updates.
