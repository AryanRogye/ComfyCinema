//
//  View+scrollViewStretch.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/27/26.
//

import SwiftUI

extension View {
    public func scrollViewStretch() -> some View {
        self
            .visualEffect { content, proxy in
                let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
                let stretch = max(minY, 0)

                return content
                    .scaleEffect(
                        x: 1 + stretch / proxy.size.width,
                        y: 1 + stretch / proxy.size.height,
                        anchor: .top
                    )
                    .offset(y: -stretch)
            }
    }
}
