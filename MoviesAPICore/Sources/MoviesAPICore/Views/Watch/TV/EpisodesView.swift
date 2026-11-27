//
//  EpisodesView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/6/26.
//

import SwiftUI

/// Shows Episode Picker
struct EpisodesView: View {

    let seasonInfo: KTSeasonInfo?
    @Binding var selectedEpisode: KTEpisode?

    #if os(iOS)
    let columns = [
        GridItem(.flexible()),
    ]
    #elseif os(macOS)
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]
    #endif

    var body: some View {
        if let seasonInfo {
            LazyVGrid(columns: columns, spacing: 22) {
                ForEach(seasonInfo.episodes, id: \.id) { episode in
                    let isSelected = selectedEpisode == episode

                    NewEpisodeRow(
                        episode: episode,
                        isSelected: isSelected,
                    ) {
                        withAnimation(
                            .spring(
                                response: 0.3,
                                dampingFraction: 0.7
                            )
                        ) {
                            selectedEpisode = episode
                        }
                    }
                }
            }
            .padding(.horizontal)
            .id(seasonInfo.id)
            .transition(.opacity)
        }
    }
}

private struct NewEpisodeRow: View {

    let episode: KTEpisode
    let isSelected: Bool
    let onSelect: () -> Void

    @Namespace private var nm
    @State private var hoveringEpisode: KTEpisode?

    private var imagePath: String? {
        episode.stillPath
    }

    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Button {
                    onSelect()
                } label: {
                    imageView
                }
                .buttonStyle(TVDetailButtonStyle())
                VStack(alignment: .leading) {
                    episodeName
                    runtime
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ExpandableText(
                text: episode.overview,
                tintColor: .yellow,
                font: .preferredFont(forTextStyle: .caption1),
                background: .black,
                foregroundStyle: .secondary
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    private var episodeName: some View {
        Text("\(episode.episodeNumber). \(episode.name)")
            .minimumScaleFactor(0.5)
#if os(iOS)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
#else
            .lineLimit(1)
            .minimumScaleFactor(0.5)
#endif
            .font(.footnote.weight(.bold))
            .foregroundStyle(isSelected ? .yellow : .primary.opacity(0.7))
    }

    @ViewBuilder
    private var runtime: some View {
        if let runtime = episode.runtime {
            Text("\(runtime)m")
                .minimumScaleFactor(0.5)
#if os(iOS)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
#else
                .lineLimit(1)
                .minimumScaleFactor(0.5)
#endif
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary.opacity(0.7))
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
                        .scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(width: 120)
                .clipShape(.rect(cornerRadius: 8))
                .contentShape(.rect)
                .overlay {
                    Circle()
                        .fill(.black.opacity(0.5))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Circle()
                                .stroke(.secondary, style: .init(lineWidth: 0.5))
                        }
                        .overlay {
                            Image(systemName: "play.fill")
                        }
                }
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                .yellow,
                                style: .init(lineWidth: 2)
                            )
                    }
                }
            } else {
                ZStack {
                    Rectangle()
                        .fill(.quaternary)

                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(width: 120)
                .clipShape(.rect(cornerRadius: 8))
            }
        }
    }

}

private struct EpisodeRow: View {

    let episode: KTEpisode
    let isSelected: Bool

    @Namespace private var nm
    @State private var hoveringEpisode: KTEpisode?


    var body: some View {
        let isHovering = hoveringEpisode == episode
        Text("EP\(episode.episodeNumber): \(episode.name)")
            .minimumScaleFactor(0.5)
#if os(iOS)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
#else
            .lineLimit(1)
            .minimumScaleFactor(0.5)
#endif
            .font(.subheadline.weight(.medium))
            .foregroundStyle(
                isSelected || isHovering ? .primary : .secondary
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(.yellow.opacity(0.16))
                        .background {
                            Capsule()
                                .stroke(
                                    .yellow.opacity(0.6),
                                    style: .init(lineWidth: 1)
                                )
                        }
                        .shadow(
                            color: .yellow,
                            radius: 8
                        )
                        .matchedGeometryEffect(
                            id: "ACTIVE_EPISODE_PILL",
                            in: nm
                        )
                } else {
                    Capsule()
                        .fill(
                            .white.opacity(isHovering ? 0.12 : 0.06)
                        )
                }
            }
            .onHover { hovering in
                if hovering {
                    hoveringEpisode = episode
                } else {
                    hoveringEpisode = nil
                }
            }

    }
}
