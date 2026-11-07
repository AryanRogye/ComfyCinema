//
//  TVDetailToolbar.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/6/26.
//

import SwiftUI

struct TVDetailToolbar: ToolbarContent {

    @Environment(PlaybackSession.self) var playbackSession
    @AppStorage("PreferStandardMediaSource") private var preferStandardMediaSource = false

    let result: KTSearchResult
    let tvUrl: URL?
    @Binding var iFrameLogs: [String]
    @Binding var videoFrameLogs: [String]
    @Binding var navigationLogs: [String]
    @Binding var showCreateCollection: Bool
    @Binding var collectionName: String
    @Binding var collectionResultToAdd: KTSearchResult?
    @Binding var displayServer: KTDisplayServer
    @Binding var timeInfo: TimeInfo?
    @Binding var lastProgressSaveAt: Date?
#if os(macOS)
    @Binding var reloadID: UUID
    @Binding var hideSeasonsAndEpisodes: Bool
    @Bindable var webViewModel: EmbeddedMovieViewModel
    let menubarController: TVDetailMenubarController
#endif
    let onSaveCurrentPlaybackPosition: () -> Void
    let onDismiss: () -> Void


    var body: some ToolbarContent {
        backbutton

#if os(macOS)
        ToolbarSpacer(.flexible)
#endif

        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                playbackCompatability
                Divider()
                hideSeasonAndEpisodes
                logsView
                CollectionFavoriteMenu(
                    result: result,
                    showCreateCollection: $showCreateCollection,
                    collectionName: $collectionName,
                    collectionResultToAdd: $collectionResultToAdd
                )
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuIndicator(.hidden)
            .environment(\.menuOrder, .fixed)

            /// Server Picker
            displayServerPicker

            /// Reload Button
            reloadbutton
        }
    }

    // MARK: - Back Button
    private var backbutton: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
#if os(macOS)
                webViewModel.stopPlayback()
                menubarController.removeMenubarItems()
#endif
                onSaveCurrentPlaybackPosition()
                if playbackSession.isPlaying(result) {
                    playbackSession.stop()
                }
                onDismiss()
            } label: {
                Image(systemName: "chevron.backward")
            }
        }
    }

    // MARK: - Playback Compatability
    @ViewBuilder
    private var playbackCompatability: some View {
        Toggle("Playback Compatibility", isOn: $preferStandardMediaSource)
        Text("Changing this reloads the player.")
    }


    // MARK: - Hide Season And Episodes
    @ViewBuilder
    private var hideSeasonAndEpisodes: some View {
#if os(macOS)
        /// Player Only on macOS
        Button {
            hideSeasonsAndEpisodes.toggle()
        } label: {
            Label(
                "Player Only",
                systemImage: hideSeasonsAndEpisodes ? "eye.slash" : "eye"
            )
            .labelStyle(.titleAndIcon)
        }
#endif
    }

    // MARK: - Logs
    @ViewBuilder
    private var logsView: some View {
#if os(iOS)
        /// iOS Logs
        NavigationLink {
            IFrameLogsView(
                logs: $iFrameLogs,
                videoLogs: $videoFrameLogs,
                navigationLogs: $navigationLogs
            )
        } label: {
            Text("Logs")
        }
        .buttonStyle(.plain)
#endif
    }

    // MARK: - Display Server Picker
    private var displayServerPicker: some View {
        Menu {
            ForEach(KTDisplayServer.entries, id: \.self) { server in
                Button {
                    self.displayServer = server
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
    }

    // MARK: - Reload Button
    @ViewBuilder
    private var reloadbutton: some View {
        if let tvUrl {
            Button {
                onSaveCurrentPlaybackPosition()
                timeInfo = nil
                lastProgressSaveAt = nil
#if os(macOS)
                reloadID = UUID()
#else
                playbackSession.webView?.load(tvUrl)
#endif
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
    }
}
