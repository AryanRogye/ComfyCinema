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
    @State private var isPlayingAll: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LiveTVHeaderView(selectedSection: $selectedSection)

#if os(iOS)
            TabView(selection: $selectedSection) {
                ForEach(liveTVManager.sections, id: \.id) { section in
                    LiveTVSectionView(section: section, selectedSection: $selectedSection, isPlayingAll: isPlayingAll && selectedSection?.id == section.id)
                        .tag(Optional(section))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(.container, edges: .bottom)
#elseif os(macOS)
            if let selectedSection {
                LiveTVSectionView(section: selectedSection, selectedSection: $selectedSection, isPlayingAll: isPlayingAll)
            }
#endif
        }
        .onAppear {
            do {
                try liveTVManager.sync()
                if selectedSection == nil {
                    selectedSection = liveTVManager.sections.first
                }
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Toggle("Play All", isOn: $isPlayingAll)
                } label: {
                    Image(systemName: "ellipsis")
                        .tint(.yellow)
                }
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

    @Binding var selectedSection: LiveTVSection?
    @State private var didPressChannel: Bool = false
    @State private var selectedChannel: LiveTVChannel? = nil
    let isPlayingAll: Bool

    @AppStorage("LiveDisplayServer") private var liveDisplayServerRawValue = KTLiveDisplayServer.dliveStream.rawValue

    private var displayServer: KTLiveDisplayServer {
        KTLiveDisplayServer.entries.first { $0.rawValue == liveDisplayServerRawValue } ?? .dliveStream
    }


    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns) {
                ForEach(section.channels, id: \.id) { channel in
                    if isPlayingAll, let url = URL(string: displayServer.loadLive(Id: Int32(channel.id))) {
                        LiveTVChannelPlayer(channel: channel, url: url)
                            .id(url)
                    } else {
                        Button {
                            didPressChannel = true
                            selectedChannel = channel
                        } label: {
                            VStack {
                                // Load the logo link, keeping the full logo visible.
                                AsyncImage(url: channel.logo.isEmpty ? nil : URL(string: channel.logo)) { phase in
                                    ZStack {
                                        Rectangle()
                                            .fill(.quaternary)

                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .scaledToFit()
                                                .padding(8)
                                        } else if phase.error != nil || channel.logo.isEmpty || URL(string: channel.logo) == nil {
                                            Image(systemName: "photo")
                                                .font(.title2)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            ProgressView()
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .clipShape(.rect(cornerRadius: 12))
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
                        .buttonStyle(LiveTVButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
            .navigationDestination(isPresented: $didPressChannel) {
                if let selectedChannel {
                    LiveTVDetailView(channel: selectedChannel, displayServer: Binding(
                        get: { displayServer },
                        set: { liveDisplayServerRawValue = $0.rawValue }
                    )) {
                        self.selectedSection = selectedSection
                        self.selectedChannel = nil
                        self.didPressChannel = false
                    }
                }
            }
        }
    }
}

/// Every grid player owns its session so iOS never reuses another tile's WKWebView.
private struct LiveTVChannelPlayer: View {
    let channel: LiveTVChannel
    let url: URL
    @State private var viewModel = EmbeddedMovieViewModel()
    @State private var playbackSession = PlaybackSession()

    var body: some View {
        VStack(spacing: 6) {
            EmbeddedMovieView(url: url, vm: viewModel, allowsInlinePlayback: true)
                .environment(playbackSession)
                .frame(height: 200)
            Text(channel.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
        }
        .onDisappear {
            // Leave delegates intact for WebView.dismantleView to stop media
            // and remove handlers, but do not reuse that emptied view later.
            playbackSession.webView = nil
#if os(macOS)
            viewModel.stopPlayback()
#endif
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
