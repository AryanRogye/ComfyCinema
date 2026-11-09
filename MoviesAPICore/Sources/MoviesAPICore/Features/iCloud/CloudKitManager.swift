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

    @discardableResult
    func checkConnection() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    public func resolveHistory(from ctx: ModelContext) async throws -> [History]? {
        let currentHistory = try extractHistory(from: ctx)
        print("Gathered Current History: \(currentHistory.count)")
        let cloudHistory = try await fetchAllHistoryRecords()
        print("Gathered Cloud History: \(cloudHistory.count)")

        let mergedHistory = CloudKitResolver.resolve(
            from: currentHistory,
            with: cloudHistory
        )
        print("Got Merged History")

        let recordsToSave = try await CloudKitResolver.recordsToSave(
            merged: mergedHistory,
            existing: cloudHistory
        )
        print("Records To Save Resolved")

        guard !recordsToSave.isEmpty else {
            return nil
        }

        let result = try await database.modifyRecords(
            saving: recordsToSave,
            deleting: [],
            savePolicy: .ifServerRecordUnchanged,
            atomically: false
        )
        print("Modified Records")

        for (_, saveResult) in result.saveResults {
            let _ = try saveResult.get()
        }

        return mergedHistory
    }

    private func extractHistory(from ctx: ModelContext) throws -> [History] {
        let descriptor = FetchDescriptor<History>(
            sortBy: [
                SortDescriptor(\.watchedAt, order: .reverse)
            ]
        )

        return try ctx.fetch(descriptor)
    }
}

extension CloudKitManager {

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
