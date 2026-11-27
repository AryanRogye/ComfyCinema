//
//  EpisodesOptionView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/27/26.
//

import SwiftUI

struct EpisodesOptionView: View {

    @Bindable var defaultManager: DefaultManager
    let seasonInfo: KTSeasonInfo?
    let tvShow: KTTVShow?
    @Binding var selectedEpisode: KTEpisode?
    @Binding var selectedSeasonNumber: Int?
    let isLoadingSeason: Bool

    var body: some View {
        switch defaultManager.seasonPicker {
        case .picker:
            SeasonsViewPicker(
                tvShow: tvShow,
                isLoadingSeason: isLoadingSeason,
                selectedSeasonNumber: $selectedSeasonNumber
            )
        case .showAll:
            SeasonsView(
                tvShow: tvShow,
                isLoadingSeason: isLoadingSeason,
                selectedSeasonNumber: $selectedSeasonNumber
            )
        }

        EpisodesView(
            seasonInfo: seasonInfo,
            selectedEpisode: $selectedEpisode
        )
        .padding(.bottom, 24)
    }
}
