//
//  MoviesAndTVShowDetailRow.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/4/26.
//

import SwiftUI

struct MoviesAndTVShowDetailRow: View {
    let imagePath: String?
    let index: Int
    let name: String
    let mediaType: KTMediaType
    let genres: [String]
    let imageWidth: CGFloat
    let imageHeight: CGFloat
    let textHeight: CGFloat
    let spacing: CGFloat
    var totalHeight: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            HomeImageView(imagePath: imagePath)
                .frame(width: imageWidth, height: imageHeight)
                .clipShape(.rect(cornerRadius: 10))

            Text("\(index + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading) {
                Text("\(name) (\(mediaType.rawValue))")
                    .font(.subheadline.weight(.medium))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                HStack(spacing: 2) {
                    ForEach(genres.enumerated(), id: \.offset) { index , genre in
                        Text("\(genre)\(index == genres.count - 1 ? "" : ", ")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: totalHeight)
        .contentShape(Rectangle())
    }
}
