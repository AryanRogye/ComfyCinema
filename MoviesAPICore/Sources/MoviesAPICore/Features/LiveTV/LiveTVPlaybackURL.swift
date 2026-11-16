import Foundation

/// DEmbed requires the player to be embedded by the provider's published page.
/// Direct navigation and app-generated iframe hosts are rejected by the provider.
enum LiveTVPlaybackURL {
    static func resolve(_ url: URL) -> URL {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "dembed.st",
              url.path == "/premiumtv/daddy.php",
              let source = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let rawID = source.queryItems?.first(where: { $0.name == "id" })?.value,
              let channelID = Int32(rawID), channelID > 0 else { return url }

        var page = URLComponents()
        page.scheme = "https"
        page.host = "dlive.sx"
        page.path = "/stream/stream-\(channelID).php"
        return page.url ?? url
    }
}
