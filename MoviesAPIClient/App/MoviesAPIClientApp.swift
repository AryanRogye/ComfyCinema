//
//  MoviesAPIClientApp.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import SwiftData
import MoviesAPICore
import MoviesAPIData
import AppIntents

struct ComfyCinemaIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [MoviesCoreIntentsPackage.self]
    }
}

@main
struct MoviesAPIClientApp: App {

#if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif

#if os(iOS)

    @State private var appRouter: AppRouter
    private let modelContainer: ModelContainer
    private let cloudKitSync: CloudKitSyncService

    init() {
        do {

            guard let identifier = Bundle.main.object(
                forInfoDictionaryKey: "AppGroup"
            ) as? String else {
                fatalError("AppGroup not found")
            }
            if identifier.isEmpty {
                fatalError("AppGroup Empty")
            }


            let schema = Schema(versionedSchema: MoviesSchemaV2.self)
            let configuration = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(
                    identifier
                ),
                cloudKitDatabase: .none,
            )
            let container = try ModelContainer(for: schema, configurations: configuration)
            AppDependencyManager.shared.add(dependency: container)
            self.modelContainer = container
            self.cloudKitSync = .init(
                modelContainer: container,
                cloudKitManager: try CloudKitManager()
            )
        } catch {
            fatalError("Could not create model container: \(error)")
        }
        let appRouter = AppRouter()
        AppDependencyManager.shared.add(dependency: appRouter)
        _appRouter = State(initialValue: appRouter)
    }
#endif

    var body: some Scene {
#if os(iOS)
        WindowGroup {
            Root(appRouter: appRouter, cloudKitSync: cloudKitSync)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    guard url.scheme == "comfycinema",
                          url.host == "watch" else {
                        return
                    }
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

                    self.appRouter.clickedWidgetWithResultID = idString
                    self.appRouter.selectedTab = .history
                }
        }
        .modelContainer(modelContainer)
#elseif os(macOS)
        WindowGroup {
            EmptyView()
                .destroyViewWindow()
                .onOpenURL { url in
                    appDelegate.appOpenedWithUrl(url)
                }
        }
#endif
    }
}
