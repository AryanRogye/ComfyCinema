//
//  MovieMoreInfo.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/6/26.
//

import SwiftUI

enum MovieSelectedOption: String {
    case moreLikeThis = "More Like This"
    case ratingsAndReviews = "Ratings & Reviews"
}

struct MovieMoreInfo: View {

    let result: KTSearchResult
    @State private var selected: MovieSelectedOption = .moreLikeThis


    var body: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    MoreInfoButton(selected: .movie(.moreLikeThis), isSelected: selected == .moreLikeThis) {
                        selected = .moreLikeThis
                    }
                    MoreInfoButton(selected: .movie(.ratingsAndReviews), isSelected: selected == .ratingsAndReviews) {
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
            case .moreLikeThis:
                MovieMoreLikeThis(result: result)
            case .ratingsAndReviews:
                RatingsAndReviews(result: result, type: .movie)
            }
        }
        .padding(.horizontal)
    }
}
