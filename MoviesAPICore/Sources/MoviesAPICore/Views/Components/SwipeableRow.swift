//
//  SwipeableRow.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/18/26.
//

import SwiftUI

struct SwipeableRow<Content: View, Actions: View>: View {

    @Binding var isSwiped: Bool
    @Binding var offset: CGFloat
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    @State private var contentWidth: CGFloat = 0
    @State private var actionWidth: CGFloat = 0

    var body: some View {
#if os(iOS)
        ZStack {
            /// we'll have a placeholder all the way to the right
            HStack {
                Spacer()
                HStack(spacing: 12) {

                    let fullShown: CGFloat = 1
                    let hidden: CGFloat = 0
                    let progress = min(abs(offset) / (actionWidth ), 1)
                    let value = hidden + (fullShown - hidden) * progress

                    let fullBlurShown: CGFloat = 10
                    let fullBlurHidden: CGFloat = 0
                    let coverBlurProgress = min(abs(offset) / (actionWidth * 0.75), 1)

                    let blurValue = fullBlurShown + (fullBlurHidden - fullBlurShown) * coverBlurProgress

                    actions
                        .opacity(value)
                        .scaleEffect(value)
                        .blur(radius: blurValue)
                }
                .padding(.leading)
                .fixedSize(horizontal: true, vertical: false)
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.width
                } action: {
                    actionWidth = $0
                }

            }
            .zIndex(0)

            ZStack {
                content
                    .allowsHitTesting(!isSwiped && offset == 0)
                    .offset(x: offset)
                    .zIndex(1)

                if isSwiped {
                    Color.clear
                        .contentShape(Rectangle())
                        .offset(x: offset)
                        .onTapGesture {
                            withAnimation(.bouncy) {
                                offset = 0
                                isSwiped = false
                            }
                        }
                        .zIndex(2)
                }
            }
        }
        .clipped()
        .contentShape(.rect)
        .simultaneousGesture(swipeAction())
        .onChange(of: isSwiped) { _, newValue in
            if !newValue {
                closeSwipeAction()
            }
        }
#elseif os(macOS)
        content
#endif
    }

    public func closeSwipeAction() {
        withAnimation(.bouncy) {
            offset = 0
            isSwiped = false
        }
    }

    private func swipeAction() -> some Gesture {
        DragGesture(minimumDistance: 25)
            .onChanged { value in
                /// make sure we're more horizontal than vertical
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }

                /// only swipe left if we're not swiped
                if !isSwiped {
                    withAnimation(.smooth(duration: 0.1)) {
                        offset = min(
                            0,
                            value.translation.width * 0.8
                        )
                        if abs(offset) == abs(actionWidth) {
                            vibrate()
                        }
                    }
                }
                /// only swipe to the right if + if we're already swiped
                else if value.translation.width > 0 && isSwiped {
                    let startingOffset = -actionWidth

                    withAnimation(.smooth(duration: 0.1)) {
                        offset = min(
                            0,
                            startingOffset + value.translation.width * 0.8
                        )
                        if abs(offset) == 0 {
                            vibrate()
                        }
                    }
                }
            }
            .onEnded { value in
                /// make sure we're more horizontal than vertical

                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }

                /// if > half of the width snap to the half
                /// and set to swiped value
                if actionWidth / 2 <= abs(offset) {
                    withAnimation(.bouncy) {
                        offset = -actionWidth
                        isSwiped = true
                        vibrate()
                    }
                }
                /// if we didnt swipe > half of the width reset the offset
                else {
                    withAnimation(.bouncy) {
                        offset = 0
                        isSwiped = false
                        vibrate()
                    }
                }
            }
    }

    #if os(iOS)
    private func vibrate() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    #elseif os(macOS)
    private func vibrate() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )
    }
    #endif
}
