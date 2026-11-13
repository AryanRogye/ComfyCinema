//
//  CloudHistoryCreator.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/8/26.
//

import CloudKit
import MoviesAPIData

enum CloudRecordResolver {}

// MARK: - `CKRecord` To Object
extension CloudRecordResolver {
    public static func deletedHistory(from record: CKRecord) -> DeletedHistory? {
        guard record.recordType == "DeletedHistory",
              let resultId = record["resultId"] as? Int,
              let mediaTypeRaw = record["mediaType"] as? String,
              let mediaType = HistoryMediaType(rawValue: mediaTypeRaw),
              let deletedAt = record["deletedAt"] as? Date
                else {
            return nil
        }

        let season = record["season"] as? Int
        let episode = record["episode"] as? Int

        return DeletedHistory(
            resultId: resultId,
            mediaType: mediaType,
            season: season,
            episode: episode,
            deletedAt: deletedAt
        )
    }

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
}

// MARK: - `CKRecord` Creation

extension CloudRecordResolver {

    public static func createHistoryDeletion(basedOn history: DeletedHistory) async throws -> CKRecord {
        let recordName = try CloudIdentifierCreator.createIdentifierToAvoidClashes(
            base: "deletion-",
            resultId: history.resultId,
            mediaType: history.mediaType,
            season: history.season,
            episode: history.episode
        )
        let record = CKRecord(
            recordType: "DeletedHistory",
            recordID: CKRecord.ID(recordName: recordName)
        )
        record["resultId"] = history.resultId
        record["mediaType"] = history.mediaType.rawValue
        record["season"] = history.season
        record["episode"] = history.episode
        record["deletedAt"] = history.deletedAt
        return record
    }

    /// Function created a `CKRecord` from a `History`
    public static func createHistoryRecord(basedOn history: History) async throws -> CKRecord {
        let recordName = try CloudIdentifierCreator.createIdentifierToAvoidClashes(
            base: "",
            resultId: history.resultId,
            mediaType: history.mediaType,
            season: history.season,
            episode: history.episode
        )

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
