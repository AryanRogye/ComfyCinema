//
//  MovieImageBackground.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/6/26.
//

import SwiftUI

struct MovieImageBackground: View {

    let imagePath: String?

    var body: some View {
        ZStack(alignment: .center) {
            imageView
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            imageView
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .blur(radius: 15)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.5),
                            .init(color: .black.opacity(0.5), location: 0.6),
                            .init(color: .black, location: 0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.5),
                    .init(color: .black.opacity(0.65), location: 0.72),
                    .init(color: .black.opacity(0.75), location: 0.86),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var imageView: some View {
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
                .clipped()
            }
        }
    }
}
