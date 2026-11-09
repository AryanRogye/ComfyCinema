//
//  CloudHistoryCreator.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/8/26.
//

import CloudKit
import MoviesAPIData

enum CloudHistoryCreator {

    /// Function Creates a `History` from a `CKRecord`
    public static func history(from record: CKRecord) -> History? {
        guard record.recordType == "SyncedHistory",
              let resultId = record["resultId"] as? Int,
              let name = record["name"] as? String,
              let mediaTypeRaw = record["mediaType"] as? String,
              let mediaType = HistoryMediaType(rawValue: mediaTypeRaw),
              let watchedAt = record["watchedAt"] as? Date
                else {
            return nil
        }

        let id = UUID(uuidString: record.recordID.recordName)
        ?? UUID()

        let season = record["season"] as? Int
        let episode = record["episode"] as? Int
        let posterPath = record["posterPath"] as? String
        let backdropPath = record["backdropPath"] as? String
        let lastStoppedAt = record["lastStoppedAt"] as? Double

        return History(
            id: id,
            resultId: resultId,
            name: name,
            mediaType: mediaType,
            season: season,
            episode: episode,
            posterPath: posterPath,
            backdropPath: backdropPath,
            watchedAt: watchedAt,
            lastStoppedAt: lastStoppedAt,
            updatedAt: record["updatedAt"] as? Date
        )
    }

    /// Function created a `CKRecord` from a `History`
    public static func createHistoryRecord(basedOn history: History) async throws -> CKRecord {

        /// Avoid duplicate
        let recordName: String

        switch history.mediaType {
        case .movie:
            recordName = "movie-\(history.resultId)"

        case .episode:
            guard let season = history.season,
                  let episode = history.episode else {
                throw CocoaError(.validationMissingMandatoryProperty)
            }

            recordName = "episode-\(history.resultId)-s\(season)-e\(episode)"
        }

        let record = CKRecord(
            recordType: "SyncedHistory",
            recordID: CKRecord.ID(recordName: recordName)
        )

        record["backdropPath"] = history.backdropPath
        record["episode"] = history.episode
        record["lastStoppedAt"] = history.lastStoppedAt
        record["mediaType"] = history.mediaType.rawValue
        record["name"] = history.name
        record["posterPath"] = history.posterPath
        record["resultId"] = history.resultId
        record["season"] = history.season
        record["watchedAt"] = history.watchedAt
        record["updatedAt"] = history.syncDate

        return record
    }
}
