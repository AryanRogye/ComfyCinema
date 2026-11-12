//
//  FavoriteInfo.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 11/10/26.
//

import Foundation
import MoviesAPIData
import WidgetKit

/// Values owned by the timeline, independent of the SwiftData context's lifetime.
struct WidgetFavoriteSnapshot: Sendable {
    let id: Int
    let name: String
    let mediaType: String
    let posterPath: String?

    init(favorite: Favorite) {
        id = favorite.id
        name = favorite.name
        mediaType = favorite.mediaType
        posterPath = favorite.posterPath
    }
}

struct FavoriteContainer {
    let id = UUID()
    let favorite: WidgetFavoriteSnapshot
    let color: SystemColor?
    let image: SystemImage?

    init(favorite: Favorite) {
        self.favorite = WidgetFavoriteSnapshot(favorite: favorite)
        self.color = nil
        self.image = nil
    }

    init(favorite: Favorite) async throws {
        // Copy every model property before suspending or releasing its context.
        let snapshot = WidgetFavoriteSnapshot(favorite: favorite)
        self.favorite = snapshot
        let loadedImage = try? await TMDBImageLoader.loadImage(from: snapshot.posterPath)
        self.image = loadedImage
        if let loadedImage {
            self.color = ColorExtractor.getDominantColor(from: loadedImage)
        } else {
            self.color = nil
        }
    }

    var watchURL: URL {
        URL(string: "comfycinema://favorite?id=\(favorite.id)")!
    }
}

struct FavoriteInfo: TimelineEntry {
    let date: Date
    let favorite1: FavoriteContainer?
    let favorite2: FavoriteContainer?
    let favorite3: FavoriteContainer?
    let favorite4: FavoriteContainer?
}
