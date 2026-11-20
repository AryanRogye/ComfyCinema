//
//  SearchResultsRow.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/15/26.
//

import SwiftUI

struct SearchResultsRow: View {
    let result: KTSearchResult

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            imageView

            description

            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    var urlForImage: URL? {
        switch result.mediaType {
        case .person:
            if let profilePath = result.profile_path {
                return URL(string: "https://image.tmdb.org/t/p/w185\(profilePath)")
            }
        default:
            if let posterPath = result.posterPath {
                return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
            }
        }
        return nil
    }

    @ViewBuilder
    private var imageView: some View {
        if let url = urlForImage {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 90, height: 135)
            .clipShape(.rect(cornerRadius: 8))
        } else {
            ZStack {
                Rectangle()
                    .fill(.quaternary)

                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 90, height: 135)
            .clipShape(.rect(cornerRadius: 8))
        }
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(result.name ?? result.title ?? "Unknown")
                    .font(.headline)
                Spacer()

                switch result.mediaType {
                case .movie:
                    Text(result.releaseDate?.prefix(4) ?? "")
                case .tv:
                    Text(result.firstAirDate?.prefix(4) ?? "")
                default:
                    EmptyView()
                }
            }

            Text(result.mediaType.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(result.overview ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
    }
}
