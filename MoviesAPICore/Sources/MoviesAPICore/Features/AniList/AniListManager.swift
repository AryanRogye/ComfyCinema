//
//  AniListManager.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 10/12/26.
//

import Foundation

enum AniListError: LocalizedError {
    case cantConstructUrl
    case serverSentErrorCode(Int?)

    var errorDescription: String? {
        switch self {
        case .cantConstructUrl:
            "Cant Construct URL"
        case .serverSentErrorCode(let num):
            "Server Sent Error Code: \(num ?? -1)"
        }
    }
}

/// ==============================================
/// SEARCH MODELS
/// ==============================================
struct AniListSearchResponse: Decodable {
    let data: AniListSearchData
}

struct AniListSearchData: Decodable {
    let Page: AniListPage
}

struct AniListPage: Decodable {
    let media: [Anime]
}

public struct Anime: Decodable, Identifiable {
    public let id: Int
    let format: String?
    let title: AnimeTitle
    let coverImage: AnimeCoverImage
    let description: String?
}

public struct AnimeTitle: Decodable {
    let romaji: String?
    let english: String?
}

public struct AnimeCoverImage: Decodable {
    let extraLarge: URL?
    let large: URL?
    let medium: URL?
}

struct AnimeEpisodeResponse: Codable, Hashable {
    let anilistId: Int
    let title: String
    let totalEpisodes: Int
    let availableServers: Int
    let episodes: [Episode]
}

struct Episode: Codable, Hashable {
    let number: Int
    let title: String
    let titleJapanese: String
    let image: String
    let airDate: String
    let duration: Int
    let filler: Bool
    let description: String
    let sub: Bool
    let dub: Bool
}

@Observable
@MainActor
final class AniListManager {

    var searchResults: [Anime] = []

    struct GraphQLRequest: Encodable {
        let query: String
        let variables: [String: String]
    }

    public static func getEpisodeInfo(on id: Int) async throws -> AnimeEpisodeResponse {
        guard let url = URL(string: "https://api.aniweeb.net/episodes/\(id)") else {
            throw AniListError.cantConstructUrl
        }
        // Perform the network call
        let (data, response) = try await URLSession.shared.data(from: url)

        // Check for success status code
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AniListError.serverSentErrorCode((response as? HTTPURLResponse)?.statusCode)
        }

        // Decode the JSON into your AnimeResponse model
        let animeData = try JSONDecoder().decode(AnimeEpisodeResponse.self, from: data)

        return animeData
    }

    func search(_ searchTerm: String) async throws {
        guard let url = URL(string: "https://graphql.anilist.co") else {
            throw AniListError.cantConstructUrl
        }

        let query = """
        query ($search: String!) {
            Page(page: 1, perPage: 5) {
                media(search: $search, type: ANIME) {
                    id
                    format
                    title {
                        romaji
                        english
                    }
                    coverImage { 
                        extraLarge 
                        large 
                        medium 
                    }
                    description
                }
            }
        }
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = GraphQLRequest(
            query: query,
            variables: ["search": searchTerm]
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)

        let response = try JSONDecoder().decode(
            AniListSearchResponse.self,
            from: data
        )

        let anime = response.data.Page.media

        self.searchResults = anime
    }

    func clearSearchResults() {
        
    }
}
