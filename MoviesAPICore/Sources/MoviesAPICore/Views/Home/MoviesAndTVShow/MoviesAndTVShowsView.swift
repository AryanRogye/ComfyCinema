//
//  MoviesAndTVShowsView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 10/27/26.
//

import SwiftUI

struct MoviesAndTVShowsView: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Binding var error: String?
    @Binding var showError: Bool

    @AppStorage("home.selectedFilter")
    private var selectedFilter: LibraryFilter = .all

    @AppStorage("home.trendingExpanded")
    private var trendingExpanded = true

    @AppStorage("home.nowPlayingMoviesExpanded")
    private var nowPlayingMoviesExpanded = true

    @AppStorage("home.popularTVExpanded")
    private var popularTVExpanded = true

    @AppStorage("home.popularMoviesExpanded")
    private var popularMoviesExpanded = true

    @AppStorage("home.topRatedTVExpanded")
    private var topRatedTVExpanded = true

    @AppStorage("home.topRatedMoviesExpanded")
    private var topRatedMoviesExpanded = true


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
                DisclosureGroup(isExpanded: $trendingExpanded) {
                    MoviesAndTVShowListView(
                        contents: filteredResults,
                        error: $error,
                        showError: $showError
                    )
                } label: {
                    Text("Trending Today")
                        .font(.title2.bold())
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                if selectedFilter == .movies || selectedFilter == .all {
                    DisclosureGroup(isExpanded: $nowPlayingMoviesExpanded) {
                        MoviesAndTVShowListView(
                            contents: tmdbManager.nowPlayingMovies,
                            error: $error,
                            showError: $showError
                        )
                    } label: {
                        Text("Now Playing Movies")
                            .font(.title2.bold())
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                }

                if selectedFilter == .tv || selectedFilter == .all {
                    DisclosureGroup(isExpanded: $popularTVExpanded) {
                        MoviesAndTVShowListView(
                            contents: tmdbManager.popularTV,
                            error: $error,
                            showError: $showError
                        )
                    } label: {
                        Text("Popular TV Shows")
                            .font(.title2.bold())
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                }

                if selectedFilter == .movies || selectedFilter == .all {
                    DisclosureGroup(isExpanded: $popularMoviesExpanded) {
                        MoviesAndTVShowListView(
                            contents: tmdbManager.popularMovies,
                            error: $error,
                            showError: $showError
                        )
                    } label: {
                        Text("Popular Movies")
                            .font(.title2.bold())
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                }

                if selectedFilter == .tv || selectedFilter == .all {
                    DisclosureGroup(isExpanded: $topRatedTVExpanded) {
                        MoviesAndTVShowListView(
                            contents: tmdbManager.topRatedTV,
                            error: $error,
                            showError: $showError
                        )
                    } label: {
                        Text("Top Rated TV Shows")
                            .font(.title2.bold())
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                }

                if selectedFilter == .movies || selectedFilter == .all {
                    DisclosureGroup(isExpanded: $topRatedMoviesExpanded) {
                        MoviesAndTVShowListView(
                            contents: tmdbManager.topRatedMovies,
                            error: $error,
                            showError: $showError
                        )
                    } label: {
                        Text("Top Rated Movies")
                            .font(.title2.bold())
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
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
