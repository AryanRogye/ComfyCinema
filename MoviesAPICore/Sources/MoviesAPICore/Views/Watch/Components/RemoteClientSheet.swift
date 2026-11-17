//
//  RemoteClientSheet.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/17/26.
//

#if os(iOS)
import SwiftUI

struct RemoteClientSheet: View {

    @Environment(RemoteClient.self) private var remoteClient
    @State private var error: String?
    @State private var isSending = false
    @State private var sent = false

    let result: KTSearchResult
    var season: Int? = nil
    var episode: Int? = nil

    var body: some View {
        Form {
            if let server = remoteClient.connectedServer {
                Text(server.server.service.name)
                Button(isSending ? "Sending…" : "Send Play Request") {
                    Task {
                        isSending = true
                        error = nil
                        sent = false
                        defer { isSending = false }
                        do {
                            try await remoteClient.sendPlayRequest(
                                id: Int(result.id),
                                name: result.name ?? result.title ?? "",
                                mediaType: result.mediaType,
                                season: season,
                                episode: episode
                            )
                            sent = true
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
                .disabled(isSending)
                Section("Player Controls") {
                    Button("Play") { sendAction { try await remoteClient.sendPlay() } }
                    Button("Pause") { sendAction { try await remoteClient.sendPause() } }
                    Button("Enter Fullscreen") { sendAction { try await remoteClient.sendFullscreen() } }
                    Button("Exit Fullscreen") { sendAction { try await remoteClient.sendExitFullscreen() } }
                }
                .disabled(isSending)
            } else {
                Text("Connect to a remote device in Settings.")
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }
            if sent {
                Text("Play request sent.")
            }
        }
        .formStyle(.grouped)
    }

    private func sendAction(_ action: @escaping @MainActor () async throws -> Void) {
        isSending = true
        error = nil
        sent = false
        Task {
            defer { isSending = false }
            do {
                try await action()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
#endif
