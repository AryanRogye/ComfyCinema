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

    @Namespace private var nm

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

    @State private var hoveringEpisode: KTEpisode?

    var body: some View {
        if let seasonInfo {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(seasonInfo.episodes, id: \.id) { episode in
                    let isSelected = selectedEpisode == episode

                    Button {
                        withAnimation(
                            .spring(
                                response: 0.3,
                                dampingFraction: 0.7
                            )
                        ) {
                            selectedEpisode = episode
                        }
                    } label: {
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
                    .buttonStyle(TVDetailButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}
