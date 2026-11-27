//
//  MovieCollectionDetailView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/27/26.
//

import SwiftUI

struct MovieCollectionDetailView: View {

    @Environment(TMDBManager.self) private var tmdbManager
    @Environment(\.dismiss) private var dismiss
    let collection: KTMovieCollection
    @State private var collectionInfo: KTCollectionResponse?

    @State private var error: String?
    @State private var showError: Bool = false

    /// Parts in release order; unreleased/undated entries go last.
    private var parts: [KTCollectionPart] {
        (collectionInfo?.parts ?? []).sorted {
            switch ($0.release_date, $1.release_date) {
            case let (lhs?, rhs?): lhs < rhs
            case (nil, _?): false
            case (_?, nil): true
            case (nil, nil): false
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                overview

                if collectionInfo != nil {
                    partsList
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
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
                collectionInfo = try await tmdbManager.collectionInfo(collectionId: collection.id)
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        Group {
            if let path = collectionInfo?.backdrop_path ?? collection.backdropPath,
               let url = URL(string: "https://image.tmdb.org/t/p/original\(path)") {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .clipped()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "film.stack")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            }
        }
        .overlay {
            LinearGradient(
                colors: [
                    .clear,
                    .clear,
                    .black.opacity(0.15),
                    .black.opacity(0.35),
                    .black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 4) {
                Text(collectionInfo?.name ?? collection.name)
                    .fontDesign(.serif)
                    .font(.largeTitle)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)

                if let collectionInfo {
                    Text("\(collectionInfo.parts.count) Movies")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Overview
    @ViewBuilder
    private var overview: some View {
        if let overview = collectionInfo?.overview, !overview.isEmpty {
            Text(overview)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 12)
        }
    }

    // MARK: - Parts
    private var partsList: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(parts, id: \.id) { part in
                NavigationLink {
                    WatchDetailView(result: searchResult(for: part))
                } label: {
                    partRow(part)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    private func partRow(_ part: KTCollectionPart) -> some View {
        HStack(alignment: .top, spacing: 12) {
            poster(path: part.poster_path)

            VStack(alignment: .leading, spacing: 4) {
                Text(part.title ?? part.name ?? "")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(year(of: part) ?? "TBA")
                    .font(.callout.weight(.light))
                    .tracking(1)
                    .foregroundStyle(.secondary)

                if !part.overview.isEmpty {
                    Text(part.overview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(.rect)
    }

    @ViewBuilder
    private func poster(path: String?) -> some View {
        if let path,
           let url = URL(string: "https://image.tmdb.org/t/p/w500\(path)") {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 80, height: 120)
            .clipped()
            .clipShape(.rect(cornerRadius: 8))
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "film")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 80, height: 120)
                .clipShape(.rect(cornerRadius: 8))
        }
    }

    // MARK: - Helpers
    private func year(of part: KTCollectionPart) -> String? {
        guard let date = part.release_date, !date.isEmpty else { return nil }
        return String(date.prefix(4))
    }

    private func searchResult(for part: KTCollectionPart) -> KTSearchResult {
        KTSearchResult(
            id: part.id,
            mediaType: .movie,
            title: part.title ?? part.name,
            name: nil,
            posterPath: part.poster_path,
            profile_path: nil,
            overview: part.overview,
            releaseDate: part.release_date,
            firstAirDate: nil,
            logoPath: nil,
            heroPosterPath: nil
        )
    }
}

#if DEBUG
#Preview {
    @Previewable @State var tmdbManager: TMDBManager?

    if let tmdbManager {
        NavigationStack {
            MovieCollectionDetailView(
                collection: KTMovieCollection(
                    id: 10,
                    name: "Star Wars Collection",
                    posterPath: "/pWVLFh4OuejTpUaDQbB1C4zoS2p.jpg",
                    backdropPath: "/iY2ujEY2m68OTTlPFTiHub9joHS.jpg"
                )
            )
            .environment(tmdbManager)
        }
    } else {
        ProgressView()
            .task {
                tmdbManager = try? .init(
                    tmdbClient: TMDBClientPreview(),
                    defaultManager: DefaultManager(),
                    token: "preview"
                )
            }
    }
}
#endif
