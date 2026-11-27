//
//  MovieCollectionView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/27/26.
//

import SwiftUI

struct MovieCollectionView: View {

    let movieInfo: KTMovieInfo?

    private var collection: KTMovieCollection? {
        movieInfo?.belongsToCollection
    }

    var body: some View {
        VStack(alignment: .leading) {
            if let collection {
                HStack(alignment: .bottom, spacing: 12) {
                    poster(path: collection.posterPath)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Part of")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(1)

                        Text(collection.name)
                            .fontDesign(.serif)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    backdrop(path: collection.backdropPath)
                }
                .clipShape(.rect(cornerRadius: 12))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Poster
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
            .frame(width: 90, height: 135)
            .clipped()
            .clipShape(.rect(cornerRadius: 8))
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "film.stack")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 90, height: 135)
                .clipShape(.rect(cornerRadius: 8))
        }
    }

    // MARK: - Backdrop
    @ViewBuilder
    private func backdrop(path: String?) -> some View {
        ZStack {
            if let path,
               let url = URL(string: "https://image.tmdb.org/t/p/w780\(path)") {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                }
            } else {
                Rectangle()
                    .fill(.quaternary)
            }

            LinearGradient(
                colors: [
                    .black.opacity(0.35),
                    .black.opacity(0.6),
                    .black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipped()
    }
}
