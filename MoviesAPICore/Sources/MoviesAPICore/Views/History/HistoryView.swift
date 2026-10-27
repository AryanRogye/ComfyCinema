//
//  HistoryView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/15/26.
//

import SwiftUI
import SwiftData

public struct HistoryView: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(BlockingService.self) var blockingService
    @Environment(PlaybackSession.self) var playbackSession

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
#elseif os(iOS)
                        NavigationLink {
                            HistoryStatsScreen(history: history)
                        } label: {
                            HistoryStatsSummaryRow(history: history)
                        }
                        .buttonStyle(.plain) // otherwise the whole label gets tinted blue
                        .padding(.horizontal)
#endif

                        Text("History")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        ForEach(history, id: \.id) { item in
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
                                Button(role: .destructive) {
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
                }
                .onDisappear {
                    resolveTask?.cancel()
                    resolveTask = nil
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
#if os(macOS)
            ToolbarSpacer(.flexible)
#endif
        }
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

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(history[index])
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
private struct HistoryStatsSummaryRow: View {
    let history: [History]

    var body: some View {
        let stats = HistoryStats(from: history)
        let hours = stats.totalSeconds / 3600

        HStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Color.purple.opacity(0.2), in: Circle())
                .foregroundStyle(.purple)

            VStack(alignment: .leading, spacing: 2) {
                Text("Your Stats")
                    .font(.headline)
                Text("\(hours.formatted(.number.precision(.fractionLength(0...1)))) hrs · \(stats.movieCount) movies · \(stats.episodeCount) episodes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

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
