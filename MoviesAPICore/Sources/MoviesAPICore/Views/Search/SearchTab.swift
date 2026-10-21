//
//  SearchTab.swift
//  MoviesAPIClient
//

import SwiftUI

public struct SearchTab: View {

    @Environment(TMDBManager.self) private var tmdbManager
    @Environment(AniListManager.self) private var aniListManager
    @Binding var enableAnimeSearch: Bool

    public var body: some View {
        ScrollView {

            if enableAnimeSearch {
                if aniListManager.searchResults.isEmpty {
                    ContentUnavailableView.search
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    searchResultView
                }
            } else {
                if tmdbManager.searchResults.isEmpty {
                    ContentUnavailableView.search
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    searchResultView
                }
            }
        }
        .navigationTitle("Search")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Toggle("Enable Anime Search", isOn: $enableAnimeSearch)
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }

    private var searchResultView: some View {
        SearchResultsView(
            enableAnimeSearch: $enableAnimeSearch,
            searchResults: tmdbManager.searchResults,
            animeSearchResults: aniListManager.searchResults
        )
    }
}
