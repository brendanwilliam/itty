# Cherri-built Shortcuts with a one-tap import link (iOS)

Status: plan. Not yet implemented.

## Context

The Ghostty iOS port (`ios/`) connects to a Mac over SSH and has a multi-step setup. We want to ship Shortcuts that
users import in one tap and then edit freely in the Shortcuts app, without us building a bespoke automation UI.

Cherri (github.com/electrikmilk/cherri, GPL-2.0, Go, v2.2.0 per a May 2026 article) compiles a text language to a
`.shortcut` file. Facts that shape the design:

- **Cherri does not produce a link.** It compiles and signs. `-s/--share=anyone` sets the signing mode (default is
  `contacts` = `people-who-know-me`), `-o/--output=` sets the output path, `--signing-server=` uses a remote signer.
- **Signing runs Apple's `shortcuts sign`, so it needs macOS.** Off macOS the file stays unsigned, and iOS 15+ rejects
  unsigned shortcuts. HubSign (the fallback) was reported failing in May 2026, so do not depend on it.
- **So the "link" is ours:** host the signed file at a stable HTTPS URL and open it via
  `shortcuts://import-shortcut?url=<encoded-url>&name=<name>`. The user sees Apple's "Add Shortcut" screen, taps Add,
  and can then edit it. (Apple has no API to mint iCloud links; the Playground's share links expire after 5 days.)
- **Per-user values** (host name, username, port) can't be baked in at app runtime, because signing needs a Mac. Use
  Cherri **import questions** so Shortcuts asks the user at import time, or a runtime `Ask`.
- The repo has no Cherri/Go tooling, no URL scheme or `onOpenURL`, no App Intents, no iOS CI, and no signing.
  `HostStore`/`Host` (`ios/Sources/Model/Host.swift`) are the connection model. `DeviceKey.authorizeCommand`
  (`ios/Sources/Keys/DeviceKey.swift`) builds the setup one-liner. `ios/deploy/headscale/` is the precedent for
  shipping setup kits.

## Approach (v1: signed templates, no LLM, no server)

Author shortcuts as `.cherri` source in the repo. A script compiles and signs them on a Mac. The signed files are
published at a stable URL. The app opens the import link from a button. Dynamic generation is deferred (see
"Later").

### 1. App: deep link entry point (new)
- Add `CFBundleURLTypes` (scheme e.g. `ghostty-ios`; confirm the final name) to `ios/Config/Info.plist`.
- Handle it with `.onOpenURL` on the `WindowGroup` in `ios/Sources/App/GhosttyApp.swift`, routing to a small
  `DeepLink` parser (new file in `ios/Sources/App/`).
- Supported routes: `connect?host=<name>` opens or focuses a session for a saved host from `HostStore`.
- **Security:** a URL scheme is callable by any app or web page. The handler selects a saved host by name only. It
  never executes a command from the URL, never creates hosts or keys, and falls through to an in-app confirmation for
  anything beyond "open this host". Add this as a required review item.

### 2. Shortcut sources (new)
- `ios/shortcuts/*.cherri` (and `ios/shortcuts/README.md`). First set:
  - **Open host:** import question for the host name, then `Open URL ghostty-ios://connect?host={name}`.
  - **Run a command on a host** (second step): uses the Shortcuts "Run Script Over SSH" action, or opens the app with
    a confirmation. Only if Cherri defines the action or `rawAction` can express it (verify below).
- Use `#define glyph/color` and import questions for anything user-specific.

### 3. Build and sign script (new)
- `ios/scripts/build-shortcuts.sh` (bash, mirrors `ios/scripts/` style):
  1. Fail with a clear message if not on macOS or `cherri` is missing (`brew install electrikmilk/cherri/cherri`).
  2. For each `ios/shortcuts/*.cherri`: `cherri <file> --share=anyone -o=<dist>/<name>.shortcut`.
  3. Verify the output is signed: signed files start with `AEA1`. Unsigned ones are a binary plist (`bplist`). Exit
     non-zero otherwise.
  4. Write a `manifest.json` (name, file, sha256, version) next to the outputs.
- Output dir `ios/shortcuts/dist/` is gitignored (extend `ios/.gitignore`).

### 4. Publishing the stable URL
- Recommended: attach the signed files and `manifest.json` to a GitHub Release (or Pages) from a **macOS runner** in a
  new workflow `.github/workflows/ios-shortcuts.yml` (trigger: tag `ios-shortcuts-*` or `workflow_dispatch`). Fallback:
  run the script locally and upload by hand until CI exists.
- The app keeps the base URL as one constant (new `ShortcutLinks` helper in `ios/Sources/UI/`) so it can move later.
- Decision to confirm: GitHub Releases vs. Pages vs. own domain. A GitHub release asset URL redirects, so test that
  Safari and Shortcuts accept it as the `url=` target. Pages or an own domain avoids the redirect.

### 5. App: "Add Shortcut" UI
- A new row or section in `ios/Sources/UI/Settings/` (or `HostEditView.swift`) with an "Add to Shortcuts" button.
- The button builds `shortcuts://import-shortcut?url=…&name=…` and opens it with `UIApplication.open`. If the open
  fails (no Shortcuts app), show the hosted file URL via the existing `CodeBlock` (`ios/Sources/UI/CodeBlock.swift`).
- Keep the helper pure so the URL builder is unit-testable.

### 6. Docs
- `ios/README.md`: short "Shortcuts" section (what's offered, how to rebuild, signing needs a Mac).
- This file: trimmed to what was built.

## Verify the unknowns first (spike, before building)

1. `brew install electrikmilk/cherri/cherri`; `cherri --help`; confirm flags and version.
2. Compile a hello-world with `--share=anyone` on a Mac; check it is signed and open it on a real iPhone to confirm the
   import prompt appears and the shortcut can be edited.
3. Host the file at a real HTTPS URL; confirm `shortcuts://import-shortcut?url=…` works from Safari and from a test
   button, including through a redirect.
4. `cherri --action=<name>` for SSH/script actions, open URL, and ask for input; if `runSSHScript` or similar isn't
   defined, test `rawAction` with an identifier extracted from a real shortcut (Cherri's `--import` or FAQ method).
5. Check import questions render on iOS and survive signing.
6. Check whether `#trigger` automations (documented as a future release, OS 27+) work on our Xcode 27 / iOS 27
   target. If they do, automation shortcuts become possible.

Stop and revisit the approach if step 2 or 3 fails.

## Testing

- Unit tests (`ios/Tests/`, new `DeepLinkTests`, `ShortcutLinksTests`): URL parsing (valid, unknown host, malformed,
  attempts to inject a command) and import-URL encoding.
- Script test: run `build-shortcuts.sh` on macOS; assert signed header and manifest hashes.
- Manual on device: tap "Add to Shortcuts" → Add → run → app opens the right host.
- Run `cd ios && xcodebuild test -project GhosttyiOS.xcodeproj -scheme GhosttyiOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`;
  `swiftlint lint --strict --fix`; `prettier -w` on docs (repo `AGENTS.md`).

## Out of scope / risks

- **GPL-2.0:** running the compiler as a build tool or server-side is fine. Do not vendor or link Cherri into the app.
  Confirm the generated shortcuts are not covered by the license.
- **Version drift:** Apple can change action identifiers or the format between iOS releases. Re-run the manual device
  test each iOS release.
- Repo rule: do not create issues or PRs from this work.

## Later (not in v1)

- **Natural language → shortcut:** a small service on a Mac that takes a prompt, has an LLM emit Cherri source against
  a curated action catalog, compiles and signs it (`--share=anyone`), validates, and serves the file at an
  unguessable short-lived URL. Needs rate limiting, an action allowlist (no arbitrary scripts or network posts without
  explicit surfacing), a repair loop on compiler errors, and an on-device test pass. `ios/deploy/<name>/` is the home.
- App Intents / `AppShortcutsProvider` so Ghostty actions appear natively in Shortcuts with no import.

## Critical files

- Modify: `ios/Config/Info.plist`, `ios/Sources/App/GhosttyApp.swift`, `ios/.gitignore`, `ios/README.md`, a view under
  `ios/Sources/UI/Settings/`.
- New: `ios/shortcuts/*.cherri`, `ios/scripts/build-shortcuts.sh`, `ios/Sources/App/DeepLink.swift`,
  `ios/Sources/UI/ShortcutLinks.swift`, `ios/Tests/DeepLinkTests.swift`, `ios/Tests/ShortcutLinksTests.swift`,
  `.github/workflows/ios-shortcuts.yml`, `ios/docs/cherri-shortcuts.md`.
- Reuse: `HostStore`/`Host` (`ios/Sources/Model/Host.swift`), `CodeBlock` (`ios/Sources/UI/CodeBlock.swift`),
  `DeviceKey.authorizeCommand` (`ios/Sources/Keys/DeviceKey.swift`), the `ios/scripts/` and `ios/deploy/` layouts.
