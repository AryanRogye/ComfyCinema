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

    public func resolveHistory(from ctx: ModelContext) async throws -> [History] {
        defer { resolveStatus = nil }
        let currentHistory = try extractHistory(from: ctx)

        resolveStatus = "Gathered Current History: \(currentHistory.count)"
        let cloudHistory = try await fetchAllHistoryRecords()
        resolveStatus = "Gathered Cloud History: \(cloudHistory.count)"

        let mergedHistory = CloudKitResolver.resolve(
            from: currentHistory,
            with: cloudHistory
        )
        resolveStatus = "Merged History: \(mergedHistory.count)"

        let recordsToSave = try await CloudKitResolver.recordsToSave(
            merged: mergedHistory,
            existing: cloudHistory
        )
        resolveStatus = "Resolved Records To Save: \(recordsToSave.count)"

        guard !recordsToSave.isEmpty else {
            return mergedHistory
        }

        var latestCloudRecords = cloudHistory

        for record in recordsToSave {
            let saved = try await saveResolvingConflict(record)

            latestCloudRecords.removeAll {
                $0.recordID == saved.recordID
            }
            latestCloudRecords.append(saved)
        }

        /// if the server won a conflict, we need to apply its winning version locally too.
        /// Returning your original mergedHistory would return data from before the conflict was resolved.
        return CloudKitResolver.resolve(
            from: currentHistory,
            with: latestCloudRecords
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

    /// Get all `[CKRecords]` for history
    @concurrent
    public func fetchAllHistoryRecords() async throws -> [CKRecord] {

        let query = CKQuery(
            recordType: "SyncedHistory",
            predicate: NSPredicate(value: true)
        )

        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        let firstPage = try await database.records(
            matching: query,
            resultsLimit: CKQueryOperation.maximumResults
        )

        for (_, result) in firstPage.matchResults {
            allRecords.append(try result.get())
        }

        cursor = firstPage.queryCursor

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
