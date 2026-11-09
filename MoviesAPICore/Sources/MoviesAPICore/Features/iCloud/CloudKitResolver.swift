//
//  CloudKitResolver.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/8/26.
//

import CloudKit

enum CloudKitResolver {
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
                guard stored.resultId == history.resultId,
                      stored.mediaType == history.mediaType else {
                    return false
                }

                switch history.mediaType {
                case .movie:
                    return true

                case .episode:
                    return stored.season == history.season &&
                    stored.episode == history.episode
                }
            }) {
                /// this means that there is a record found in here so we compare its mostRecently watchedAt
                if history.watchedAt > stored.watchedAt {
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

    static func recordsToSave(
        merged: [History],
        existing: [CKRecord]
    ) async throws -> [CKRecord] {
        var recordsToSave: [CKRecord] = []

        for history in merged {
            let existingRecord = existing.first { record in
                guard let stored = CloudHistoryCreator.history(from: record) else {
                    return false
                }

                return matches(history, stored)
            }

            if let existingRecord {
                guard let stored = CloudHistoryCreator.history(from: existingRecord)
                        else {
                    continue
                }

                // Cloud already has the latest version.
                if stored.watchedAt >= history.watchedAt {
                    continue
                }

                // Update the existing record, preserving its ID/change tag.
                existingRecord["watchedAt"] = history.watchedAt
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
