//
//  CloudKitManager.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/7/26.
//

import CloudKit
import SwiftData
import Defaults

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
final class CloudKitManager {

    let identifier: String
    let container: CKContainer
    let database: CKDatabase
    var resolveStatus: String?

    var enabledCloudSave: Bool = Defaults[.enabledCloudSave] {
        didSet {
            Defaults[.enabledCloudSave] = enabledCloudSave
        }
    }

    init() throws {
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

    public func resolveHistory(from ctx: ModelContext) async throws -> [History]? {
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
            resolveStatus = nil
            return nil
        }

        let result = try await database.modifyRecords(
            saving: recordsToSave,
            deleting: [],
            savePolicy: .ifServerRecordUnchanged,
            atomically: false
        )
        resolveStatus = "Modified Records"

        for (_, saveResult) in result.saveResults {
            let _ = try saveResult.get()
        }

        resolveStatus = nil
        return mergedHistory
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
