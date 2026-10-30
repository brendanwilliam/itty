import Foundation

/// A `itty://` link, e.g. from a Shortcut. The only route is
/// `itty://connect?host=<name>`, which opens a host that is already
/// saved. Any app or web page can open these URLs, so a link never runs a
/// command and never creates a host or key; it only selects an existing one.
enum DeepLink: Equatable {
    static let scheme = "itty"

    case connect(host: String)

    /// Nil for anything but a well-formed `connect` link with a single
    /// `host` and nothing else.
    static func parse(_ url: URL) -> DeepLink? {
        guard url.scheme?.lowercased() == scheme,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.host?.lowercased() == "connect",
              parts.path.isEmpty || parts.path == "/",
              parts.fragment == nil,
              let items = parts.queryItems, items.count == 1,
              items[0].name == "host",
              let name = items[0].value, !name.isEmpty else { return nil }
        return .connect(host: name)
    }

    /// The saved host a link refers to, if there is exactly one.
    @MainActor
    func resolve(in store: HostStore) -> Host? {
        switch self {
        case .connect(let name):
            if name.caseInsensitiveCompare(Host.local.name) == .orderedSame { return .local }
            return store.host(named: name)
        }
    }
}
