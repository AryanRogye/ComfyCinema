//
//  TVDetailMenubarController.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/6/26.
//

/// MenuBar shows up on TVDetailView only on macOS
#if os(macOS)

import AppKit
import SwiftUI

@MainActor
final class TVDetailMenubarController: NSObject {

    private var windowContainer: WindowCoordinatorContainer?

    private var onIFrameLogs: Binding<[String]>?
    private var onVideoFrameLogs: Binding<[String]>?
    private var onNavigationLogs: Binding<[String]>?

    private var debugMenuItem: NSMenuItem?

    private let windowID = UUID().uuidString

    override init() {
        super.init()
    }

    public func assignLogs(
        iFrame: Binding<[String]>,
        videoFrame: Binding<[String]>,
        navigation: Binding<[String]>
    ) {
        onIFrameLogs = iFrame
        onVideoFrameLogs = videoFrame
        onNavigationLogs = navigation
    }

    public func assignWindowContainer(_ windowContainer: WindowCoordinatorContainer) {
        self.windowContainer = windowContainer
    }

    @objc private func showLogs() {

        guard let onIFrameLogs else { return }
        guard let onVideoFrameLogs else { return }
        guard let onNavigationLogs else { return }

        windowContainer?.windowCoordinator.showWindow(
            id: windowID,
            title: "Logs",
            content: NavigationStack {
                IFrameLogsView(
                    logs: onIFrameLogs,
                    videoLogs: onVideoFrameLogs,
                    navigationLogs: onNavigationLogs
                )
            }
        )
    }

    public func attachMenubarItems() {
        guard debugMenuItem == nil else { return }

        let menuItem = NSMenuItem(
            title: "Debug",
            action: nil,
            keyEquivalent: ""
        )

        let menu = NSMenu(title: "Debug")

        let logs = NSMenuItem(
            title: "Logs",
            action: #selector(showLogs),
            keyEquivalent: ""
        )

        logs.target = self

        menu.addItem(logs)
        menuItem.submenu = menu

        NSApp.mainMenu?.addItem(menuItem)

        debugMenuItem = menuItem
    }

    public func removeMenubarItems() {
        guard let debugMenuItem else {
            print("NO DEBUG MENU ITEM")
            return
        }

        guard let mainMenu = NSApp.mainMenu else {
            print("NO MAIN MENU")
            return
        }

        print("BEFORE:", mainMenu.items.map(\.title))

        if let index = mainMenu.items.firstIndex(where: { $0 === debugMenuItem }) {
            print("FOUND AT INDEX:", index)

            mainMenu.removeItem(at: index)

            print("AFTER:", mainMenu.items.map(\.title))
        } else {
            print("STORED ITEM IS NOT IN MAIN MENU")
        }

        self.debugMenuItem = nil
    }
}
#endif
