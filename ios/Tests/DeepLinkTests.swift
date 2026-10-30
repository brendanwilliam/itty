import XCTest
@testable import GhosttyiOS

/// `ghostty-ios://` links open a saved host and nothing else: any app or
/// web page can open one.
@MainActor
final class DeepLinkTests: XCTestCase {
    private var store: HostStore!

    override func setUp() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("deeplink-hosts-\(UUID().uuidString).json")
        store = HostStore(url: url)
        store.upsert(Host(name: "Studio Mac", hostname: "studio.local", username: "me"))
        store.upsert(Host(name: "Laptop", hostname: "laptop.local", username: "me"))
    }

    private func parse(_ string: String) -> DeepLink? {
        URL(string: string).flatMap(DeepLink.parse)
    }

    func testConnectNamesAHost() {
        XCTAssertEqual(parse("ghostty-ios://connect?host=Laptop"), .connect(host: "Laptop"))
        XCTAssertEqual(parse("ghostty-ios://connect?host=Studio%20Mac"), .connect(host: "Studio Mac"))
        XCTAssertEqual(parse("GHOSTTY-IOS://connect/?host=Laptop"), .connect(host: "Laptop"))
    }

    func testAnythingElseIsRejected() {
        XCTAssertNil(parse("https://connect?host=Laptop"), "wrong scheme")
        XCTAssertNil(parse("ghostty-ios://run?host=Laptop"), "unknown route")
        XCTAssertNil(parse("ghostty-ios://connect/extra?host=Laptop"), "extra path")
        XCTAssertNil(parse("ghostty-ios://connect"), "no host")
        XCTAssertNil(parse("ghostty-ios://connect?host="), "empty host")
        XCTAssertNil(parse("ghostty-ios://connect?name=Laptop"), "wrong parameter")
        XCTAssertNil(parse("ghostty-ios://connect?host=Laptop&command=ls"), "extra parameter")
        XCTAssertNil(parse("ghostty-ios://connect?host=Laptop&host=Studio%20Mac"), "two hosts")
        XCTAssertNil(parse("ghostty-ios://connect?host=Laptop#frag"), "fragment")
    }

    func testResolvesASavedHostIgnoringCase() {
        XCTAssertEqual(DeepLink.connect(host: "laptop").resolve(in: store)?.hostname, "laptop.local")
        XCTAssertEqual(DeepLink.connect(host: "studio mac").resolve(in: store)?.hostname, "studio.local")
    }

    func testThisIPhoneOpensTheLocalShell() {
        XCTAssertEqual(DeepLink.connect(host: "this iphone").resolve(in: store), .local)
    }

    func testUnknownNamesOpenNothing() {
        XCTAssertNil(DeepLink.connect(host: "Nowhere").resolve(in: store))
        XCTAssertNil(DeepLink.connect(host: "Laptop; rm -rf ~").resolve(in: store))
        XCTAssertNil(DeepLink.connect(host: "laptop.local").resolve(in: store), "names, not addresses")
    }

    func testAmbiguousNamesOpenNothing() {
        store.upsert(Host(name: "laptop", hostname: "other.local", username: "me"))
        XCTAssertNil(DeepLink.connect(host: "Laptop").resolve(in: store))
    }

    func testResolvingNeverChangesTheSavedHosts() {
        let before = store.hosts
        _ = DeepLink.connect(host: "Nowhere").resolve(in: store)
        _ = DeepLink.connect(host: "Laptop").resolve(in: store)
        XCTAssertEqual(store.hosts, before)
    }
}
