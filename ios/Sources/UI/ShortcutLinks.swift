import Foundation

/// The Shortcuts we host, and the links that import them. Opening
/// `shortcuts://import-shortcut?url=…&name=…` shows Apple's "Add Shortcut"
/// screen; the shortcut is then the user's to edit.
///
/// The files are built and signed on a Mac by `scripts/build-shortcuts.sh`
/// and published by `.github/workflows/ios-shortcuts.yml`.
enum ShortcutLinks {
    /// Where the signed files live. The only place the address is written.
    static let baseURL = URL(string: "https://brendanwilliam.github.io/itty/shortcuts/")!

    struct Offering: Identifiable, Equatable {
        /// The name Shortcuts shows, and the stem of the hosted file.
        let name: String
        let summary: String
        var id: String { name }
        var fileName: String { "\(name).shortcut" }
    }

    static let offerings = [
        Offering(name: "Open Host", summary: "Asks for a saved host's name, then opens it in itty."),
    ]

    /// The hosted file for an offering.
    static func fileURL(for offering: Offering, base: URL = baseURL) -> URL {
        base.appendingPathComponent(offering.fileName.replacingOccurrences(of: " ", with: "-").lowercased())
    }

    /// The link that imports an offering into the Shortcuts app.
    static func importURL(for offering: Offering, base: URL = baseURL) -> URL {
        importURL(file: fileURL(for: offering, base: base), name: offering.name)
    }

    static func importURL(file: URL, name: String) -> URL {
        URL(string: "shortcuts://import-shortcut?url=\(encode(file.absoluteString, keeping: ":/"))&name=\(encode(name))")!
    }

    /// Percent-encodes everything but unreserved characters (and `keeping`),
    /// so `&`, `=` and `+` inside a value can't be mistaken for query syntax.
    /// The file address keeps its `:` and `/`: with them escaped, Shortcuts
    /// on a device answered "The shortcut URL provided was invalid".
    static func encode(_ value: String, keeping extra: String = "") -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreserved.union(CharacterSet(charactersIn: extra))) ?? ""
    }

    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}
