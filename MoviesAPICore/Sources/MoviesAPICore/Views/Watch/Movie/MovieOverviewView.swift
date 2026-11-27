//
//  MovieInfoView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/27/26.
//

import SwiftUI

struct MovieOverviewView: View {

    let result: KTSearchResult

    var body: some View {
        VStack(alignment: .leading) {
            if let overview = result.overview {
                ExpandableText(
                    text: overview,
                    tintColor: .yellow,
                    font: .preferredFont(forTextStyle: .body),
                    background: .black,
                    foregroundStyle: .secondary
                )
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
