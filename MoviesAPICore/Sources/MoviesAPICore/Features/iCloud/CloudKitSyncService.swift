//
//  CloudKitSyncService.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/8/26.
//

import SwiftData
import Defaults
import MoviesAPIData
import WidgetKit

@Observable
@MainActor
public final class CloudKitSyncService {
    let modelContainer: ModelContainer
    private let cloudKitManager: CloudKitManager
    private let deletionStore: HistoryDeletionStore

    private var isSyncing: Bool = false
    private var cloudQueue = TaskQueue()

    var resolveStatus: String? {
        cloudKitManager.resolveStatus
    }

    var enabledCloudSave: Bool = Defaults[.enabledCloudSave] {
        didSet {
            Defaults[.enabledCloudSave] = enabledCloudSave
        }
    }

    public init(
        modelContainer: ModelContainer,
        cloudKitManager: CloudKitManager
    ) {
        self.modelContainer = modelContainer
        self.cloudKitManager = cloudKitManager
        self.deletionStore = HistoryDeletionStore(identifier: cloudKitManager.identifier)
    }

    var pendingSyncs: Int = 0

    func addToHistoryThenSync(_ history: History) {
        guard enabledCloudSave else { return }
        // A newer watch date supersedes a tombstone; keep the marker so older
        // copies on other devices cannot bring deleted progress back.
        syncSaveToCloud()
    }

    func didJustDeleteHistory(_ history: History) {
        // Snapshot before the caller deletes the SwiftData object. Record even
        // with sync disabled so enabling it later preserves the deletion.
        deletionStore.record(DeletedHistory(history: history))
        syncSaveToCloud()
    }

    func syncSaveToCloud() {
        guard enabledCloudSave else { return }
        Task {
            cloudQueue.enqueue {
                do {
                    try await self.saveToCloud()
                } catch {
                    /// ignore error
                }
            }
        }
    }

    func saveToCloud() async throws {
        guard enabledCloudSave else { return }

        pendingSyncs += 1
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        let ctx = modelContainer.mainContext

        repeat {
            pendingSyncs = 0

            // Never import cloud history until pending deletions are uploaded.
            // Failed uploads remain durable and are retried on the next sync.
            for deletion in deletionStore.pending {
                try await cloudKitManager.markHistoryAsDeleted(deletion)
                deletionStore.markUploaded(deletion)
            }

            let merged = try await cloudKitManager.resolveHistory(
                from: ctx,
                localDeletions: deletionStore.deletions
            )
            let deleted: [DeletedHistory] = try await cloudKitManager.fetchAllDeletedRecords().compactMap {
                return CloudRecordResolver.deletedHistory(from: $0)
            }

            try reconcileLocalHistory(merged, in: ctx)
            try removeFromHistoryDeleted(deleted + deletionStore.deletions, in: ctx)

#if os(iOS)
            SettingLogs.shared.add("Synced to iCloud")
#endif
        } while pendingSyncs > 0 && enabledCloudSave
        WidgetCenter.shared.reloadAllTimelines()
    }

    func removeFromHistoryDeleted(
        _ deleted: [DeletedHistory],
        in ctx: ModelContext
    ) throws {

        let history = try ctx.fetch(FetchDescriptor<History>())
        for history in history {
            if deleted.contains(where: {
                $0.matches(history) && history.syncDate <= $0.deletedAt
            }) {
                ctx.delete(history)
            }
        }
        try ctx.save()
    }

    @MainActor
    func reconcileLocalHistory(
        _ merged: [History],
        in ctx: ModelContext
    ) throws {
        let existing = try ctx.fetch(FetchDescriptor<History>())

        for incoming in merged {
            let match = existing.first { local in
                guard local.resultId == incoming.resultId,
                      local.mediaType == incoming.mediaType else {
                    return false
                }

                if local.mediaType == .episode {
                    return local.season == incoming.season &&
                    local.episode == incoming.episode
                }

                return true
            }

            if let match {
                // Preserve local edits made while CloudKit was awaiting a response.
                guard incoming.syncDate > match.syncDate else { continue }

                // Update the existing SwiftData object.
                match.watchedAt = incoming.watchedAt
                match.lastStoppedAt = incoming.lastStoppedAt
                match.updatedAt = incoming.updatedAt
                match.name = incoming.name
                match.posterPath = incoming.posterPath
                match.backdropPath = incoming.backdropPath
            } else {
                // Important: create a new object rather than
                // inserting an object owned by another context.
                ctx.insert(incoming)
            }
        }

        try ctx.save()
    }
}
