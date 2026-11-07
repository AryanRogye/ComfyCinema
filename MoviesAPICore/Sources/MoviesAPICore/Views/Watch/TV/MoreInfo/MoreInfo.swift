//
//  MoreInfo.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/6/26.
//

import SwiftUI

enum TVSelectedOption: String {
    case castAndCrew = "Cast & Crew"
    case moreLikeThis = "More Like This"
    case ratingsAndReviews = "Ratings & Reviews"
}

struct TVMoreInfo: View {

    let selectedEpisode: KTEpisode?
    let result: KTSearchResult
    @State private var selected: TVSelectedOption = .moreLikeThis


    var body: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    if selectedEpisode != nil {
                        MoreInfoButton(selected: .tv(.castAndCrew), isSelected: selected == .castAndCrew) {
                            selected = .castAndCrew
                        }
                    }
                    MoreInfoButton(selected: .tv(.moreLikeThis), isSelected: selected == .moreLikeThis) {
                        selected = .moreLikeThis
                    }
                    MoreInfoButton(selected: .tv(.ratingsAndReviews), isSelected: selected == .ratingsAndReviews) {
                        selected = .ratingsAndReviews
                    }
                }
                .padding(8)
            }
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.06))
            }

            switch selected {
            case .castAndCrew:
                CastAndCrew(selectedEpisode: selectedEpisode)
            case .moreLikeThis:
                TVMoreLikeThis(result: result)
            case .ratingsAndReviews:
                RatingsAndReviews(result: result, type: .tv)
            }
        }
        .padding(.horizontal)
    }
}
