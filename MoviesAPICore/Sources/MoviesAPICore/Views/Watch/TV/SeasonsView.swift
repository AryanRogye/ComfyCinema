//
//  SeasonsView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/6/26.
//

import SwiftUI

/// Shows season number picker
struct SeasonsView: View {

    let tvShow: KTTVShow?
    let isLoadingSeason: Bool

    @Binding var selectedSeasonNumber: Int?

    @Namespace private var nm

    #if os(iOS)
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    #elseif os(macOS)
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]
    #endif

    var body: some View {
        if let tvShow {
            VStack(alignment: .leading) {
                if let selectedSeasonNumber {
                    Text("Season \(selectedSeasonNumber)")
                        .font(.title2)
                        .fontWeight(.bold)
                } else {
                    Text("Seasons")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(tvShow.seasons, id: \.id) { season in
                        let seasonNumber = Int(season.seasonNumber)
                        let isSelected = selectedSeasonNumber == seasonNumber

                        Button {
                            guard !isLoadingSeason else { return }

                            withAnimation(
                                .spring(
                                    response: 0.3,
                                    dampingFraction: 0.7
                                )
                            ) {
                                selectedSeasonNumber = seasonNumber
                            }
                        } label: {
                            Text("Season \(season.seasonNumber)")
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(
                                    isSelected ? .primary : .secondary
                                )
                                .frame(maxWidth: .infinity)
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
                                                id: "ACTIVE_SEASON_PILL",
                                                in: nm
                                            )
                                    } else {
                                        Capsule()
                                            .fill(.white.opacity(0.06))
                                    }
                                }
                        }
                        .buttonStyle(TVDetailButtonStyle())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
        }
    }
}
