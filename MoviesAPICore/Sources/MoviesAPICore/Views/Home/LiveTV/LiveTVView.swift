//
//  LiveTVView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 10/27/26.
//

import SwiftUI

struct LiveTVView: View {

    @Binding var error: String?
    @Binding var showError: Bool
    @Environment(LiveTVManager.self) var liveTVManager

    @State private var selectedSection: LiveTVSection? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LiveTVHeaderView(selectedSection: $selectedSection)

#if os(iOS)
            TabView(selection: $selectedSection) {
                ForEach(liveTVManager.sections, id: \.id) { section in
                    LiveTVSectionView(section: section)
                        .tag(Optional(section))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(.container, edges: .bottom)
#elseif os(macOS)
            if let selectedSection {
                LiveTVSectionView(section: selectedSection)
            }
#endif
        }
        .onAppear {
            do {
                try liveTVManager.sync()
                selectedSection = liveTVManager.sections.first
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}

private struct LiveTVSectionView: View {
    let section: LiveTVSection

#if os(iOS)
    let columns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
#elseif os(macOS)
    let columns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
#endif

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns) {
                ForEach(section.channels, id: \.id) { channel in
                    VStack {
                        /// add logo here later
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.secondary.opacity(0.2))
                            .frame(maxWidth: .infinity)
                            .frame(height: 100)
                        Text(channel.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40, alignment: .center)
                    }
                    .padding(4)
                    .background {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.2))
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
    }
}

private struct LiveTVHeaderView: View {

    @Environment(LiveTVManager.self) var liveTVManager
    @Binding var selectedSection: LiveTVSection?
    @Namespace private var nm

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(liveTVManager.sections, id: \.id) { section in
                        let isSelected = selectedSection?.id == section.id
                        Button {
                            self.selectedSection = section
                        } label: {
                            Text(section.name)
                                .padding(8)
                                .frame(height: 40)
                                .background {
                                    if isSelected {
                                        Capsule()
                                            .fill(.yellow.opacity(0.16))
                                            .background {
                                                Capsule()
                                                    .stroke(
                                                        .yellow.opacity(0.6),
                                                        style: .init(lineWidth: 1)
                                                    )
                                            }
                                            .shadow(
                                                color: .yellow,
                                                radius: 8
                                            )
                                            .matchedGeometryEffect(
                                                id: "ACTIVE_LIVE_TV_PILL",
                                                in: nm
                                            )
                                    } else {
                                        Capsule()
                                            .fill(.white.opacity(0.06))
                                    }
                                }
                        }
                        .buttonStyle(LiveTVButtonStyle())
                        .id(section.id)
                    }
                }
                .padding(.horizontal, 8)
            }
            .onChange(of: selectedSection?.id) { _, newID in
                guard let newID else { return }

                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }
}

private struct LiveTVButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.18), value: configuration.isPressed)
    }
}
