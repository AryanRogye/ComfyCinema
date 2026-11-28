//
//  CastAndCrew.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/6/26.
//

import SwiftUI

struct CastAndCrew: View {

    @Environment(PlaybackSession.self) var playbackSession

    let credits: KTCredits?

    @State private var selectedPerson: KTSearchResult?

    var body: some View {
        if let credits {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(credits.cast, id: \.self) { star in
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
                        .contentShape(.rect)
                        .onTapGesture {
                            playbackSession.stop()
                            selectedPerson = KTSearchResult(
                                id: star.id,
                                mediaType: .person,
                                title: nil,
                                name: star.name,
                                posterPath: nil,
                                profile_path: star.profilePath,
                                overview: nil,
                                releaseDate: nil,
                                firstAirDate: nil,
                                logoPath: nil,
                                heroPosterPath: nil
                            )
                        }
                    }
                }
            }
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.06))
            }
            .padding(.horizontal)
            .navigationDestination(item: $selectedPerson) { person in
                WatchDetailView(result: person)
            }
        }
    }
}
