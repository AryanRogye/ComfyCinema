//
//  CloudKitResolver.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/8/26.
//

import CloudKit
import MoviesAPIData

enum CloudKitResolver {

    /// Function resolves current history from records
    /// stored in iCloud
    public static func resolve(
        from history: [History],
        with records: [CKRecord]
    ) -> [History] {

        var updatedHistory: [History] = []

        var storedHistory = records.compactMap {
            CloudHistoryCreator.history(from: $0)
        }

        for history in history {
            /// Check to see if the storedHistory contains the same resultId and the mediaType
            if let stored = storedHistory.first(where: { stored in

                /// Skip if resultID or mediaType doesnt match
                guard stored.resultId == history.resultId, stored.mediaType == history.mediaType else {
                    return false
                }

                /// Handle each media type seperately
                switch history.mediaType {
                case .movie:
                    /// Movie doesnt need any extra checks
                    return true

                case .episode:
                    /// Episodes need to match seasons and episodes
                    return stored.season == history.season &&
                    stored.episode == history.episode
                }
            }) {
                /// Keep the most recently edited history, including playback progress.
                if history.syncDate > stored.syncDate {
                    updatedHistory.append(history)
                } else {
                    updatedHistory.append(stored)
                }
                storedHistory.removeAll(where: { $0.id == stored.id })
            } else {
                /// does not match in here
                updatedHistory.append(history)
            }
        }

        for history in storedHistory {
            updatedHistory.append(history)
        }

        return updatedHistory
    }

    /// Function returns updated CKRecords, if any history in merged is inside of existing
    /// we will update
    static func recordsToSave(
        merged: [History],
        existing: [CKRecord]
    ) async throws -> [CKRecord] {

        var recordsToSave: [CKRecord] = []

        for history in merged {
            /// see if history exists in stored iCloud history
            let existingRecord = existing.first { record in
                guard let stored = CloudHistoryCreator.history(from: record) else {
                    return false
                }

                return matches(history, stored)
            }

            if let existingRecord {
                /// Create a `History` based off stored
                guard let stored = CloudHistoryCreator.history(from: existingRecord) else {
                    continue
                }

                /// Cloud already has the latest version.
                if stored.syncDate >= history.syncDate {
                    continue
                }

                /// Update the existing record, preserving its ID/change tag.
                existingRecord["watchedAt"] = history.watchedAt
                existingRecord["updatedAt"] = history.syncDate
                existingRecord["lastStoppedAt"] =
                history.lastStoppedAt.map { NSNumber(value: $0) }

                recordsToSave.append(existingRecord)

            } else {
                // No corresponding CloudKit record exists.
                let record = try await CloudHistoryCreator.createHistoryRecord(
                    basedOn: history
                )

                recordsToSave.append(record)
            }
        }

        return recordsToSave
    }

    static func matches(_ lhs: History, _ rhs: History) -> Bool {
        guard lhs.resultId == rhs.resultId,
              lhs.mediaType == rhs.mediaType else {
            return false
        }

        switch lhs.mediaType {
        case .movie:
            return true
        case .episode:
            return lhs.season == rhs.season &&
            lhs.episode == rhs.episode
        }
    }
}
