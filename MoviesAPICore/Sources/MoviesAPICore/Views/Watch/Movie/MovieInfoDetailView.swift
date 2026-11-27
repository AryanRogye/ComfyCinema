//
//  MovieInfoDetailView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/27/26.
//

import SwiftUI

struct MovieInfoDetailView: View {

    let result: KTSearchResult
    let movieInfo: KTMovieInfo?

    private var allGenres: String {
        return genres.joined(separator: " · ")
    }
    private var genres: [String] {
        movieInfo?.genres.map(\.name) ?? []
    }

    private var year: String? {
        guard let release_date = movieInfo?.release_date else { return nil }
        return String(release_date.prefix(4))
    }

    var body: some View {
        HStack {
            Group {
                if let year {
                    Text(year)
                } else {
                    Text("No Year")
                }
            }
            .font(.callout.weight(.light))
            .fontDesign(.default)
            .tracking(1)

            Text(allGenres)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
                .fontDesign(.default)

            Spacer()
        }
        .padding(.top, 8)
        .padding(.horizontal)
    }
}
