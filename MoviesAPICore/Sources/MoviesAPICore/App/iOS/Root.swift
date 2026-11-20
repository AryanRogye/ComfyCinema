//
//  ContentView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

#if os(iOS)

import SwiftUI
import WebKit
import SwiftData
import Defaults
import MoviesAPIData
import SwiftUIIntrospect

public struct Root: View {

    private enum PlaybackRoute: Hashable {
        case player(UUID)
    }

    @Bindable var appRouter: AppRouter
    @Query var history: [History]

    @Environment(\.modelContext) private var ctx

    @Bindable var cloudKitSync: CloudKitSyncService
    @State private var tmdbManager: TMDBManager?
    @State private var liveTVManager: LiveTVManager?
    @State private var defaultManager = DefaultManager()
    @State private var blockingService = BlockingService()
    @State private var playbackSession = PlaybackSession()
    @State private var remoteClient = RemoteClient()

    @State private var homePath: [PlaybackRoute] = []
    @State private var libraryPath: [PlaybackRoute] = []
    @State private var remotePath: [PlaybackRoute] = []
    @State private var historyPath: [PlaybackRoute] = []
    @State private var settingsPath: [PlaybackRoute] = []
    @State private var searchPath: [PlaybackRoute] = []
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var error: String?
    @State private var showError: Bool = false
    @State private var intentTriggeredResult: KTSearchResult?

    public init(appRouter: AppRouter, cloudKitSync: CloudKitSyncService) {
        self.appRouter = appRouter
        self.cloudKitSync = cloudKitSync
    }

    @Default(.hasShownCloudSavePrompt)
    private var hasShownCloudSavePrompt

    public var body: some View {
        ZStack {
            if let tmdbManager, let liveTVManager, hasShownCloudSavePrompt {
                TabView(selection: $appRouter.selectedTab) {
                    if defaultManager.useCustomTabIcons {
                        Tab(value: .home) {
                            homeView
                        } label: {
                            TabID.home.label
                        }

                        Tab(value: .library) {
                            libraryView
                        } label: {
                            TabID.library.label
                        }

                        Tab(value: .history) {
                            historyView
                        } label: {
                            TabID.history.label
                        }

                        Tab(value: .remote) {
                            remoteView
                        } label: {
                            TabID.remote.label
                        }

                        Tab(value: .settings) {
                            settingsView
                        } label: {
                            TabID.settings.label
                        }

                        Tab(value: .search, role: .search) {
                            searchView
                        } label: {
                            TabID.search.label
                        }
                    } else {
                        Tab(TabID.home.rawValue, systemImage: TabID.home.icon, value: .home) {
                            homeView
                        }

                        Tab(TabID.library.rawValue, systemImage: TabID.library.icon, value: .library) {
                            libraryView
                        }

                        Tab(TabID.history.rawValue, systemImage: TabID.history.icon, value: .history) {
                            historyView
                        }

                        Tab(TabID.remote.rawValue, systemImage: TabID.remote.icon, value: .remote) {
                            remoteView
                        }

                        Tab(TabID.settings.rawValue, systemImage: TabID.settings.icon, value: .settings) {
                            settingsView
                        }

                        Tab(value: .search, role: .search) {
                            searchView
                        }
                    }
                }
                .animation(.smooth, value: defaultManager.useCustomTabIcons)
                .tint(.yellow)
                .introspect(.tabView, on: .iOS(.v26, .v27)) { controller in
                    _ = tryAllowingSixTabs(on: controller)
                }
                .onChange(of: playbackSession.activationID) {
                    playbackSession.sourceTab = appRouter.selectedTab
                }
                .tabViewBottomAccessory(isEnabled: playbackSession.isActive) {
                    PlaybackPlayerView(returnToPlayback: returnToPlayback)
                }
                .tabBarMinimizeBehavior(.onScrollDown)
                .environment(tmdbManager)
                .environment(liveTVManager)
                .environment(blockingService)
                .environment(remoteClient)
                .environment(cloudKitSync)
                .environment(playbackSession)
                .environment(defaultManager)
                .environment(appRouter)
                .modifier(
                    SearchTabModifier(
                        isSearchTabSelected: appRouter.selectedTab == .search,
                        searchText: $searchText
                    ) {
                        search(using: tmdbManager)
                    }
                )
                .sheet(item: $intentTriggeredResult) { search in
                    NavigationStack {
                        WatchDetailView(result: search)
                            .environment(tmdbManager)
                            .environment(liveTVManager)
                            .environment(cloudKitSync)
                            .environment(blockingService)
                            .environment(playbackSession)
                            .environment(defaultManager)
                            .environment(appRouter)
                    }
                }
            } else if !hasShownCloudSavePrompt {
                CloudSavePrompt(cloudKitSync: cloudKitSync)
            } else {
                ProgressView()
            }
        }
        /// Checking if app was triggered by intent
        .onAppear {
            if let searchTriggered = appRouter.searchTriggered {
                intentTriggeredResult = searchTriggered
                SettingLogs.shared.add("Using SearchTriggered From Intent To Open: \(searchTriggered)")
            }
        }
        /// Intent Triggered Search
        .onChange(of: appRouter.searchTriggered) { _, newValue in
            if let newValue {
                intentTriggeredResult = newValue
                SettingLogs.shared.add("Using SearchTriggered From Intent To Open: \(newValue)")
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .task {
            do {
                let manager = try TMDBManager(defaultManager: defaultManager)
                let liveTVManager = try LiveTVManager(defaultManager: defaultManager)

                self.tmdbManager = manager
                self.liveTVManager = liveTVManager

                try await self.cloudKitSync.saveToCloud()
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }

    private func returnToPlayback() {
        guard let sourceTab = playbackSession.sourceTab else { return }

        appRouter.selectedTab = sourceTab
        let route = PlaybackRoute.player(playbackSession.activationID)

        func append(_ route: PlaybackRoute, to path: inout [PlaybackRoute]) {
            guard path.last != route else { return }
            path.append(route)
        }

        switch sourceTab {
        case .home:
            append(route, to: &homePath)
        case .library:
            append(route, to: &libraryPath)
        case .remote:
            append(route, to: &remotePath)
        case .history:
            append(route, to: &historyPath)
        case .settings:
            append(route, to: &settingsPath)
        case .search:
            append(route, to: &searchPath)
        }
    }

    private func search(using manager: TMDBManager) {
        guard !isSearching else { return }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            manager.clearSearchResults()
            return
        }

        isSearching = true
        Task {
            defer { isSearching = false }
            do {
                try await manager.search(query)
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }


    private var homeView: some View {
        NavigationStack(path: $homePath) {
            Home()
                .navigationDestination(for: PlaybackRoute.self) { _ in
                    PlaybackDestination()
                }
        }
    }

    private var libraryView: some View {
        NavigationStack(path: $libraryPath) {
            Library()
                .navigationDestination(for: PlaybackRoute.self) { _ in
                    PlaybackDestination()
                }
        }
    }

    private var historyView: some View {
        NavigationStack(path: $historyPath) {
            HistoryView()
                .navigationDestination(for: PlaybackRoute.self) { _ in
                    PlaybackDestination()
                }
        }
    }

    private var remoteView: some View {
        NavigationStack(path: $remotePath) {
            RemoteDevicesView()
                .navigationDestination(for: PlaybackRoute.self) { _ in
                    PlaybackDestination()
                }
        }
    }

    private var settingsView: some View {
        NavigationStack(path: $settingsPath) {
            SettingsView()
                .navigationDestination(for: PlaybackRoute.self) { _ in
                    PlaybackDestination()
                }
        }
    }

    private var searchView: some View {
        NavigationStack(path: $searchPath) {
            SearchTab()
                .navigationDestination(for: PlaybackRoute.self) { _ in
                    PlaybackDestination()
                }
        }
    }
}

private struct SearchTabModifier: ViewModifier {

    let isSearchTabSelected: Bool
    @Binding var searchText: String
    let submit: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isSearchTabSelected {
            content
                .searchable(text: $searchText, prompt: "Search movies, TV, and people")
                .tabViewSearchActivation(.searchTabSelection)
                .onSubmit(of: .search, submit)
        } else {
            content
        }
    }
}

#Preview {
    let schema = Schema(versionedSchema: MoviesSchemaV2.self)
    let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, configurations: configuration)

    Root(
        appRouter: AppRouter(),
        cloudKitSync: CloudKitSyncService(
            modelContainer: container,
            cloudKitManager: try! CloudKitManager()
        )
    )
    .modelContainer(container)
}
#endif
