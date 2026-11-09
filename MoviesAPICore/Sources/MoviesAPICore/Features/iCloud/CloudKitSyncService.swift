//
//  CloudKitSyncService.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/8/26.
//

import SwiftData
import Defaults

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

    func saveToCloud() async throws {
        if isSyncing { return }
        isSyncing = true
        defer { isSyncing = false }

        let ctx = modelContainer.mainContext

        guard enabledCloudSave else { return }

        let merged = try await cloudKitManager.resolveHistory(from: ctx)

        // Reconcile merged history into ctx without deleting everything.
        try reconcileLocalHistory(merged, in: ctx)
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
                // Update the existing SwiftData object.
                match.watchedAt = incoming.watchedAt
                match.lastStoppedAt = incoming.lastStoppedAt
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
