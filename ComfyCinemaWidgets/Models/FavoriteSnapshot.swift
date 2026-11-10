//
//  FavoriteSnapshot.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 11/9/26.
//

import Foundation
import AppIntents

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
