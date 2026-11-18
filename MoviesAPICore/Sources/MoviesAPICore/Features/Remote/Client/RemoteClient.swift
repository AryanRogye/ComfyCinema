//
//  RemoteClient.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/16/26.
//

#if os(iOS)

import Foundation

struct ConnectedServer {
    let server: ResolvedServer
    let url: URL
}

enum RemoteClientError: LocalizedError {
    case cantMakeHealthRequest
    case cantMakePlayRequest
    case wrongPlayRequestArgument
    case playRequestFailed(Int)
    case cantMakePlayerAction
    case playerActionFailed(Int)

    var errorDescription: String? {
        switch self {
        case .cantMakeHealthRequest:
            "Cant Make Health Request"
        case .cantMakePlayRequest:
            "Cant Make Play Request"
        case .wrongPlayRequestArgument:
            "Wrong Play Request Argument"
        case .playRequestFailed(let status):
            "Play request failed (HTTP \(status))."
        case .cantMakePlayerAction:
            "Connect to a remote device first."
        case .playerActionFailed(let status):
            "Player action failed (HTTP \(status))."
        }
    }
}

@Observable
@MainActor
final class RemoteClient {
    let remoteServerResolver = RemoteServerResolver()

    private(set) var connectedServer: ConnectedServer?
    private(set) var error: Error?
    private let clientQueue = TaskQueue()

    var discoveredDevices: [ResolvedServer] {
        remoteServerResolver.discoveredDevices
    }

    public func connect(to server: ResolvedServer) throws {
        guard let hostname = server.hostname,
              let port = server.port,
              let url = URL(string: "http://\(hostname):\(port)/")
        else {
            throw URLError(.badURL)
        }

        connectedServer = ConnectedServer(server: server, url: url)
        sendHealthRequest()
    }

    public func sendPause() async throws {
        try await sendPlayerAction(path: "remote/pause")
    }

    public func sendPlay() async throws {
        try await sendPlayerAction(path: "remote/player/play")
    }

    public func sendFullscreen() async throws {
        try await sendPlayerAction(path: "remote/player/fullscreen/enter")
    }

    public func sendExitFullscreen() async throws {
        try await sendPlayerAction(path: "remote/player/fullscreen/exit")
    }

    public func forwardTenSeconds() async throws {
        try await sendPlayerAction(path: "remote/player/forwardTenSeconds")
    }

    public func backwardTenSeconds() async throws {
        try await sendPlayerAction(path: "remote/player/backwardTenSeconds")
    }

    public func seek(to time: Double) async throws {
        guard let connectedServer else {
            throw RemoteClientError.cantMakePlayerAction
        }

        var urlRequest = URLRequest(url: connectedServer.url.appending(path: "remote/player/seek"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(time)

        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw RemoteClientError.playRequestFailed(response.statusCode)
        }
    }

    private func sendPlayerAction(path: String) async throws {
        guard let connectedServer else {
            throw RemoteClientError.cantMakePlayerAction
        }
        var request = URLRequest(url: connectedServer.url.appending(path: path))
        request.httpMethod = "POST"
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw RemoteClientError.playerActionFailed(response.statusCode)
        }
    }

    public func sendPlayRequest(
        id: Int,
        name: String,
        mediaType: KTMediaType,
        season: Int? = nil,
        episode: Int? = nil
    ) async throws {
        guard let connectedServer else {
            throw RemoteClientError.cantMakePlayRequest
        }

        let mtype: PlayRequest.MediaType
        switch mediaType {
        case .movie:
            mtype = .movie
        case .tv:
            mtype = .tv
        default:
            throw RemoteClientError.wrongPlayRequestArgument
        }

        let request = PlayRequest(
            id: id,
            name: name,
            mediaType: mtype,
            season: season,
            episode: episode
        )

        var urlRequest = URLRequest(url: connectedServer.url.appending(path: "remote/play"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw RemoteClientError.playRequestFailed(response.statusCode)
        }
    }

    public func sendHealthRequest() {
        guard let connectedServer else {
            self.error = RemoteClientError.cantMakeHealthRequest
            return
        }
        let healthUrl = connectedServer.url.appending(path: "health")

        print("1. Enqueuing:", healthUrl)

        Task {
            print("2. Queue started")

            do {
                let (data, response) = try await URLSession.shared.data(from: healthUrl)

                print("3. Received response:", response)

                guard let response = response as? HTTPURLResponse,
                      response.statusCode == 200
                        else {
                    throw URLError(.badServerResponse)
                }

                print(String(decoding: data, as: UTF8.self))
            } catch {
                print("Request failed:", error)
                /// error here, TODO: Figure out how to send this back
                self.error = error
            }
        }
    }
}

#endif
