//
//  SecretTapButton.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/3/26.
//

import SwiftUI

#if os(iOS)
struct SecretTapButton: View {
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
struct SettingLogsView: View {
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
                            logs.clear()
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
