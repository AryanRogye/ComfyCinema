//
//  MovieImageView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/27/26.
//

import SwiftUI

struct MovieImageView: View {

    let result: KTSearchResult
    let imagePath: String?

    var body: some View {
        Group {
            if let posterPath = imagePath,
               let url = URL(
                string: "https://image.tmdb.org/t/p/original\(posterPath)"
               ) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(maxWidth: .infinity)
                .clipped()
            } else {
                ZStack {
                    Rectangle()
                        .fill(.quaternary)

                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
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
            VStack(alignment: .leading) {
                if let logoPath = result.logoPath,
                   let url = URL(string: "https://image.tmdb.org/t/p/w500\(logoPath)") {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 50)
                            .padding(.horizontal, 6)
                    }  placeholder: {
                        Color.clear
                    }
                } else {
                    Text(result.name ?? result.title ?? "")
                        .fontDesign(.serif)
                        .font(.largeTitle)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }
}
