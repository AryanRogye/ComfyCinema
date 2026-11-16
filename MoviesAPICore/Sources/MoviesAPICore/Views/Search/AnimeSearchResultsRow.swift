//
//  AnimeSearchResultsRow.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 10/14/26.
//

import SwiftUI

struct AnimeSearchResultsRow: View {

    let result: Anime

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            imageView

            description

            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var imageView: some View {
        if let posterPath = result.coverImage.extraLarge {
            AsyncImage(url: posterPath) { image in
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

//    https:s4.anilist.co/file/anilistcdn/media/anime/cover/medium/b185-GvXiR8AKTmdn.jpg

    private var description: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(result.title.english ?? result.title.romaji ?? "Unknown")
                    .font(.headline)
                Spacer()
            }

            if let format = result.format {
                Text(format)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let description = result.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
    }
}
