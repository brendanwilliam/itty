# Cherri-built Shortcuts with a one-tap import link (iOS)

Status: working on a device. The button in Settings > Shortcuts adds the shortcut, and running it opens the saved host.
Still open: the run-a-command shortcut and `#trigger` automations (below).

## What was built

- **Deep link:** `itty://connect?host=<name>` (`Sources/App/DeepLink.swift`, `CFBundleURLTypes` in
  `Config/Info.plist`, `.onOpenURL` in `HostListView`). It opens a saved host by exact name, ignoring case and apostrophe style
  (macOS names a Mac "Brendan’s MacBook Pro" with a curly one), or `This iPhone`.
  Unknown, empty and duplicate names do nothing, and any other route or parameter is rejected. It never runs a command or
  creates a host or key, because any app or web page can open the URL. `HostStore.host(named:)` is the lookup.
- **Add button:** Settings > Shortcuts has an "Add … to Shortcuts" button per offering (`ShortcutLinks.addURL`). It opens the
  offering's iCloud share link, which goes straight to Apple's Add Shortcut screen, or the hosted file (GitHub Pages,
  `ShortcutLinks.baseURL`) if the offering has no link; the browser downloads that one and you open it in Shortcuts. The
  file address is shown in a `CodeBlock` if the link won't open.
- **iCloud link:** made by hand, because Apple creates it only from Share > Copy iCloud Link in the Shortcuts app. It points
  at the copy that was shared, not the file the workflow builds, so after changing a `.cherri` file, import the new file,
  share it again and update `Offering.iCloudLink`.
- **Sources:** `shortcuts/open-host.cherri` (an import question for the host name, then `openURL`). The question is asked once, when the shortcut is added, not on every run. See `shortcuts/README.md`.
- **Build and sign:** `scripts/build-shortcuts.sh` compiles with `--share=anyone`, checks each output starts with `AEA1`, and
  writes `manifest.json`. It needs macOS and `cherri`.
- **Publish:** `.github/workflows/ios-shortcuts.yml` (tag `ios-shortcuts-*` or manual) builds on a macOS runner and deploys to
  GitHub Pages. Pages must be enabled on the fork (Settings > Pages > Source: GitHub Actions).
- **Tests:** `DeepLinkTests`, `ShortcutLinksTests`.

Cherri is GPL-2.0 and is only run as a build tool; nothing from it is linked into the app.

## Findings from the device

1. `scripts/build-shortcuts.sh` compiles and signs `open-host.cherri` with Cherri 2.3.0; the output starts with `AEA1`.
   Building it found three mistakes, now fixed: an invalid glyph, a missing `#include 'actions/web'`, and ANSI colors in the
   version string.
2. The signed file, downloaded from Pages and opened in Shortcuts, shows the Add Shortcut screen and can be edited.
3. `shortcuts://import-shortcut?url=<Pages file>` fails on an iPhone with "The shortcut URL provided was invalid", both
   percent-encoded and unescaped. The cause is unknown. The iCloud link works.
4. The import question survives signing. Running the shortcut opens the host when its name matches a saved host. A name
   that matches nothing (the "My Mac" default) just opens itty on the host list. That the app does nothing for unknown names
   is covered by unit tests, not yet checked on the phone.

## Still open

- Find a Shortcuts action (or `rawAction`) for "Run Script Over SSH" to add a run-a-command shortcut. Anything that runs a
  command must show a confirmation in the app first.
- Check whether `#trigger` automations work on iOS 27.
- Find out why `shortcuts://import-shortcut?url=` rejects the Pages URL (content type, host, or an iCloud-only rule), if a
  link that needs no hand-made iCloud copy is wanted.

## Risks

- Apple can change action identifiers or the format between iOS releases; repeat the device test each release.
- HubSign (Cherri's remote signer) was reported failing in May 2026, so signing relies on a Mac.

## Later

- Natural language to shortcut: a Mac-side service that has an LLM emit Cherri source against a curated action catalog,
  compiles and signs it, and serves it at a short-lived unguessable URL. It needs an action allowlist, rate limiting and a
  repair loop. `ios/deploy/<name>/` is the home.
- App Intents / `AppShortcutsProvider`, so Ghostty actions appear in Shortcuts with no import.
