#if os(macOS)
//
//  MacOSRoot.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/18/26.
//

import SwiftUI
import SwiftData
import Defaults
import MoviesAPIData

struct MacOSRoot: View {

    @Query var history: [History]

    @Environment(\.modelContext) private var ctx

    @Bindable var windowContainer: WindowCoordinatorContainer
    @Bindable var appRouter: AppRouter
    @Bindable var cloudKitSync: CloudKitSyncService
    @Bindable var remoteServer: RemoteServer
    @State private var tmdbManager: TMDBManager?
    @State private var liveTVManager: LiveTVManager?
    @State private var defaultsManager = DefaultsManager()
    @State private var blockingService = BlockingService()
    @State private var playbackSession = PlaybackSession()

    @State private var selectedTab: MacOSTab = .home

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var path = NavigationPath()
    @State private var navigationID = UUID()
    @State private var intentTriggeredResult: KTSearchResult?

    @State private var clientJustJoined: Bool = false

    @Default(.hasShownCloudSavePrompt)
    private var hasShownCloudSavePrompt

    @AppStorage("home.homeOption")
    private var homeOption: HomeOption = .moviesAndTVShows

    var body: some View {
        ZStack {
            if let tmdbManager, let liveTVManager, hasShownCloudSavePrompt {
                VisualEffectView()

                HStack(spacing: 0) {
                    MacOSRootSidebar(selectedTab: $selectedTab, path: $path) { tab in
                        path = NavigationPath()
                        selectedTab = tab
                        // Reset Boolean-driven destinations as well as value-based routes.
                        navigationID = UUID()
                    }
                        .environment(tmdbManager)
                        .environment(blockingService)
                        .environment(playbackSession)
                        .environment(defaultsManager)

                    Divider()

                    NavigationStack(path: $path) {
                        Group {
                            switch selectedTab {
                            case .home:
                                ComfyHeaderView(tab: .home) {
                                    Home()
                                }

                            case .library:
                                ComfyHeaderView(tab: .library) {
                                    Library()
                                }

                            case .history:
                                ComfyHeaderView(tab: .history) {
                                    HistoryView()
                                }

                            case .settings:
                                ComfyHeaderView(tab: .settings) {
                                    SettingsView()
                                }
                            }
                        }
                        .navigationDestination(for: MacOSRoute.self) { route in
                            switch route {
                            case .searchResults:
                                ScrollView {
                                    SearchResultsView(
                                        searchResults: tmdbManager.searchResults
                                    )
                                }
                            }
                        }
                    }
                    .id(navigationID)
                    .environment(windowContainer)
                    .environment(tmdbManager)
                    .environment(liveTVManager)
                    .environment(blockingService)
                    .environment(cloudKitSync)
                    .environment(playbackSession)
                    .environment(defaultsManager)
                    .environment(appRouter)
                    .environment(remoteServer)
                    .sheet(item: $intentTriggeredResult) { result in
                        NavigationStack {
                            WatchDetailView(result: result)
                        }
                        .environment(windowContainer)
                        .environment(tmdbManager)
                        .environment(liveTVManager)
                        .environment(cloudKitSync)
                        .environment(blockingService)
                        .environment(playbackSession)
                        .environment(defaultsManager)
                        .environment(appRouter)
                    }
                }
            } else if !hasShownCloudSavePrompt {
                CloudSavePrompt(cloudKitSync: cloudKitSync)
            } else {
                ProgressView()
            }

            VStack {
                Spacer()
                if clientJustJoined {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .symbolRenderingMode(.hierarchical)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Client Connected")
                                .font(.subheadline.weight(.semibold))

                            Text("Remote control is ready")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: .rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.primary.opacity(0.08))
                    }
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
                    .padding(.bottom)
                    .transition(
                        .move(edge: .bottom)
                        .combined(with: .opacity)
                    )
                }
            }
            .animation(.bouncy, value: clientJustJoined)
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .background(.clear)
        .ignoresSafeArea(edges: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: appRouter.searchTriggered, initial: true) { _, result in
            if let result {
                intentTriggeredResult = result
                appRouter.searchTriggered = nil
            }
        }
        .task {
            do {
                let manager = try TMDBManager(defaultsManager: defaultsManager)
                let liveTVManager = try LiveTVManager(defaultsManager: defaultsManager)

                self.tmdbManager = manager
                self.liveTVManager = liveTVManager

                try await cloudKitSync.saveToCloud()
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
            remoteServer.onClientConnected = {
                clientJustJoined = true
                do {
                    try await Task.sleep(for: .seconds(3))
                } catch {
                    clientJustJoined = false
                }
                clientJustJoined = false
            }
        }
        .onChange(of: appRouter.remoteRequest, initial: true) { _, request in
            guard let request else { return }
            appRouter.remoteRequest = nil

            if selectedTab != .home { selectedTab = .home }
            if homeOption != .moviesAndTVShows { homeOption = .moviesAndTVShows }

            // Always pop back to the home root, even when already deep in the stack.
            path = NavigationPath()
            navigationID = UUID()

            // Hand the request over only after the rebuilt stack exists, so the home view
            // that consumes it isn't torn down by the reset above.
            Task { @MainActor in
                appRouter.routedRemoteRequest = request
            }
        }
        .onChange(of: appRouter.selectedHistory, initial: true) { _, history in
            if history != nil {
                selectedTab = .history
                path = NavigationPath()
                navigationID = UUID()
            }
        }
        .onChange(of: appRouter.clickedWidgetWithResultID, initial: true) { _, id in
            guard id != nil, selectedTab != .history else { return }
            selectedTab = .history
            path = NavigationPath()
            navigationID = UUID()
        }
        .onChange(of: appRouter.clickedWidgetWithFavoriteID, initial: true) { _, id in
            guard id != nil, selectedTab != .library else { return }
            selectedTab = .library
            path = NavigationPath()
            navigationID = UUID()
        }
    }
}

struct ComfyHeaderView<Content: View>: View {

    let tab: MacOSTab
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack {
            ComfyRowView(tab: tab, font: .system(size: 14, weight: .medium, design: .rounded))
                .padding([.top, .horizontal])
                .padding(.bottom, 4)
            Divider()
            content()
        }
    }
}

struct ComfyRowView: View {

    let tab: MacOSTab
    var font: Font = .system(size: 14, weight: .regular, design: .rounded)

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(tab.color)
                .frame(width: 25, height: 25)
                .overlay {
                    ZStack {
                        tab.icon
                            .foregroundStyle(.black)
                            .fontWeight(.black)
                            .scaleEffect(1.04)

                        tab.icon
                            .foregroundStyle(.white)
                            .fontWeight(.black)
                            .scaleEffect(tab.primaryScale)
                    }
                }

            Text(tab.rawValue)
                .font(font)

            Spacer()
        }
    }
}

#endif
