//
//  CarouselView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/4/26.
//

import SwiftUI

struct CarouselView<Content: View>: View {

    @ViewBuilder var content: Content
    var scrollProgress: (CGFloat) -> ()

    @State private var progress: CGFloat = 0
    var movement: CGFloat = 60

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    Group(subviews: content) { collection in
                        ForEach(collection) { subView in

                            let index = collection.firstIndex(where: { $0.id == subView.id }) ?? 0
                            let isLast = index == collection.count - 1
                            let opacity = isLast ? 0 : max(min(progress - CGFloat(index), 1), 0)

                            ZStack {
                                subView
                                    .frame(width: size.width, height: size.height)
                                    .clipped()
                                    .backgroundExtensionEffect()
                                    .safeAreaPadding(.horizontal, movement + 10)
                                    .mask {
                                        Rectangle()
                                            .ignoresSafeArea()
                                    }
                            }
                            .frame(width: size.width, height: size.height)
                            .compositingGroup()
                            .opacity(1 - opacity)
                            .visualEffect { [movement] content, proxy in
                                let minX = proxy.frame(in: .scrollView(axis: .horizontal)).minX
                                let movementProgress = max(min(minX / size.width, 1), -1)

                                return content
                                    .offset(x: -minX)
                                    .offset(x: movement * movementProgress)
                            }
                            .zIndex(Double(-index))
                        }
                    }
                }
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.x + $0.contentInsets.leading
            } action: { oldValue, newValue in
                progress = max(newValue / size.width, 0)
                scrollProgress(progress)
            }
        }
    }
}
