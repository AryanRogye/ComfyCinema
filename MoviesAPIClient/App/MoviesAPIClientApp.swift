//
//  MoviesAPIClientApp.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import SwiftData
import MoviesAPICore
import AppIntents

struct ComfyCinemaIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [MoviesCoreIntentsPackage.self]
    }
}

@main
struct MoviesAPIClientApp: App {

    @State private var appRouter: AppRouter

#if os(iOS)
    private let modelContainer: ModelContainer
#endif

#if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif

    init() {
        do {
            let schema = Schema(versionedSchema: MoviesSchemaV2.self)
            let container = try ModelContainer(for: schema)
            AppDependencyManager.shared.add(dependency: container)
            self.modelContainer = container
        } catch {
            fatalError("Could not create model container: \(error)")
        }
        let appRouter = AppRouter()
        AppDependencyManager.shared.add(dependency: appRouter)
        _appRouter = State(initialValue: appRouter)
    }

    var body: some Scene {
#if os(iOS)
        WindowGroup {
            Root(appRouter: appRouter)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
#elseif os(macOS)
        WindowGroup { EmptyView().destroyViewWindow() }
#endif
    }
}
