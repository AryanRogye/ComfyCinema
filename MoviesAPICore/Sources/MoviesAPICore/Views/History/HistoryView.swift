//
//  HistoryView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/15/26.
//

import SwiftUI
import SwiftData
import MoviesAPIData

public struct HistoryView: View {

    @Environment(AppRouter.self) var appRouter
    @Environment(TMDBManager.self) var tmdbManager
    @Environment(BlockingService.self) var blockingService
    @Environment(PlaybackSession.self) var playbackSession
    @Environment(CloudKitSyncService.self) var cloudKitSyncService

    @Environment(\.modelContext) var modelContext

    @Query(sort: \History.watchedAt, order: .reverse)
    var history: [History]

    @State private var searchResult: KTSearchResult?
    @State private var resolveTask: Task<Void, Never>?
    @State private var selectedHistory: History?
    @State private var resolvingHistory: History?
    @State private var isResolving: Bool = false
    @State private var goToDetail: Bool = false

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var searchHistory: String = ""

    var filteredHistory: [History] {
        if searchHistory.isEmpty {
            history
        } else {
            FilterEngine.filter(searchResult: searchHistory, history: history)
        }
    }

    public init() {}

    @AppStorage("DisplayServer") private var displayServerRawValue = KTDisplayServer.moviesApi.rawValue

    private var displayServer: KTDisplayServer {
        KTDisplayServer.entries.first { $0.rawValue == displayServerRawValue } ?? .moviesApi
    }

    private var displayServerBinding: Binding<KTDisplayServer> {
        Binding(
            get: { displayServer },
            set: { displayServerRawValue = $0.rawValue }
        )
    }

    public var body: some View {
        Group {
            if history.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack {
#if os(macOS)
                        HistoryStatsView(history: history)
#endif

                        /// search view
                        historySearchView

                        Text("History")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 6)

                        ForEach(filteredHistory, id: \.id) { item in
                            Button {
                                playbackSession.stop()
                                resolve(item)
                            } label: {
                                HistoryRow(
                                    history: item,
                                    isResolving: resolvingHistory == item
                                )
                            }
                            .buttonStyle(HistoryButton())
                            .contextMenu {
                                /// TODO: Here
                                Button(role: .destructive) {
                                    cloudKitSyncService.didJustDeleteHistory(item)
                                    modelContext.delete(item)
                                } label: {
                                    Label(
                                        "Remove",
                                        systemImage: "trash"
                                    )
                                }
                            }
                        }
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .alert(isPresented: $showError) {
                    Alert(
                        title: Text("Error"),
                        message: Text("\(error, default: "Unknown Error")")
                    )
                }
                .navigationDestination(isPresented: $goToDetail, destination: {
                    if let selectedHistory, let searchResult {
                        switch selectedHistory.mediaType {
                        case .episode:
                            if let season = selectedHistory.season, let episode = selectedHistory.episode {
                                TVDetailView(
                                    displayServer: displayServerBinding,
                                    result: searchResult,
                                    seasonNumber: season,
                                    episodeNumber: episode
                                )
                                .environment(tmdbManager)
                                .environment(blockingService)
                            }
                        case .movie:
                                MovieDetailView(
                                    displayServer: displayServerBinding,
                                    result: searchResult
                                )
                                .environment(tmdbManager)
                                .environment(blockingService)
                        }
                    }
                })
                .onAppear {
                    /// if we come back
                    self.selectedHistory = nil
                    self.searchResult = nil
                    self.goToDetail = false
                    self.resolvingHistory = nil
                    if let h = appRouter.selectedHistory, !isResolving {
                        resolve(h)
                        appRouter.selectedHistory = nil
                    } else if let id = appRouter.clickedWidgetWithResultID, !isResolving {
                        /// we wanna find the history in current
                        if let h = history.first(where: { $0.id.uuidString == id }) {
                            resolve(h)
                            appRouter.clickedWidgetWithResultID = nil
                        }
                    }
                }
                .onDisappear {
                    resolveTask?.cancel()
                    resolveTask = nil
                }
                .onChange(of: appRouter.selectedHistory) {
                    if let h = appRouter.selectedHistory, !isResolving {
                        resolve(h)
                        appRouter.selectedHistory = nil
                    }
                }
                .onChange(of: appRouter.clickedWidgetWithResultID) {
                    guard let id = appRouter.clickedWidgetWithResultID else { return }
                    if !isResolving, let h = history.first(where: { $0.id.uuidString == id }) {
                        resolve(h)
                        appRouter.clickedWidgetWithResultID = nil
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
#if os(macOS)
            ToolbarSpacer(.flexible)
#elseif os(iOS)
            ToolbarItemGroup(placement: .primaryAction) {
                NavigationLink {
                    HistoryStatsScreen(history: history)
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                }
            }
#endif
        }
    }

    private var historySearchView: some View {
        TextField("Search History", text: $searchHistory)
            .textFieldStyle(.plain)
            .padding(12)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal)
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "No Watch History",
            systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
            description: Text("Movies and episodes you watch will show up here.")
        )
    }

    private func resolve(_ history: History) {
        if isResolving { return }

        resolveTask = Task {
            resolvingHistory = history
            isResolving = true

            defer {
                isResolving = false
                resolvingHistory = nil
            }

            do {
                try await tmdbManager.search(history.name)

                if let result = tmdbManager.searchResults.first(
                    where: { $0.id == history.resultId }
                ) {
                    searchResult = result
                    selectedHistory = history
                    goToDetail = true
                }

                tmdbManager.clearSearchResults()
            } catch {
                self.error = error.localizedDescription
                showError = true
            }
        }
    }
}


private struct HistoryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.18), value: configuration.isPressed)
    }
}

#if os(iOS)

private struct HistoryStatsScreen: View {
    let history: [History]

    var body: some View {
        ScrollView {
            HistoryStatsView(history: history)
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
