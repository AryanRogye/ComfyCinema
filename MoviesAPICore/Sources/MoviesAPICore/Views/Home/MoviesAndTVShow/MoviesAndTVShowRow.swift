//
//  HomeRow.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/16/26.
//

import SwiftUI

struct MoviesAndTVShowRow: View {

    let imagePath: String?
    let name: String
    let mediaType: KTMediaType
    let showMediaType: Bool
    let imageHeight: CGFloat
    let textHeight: CGFloat
    let spacing: CGFloat
    var totalHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            HomeImageView(imagePath: imagePath)
                .frame(width: 110, height: imageHeight)
                .clipShape(.rect(cornerRadius: 10))
        }
        .frame(width: 110, height: totalHeight)
        .overlay(alignment: .topTrailing) {
            if showMediaType {
                Text(mediaType.rawValue)
                    .font(.caption2.bold())
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .glassEffect(.regular.tint(.yellow.opacity(0.1)), in: .capsule)
                    .overlay {
                        Capsule()
                            .strokeBorder(.yellow.opacity(0.2), lineWidth: 1)
                    }
                    .padding(5)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
    }
}
