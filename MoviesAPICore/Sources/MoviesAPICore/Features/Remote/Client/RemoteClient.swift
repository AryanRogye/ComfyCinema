//
//  RemoteClient.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/16/26.
//

#if os(iOS)

import Foundation

@Observable
@MainActor
final class RemoteClient: NSObject, NetServiceBrowserDelegate {
    private let browser = NetServiceBrowser()

    var discoveredDevices: [NetService] = []

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
        discoveredDevices.append(service)
        print("Found:", service.name)
    }

    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didRemove service: NetService,
        moreComing: Bool
    ) {
        discoveredDevices.removeAll {
            $0 == service
        }
    }

}

#endif
