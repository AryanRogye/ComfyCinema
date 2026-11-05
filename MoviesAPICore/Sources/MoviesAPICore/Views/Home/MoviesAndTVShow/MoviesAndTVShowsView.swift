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
    @Binding var error: String?
    @Binding var showError: Bool

    @AppStorage("home.selectedFilter")
    private var selectedFilter: LibraryFilter = .all

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                MoviesAndTVShowHeroView(contents: filteredResults)

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
