//
//  TVShowInfo.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/6/26.
//

import SwiftUI

/// This is info about the TV Show
/// Name and Description/Overview
struct TVShowInfoView: View {
    let selectedEpisode: KTEpisode?

    var body: some View {
        if let selectedEpisode {
            VStack(alignment: .leading, spacing: 8) {
                Text(selectedEpisode.name)
                    .font(.title3)
                    .fontWeight(.semibold)

                ExpandableText(
                    text: selectedEpisode.overview,
                    tintColor: .yellow,
                    font: .preferredFont(forTextStyle: .body),
                    background: .black,
                    foregroundStyle: .secondary
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            /// Background only looks nice on macOS
#if os(macOS)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.06))
            }
#endif
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
}
