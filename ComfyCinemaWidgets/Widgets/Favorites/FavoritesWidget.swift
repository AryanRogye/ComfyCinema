//
//  FavoritesWidget.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 11/9/26.
//

import WidgetKit
import SwiftUI
import MoviesAPIData

struct FavoriteContainer {
    let id = UUID()
    let favorite: Favorite
    let color: SystemColor?
    let image: SystemImage?

    init(favorite: Favorite) {
        self.favorite = favorite
        self.color = nil
        self.image = nil
    }

    init(favorite: Favorite) async throws {
        let image = try? await TMDBImageLoader.loadImage(from: favorite.posterPath)
        let color = image == nil ? nil : ColorExtractor.getDominantColor(from: image!)
        self.favorite = favorite
        self.color = color
        self.image = image
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

struct FavoritesProvider: AppIntentTimelineProvider {
    func placeholder(
        in context: Context
    ) -> FavoriteInfo {
        return FavoriteInfo(
            date: Date(),
            favorite1: .init(favorite: .init(
                id: 969681,
                name: "Spider-Man: Brand New Day",
                mediaType: "movie",
                posterPath: "/9JCQtDCSpPR2ld55yNlEg1VwcQo.jpg"
            )),
            favorite2: .init(favorite: .init(
                id: 99861,
                name: "Avengers: Age of Ultron",
                mediaType: "movie",
                posterPath: "/4ssDuvEDkSArWEdyBl2X5EHvYKU.jpg",
            )),
            favorite3: .init(favorite: .init(
                id: 99861,
                name: "Marvel's Daredevil",
                mediaType: "show",
                posterPath: "/u6tICVagGwukuFPr0qBUwOqCKSn.jpg",
            )),
            favorite4: .init(favorite: .init(
                id: 60573,
                name: "Silicon Valley",
                mediaType: "show",
                posterPath: "/4ptpmWBVD9HY9hMh8Cbs6SMiy7p.jpg"
            )),
        )
    }

    func snapshot(
        for configuration: FavoritesIntent,
        in context: Context
    ) async -> FavoriteInfo {
        return FavoriteInfo(
            date: Date(),
            favorite1: try? await .init(favorite: .init(
                id: 95396,
                name: "Severance",
                mediaType: "show",
                posterPath: "/pPHpeI2X1qEd1CS1SeyrdhZ4qnT.jpg"
            )),
            favorite2: try? await .init(favorite: .init(
                id: 88329,
                name: "Hawkeye",
                mediaType: "show",
                posterPath: "/ct5pNE5dDHryHLDnxyZPYcqO1sz.jpg"
            )),
            favorite3: try? await .init(favorite: .init(
                id: 61889,
                name: "Marvel's Daredevil",
                mediaType: "show",
                posterPath: "/QWbPaDxiB6LW2LjASknzYBvjMj.jpg"
            )),
            favorite4: try? await .init(favorite: .init(
                id: 62560,
                name: "Mr. Robot",
                mediaType: "show",
                posterPath: "/kv1nRqgebSsREnd7vdC2pSGjpLo.jpg"
            )),
        )

    }

    func timeline(
        for configuration: FavoritesIntent,
        in context: Context
    ) async -> Timeline<FavoriteInfo> {

        var favorite1: FavoriteContainer? = nil
        var favorite2: FavoriteContainer? = nil
        var favorite3: FavoriteContainer? = nil
        var favorite4: FavoriteContainer? = nil

        if let fav1 = configuration.favorite1 {
            favorite1 = try? await .init(favorite: createFavorite(from: fav1))
        }
        if let fav2 = configuration.favorite2 {
            favorite2 = try? await .init(favorite: createFavorite(from: fav2))
        }
        if let fav3 = configuration.favorite3 {
            favorite3 = try? await .init(favorite: createFavorite(from: fav3))
        }
        if let fav4 = configuration.favorite4 {
            favorite4 = try? await .init(favorite: createFavorite(from: fav4))
        }

        let favoriteInfo = FavoriteInfo(
            date: Date(),
            favorite1: favorite1,
            favorite2: favorite2,
            favorite3: favorite3,
            favorite4: favorite4,
        )

        return Timeline(
            entries: [favoriteInfo],
            policy: .never
        )
    }

    private func createFavorite(from snapshot: FavoriteSnapshot) -> Favorite {
        return .init(
            id: snapshot.id,
            name: snapshot.name,
            mediaType: snapshot.mediaType,
            posterPath: snapshot.posterPath
        )
    }
}

struct FavoritesWidget: Widget {

    let kind: String = "FavoriteWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: FavoritesIntent.self,
            provider: FavoritesProvider()
        ) { entry in
            FavoritesWidgetView(entry: entry)
                .contentMargins(.zero)
                .containerBackground(.clear, for: .widget)
                .background(.clear)
        }
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge
        ])
    }
}
