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

    public func matches(with stored: StoredServer) -> Bool {
        return service.name == stored.name &&
        hostname == stored.hostname &&
        port == stored.port
    }
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
//
//    func netServiceBrowser(
//        _ browser: NetServiceBrowser,
//        didNotSearch errorDict: [String : NSNumber]
//    ) {
//        /// -72008 = local network permission denied / missing NSBonjourServices
//        print("Browser: DID NOT SEARCH:", errorDict)
//    }

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

    /// hostname/port are only available after resolution, but `discoveredDevices`
    /// is appended to in `didFind`. Re-assign the entry so observers (e.g. Always
    /// Connect) re-check it now that its address is known.
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let index = discoveredDevices.firstIndex(where: { $0.service == sender }) else {
            return
        }
        discoveredDevices[index] = discoveredDevices[index]
    }

}

#endif
