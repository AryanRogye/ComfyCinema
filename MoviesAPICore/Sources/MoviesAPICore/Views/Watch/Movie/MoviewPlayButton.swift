//
//  MoviewPlayButton.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/27/26.
//

import SwiftUI

struct MoviewPlayButton: View {

    let onLoadMovie: () -> Void

    var body: some View {
        Button {
            onLoadMovie()
        } label: {
            Label("Play Movie", systemImage: "play.fill")
                .font(.headline)
                .fontDesign(.rounded)
                .fontWeight(.bold)
                .foregroundStyle(.black)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .glassEffect(
                    .clear.tint(.white),
                    in: .capsule
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
        .padding(.horizontal)
    }
}
