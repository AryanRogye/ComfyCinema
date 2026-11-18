//
//  MoviesAndTVShowsView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 10/27/26.
//

import SwiftUI
import SwiftData

struct MoviesAndTVShowsView: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(AppRouter.self) var appRouter
    @Environment(BlockingService.self) var blockingService
    @Environment(CloudKitSyncService.self) var cloudKitSync
    @Binding var error: String?
    @Binding var showError: Bool

    @AppStorage("home.selectedFilter")
    private var selectedFilter: LibraryFilter = .all

    @State private var isResolving: Bool = false
    @State private var resolveTask: Task<Void, Never>?
    @State private var resolvingRequest: PlayRequest?
    @State private var searchResult: KTSearchResult?
    @State private var season: Int?
    @State private var episode: Int?
    @State private var goToDetail: Bool = false

    var filteredResults: [KTTrendingResult] {
        switch selectedFilter {
        case .all:
            tmdbManager.trendingResults
        case .tv:
            tmdbManager.trendingResults.filter { result in
                result.mediaType == .tv
            }
        case .movies:
            tmdbManager.trendingResults.filter { result in
                result.mediaType == .movie
            }
        }
    }

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                MoviesAndTVShowHeroView(contents: filteredResults)

                ContinueWhereYouLeftOffView()

                if selectedFilter == .movies || selectedFilter == .all {
                    MoviesAndTVShowLabelView(
                        label: "Now Playing Movies",
                        contents: tmdbManager.nowPlayingMovies,
                        showMediaType: false,
                        error: $error,
                        showError: $showError
                    )
                }

                if selectedFilter == .tv || selectedFilter == .all {
                    MoviesAndTVShowLabelView(
                        label: "Popular TV Shows",
                        contents: tmdbManager.popularTV,
                        showMediaType: false,
                        error: $error,
                        showError: $showError
                    )
                }

                if selectedFilter == .movies || selectedFilter == .all {
                    MoviesAndTVShowLabelView(
                        label: "Popular Movies",
                        contents: tmdbManager.popularMovies,
                        showMediaType: false,
                        error: $error,
                        showError: $showError
                    )
                }

                if selectedFilter == .tv || selectedFilter == .all {
                    MoviesAndTVShowLabelView(
                        label: "Top Rated TV Shows",
                        contents: tmdbManager.topRatedTV,
                        showMediaType: false,
                        error: $error,
                        showError: $showError
                    )
                }

                if selectedFilter == .movies || selectedFilter == .all {
                    MoviesAndTVShowLabelView(
                        label: "Top Rated Movies",
                        contents: tmdbManager.topRatedMovies,
                        showMediaType: false,
                        error: $error,
                        showError: $showError
                    )
                }
            }
            .padding(.bottom)
        }
        .navigationDestination(isPresented: $goToDetail, destination: {
            if let searchResult {
                switch searchResult.mediaType {
                case .tv:
                    TVDetailView(
                        displayServer: displayServerBinding,
                        result: searchResult,
                        seasonNumber: season,
                        episodeNumber: episode
                    )
                    .environment(tmdbManager)
                    .environment(blockingService)
                case .movie:
                    MovieDetailView(
                        displayServer: displayServerBinding,
                        result: searchResult,
                        loadingMovie: true
                    )
                    .environment(tmdbManager)
                    .environment(blockingService)
                    .environment(cloudKitSync)
                default:
                    EmptyView()
                }
            }
        })
        .onChange(of: appRouter.routedRemoteRequest, initial: true) { _, request in
            if let request {
                resolve(request)
                appRouter.routedRemoteRequest = nil
            }
        }
        .toolbar {

#if os(macOS)
            ToolbarSpacer(.flexible)
#endif
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(LibraryFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Image(systemName: "line.horizontal.3.decrease")
                }
            }
        }
    }

    private func resolve(_ remoteRequest: PlayRequest) {
        if isResolving { return }
        resolveTask = Task {

            self.resolvingRequest = remoteRequest
            isResolving = true
            defer {
                isResolving = false
                resolvingRequest = nil
            }

            do {
                try await tmdbManager.search(remoteRequest.name)
                if !tmdbManager.searchResults.isEmpty {
                    if let result = tmdbManager.searchResults.first(where: { remoteRequest.matches($0) }) {
                        self.searchResult = result
                        if let season = remoteRequest.season, let episode = remoteRequest.episode {
                            self.season = season
                            self.episode = episode
                        }
                        self.goToDetail = true
                    }
                    /// Clear once we finish
                    tmdbManager.clearSearchResults()
                }
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }

}

private struct MoviesAndTVShowLabelView<Media: MediaListItem>: View {

    let label: String
    let contents: [Media]
    let showMediaType: Bool
    @Binding var error: String?
    @Binding var showError: Bool

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Text(label)
                    .font(.title2.bold())
                    .padding(.horizontal)
                    .foregroundStyle(.yellow)

                NavigationLink {
                    MoviesAndTVShowDetailListView(
                        contents: contents,
                        error: $error,
                        showError: $showError
                    )
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.yellow.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            MoviesAndTVShowListView(
                contents: contents,
                showMediaType: showMediaType,
                error: $error,
                showError: $showError
            )
        }
    }
}
