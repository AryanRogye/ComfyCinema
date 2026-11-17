//
//  RemoteServerResolver.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/17/26.
//

#if os(iOS)

import Foundation

struct ResolvedServer: Hashable, Identifiable {
    let id = UUID()
    let service: NetService
    var hostname: String? {
        if let hostname = service.hostName {
            return hostname.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
        return nil
    }
    var port: Int? { service.port }
}

@Observable
@MainActor
final class RemoteServerResolver: NSObject, @MainActor NetServiceBrowserDelegate, @MainActor NetServiceDelegate {
    private let browser = NetServiceBrowser()

    var discoveredDevices: [ResolvedServer] = []

    override init() {
        super.init()
        browser.delegate = self
        startSearching()
    }

    func startSearching() {
        browser.searchForServices(
            ofType: "_comfycinema._tcp.",
            inDomain: "local."
        )
    }

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        print("Browser: will search")
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        print("Resolved:", sender.name)
        print("Hostname:", sender.hostName ?? "Unknown")
        print("Port:", sender.port)
    }

    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didNotSearch errorDict: [String : NSNumber]
    ) {
        /// -72008 = local network permission denied / missing NSBonjourServices
        print("Browser: DID NOT SEARCH:", errorDict)
    }

    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        service.delegate = self
        discoveredDevices.append(.init(service: service))
        service.resolve(withTimeout: 5)
    }

    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didRemove service: NetService,
        moreComing: Bool
    ) {
        discoveredDevices.removeAll {
            $0.service == service
        }
    }

}

#endif
