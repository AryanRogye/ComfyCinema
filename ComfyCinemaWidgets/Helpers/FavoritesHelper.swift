//
//  FavoritesHelper.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 11/9/26.
//

import SwiftData
import MoviesAPIData

@MainActor
enum FavoritesHelper: Sendable {
    public static func fetchAllFavorites(
        from container: ModelContainer
    ) async throws -> [Favorite] {

        let context = container.mainContext

        let descriptor = FetchDescriptor<Favorite>()
        let favorites: [Favorite] = try context.fetch(descriptor)
        return favorites
    }
}
