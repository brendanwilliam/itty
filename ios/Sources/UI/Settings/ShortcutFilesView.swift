import SwiftUI

/// The `.shortcut` files in the local shell's home folder, made by
/// `cherri program.cherri`, with a share sheet for each.
///
/// Files are unsigned unless compiled with `cherri --sign`, which sends the
/// shortcut to a signing service (opt-in, needs a connection).
struct ShortcutFilesView: View {
    @Environment(\.openURL) private var openURL
    @State private var files: [URL] = []
    /// An offering the Shortcuts app wouldn't open, whose file address is shown instead.
    @State private var unopened: ShortcutLinks.Offering?

    var body: some View {
        List {
            Section {
                ForEach(ShortcutLinks.offerings) { offering in
                    Button {
                        // The shortcuts://import-shortcut link answers "The shortcut URL
                        // provided was invalid" on a device, so open the iCloud link instead.
                        openURL(ShortcutLinks.addURL(for: offering)) { accepted in
                            unopened = accepted ? nil : offering
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Add \(offering.name) to Shortcuts", systemImage: "plus.square")
                            Text(offering.summary).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if let unopened {
                    Text("The browser didn't open. Download this file, then open it in Shortcuts:")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    CodeBlock(text: ShortcutLinks.fileURL(for: unopened).absoluteString, wraps: true)
                }
            } header: {
                Text("From itty")
            } footer: {
                Text("Shortcuts asks you to confirm before adding one, and you can edit it afterwards.")
            }

            if files.isEmpty {
                Section {
                    Text("No shortcuts yet.")
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Write a program in the terminal (for example with vim) and compile it with `cherri hello.cherri`; add `--sign` while online to sign it. The result appears here.")
                }
            } else {
                Section {
                    ForEach(files, id: \.self) { file in
                        ShareLink(item: file) {
                            Label(file.lastPathComponent, systemImage: "square.and.arrow.up")
                        }
                    }
                } footer: {
                    Text("Signed shortcuts import on any device. Unsigned ones may not.")
                }
            }
        }
        .navigationTitle("Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { files = Self.shortcutFiles(in: LocalEnvironment.home) }
    }

    /// `.shortcut` files under `folder`, newest first, at most a few levels deep.
    static func shortcutFiles(in folder: URL, depth: Int = 3) -> [URL] {
        let manager = FileManager.default
        guard let entries = try? manager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var found: [URL] = []
        for entry in entries {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true {
                if depth > 0 { found += shortcutFiles(in: entry, depth: depth - 1) }
            } else if entry.pathExtension == "shortcut" {
                found.append(entry)
            }
        }
        return found.sorted { modified($0) > modified($1) }
    }

    private static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}
