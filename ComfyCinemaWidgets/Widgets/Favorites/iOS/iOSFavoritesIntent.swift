//
//  FavoritesIntent.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 11/9/26.
//

#if os(iOS)

import WidgetKit
import AppIntents
import MoviesAPIData

struct FavoritesIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Favorites"
    static let description: IntentDescription? = "A list of your favorite movies."

    @Parameter(title: "Favorite Item 1")
    var favorite1: FavoriteSnapshot?

    @Parameter(title: "Favorite Item 2")
    var favorite2: FavoriteSnapshot?

    @Parameter(title: "Favorite Item 3")
    var favorite3: FavoriteSnapshot?

    @Parameter(title: "Favorite Item 4")
    var favorite4: FavoriteSnapshot?
}

struct FavoriteSnapshot: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Favorite")
    static let defaultQuery = FavoritesQuery()

    let favoriteID: Int
    let name: String
    let mediaType: String
    let posterPath: String?

    var id: Int { favoriteID }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(mediaType)")
    }
}

struct FavoritesQuery: EntityQuery {
    func entities(for identifiers: [FavoriteSnapshot.ID]) async throws -> [FavoriteSnapshot] {
        let favorites = try await suggestedEntities()
        let favoritesByID = Dictionary(uniqueKeysWithValues: favorites.map { ($0.id, $0) })
        return identifiers.compactMap { favoritesByID[$0] }
    }

    @MainActor
    func suggestedEntities() async throws -> [FavoriteSnapshot] {
        let container = try ModelConfigFetcher.fetch()
        let favorites = try await FavoritesHelper.fetchAllFavorites(from: container)
        return favorites.map {
            FavoriteSnapshot(
                favoriteID: $0.id,
                name: $0.name,
                mediaType: $0.mediaType,
                posterPath: $0.posterPath)
        }
    }
}

#endif
