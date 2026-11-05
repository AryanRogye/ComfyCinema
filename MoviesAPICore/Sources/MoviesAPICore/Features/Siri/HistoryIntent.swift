//
//  AppIntents.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/3/26.
//

import AppIntents
import SwiftData

struct HistoryEntity: AppEntity {
    let id: UUID

    @Property(title: "Content Title")
    var contentTitle: String

    @Property(title: "Media Type")
    var mediaType: String

    @Property(title: "Season")
    var season: Int?

    @Property(title: "Episode")
    var episode: Int?

    @Property(title: "Watched At")
    var watchedAt: Date

    static let typeDisplayRepresentation =
    TypeDisplayRepresentation(name: "History Item")

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(contentTitle) (\(mediaType)) - Watched on \(watchedAt.formatted())")
    }

    static var defaultQuery: HistoryQuery {
        HistoryQuery()
    }

    init(history: History) {
        self.id = history.id
        self.contentTitle = history.name
        self.mediaType = history.mediaType.rawValue
        self.season = history.season
        self.episode = history.episode
        self.watchedAt = history.watchedAt
    }
}

struct HistoryQuery: EntityQuery {
    @Dependency
    private var container: ModelContainer

    func entities(
        for identifiers: [HistoryEntity.ID]
    ) async throws -> [HistoryEntity] {
        let context = ModelContext(container)
        let requestedIDs = identifiers

        let descriptor = FetchDescriptor<History>(
            predicate: #Predicate { history in
                requestedIDs.contains(history.id)
            }
        )

        let history = try context.fetch(descriptor)

        await SettingLogs.shared.add(
            "Called HistoryQuery for \(requestedIDs.count) history items. Returning \(history.count) results"
        )

        return history.map { HistoryEntity(history: $0) }
    }
}

struct OpenHistoryIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Watch History"

    @Parameter(title: "History Item")
    var target: HistoryEntity

    @Dependency
    private var appRouter: AppRouter

    @Dependency
    private var container: ModelContainer

    static var openAppWhenRun: Bool = true
    static var supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {

        let descriptor = FetchDescriptor<History>()
        let context = ModelContext(container)
        let history = try context.fetch(descriptor)

        appRouter.selectedTab = .history
        appRouter.selectedHistory = history.first(where: { $0.id == target.id })

        SettingLogs.shared.add(
            "Called Perform In OpenHistoryIntent for target: \(target.contentTitle). Changing Tabs To History"
        )

        return .result()
    }
}

@available(iOS 27.3, macOS 27.3, *)
@AppIntent(.tool)
struct ContentHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Recently Watched Content"

    static let description = IntentDescription(
        """
        Returns the 10 most recently watched movies and TV episodes \
        in ComfyCinema, including their titles and watch dates.
        """
    )

    @Dependency
    private var container: ModelContainer

    static var parameterSummary: some ParameterSummary {
        Summary("Get recently watched content in ComfyCinema")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[HistoryEntity]> {

        let context = ModelContext(container)

        var descriptor = FetchDescriptor<History>(
            sortBy: [
                SortDescriptor(\History.watchedAt, order: .reverse)
            ]
        )
        descriptor.fetchLimit = 10

        let history = try context.fetch(descriptor)

        SettingLogs.shared.add(
            "Called Perform In ContentHistoryIntent with \(history.count) results"
        )
        return .result(
            value: history.map { HistoryEntity(history: $0) }
        )
    }

    func fetchAllHistory(in context: ModelContext) -> [History] {
        let descriptor = FetchDescriptor<History>()

        do {
            let allHistory = try context.fetch(descriptor)
            return allHistory
        } catch {
            print("Error fetching all history: \(error)")
            return []
        }
    }
}
