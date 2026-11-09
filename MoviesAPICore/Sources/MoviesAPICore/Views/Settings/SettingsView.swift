//
//  SettingsView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI

public struct SettingsView: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(DefaultManager.self) var defaultManager
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

        @Bindable var defaultManager = defaultManager

        Form {
            Section {
                Toggle("Include Adult Content", isOn: $defaultManager.includeAdult)
                    .toggleStyle(.switch)
            } header: {
                Label("Search Settings", systemImage: "magnifyingglass")
            }

            Section {
                if blockingService.isNetworkFilteringReady {
                    Label("Blocking Ready", systemImage: "checkmark.circle.fill")
                } else {
                    ProgressView("Preparing Blocking")
                }
            } header: {
                Label("Network", systemImage: "network")
            }

            Section {
                NavigationLink {
                    SyncView()
                } label: {
                    Label("Configuration", systemImage: "doc")
                }
            } header: {
                Label("iCloud", systemImage: "cloud")
            }

#if os(iOS)
            NavigationLink {
                StorageView()
            } label: {
                Label("Storage", systemImage: "internaldrive")
            }
#endif

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

#if os(iOS)
#endif
}
