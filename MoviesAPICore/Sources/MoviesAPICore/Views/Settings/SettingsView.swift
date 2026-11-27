//
//  SettingsView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI

public struct SettingsView: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(DefaultsManager.self) var defaultsManager
    @Environment(BlockingService.self) var blockingService
#if os(iOS)
    @State private var motionMonitor = SecretMotionManager()
#endif
    @State private var rightUnlocked = false
    @State private var secondaryShowSecretMenu = false
    @State private var rightUnlockTask: Task<Void, Never>?
    @State private var leftUnlockTask: Task<Void, Never>?
    @State private var awaitingRotation = false

    public var body: some View {

        @Bindable var defaultsManager = defaultsManager

        Form {

            AppearanceSettings(defaultsManager: defaultsManager)

            SearchSettings(defaultsManager: defaultsManager)

            NetworkSettings()

#if os(macOS)
            WidgetSettingsView()
#endif

            StorageSettingsView()

#if os(macOS)
            LogSettingsView()
#endif
            AttributionView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
#if os(macOS)
            ToolbarSpacer(.flexible)
#endif
        }
        .formStyle(.grouped)
#if os(macOS)
        .scrollContentBackground(.hidden)
        .background(.clear)
#endif
#if os(iOS)
        .overlay(alignment: .bottomLeading) {
            if rightUnlocked {
                SecretTapButton(requiredTaps: 5) {
                    rightUnlockTask?.cancel()
                    rightUnlocked = false
                    awaitingRotation = true

                    motionMonitor.startMonitoring()

                    leftUnlockTask = Task {
                        try? await Task.sleep(for: .seconds(5))
                        guard !Task.isCancelled else { return }
                        motionMonitor.stopMonitoring()
                        awaitingRotation = false
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            SecretTapButton(requiredTaps: 5) {
                rightUnlockTask?.cancel()
                leftUnlockTask?.cancel()
                rightUnlocked = true

                rightUnlockTask = Task {
                    try? await Task.sleep(for: .seconds(5))
                    guard !Task.isCancelled else { return }

                    rightUnlocked = false
                }
            }
            .disabled(awaitingRotation || rightUnlocked)
        }
        .sheet(isPresented: $secondaryShowSecretMenu) {
            SettingLogsView()
        }
        .onChange(of: motionMonitor.didRotate) { _, completed in
            guard completed, awaitingRotation else { return }

            leftUnlockTask?.cancel()
            motionMonitor.stopMonitoring()

            awaitingRotation = false

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            secondaryShowSecretMenu = true
        }
        .onDisappear {
            rightUnlockTask?.cancel()
            leftUnlockTask?.cancel()

            rightUnlocked = false
            awaitingRotation = false
            motionMonitor.stopMonitoring()
        }
#endif
    }
}

// MARK: - Appearance Settings
struct AppearanceSettings: View {

    @Bindable var defaultsManager: DefaultsManager

    var body: some View {
        Section {
#if os(iOS)
            Toggle("Use Custom Tab Icons", isOn: $defaultsManager.useCustomTabIcons)
                .toggleStyle(.switch)
#endif
            Picker("Season Style", selection: $defaultsManager.seasonPicker) {
                ForEach(SeasonsPicker.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        } header: {
            Label("Appearance", systemImage: "pencil.and.scribble")
        }
    }
}

// MARK: - Search Settings
struct SearchSettings: View {

    @Bindable var defaultsManager: DefaultsManager

    var body: some View {
        Section {
            Toggle("Include Adult Content", isOn: $defaultsManager.includeAdult)
                .toggleStyle(.switch)
        } header: {
            Label("Search Settings", systemImage: "magnifyingglass")
        }
    }
}

// MARK: - Network Settings
struct NetworkSettings: View {

    @Environment(BlockingService.self) var blockingService

    var body: some View {
        Section {
            if blockingService.isNetworkFilteringReady {
                Label("Blocking Ready", systemImage: "checkmark.circle.fill")
            } else {
                ProgressView("Preparing Blocking")
            }
#if os(macOS)
            NavigationLink {
                RemoteServerView()
            } label: {
                Text("Remote Control")
            }
#endif
        } header: {
            Label("Network", systemImage: "network")
        }
    }
}

#if os(macOS)

// MARK: - Widget Settings
struct WidgetSettingsView: View {
    var body: some View {
        Section("Widgets") {
            NavigationLink {
                WidgetFavoriteConfigView()
            } label: {
                Label("Configure Favorites", systemImage: "star.fill")
            }
        }
    }
}
#endif

// MARK: - Storage Settings
struct StorageSettingsView: View {
    var body: some View {
        Section {
            NavigationLink {
                SyncView()
            } label: {
                Label("iCloud", systemImage: "cloud")
            }
#if os(iOS)
            NavigationLink {
                StorageView()
            } label: {
                Text("View Storage Space")
            }
#endif
        } header: {
            Label("Storage", systemImage: "internaldrive")
        }
    }
}

#if os(macOS)

// MARK: - Log Settings
struct LogSettingsView: View {
    var body: some View {
        Section {
            NavigationLink {
                SettingLogsView()
            } label: {
                Text("View")
            }
        } header: {
            Label("Logs", systemImage: "doc.text")
        }
    }
}
#endif

// MARK: - Attribution
struct AttributionView: View {
    var body: some View {
        Section {
            Link(destination: URL(string: "https://www.themoviedb.org")!) {
                Label("The Movie Database (TMDB)", systemImage: "film")
            }

            Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                .foregroundStyle(.secondary)
        } header: {
            Label("Attribution", systemImage: "info.circle")
        }
    }
}
