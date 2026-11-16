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
    #if os(macOS)
    public static func fetchAllWidgetFavorites(
        from container: ModelContainer
    ) throws -> WidgetFavorites? {
        let context = container.mainContext

        let descriptor = FetchDescriptor<WidgetFavorites>()
        let favorites = try context.fetch(descriptor).first
        return favorites
    }
    #endif
    public static func fetchAllFavorites(
        from container: ModelContainer
    ) throws -> [Favorite] {

        let context = container.mainContext

        let descriptor = FetchDescriptor<Favorite>()
        let favorites: [Favorite] = try context.fetch(descriptor)
        return favorites
    }
}
