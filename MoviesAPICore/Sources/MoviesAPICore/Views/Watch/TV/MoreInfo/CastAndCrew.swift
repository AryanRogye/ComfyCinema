//
//  CastAndCrew.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/6/26.
//

import SwiftUI

struct CastAndCrew: View {

    let selectedEpisode: KTEpisode?

    var body: some View {
        if let selectedEpisode {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(selectedEpisode.guestStars, id: \.self) { star in
                        VStack {
                            ZStack {
                                if let path = star.profilePath,
                                   let url = URL(string: "https://image.tmdb.org/t/p/w185\(path)") {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                } else {
                                    Rectangle()
                                        .fill(.gray.opacity(0.15))
                                        .overlay {
                                            Image(systemName: "person.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .foregroundStyle(.secondary)
                                                .padding(30)
                                        }
                                }
                            }
                            .frame(width: 120, height: 180)
                            .clipped()
                            .clipShape(.rect(cornerRadius: 12))

                            Text(star.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(height: 36, alignment: .top)
                        }
                    }
                }
            }
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.06))
            }
        }
    }
}
