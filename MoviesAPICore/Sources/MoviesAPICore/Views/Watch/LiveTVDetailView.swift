//
//  LiveTVDetailView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 10/27/26.
//

import SwiftUI
import WebKit

struct LiveTVDetailView: View {

    @Environment(\.dismiss) var dismiss
    @Environment(PlaybackSession.self) var playbackSession
    let channel: LiveTVChannel

    @AppStorage("LiveDisplayServer") private var liveDisplayServerRawValue = KTLiveDisplayServer.dliveStream.rawValue

    private var displayServer: KTLiveDisplayServer {
        KTLiveDisplayServer.entries.first { $0.rawValue == liveDisplayServerRawValue } ?? .dliveStream
    }

    @State private var liveUrl: URL?
    @State private var hasLoadedLiveUrl: Bool = false
    @State private var reloadID = UUID()
    @State var webviewModel: EmbeddedMovieViewModel = .init()

    @AppStorage("PreferStandardMediaSource") private var preferStandardMediaSource = false

    var body: some View {
        ZStack {
            if let liveUrl {
#if os(iOS)
                GeometryReader { proxy in
                    EmbeddedMovieView(url: liveUrl, vm: webviewModel)
                        .id(reloadID)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .padding(.horizontal, 10)
                }
                .frame(height: 200)
#elseif os(macOS)
                EmbeddedMovieView(url: liveUrl, vm: webviewModel)
                    .id(reloadID)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                    .padding(.top, 50)
#endif
            }
        }
        .navigationBarBackButtonHidden()
        .navigationTitle(channel.name)
        .frame(maxWidth: .infinity)
        .onChange(of: displayServer) {
            if hasLoadedLiveUrl {
                playbackSession.stop()
                reloadLiveTV()
            }
        }
        .onAppear {
            playbackSession.stop()
            loadLiveTV()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
#if os(macOS)
                    webviewModel.stopPlayback()
#endif
                    self.liveUrl = nil
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                }
            }

#if os(macOS)
            ToolbarSpacer(.flexible)
#endif

            ToolbarItemGroup(placement: .primaryAction) {

                Menu {
                    Toggle("Playback Compatibility", isOn: $preferStandardMediaSource)
                    Text("Changing this reloads the player.")
                    Divider()
#if os(macOS)
                    Button("Freeze Proccess") { webviewModel.freezeProcess() }
                    Button("UnFreeze Proccess") { webviewModel.unfreezeProcess() }
#endif
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuIndicator(.hidden)
                .environment(\.menuOrder, .fixed)


                Menu {
                    ForEach(KTLiveDisplayServer.entries, id: \.self) { server in
                        Button {
                            liveDisplayServerRawValue = server.rawValue
                        } label: {
                            if displayServer == server {
                                Label(server.rawValue, systemImage: "checkmark")
                            } else {
                                Text(server.rawValue)
                            }
                        }
                    }
                } label: {
                    Text(displayServer.rawValue)
                        .foregroundStyle(.yellow)
                }
                .tint(.yellow)

                if liveUrl != nil {
                    Button {
                        reloadLiveTV()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }

    }

    private func loadLiveTV() {
        let str = displayServer.loadLive(Id: Int32(channel.id))
        guard let url = URL(string: str) else { return }
        self.liveUrl = url
        hasLoadedLiveUrl = true
    }

    private func reloadLiveTV() {
        loadLiveTV()
        reloadID = UUID()
    }
}
