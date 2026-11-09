//
//  CloudHistoryCreator.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/8/26.
//

import CloudKit

enum CloudHistoryCreator {


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
            lastStoppedAt: lastStoppedAt
        )
    }

    public static func createHistoryRecord(basedOn history: History) async throws -> CKRecord {
        let record = CKRecord(recordType: "SyncedHistory")

        record["backdropPath"] = history.backdropPath
        record["episode"] = history.episode
        record["lastStoppedAt"] = history.lastStoppedAt
        record["mediaType"] = history.mediaType.rawValue
        record["name"] = history.name
        record["posterPath"] = history.posterPath
        record["resultId"] = history.resultId
        record["season"] = history.season
        record["watchedAt"] = history.watchedAt

        return record
    }
}
