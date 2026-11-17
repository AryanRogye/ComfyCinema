//
//  RemoteServer.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/16/26.
//

#if os(macOS)

import Hummingbird
import Foundation

@Observable
final class RemoteServer: NSObject, NetServiceDelegate {

    var startServerTask: Task<Void, Never>?
    var stopServerTask : Task<Void, Never>?

    var discoveryService: NetService

    var applicationServer: Application<RouterResponder<BasicRequestContext>>?

    var error: String?

    override init() {
        /// publish locally
        discoveryService = NetService(
            domain: "local.",
            type: "_comfycinema._tcp.",
            name: Host.current().localizedName ?? "ComfyCinema",
            port: 8082
        )
        super.init()

        discoveryService.delegate = self
        discoveryService.publish()
        startServer()
    }

    func netServiceDidPublish(_ sender: NetService) {
        print("Bonjour published:", sender.name)
    }

    func netService(
        _ sender: NetService,
        didNotPublish errorDict: [String: NSNumber]
    ) {
        print("Bonjour failed:", errorDict)
    }

    public func startServer() {
        guard startServerTask == nil else { return }
        let router = Router()

        router.get("/health") { request, context in
            return "ComfyCinema Remote Server"
        }

        router.post("/remote/pause") { request, context in
            return "Pause requested"
        }

        applicationServer = Application(
            router: router,
            configuration: .init(address: .hostname("0.0.0.0", port: 8082))
        )

        guard let applicationServer else { return }

        startServerTask = Task {
            do {
                try await applicationServer.runService()
            } catch {
                self.error = "HTTP server failed: \(String(reflecting: error))"
            }
        }
    }

    public func stopServer() {
        let runningTask = startServerTask

        startServerTask = nil
        runningTask?.cancel()

        stopServerTask = Task {
            await runningTask?.value
        }
    }
}

#endif
