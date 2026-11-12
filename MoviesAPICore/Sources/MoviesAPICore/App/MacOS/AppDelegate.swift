#if os(macOS)
//
//  AppDelegate.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/18/26.
//

import AppKit
import AppIntents
import SwiftData
import MoviesAPIData

public class AppDelegate: NSObject, NSApplicationDelegate {

    private enum WidgetRoute {
        case history(String)
        case favorite(Int)
    }

    var appCoordinator: AppCoordinator?
    private var pendingWidgetRoute: WidgetRoute?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        guard !ProcessInfo.isSwiftUIPreview else { return }

        do {
            appCoordinator = try AppCoordinator()
            openPendingWidgetRoute()
        } catch {
            fatalError("Cant Load iCloud Config")
        }
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        appCoordinator?.openApp()
        return true
    }

    @MainActor
    public func applicationShouldTerminate(
        _ sender: NSApplication
    ) -> NSApplication.TerminateReply {
        Task {
            do {
                try await appCoordinator?.cloudKitSync.saveToCloud()
            } catch {
                print("CloudKit sync failed during termination:", error)
            }

            sender.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }

    public func applicationWillTerminate(_ notification: Notification) {
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        Task {
            do {
                try await appCoordinator?.cloudKitSync.saveToCloud()
            } catch {
                print("CloudKit sync failed during termination:", error)
            }
        }
        return false
    }

    public func application(
        _ application: NSApplication,
        open urls: [URL]
    ) {
        for url in urls {
            appOpenedWithUrl(url)
        }
    }

    @MainActor
    public func appOpenedWithUrl(_ url: URL) {
        SettingLogs.shared.add("Triggered OpenURL: \(url)")
        guard url.scheme == "comfycinema" else { return }
        let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )
        guard let idString = components?
            .queryItems?
            .first(where: { $0.name == "id" })?
            .value else {
            return
        }

        switch url.host {
        case "watch":
            pendingWidgetRoute = .history(idString)
        case "favorite":
            guard let id = Int(idString) else { return }
            pendingWidgetRoute = .favorite(id)
        default:
            return
        }
        openPendingWidgetRoute()
    }

    @MainActor
    private func openPendingWidgetRoute() {
        guard let appCoordinator, let route = pendingWidgetRoute else { return }
        pendingWidgetRoute = nil
        switch route {
        case .history(let id):
            appCoordinator.appRouter.clickedWidgetWithResultID = id
            SettingLogs.shared.add("Opened From Widget: \(id)")
        case .favorite(let id):
            appCoordinator.appRouter.clickedWidgetWithFavoriteID = id
            SettingLogs.shared.add("Opened Favorite From Widget: \(id)")
        }
        appCoordinator.openApp()
    }
}

@Observable
@MainActor
final class WindowCoordinatorContainer {
    let windowCoordinator = WindowCoordinator()
}

@MainActor
class AppCoordinator {

    let windowContainer = WindowCoordinatorContainer()
    let cloudKitSync: CloudKitSyncService
    let appRouter = AppRouter()

    private let modelContainer: ModelContainer = {
        do {

            guard let identifier = Bundle.main.object(
                forInfoDictionaryKey: "AppGroup"
            ) as? String else {
                fatalError("AppGroup not found")
            }
            if identifier.isEmpty {
                fatalError("AppGroup Empty")
            }

            let schema = Schema(versionedSchema: MoviesSchemaV3.self)
            let configuration = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(identifier),
                cloudKitDatabase: .none
            )
            return try ModelContainer(
                for: schema,
                migrationPlan: MoviesMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("Could not create model container: \(error)")
        }
    }()

    init() throws {
        cloudKitSync = .init(
            modelContainer: modelContainer,
            cloudKitManager: try CloudKitManager()
        )
        AppDependencyManager.shared.add(dependency: self.appRouter)
        AppDependencyManager.shared.add(dependency: self.modelContainer)
        openApp()
    }

    let appID = UUID().uuidString

    public func openApp() {

        let targetScreen = AppCoordinator.screenUnderMouse() ?? NSScreen.main

        let size: NSSize
        if let targetScreen {
            size = .init(width: targetScreen.visibleFrame.width - 100, height: targetScreen.visibleFrame.height - 100)
        } else {
            size = .init(width: 500, height: 500)
        }

        let window = windowContainer.windowCoordinator.showWindow(
            id: appID,
            title: "ComfyCinema",
            content: MacOSRoot(windowContainer: windowContainer, appRouter: appRouter, cloudKitSync: cloudKitSync)
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark),
            size: size,
            isMiniaturizable: true,
            alwaysActiveFocusedLook: true
        )

        if let targetScreen {
            let frame = targetScreen.visibleFrame
            window.setFrameOrigin(CGPoint(
                x: frame.midX - window.frame.width / 2,
                y: frame.midY - window.frame.height / 2
            ))
        }

    }

    /**
     * Grab the screen under the mouse
     */
    public nonisolated static func screenUnderMouse() -> NSScreen? {
        let loc = NSEvent.mouseLocation
        return NSScreen.screens.first {
            NSMouseInRect(loc, $0.frame, false)
        }
    }
}

#endif
