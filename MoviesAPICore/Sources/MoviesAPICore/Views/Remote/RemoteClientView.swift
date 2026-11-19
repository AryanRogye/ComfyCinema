//
//  RemoteClientView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/17/26.
//

#if os(iOS)
import SwiftUI

// MARK: - Helpers

private extension View {
    /// Flat, solid card used by every section.
    func remoteSurface(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 20, style: .continuous))
    }
}

private struct RemotePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - View

struct RemoteClientView: View {

    /// Parameters
    var result: KTSearchResult? = nil
    var season: Int? = nil
    var episode: Int? = nil

    @Environment(RemoteClient.self) private var remoteClient

    @State private var error: String?

    /// Action Related
    @State private var isSending = false
    @State private var sent = false

    @State private var seconds: String = ""
    @FocusState private var isSeekFocused: Bool

    /// Volume Related
    @State private var currentVolume: Float?
    @State private var volumeTask: Task<Void, Never>?

    /// Display Server Related
    @State private var currentServer: KTDisplayServer?

    private let secondaryText = Color.white.opacity(0.6)
    private let controlFill = Color.white.opacity(0.07)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                if let error {
                    errorBanner(error)
                }

                if let connectedServer = remoteClient.connectedServer {
                    VStack(spacing: 12) {
                        deviceHeader(connectedServer)
                        playbackControls
                        seekRow
                        displayServerRow
                        if result != nil {
                            playRequestRow
                        }
                        if currentVolume != nil {
                            volumeRow
                        }
                    }
                    .onAppear {
                        volumeTask = Task {
                            do {
                                currentVolume = try await remoteClient.getVolume()
                            } catch {
                                self.error = error.localizedDescription
                            }
                        }
                    }
                } else {
                    emptyState
                }
            }
            .disabled(isSending)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .animation(.default, value: error)
        .animation(.default, value: currentVolume == nil)
        /// Runs every time the view appears (and again if the connected device
        /// changes), since the display server can be changed on the remote at any time.
        .task(id: remoteClient.connectedServer?.url) {
            await refreshDisplayServer()
        }
    }

    // MARK: Sections

    private func deviceHeader(_ connected: ConnectedServer) -> some View {
        HStack(spacing: 14) {
            Image("MacBookPro", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(connected.server.service.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 7, height: 7)
                    Text("Connected")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }
            }

            Spacer(minLength: 0)
        }
        .remoteSurface()
    }

    private var playbackControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                skipButton("gobackward.10", label: "Back 10 seconds") {
                    run { try await remoteClient.backwardTenSeconds() }
                }

                Button {
                    run { try await remoteClient.sendPlay() }
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(Color.yellow, in: .rect(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(RemotePressStyle())
                .accessibilityLabel("Play")

                skipButton("goforward.10", label: "Forward 10 seconds") {
                    run { try await remoteClient.forwardTenSeconds() }
                }
            }

            HStack(spacing: 10) {
                secondaryButton("pause.fill", title: "Pause") {
                    run { try await remoteClient.sendPause() }
                }
                secondaryButton("arrow.up.left.and.arrow.down.right", title: "Fullscreen") {
                    run { try await remoteClient.sendFullscreen() }
                }
                secondaryButton("arrow.down.right.and.arrow.up.left", title: "Exit") {
                    run { try await remoteClient.sendExitFullscreen() }
                }
            }
        }
        .remoteSurface()
    }

    private var seekRow: some View {
        let isValid = Self.parseTime(seconds) != nil

        return HStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(secondaryText)

            Text("Seek to")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)

            Spacer()

            TextField(
                "",
                text: $seconds,
                prompt: Text("0:00").foregroundStyle(.white.opacity(0.3))
            )
            .focused($isSeekFocused)
            .font(.system(.body, design: .rounded).monospacedDigit())
            .foregroundStyle(.white)
            .keyboardType(.numbersAndPunctuation)
            .submitLabel(.go)
            .onSubmit(seek)
            .multilineTextAlignment(.center)
            .frame(width: 96)
            .padding(.vertical, 8)
            .background(controlFill, in: .rect(cornerRadius: 10, style: .continuous))

            Button(action: seek) {
                Text("Go")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.yellow, in: .rect(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(RemotePressStyle())
            .disabled(!isValid)
            .opacity(isValid ? 1 : 0.35)
        }
        .remoteSurface(padding: 12)
    }

    private var displayServerRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "server.rack")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(secondaryText)

            Text("Display Server")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)

            Spacer()

            Menu {
                ForEach(KTDisplayServer.entries, id: \.self) { server in
                    Button {
                        setDisplayServer(server)
                    } label: {
                        if currentServer == server {
                            Label(server.rawValue, systemImage: "checkmark")
                        } else {
                            Text(server.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(currentServer?.rawValue ?? "Not set")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.yellow)
            }
            .tint(.yellow)
        }
        .remoteSurface(padding: 14)
    }

    private var playRequestRow: some View {
        Button {
            guard let result else { return }
            run {
                try await remoteClient.sendPlayRequest(
                    id: Int(result.id),
                    name: result.name ?? result.title ?? "",
                    mediaType: result.mediaType,
                    season: season,
                    episode: episode
                )
                sent = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    sent = false
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: sent ? "checkmark.circle.fill" : "airplayvideo")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(sent ? Color.green : Color.yellow)
                    .frame(width: 24)

                Text(sent ? "Request Sent" : "Send Play Request")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .remoteSurface(padding: 14)
            .contentShape(.rect)
        }
        .buttonStyle(RemotePressStyle())
    }

    private var volumeRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.footnote)
                .foregroundStyle(secondaryText)

            Slider(
                value: Binding(
                    get: { currentVolume ?? 0 },
                    set: { currentVolume = $0 }
                ),
                in: 0...1,
                step: 0.1,
                onEditingChanged: { isEditing in
                    guard !isEditing, let volume = currentVolume else { return }
                    // User finished dragging: send volume to the remote server.
                    volumeTask?.cancel()
                    volumeTask = Task {
                        do {
                            try await remoteClient.setVolume(to: volume)
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
            )
            .tint(.yellow)

            Image(systemName: "speaker.wave.3.fill")
                .font(.footnote)
                .foregroundStyle(secondaryText)
        }
        .remoteSurface(padding: 14)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(secondaryText)
                .padding(.bottom, 4)

            Text("No Server Connected")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Open Settings and pick a device to control playback.")
                .font(.footnote)
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
        }
        .remoteSurface(padding: 28)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                error = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .accessibilityLabel("Dismiss error")
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.14), in: .rect(cornerRadius: 16, style: .continuous))
    }

    // MARK: Buttons

    private func skipButton(
        _ symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 76, height: 64)
                .background(controlFill, in: .rect(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(RemotePressStyle())
        .accessibilityLabel(label)
    }

    private func secondaryButton(
        _ symbol: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(controlFill, in: .rect(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(RemotePressStyle())
    }

    // MARK: Actions

    private func seek() {
        // Invalid input does nothing.
        guard let time = Self.parseTime(seconds) else { return }
        isSeekFocused = false
        run { try await remoteClient.seek(to: time) }
    }

    /// Accepts plain seconds ("90", "75.5") or clock style ("1:30", "1:02:03").
    static func parseTime(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count <= 3 else { return nil }
        var total = 0.0
        for part in parts {
            guard let value = Double(part), value.isFinite, value >= 0 else { return nil }
            total = total * 60 + value
        }
        return total
    }

    private func refreshDisplayServer() async {
        guard remoteClient.connectedServer != nil else {
            currentServer = nil
            return
        }
        do {
            let server = try await remoteClient.getServer()
            if !Task.isCancelled { currentServer = server }
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }

    private func setDisplayServer(_ server: KTDisplayServer) {
        run {
            try await remoteClient.setServer(entry: server)
            currentServer = server
        }
    }

    /// Light haptic, then send.
    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        sendAction(action)
    }

    private func sendAction(_ action: @escaping @MainActor () async throws -> Void) {
        isSending = true
        error = nil
        sent = false
        Task {
            defer { isSending = false }
            do {
                try await action()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

#endif
