//
//  SearchTextField.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/27/26.
//

import SwiftUI

struct SearchTextField: View {

    @Binding var searchText: String
    var focused: FocusState<Bool>.Binding
    let showXMark: Bool
    let onSubmit: () -> Void

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 8) {

                Image(systemName: "magnifyingglass")
                    .foregroundStyle(
                        .secondary.opacity(focused.wrappedValue ? 1 : 0.5)
                    )
                    .font(.body.weight(.medium))
                    .scaleEffect(focused.wrappedValue ? 1.08 : 1.0)
                    .symbolEffect(.pulse, value: focused.wrappedValue)
                    .animation(.snappy(duration: 0.25), value: focused.wrappedValue)

                TextField(
                    "Search Movies, TV, and People",
                    text: $searchText,
                    prompt: Text("Search Movies, TV, and People")
                        .foregroundStyle(.secondary)
                        .font(.body.weight(.medium))
                )
                .textFieldStyle(.plain)
                .focused(focused)
                .submitLabel(.search)
                .onSubmit { onSubmit() }

                if showXMark {
                    xmark
                }
            }
            .padding(.leading, 14)
            .frame(height: 44)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .animation(.smooth(duration: 0.25), value: showXMark)
        .animation(.smooth(duration: 0.25), value: focused.wrappedValue)
    }

    private var xmark: some View {
        Button {
            if !searchText.isEmpty {
                searchText = ""
            } else {
                focused.wrappedValue = false
            }
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
                .imageScale(.medium)
                .frame(width: 40, height: 40)
                .symbolEffect(.bounce, value: showXMark)
        }
        .buttonStyle(.plain)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }
}
