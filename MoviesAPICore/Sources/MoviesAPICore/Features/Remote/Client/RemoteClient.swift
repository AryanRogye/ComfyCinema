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

    var errorDescription: String? {
        switch self {
        case .cantMakeHealthRequest:
            "Cant Make Health Request"
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
