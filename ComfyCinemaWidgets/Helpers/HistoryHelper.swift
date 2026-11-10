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
            historyId: history.id,
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
