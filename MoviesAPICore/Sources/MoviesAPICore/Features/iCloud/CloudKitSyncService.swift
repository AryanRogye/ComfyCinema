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

    private var isSyncing: Bool = false

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
    }

    var pendingSyncs: Int = 0

    func syncSaveToCloud() {
        Task {
            do {
                try await saveToCloud()
            } catch {
                // Log or expose the failure.
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

            let merged = try await cloudKitManager.resolveHistory(from: ctx)
            try reconcileLocalHistory(merged, in: ctx)

#if os(iOS)
            SettingLogs.shared.add("Synced to iCloud")
#endif
        } while pendingSyncs > 0 && enabledCloudSave
        WidgetCenter.shared.reloadAllTimelines()
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
