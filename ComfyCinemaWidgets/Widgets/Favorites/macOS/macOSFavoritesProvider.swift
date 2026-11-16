//
//  macOSFavoritesWidget.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 11/10/26.
//

#if os(macOS)

import WidgetKit
import SwiftUI
import MoviesAPIData
import OSLog

struct FavoritesProvider: TimelineProvider {

    func placeholder(in context: Context) -> FavoriteInfo {
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


    func getSnapshot(
        in context: Context,
        completion: @escaping (FavoriteInfo) -> Void
    ) {
        Task { completion(await snapshot()) }
    }

    private func snapshot() async -> FavoriteInfo {
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

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<FavoriteInfo>) -> Void
    ) {
        Task { completion(await timeline()) }
    }

    private func timeline() async -> Timeline<FavoriteInfo> {
        let retryDate = Date.now.addingTimeInterval(15 * 60)
        do {
            let entry = try await fetchWidgetFavorites() ?? emptyEntry()
            return Timeline(entries: [entry], policy: .after(retryDate))
        } catch {
            Logger(subsystem: "com.aryanrogye.MoviesAPIClient", category: "FavoritesWidget")
                .error("Unable to load favorites: \(String(describing: error), privacy: .public)")
            return Timeline(entries: [emptyEntry()], policy: .after(retryDate))
        }
    }

    private func emptyEntry() -> FavoriteInfo {
        FavoriteInfo(
            date: .now,
            favorite1: nil,
            favorite2: nil,
            favorite3: nil,
            favorite4: nil
        )
    }

    @MainActor
    func fetchWidgetFavorites() async throws -> FavoriteInfo? {
        let container = try ModelConfigFetcher.fetch()

        guard let widgetFavorites = try FavoritesHelper.fetchAllWidgetFavorites(
            from: container
        ) else {
            return nil
        }

        let favs = try FavoritesHelper.fetchAllFavorites(from: container)

        func favorite(for id: Int?) async throws -> FavoriteContainer? {
            guard let id,
                  let fav = favs.first(where: { $0.id == id }) else {
                return nil
            }

            return try await FavoriteContainer(favorite: fav)
        }

        return FavoriteInfo(
            date: Date(),
            favorite1: try await favorite(for: widgetFavorites.favorite1ID),
            favorite2: try await favorite(for: widgetFavorites.favorite2ID),
            favorite3: try await favorite(for: widgetFavorites.favorite3ID),
            favorite4: try await favorite(for: widgetFavorites.favorite4ID)
        )
    }
}
#endif
