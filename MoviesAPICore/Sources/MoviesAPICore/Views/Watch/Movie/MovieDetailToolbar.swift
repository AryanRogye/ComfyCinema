//
//  MovieDetailToolbar.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/6/26.
//

import SwiftUI
import MoviesAPIData

struct MovieDetailToolbar: ToolbarContent {

    @Environment(PlaybackSession.self) var playbackSession

    let result: KTSearchResult
    let history: History?
    @Binding var movieUrl: URL?
    @Binding var showCreateCollection: Bool
    @Binding var collectionName: String
    @Binding var collectionResultToAdd: KTSearchResult?
    @Binding var displayServer: KTDisplayServer
#if os(macOS)
    @Binding var window: NSWindow?
    @Binding var reloadID: UUID
    @Bindable var webViewModel: EmbeddedMovieViewModel
#endif


    let screenshotter: EmbeddedMovieScreenshoter
    let onDismiss: () -> Void

    var body: some ToolbarContent {
        backbutton

#if os(macOS)
        ToolbarSpacer(.flexible)
#endif

        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Divider()
                historyId
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

            displayServerPicker
            reloadbutton
        }
    }

    // MARK: - Back Button
    private var backbutton: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
#if os(macOS)
                webViewModel.stopPlayback()
#endif
                if playbackSession.isPlaying(result) {
                    playbackSession.stop()
                }

                if movieUrl != nil {
                    screenshotter.stop()
                    self.movieUrl = nil
#if os(macOS)
                    if let window {
                        let frame = window.frame
                        window.setFrame(NSRect(x: frame.minX, y: frame.maxY - 860, width: 850, height: 860), display: true)
                    }
#endif
                } else {
                    onDismiss()
                }
            } label: {
                Image(systemName: "chevron.backward")
            }
        }
    }

    @ViewBuilder
    private var historyId: some View {
        if let history {
            Button {
#if os(iOS)
                UIPasteboard.general.string = history.id.uuidString
#elseif os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(
                    history.id.uuidString,
                    forType: .string
                )
#endif
            } label: {
                Text(history.id.uuidString)
            }
        }
    }

    // MARK: - Display Server Picker
    private var displayServerPicker: some View {
        Menu {
            ForEach(KTDisplayServer.entries, id: \.self) { server in
                Button {
                    displayServer = server
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
        if let movieUrl {
            Button {
#if os(macOS)
                reloadID = UUID()
#else
                playbackSession.webView?.load(movieUrl)
#endif
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
    }
}
