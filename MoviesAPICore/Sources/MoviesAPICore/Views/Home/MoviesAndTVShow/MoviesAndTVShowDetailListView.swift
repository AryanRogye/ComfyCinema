//
//  MoviesAndTVShowDetailListView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/4/26.
//

import Foundation
import SwiftUI
import SwiftData

struct MoviesAndTVShowDetailListView<Media: MediaListItem>: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(PlaybackSession.self) var playbackSession
    @Environment(\.modelContext) var modelContext

    let contents: [Media]
    @Binding var error: String?
    @Binding var showError: Bool

    @State private var isResolving: Bool = false
    @State private var resolveTask: Task<Void, Never>?
    @State private var resolvingMedia: Media?
    @State private var searchResult: KTSearchResult?
    @State private var goToDetail: Bool = false

    var imageHeight: CGFloat {
        105
    }
    var imageWidth: CGFloat {
        70
    }
    var textHeight: CGFloat {
        0
    }
    var spacing: CGFloat {
        18
    }

    var totalHeight: CGFloat {
        imageHeight + textHeight + spacing
    }

    var popularTVRows: [GridItem] {
        [
            GridItem(.fixed(totalHeight), spacing: 12),
            GridItem(.fixed(totalHeight), spacing: 12),
        ]
    }

    @State private var showCreateCollection: Bool = false
    @State private var collectionName: String = ""
    @State private var collectionResultToAdd: Media?


    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack {
                if contents.isEmpty {
                    ProgressView()
                } else {
                    ForEach(Array(contents.enumerated()), id: \.element.mediaListItemID) { index, content in
                        MoviesAndTVShowDetailRow(
                            imagePath: content.posterPath ?? content.backdropPath,
                            index: index,
                            name: content.displayName,
                            mediaType: content.mediaType,
                            genres: content.genresTypes,
                            imageWidth: imageWidth,
                            imageHeight: imageHeight,
                            textHeight: textHeight,
                            spacing: spacing,
                            totalHeight: totalHeight
                        )
                        .contextMenu {
                            MediaContextMenu(
                                result: content,
                                showCreateCollection: $showCreateCollection,
                                collectionName: $collectionName,
                                collectionResultToAdd: $collectionResultToAdd
                            )
                        }
                        .onTapGesture {
                            playbackSession.stop()
                            resolve(content)
                        }
                        .overlay {
                            if resolvingMedia?.id == content.id && resolvingMedia?.mediaType == content.mediaType {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(.black.opacity(0.1))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .navigationDestination(isPresented: $goToDetail) {
            if let searchResult {
                WatchDetailView(result: searchResult)
            }
        }
        .modifier(CreateCollectionModifier(
            showCreateCollection: $showCreateCollection,
            collectionName: $collectionName,
            collectionResultToAdd: $collectionResultToAdd
        ))
    }

    private func resolve(_ result: Media) {
        if isResolving { return }
        resolveTask = Task {

            self.resolvingMedia = result
            isResolving = true
            defer {
                isResolving = false
                resolvingMedia = nil
            }

            do {
                try await tmdbManager.search(result.displayName)
                if !tmdbManager.searchResults.isEmpty {
                    if let result = tmdbManager.searchResults.first(where: { $0.id == result.id }) {
                        self.searchResult = result
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
