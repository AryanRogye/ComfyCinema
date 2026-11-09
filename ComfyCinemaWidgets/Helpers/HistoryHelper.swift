//
//  HistoryHelper.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 11/9/26.
//

import Foundation
import SwiftData
import MoviesAPIData
import SwiftUI

@MainActor
enum HistoryHelper: Sendable {

    public static func loadHistoryImage(
        from posterPath: String?
    ) async throws -> SystemImage? {
        guard let posterPath else { return nil }
        guard let url = URL(    string: "https://image.tmdb.org/t/p/w500\(posterPath)") else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)

        print("Poster response:", response)
        print("Poster bytes:", data.count)

#if os(macOS)
        return NSImage(data: data)
#else
        return UIImage(data: data)
#endif
    }

    public static func fetchLatestHistory(
        from container: ModelContainer
    ) throws -> HistorySnapshot? {

        let context = container.mainContext

        /// Grab Latest History
        var descriptor = FetchDescriptor<History>(
            sortBy: [
                SortDescriptor(\.watchedAt, order: .reverse)
            ]
        )
        descriptor.fetchLimit = 1

        /// Resolve
        guard let history = try context.fetch(descriptor).first else {
            return nil
        }

        /// Return Snapshot
        return HistorySnapshot(
            resultId: history.resultId,
            name: history.name,
            mediaType: history.mediaType,
            posterPath: history.posterPath,
            season: history.season,
            episode: history.episode,
            updatedAt: history.watchedAt
        )
    }
}
