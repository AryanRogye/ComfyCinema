public struct PlayRequest: Codable, Sendable, Equatable {
    public enum MediaType: String, Codable, Sendable {
        case movie
        case tv

        var kt_mediaType: KTMediaType {
            switch self {
            case .movie:
                return .movie
            case .tv:
                return .tv
            }
        }
    }

    public let id: Int
    public let name: String
    public let mediaType: MediaType
    public let season: Int?
    public let episode: Int?

    public init(id: Int, name: String, mediaType: MediaType, season: Int? = nil, episode: Int? = nil) {
        self.id = id
        self.name = name
        self.mediaType = mediaType
        self.season = season
        self.episode = episode
    }

    public func matches(_ result: KTSearchResult) -> Bool {
        id == Int(result.id) && mediaType.kt_mediaType == result.mediaType
    }
}
