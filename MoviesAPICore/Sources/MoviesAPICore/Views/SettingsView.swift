//
//  SettingsView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI

@Observable
@MainActor
final class SettingLogs {
    static let shared = SettingLogs()
    var logs: [String] = []

    public func add(_ value: Any) {
        logs.append(String(describing: value))
        if logs.count > 1000 { logs.removeFirst(logs.count - 1000) }
    }
}

public struct SettingsView: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(BlockingService.self) var blockingService

    public init() {}

#if os(iOS)
    @State private var motionMonitor = SecretMotionManager()
#endif
    @State private var rightUnlocked = false
    @State private var secondaryShowSecretMenu = false
    @State private var rightUnlockTask: Task<Void, Never>?
    @State private var leftUnlockTask: Task<Void, Never>?
    @State private var awaitingRotation = false

    public var body: some View {

        @Bindable var tmdbManager = tmdbManager

        Form {
            Section {
                Toggle("Include Adult Content", isOn: $tmdbManager.includeAdult)
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

#if os(iOS)
private struct SecretTapButton: View {
    let requiredTaps: Int
    let action: () -> Void

    @State private var tapCount = 0
    @State private var resetTask: Task<Void, Never>?
    @State private var highlightTask: Task<Void, Never>?
    @State private var isHighlighted = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light)
                .impactOccurred()

            tapCount += 1
            isHighlighted = true

            resetTask?.cancel()
            highlightTask?.cancel()

            if tapCount >= requiredTaps {
                tapCount = 0
                action()
            } else {
                resetTask = Task {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    tapCount = 0
                }
            }

            highlightTask = Task {
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                isHighlighted = false
            }
        } label: {
            Rectangle()
                .fill(isHighlighted ? .primary.opacity(0.1) : Color.clear)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(8)
        .onDisappear {
            resetTask?.cancel()
            highlightTask?.cancel()
        }
    }
}
#endif

#if os(iOS)
private struct SettingLogsView: View {
    @Bindable var logs = SettingLogs.shared

    var body: some View {
        NavigationStack {
            Group {
                if logs.logs.isEmpty {
                    ContentUnavailableView(
                        "No Logs",
                        systemImage: "text.alignleft",
                        description: Text("Logs will appear here as events occur.")
                    )
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(logs.logs.enumerated()), id: \.offset) { index, log in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text("\(index + 1)")
                                            .foregroundStyle(.tertiary)
                                            .frame(width: 30, alignment: .trailing)

                                        Text(log)
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .textSelection(.enabled)
                                    }
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.vertical, 4)
                                    .id(index)
                                }
                            }
                            .padding()
                        }
                        .onChange(of: logs.logs.count) {
                            if !logs.logs.isEmpty {
                                withAnimation {
                                    proxy.scrollTo(logs.logs.count - 1, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Developer Logs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            UIPasteboard.general.string =
                            logs.logs.joined(separator: "\n")
                        } label: {
                            Label("Copy All", systemImage: "doc.on.doc")
                        }

                        Button(role: .destructive) {
                            logs.logs.removeAll()
                        } label: {
                            Label("Clear Logs", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(logs.logs.isEmpty)
                }
            }
        }
    }
}

import CoreMotion

@MainActor
@Observable
final class SecretMotionManager {
    private let motionManager = CMMotionManager()

    private(set) var didRotate = false
    private var wasUpsideDown = false

    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else { return }

        didRotate = false
        wasUpsideDown = false

        motionManager.deviceMotionUpdateInterval = 0.1

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self, let motion else { return }

            let gravity = motion.gravity

            // Portrait upside down
            if gravity.y > 0.85 {
                self.wasUpsideDown = true
            }

            // Returned to normal portrait
            if self.wasUpsideDown && gravity.y < -0.85 {
                self.didRotate = true
                self.stopMonitoring()
            }
        }
    }

    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
    }
}
#endif
