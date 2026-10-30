# Cherri-built Shortcuts with a one-tap import link (iOS)

Status: built and signed on a Mac; not yet verified on a device. The spike below is still open.

## What was built

- **Deep link:** `ghostty-ios://connect?host=<name>` (`Sources/App/DeepLink.swift`, `CFBundleURLTypes` in
  `Config/Info.plist`, `.onOpenURL` in `HostListView`). It opens a saved host by exact name, ignoring case, or `This iPhone`.
  Unknown, empty and duplicate names do nothing, and any other route or parameter is rejected. It never runs a command or
  creates a host or key, because any app or web page can open the URL. `HostStore.host(named:)` is the lookup.
- **Import link:** `ShortcutLinks` builds `shortcuts://import-shortcut?url=…&name=…` for the files hosted at
  `ShortcutLinks.baseURL` (GitHub Pages). Settings > Shortcuts has an Add button per offering, and shows the file address
  in a `CodeBlock` if the Shortcuts app won't open.
- **Sources:** `shortcuts/open-host.cherri` (an import question for the host name, then `openURL`). See `shortcuts/README.md`.
- **Build and sign:** `scripts/build-shortcuts.sh` compiles with `--share=anyone`, checks each output starts with `AEA1`, and
  writes `manifest.json`. It needs macOS and `cherri`.
- **Publish:** `.github/workflows/ios-shortcuts.yml` (tag `ios-shortcuts-*` or manual) builds on a macOS runner and deploys to
  GitHub Pages. Pages must be enabled on the fork (Settings > Pages > Source: GitHub Actions).
- **Tests:** `DeepLinkTests`, `ShortcutLinksTests`.

Cherri is GPL-2.0 and is only run as a build tool; nothing from it is linked into the app.

## Still to verify (needs a Mac signer and a real iPhone)

1. Done on a Mac with Cherri 2.3.0: `scripts/build-shortcuts.sh` compiles and signs `open-host.cherri`, the output starts with
   `AEA1`, and `manifest.json` is written. Building it found three mistakes, now fixed: an invalid glyph, a missing
   `#include 'actions/web'`, and ANSI colors in the version string.
2. Open the signed file on an iPhone: the import prompt appears and the shortcut can be edited.
3. Publish to Pages and confirm `shortcuts://import-shortcut?url=…` works from the app button and from Safari.
4. Confirm the import question shows on iOS and survives signing, and that running the shortcut opens the right host.
5. Find a Shortcuts action (or `rawAction`) for "Run Script Over SSH" to add a run-a-command shortcut. Anything that runs a
   command must show a confirmation in the app first.
6. Check whether `#trigger` automations work on iOS 27.

If step 2 or 3 fails, revisit the approach.

## Risks

- Apple can change action identifiers or the format between iOS releases; repeat the device test each release.
- HubSign (Cherri's remote signer) was reported failing in May 2026, so signing relies on a Mac.

## Later

- Natural language to shortcut: a Mac-side service that has an LLM emit Cherri source against a curated action catalog,
  compiles and signs it, and serves it at a short-lived unguessable URL. It needs an action allowlist, rate limiting and a
  repair loop. `ios/deploy/<name>/` is the home.
- App Intents / `AppShortcutsProvider`, so Ghostty actions appear in Shortcuts with no import.
