import XCTest
@testable import GhosttyiOS

final class ShortcutLinksTests: XCTestCase {
    private let base = URL(string: "https://example.com/shortcuts/")!

    func testImportLinkCarriesTheEncodedFileAddressAndName() {
        let offering = ShortcutLinks.Offering(name: "Open Host", summary: "")
        XCTAssertEqual(
            ShortcutLinks.importURL(for: offering, base: base).absoluteString,
            "shortcuts://import-shortcut?url=https://example.com/shortcuts/open-host.shortcut&name=Open%20Host")
    }

    func testAddLinkPrefersTheICloudLinkAndFallsBackToTheHostedFile() {
        let icloud = URL(string: "https://www.icloud.com/shortcuts/abc")!
        XCTAssertEqual(
            ShortcutLinks.addURL(for: .init(name: "Open Host", summary: "", iCloudLink: icloud), base: base), icloud)
        XCTAssertEqual(
            ShortcutLinks.addURL(for: .init(name: "Open Host", summary: ""), base: base).absoluteString,
            "https://example.com/shortcuts/open-host.shortcut")
    }

    func testFileNameIsTheLowercasedNameWithDashes() {
        let offering = ShortcutLinks.Offering(name: "Open Host", summary: "")
        XCTAssertEqual(ShortcutLinks.fileURL(for: offering, base: base).lastPathComponent, "open-host.shortcut")
    }

    func testQuerySyntaxInsideAValueIsEncoded() {
        let url = ShortcutLinks.importURL(file: URL(string: "https://example.com/a?b=c&d=e+f")!, name: "A&B=C+é")
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(query.map(\.name), ["url", "name"], "only two parameters")
        XCTAssertEqual(query[0].value, "https://example.com/a?b=c&d=e+f")
        XCTAssertEqual(query[1].value, "A&B=C+é")
    }

    func testEveryOfferingHasASourceFile() throws {
        // Tests run from the built app; find shortcuts/ relative to this file.
        let shortcuts = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("shortcuts")
        for offering in ShortcutLinks.offerings {
            let stem = ShortcutLinks.fileURL(for: offering).deletingPathExtension().lastPathComponent
            XCTAssertTrue(FileManager.default.fileExists(atPath: shortcuts.appendingPathComponent("\(stem).cherri").path),
                          "\(offering.name) has no shortcuts/\(stem).cherri")
        }
    }
}
