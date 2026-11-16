//
//  TVMoreLikeThis.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/6/26.
//

import SwiftUI

struct TVMoreLikeThis: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(PlaybackSession.self) var playbackSession
    let result: KTSearchResult

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var response: KTTVListResponse?

    @State private var showDetail: Bool = false
    @State private var selectedResult: KTSearchResult?

    @State private var isResolving: Bool = false
    @State private var resolveTask: Task<Void, Never>?


    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack {
                if let response {
                    ForEach(response.results, id: \.self) { result in
                        VStack {
                            artwork(result: result)
                            Text(result.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(height: 36, alignment: .top)
                        }
                        .frame(width: 120)
                        .onTapGesture {
                            playbackSession.stop()
                            resolve(result)
                        }
                    }
                } else {
                    ProgressView()
                }
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
                response = try await tmdbManager.recommendationsForTV(for: result.id)
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
        .navigationDestination(isPresented: $showDetail) {
            if let selectedResult {
                WatchDetailView(result: selectedResult)
            }
        }
    }

    func resolve(_ result: KTTVListResult) {
        if isResolving { return }
        resolveTask = Task {

            isResolving = true
            defer {
                isResolving = false
            }

            do {
                try await tmdbManager.search(result.displayName)
                if !tmdbManager.searchResults.isEmpty {
                    if let result = tmdbManager.searchResults.first(where: { $0.id == result.id }) {
                        self.selectedResult = result
                        self.showDetail = true
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

    @ViewBuilder
    private func artwork(result: KTTVListResult) -> some View {
        if let posterPath = result.posterPath,
           let url = URL(
            string: "https://image.tmdb.org/t/p/w500\(posterPath)"
           ) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 120, height: 180)
            .clipped()
            .clipShape(.rect(cornerRadius: 12))
        } else {
            posterPlaceholder(for: result.mediaType)
        }
    }

    private func posterPlaceholder(for mediaType: KTMediaType) -> some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(
                    systemName: mediaType == .movie
                    ? "film"
                    : "play.rectangle"
                )
                .font(.title3)
                .foregroundStyle(.secondary)
            }
    }
}
