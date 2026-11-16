//
//  CloudKitManager.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/7/26.
//

import CloudKit
import SwiftData
import Defaults
import MoviesAPIData

enum CloudKitError: LocalizedError {
    case noToken
    case tokenEmpty
    var errorDescription: String? {
        switch self {
        case .noToken:
            "No iCloudIdentifier in Info.plist"
        case .tokenEmpty:
            "iCloudIdentifier is empty"
        }
    }
}

@Observable
@MainActor
public final class CloudKitManager {

    let identifier: String
    let container: CKContainer
    let database: CKDatabase
    var resolveStatus: String?

    public init() throws {
        guard let identifier = Bundle.main.object(
            forInfoDictionaryKey: "iCloudIdentifier"
        ) as? String else {
            throw CloudKitError.noToken
        }
        if identifier.isEmpty {
            throw CloudKitError.tokenEmpty
        }

        self.identifier = identifier
        self.container = CKContainer(identifier: identifier)
        self.database = container.privateCloudDatabase
    }
}

// MARK: - History iCloud
extension CloudKitManager {

    /// Called when created history so we can remove from the iCloud Records if it exists
    public func removeHistoryFromDeletedIfNeeded(_ history: History) async throws {
        let deletedHistory = DeletedHistory(history: history)
        let deleted = try await CloudRecordResolver.createHistoryDeletion(basedOn: deletedHistory)
        try await database.deleteRecord(withID: deleted.recordID)
    }

    /// Called when history is deleted
    public func markHistoryAsDeleted(_ history: History) async throws {
        let deletedHistory = DeletedHistory(history: history)
        let deleted = try await CloudRecordResolver.createHistoryDeletion(basedOn: deletedHistory)
        let _ = try await database.modifyRecords(
            saving: [deleted],
            deleting: [],
            savePolicy: .ifServerRecordUnchanged,
            atomically: false
        )
    }

    public func resolveHistory(from ctx: ModelContext) async throws -> [History] {
        defer { resolveStatus = nil }
        let currentHistory = try extractHistory(from: ctx)
        resolveStatus = "Gathered Current History: \(currentHistory.count)"

        let cloudHistory = try await fetchAllHistoryRecords()
        resolveStatus = "Gathered Cloud History: \(cloudHistory.count)"

        let deletedHistory = try await fetchAllDeletedRecords()
        resolveStatus = "Gathered Deleted Cloud History: \(deletedHistory.count)"

        let mergedHistory = CloudHistoryResolver.resolve(
            from: currentHistory,
            with: cloudHistory,
            deleted: deletedHistory
        )
        resolveStatus = "Merged History: \(mergedHistory.count)"

        let recordsToSave = try await CloudHistoryResolver.recordsToSave(
            merged: mergedHistory,
            existing: cloudHistory
        )
        resolveStatus = "Resolved Records To Save: \(recordsToSave.count)"

        guard !recordsToSave.isEmpty else {
            return mergedHistory
        }

        let results = try await database.modifyRecords(
            saving: recordsToSave,
            deleting: [],
            savePolicy: .ifServerRecordUnchanged,
            atomically: false
        )

        var latestCloudRecords = cloudHistory

        for (_, result) in results.saveResults {
            let saved: CKRecord

            switch result {
            case .success(let record):
                saved = record

            case .failure(let error):
                guard let ckError = error as? CKError,
                      ckError.code == .serverRecordChanged else {
                    throw error
                }

                guard let original = recordsToSave.first(where: {
                    $0.recordID == ckError.clientRecord?.recordID
                }) else {
                    throw error
                }

                saved = try await saveResolvingConflict(original)
            }

            latestCloudRecords.removeAll {
                $0.recordID == saved.recordID
            }
            latestCloudRecords.append(saved)
        }

        /// if the server won a conflict, we need to apply its winning version locally too.
        /// Returning your original mergedHistory would return data from before the conflict was resolved.
        return CloudHistoryResolver.resolve(
            from: currentHistory,
            with: latestCloudRecords,
            deleted: deletedHistory
        )
    }

    private func saveResolvingConflict(
        _ record: CKRecord,
        retriesRemaining: Int = 3
    ) async throws -> CKRecord {
        do {
            return try await database.save(record)
        } catch let error as CKError {
            guard error.code == .serverRecordChanged,
                  retriesRemaining > 0,
                  let server = error.serverRecord,
                  let localDate = (record["updatedAt"] as? Date)
                    ?? (record["watchedAt"] as? Date),
                  let serverDate = (server["updatedAt"] as? Date)
                    ?? (server["watchedAt"] as? Date) else {
                throw error
            }

            resolveStatus = "Saving conflict retry: \(retriesRemaining)"

            // Server already has an equally recent or newer version.
            guard localDate > serverDate else {
                return server
            }

            // Local wins, but use the server record's current change tag.
            server["watchedAt"] = record["watchedAt"]
            server["updatedAt"] = localDate
            server["lastStoppedAt"] = record["lastStoppedAt"]

            return try await saveResolvingConflict(
                server,
                retriesRemaining: retriesRemaining - 1
            )
        }
    }

}

// MARK: - SwiftData retrieval
extension CloudKitManager {
    /// Function Gets all the `[History]` from SwiftData
    private func extractHistory(from ctx: ModelContext) throws -> [History] {
        let descriptor = FetchDescriptor<History>(
            sortBy: [
                SortDescriptor(\.watchedAt, order: .reverse)
            ]
        )

        return try ctx.fetch(descriptor)
    }
}

// MARK: - Fetch From iCloud
extension CloudKitManager {

    @concurrent
    public func fetchAllDeletedRecords() async throws -> [CKRecord] {
        let query = CKQuery(
            recordType: "DeletedHistory",
            predicate: NSPredicate(value: true)
        )

        return try await fetchAllRecords(matching: query)
    }

    @concurrent
    public func fetchAllHistoryRecords() async throws -> [CKRecord] {
        let query = CKQuery(
            recordType: "SyncedHistory",
            predicate: NSPredicate(value: true)
        )

        return try await fetchAllRecords(matching: query)
    }

    @concurrent
    private func fetchAllRecords(
        matching query: CKQuery
    ) async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []

        let firstPage = try await database.records(
            matching: query,
            resultsLimit: CKQueryOperation.maximumResults
        )

        for (_, result) in firstPage.matchResults {
            allRecords.append(try result.get())
        }

        var cursor = firstPage.queryCursor

        while let currentCursor = cursor {
            let page = try await database.records(
                continuingMatchFrom: currentCursor,
                resultsLimit: CKQueryOperation.maximumResults
            )

            for (_, result) in page.matchResults {
                allRecords.append(try result.get())
            }

            cursor = page.queryCursor
        }

        return allRecords
    }
}
