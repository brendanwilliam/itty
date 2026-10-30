# Shortcuts

Shortcuts the app offers in Settings > Shortcuts, written in
[Cherri](https://github.com/electrikmilk/cherri) (GPL-2.0, used here only as a
build tool; nothing from it is linked into the app).

| Source | Shortcut | What it does |
| --- | --- | --- |
| `open-host.cherri` | Open Host | Asks (at import time) for a saved host's name, then opens `ghostty-ios://connect?host=<name>`. |

## Build

Signing runs Apple's `shortcuts sign`, so this needs a Mac:

```sh
brew install electrikmilk/cherri/cherri
ios/scripts/build-shortcuts.sh        # writes ios/shortcuts/dist/
```

`dist/` holds one signed `<name>.shortcut` per source plus `manifest.json`
(name, file, SHA-256). It is gitignored. Pushing a tag named `ios-shortcuts-*`
(or running the workflow by hand) builds and publishes it with
`.github/workflows/ios-shortcuts.yml`. The app's Add buttons point at the
published address in `Sources/UI/ShortcutLinks.swift`.

The file name is the published name: `open-host.cherri` becomes
`open-host.shortcut`, and `ShortcutLinks.fileURL(for:)` derives the same name
from the offering's title.

## The `ghostty-ios://` link

`ghostty-ios://connect?host=<name>` opens a host that is already saved (or
`This iPhone`). Any app or web page can open this URL, so the handler
(`Sources/App/DeepLink.swift`) only selects an existing host by name: it
never runs a command and never creates a host or key. Unknown or duplicate
names do nothing.
