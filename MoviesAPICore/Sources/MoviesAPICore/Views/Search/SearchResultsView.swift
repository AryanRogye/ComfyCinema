//
//  SearchResultsView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import SwiftData

struct SearchResultsView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(PlaybackSession.self) var playbackSession
    @Binding var enableAnimeSearch: Bool
    @Query var favorites: [Favorite]
    @Query var collections: [Collection]
    let searchResults: [KTSearchResult]
    let animeSearchResults: [Anime]

    @State private var selectedResult: KTSearchResult?
    @State private var selectedAnime: Anime?
    @State private var showDetail = false

    @State private var showCreateCollection: Bool = false
    @State private var collectionName: String = ""
    @State private var collectionResultToAdd: KTSearchResult?

    var body: some View {
        if enableAnimeSearch {
            ForEach(animeSearchResults, id: \.id) { result in
                AnimeSearchResultsRow(result: result)
                    .contentShape(.rect)
                    .onTapGesture {
                        playbackSession.stop()
                        selectedAnime = result
                        showDetail = true
                    }
            }
            /// TODO: Add Modifier for collection later on
            .navigationDestination(isPresented: $showDetail) {
                if let selectedAnime {
                    AnimeWatchDetailView(result: selectedAnime)
                }
            }
        } else {
            ForEach(searchResults, id: \.id) { result in
                SearchResultsRow(result: result)
                    .contextMenu {
                        contextMenu(result: result)
                    }
                    .contentShape(.rect)
                    .onTapGesture {
                        playbackSession.stop()
                        selectedResult = result
                        showDetail = true
                    }
            }
            .modifier(CreateCollectionViewModifier(
                showCreateCollection: $showCreateCollection,
                collectionName: $collectionName,
                collectionResultToAdd: $collectionResultToAdd
            ))
            .navigationDestination(isPresented: $showDetail) {
                if let selectedResult {
                    WatchDetailView(result: selectedResult)
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(result: KTSearchResult) -> some View {
        CollectionFavoriteMenu(
            result: result,
            showCreateCollection: $showCreateCollection,
            collectionName: $collectionName,
            collectionResultToAdd: $collectionResultToAdd
        )
    }
}

#if DEBUG
#Preview {
    @Previewable @State var tmdbManager: TMDBManager?

    if let tmdbManager {
        NavigationStack {
            SearchResultsView(
                enableAnimeSearch: .constant(false),
                searchResults: [
                    KTSearchResult(
                        id: 969681,
                        mediaType: .movie,
                        title: "Spider-Man: Brand New Day",
                        name: nil,
                        posterPath: "/bjiS5ipwxb9JFy3XRRN4OAilSeX.jpg",
                        overview: """
                    Fighting crime full-time as Spider-Man in a world that doesn't remember him—and the pressure of seeing his old friends move on without him—sparks a change in Peter Parker he may not have the power to control.
                    """,
                        releaseDate: "2026-07-31",
                        firstAirDate: nil
                    ),
                    KTSearchResult(
                        id: 38867,
                        mediaType: .tv,
                        title: nil,
                        name: "Lab Rats",
                        posterPath: "/lcQMvn9ZptPd3dxn0a17viRfi7Y.jpg",
                        overview: """
                    Leo discovers three superhuman teenagers living in a secret underground lab beneath his new home.
                    """,
                        releaseDate: nil,
                        firstAirDate: "2012-02-27"
                    )
                ],
                animeSearchResults: []
            )
            .environment(tmdbManager)
            .environment(PlaybackSession())
            .environment(BlockingService())
            .modelContainer(
                for: [Favorite.self, History.self, Collection.self],
                inMemory: true
            )
        }
    } else {
        ProgressView()
            .task {
                do {
                    tmdbManager = try .init(
                        tmdbClient: TMDBClientPreview(),
                        token: "preview"
                    )
                } catch {
                    print(error.localizedDescription)
                }
            }
    }

}
#endif
