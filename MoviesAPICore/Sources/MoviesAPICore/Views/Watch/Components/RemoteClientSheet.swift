//
//  RemoteClientSheet.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/17/26.
//

#if os(iOS)
import SwiftUI

struct RemoteClientSheet: View {

    @Environment(RemoteClient.self) private var remoteClient
    @State private var error: String?
    @State private var isSending = false
    @State private var sent = false

    let result: KTSearchResult
    var season: Int? = nil
    var episode: Int? = nil

    @State private var seconds: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {

                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 28)
                                .fill(Color(white: 0.12))
                        }
                }
                if let connectedServer = remoteClient.connectedServer {
                    /// Top Row
                    HStack(alignment: .center) {
                        Image("MacBookPro", bundle: .module)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 110, height: 50)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(connectedServer.server.hostname ?? "Unknown")
                                .font(
                                    .system(
                                        size: 16,
                                        weight: .semibold,
                                        design: .rounded
                                    )
                                )
                                .foregroundStyle(.white)

                            HStack {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 7, height: 7)

                                Text("Available")
                                    .font(
                                        .system(
                                            size: 14,
                                            weight: .medium,
                                            design: .rounded
                                        )
                                    )
                                    .foregroundStyle(.white.opacity(0.6))

                                Spacer()
                            }
                        }
                    }
                    .padding(8)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color(white: 0.12))
                    }

                    VStack(spacing: 22) {
                        HStack(spacing: 14) {
                            remoteButton("gobackward.10") {
                                /// Back 10 seconds
                                sendAction { try await remoteClient.backwardTenSeconds() }
                            }

                            remoteButton(
                                "play.fill",
                                size: 34,
                                highlighted: true
                            ) {
                                /// Play
                                sendAction { try await remoteClient.sendPlay() }
                            }

                            remoteButton("goforward.10") {
                                /// Forward 10 seconds
                                sendAction { try await remoteClient.forwardTenSeconds() }
                            }
                        }

                        Rectangle()
                            .fill(.white.opacity(0.12))
                            .frame(height: 1)

                        HStack(spacing: 14) {
                            remoteButton("pause.fill") {
                                /// Pause
                                sendAction { try await remoteClient.sendPause() }
                            }

                            remoteButton(
                                "arrow.up.left.and.arrow.down.right",
                                size: 25
                            ) {
                                /// Enter fullscreen
                                sendAction { try await remoteClient.sendFullscreen() }
                            }

                            remoteButton(
                                "arrow.down.right.and.arrow.up.left",
                                size: 25
                            ) {
                                /// Exit fullscreen
                                sendAction { try await remoteClient.sendExitFullscreen() }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color(white: 0.12))
                    }

                    HStack(alignment: .center) {
                        Image(systemName: "clock")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)

                        Text("Seek to Time")
                            .foregroundStyle(.white)
                            .fontWeight(.medium)

                        Spacer()

                        TextField(
                            "mm:ss",
                            text: $seconds,
                            prompt: Text("mm:ss")
                                .foregroundStyle(.gray.opacity(0.4))
                        )
                        .foregroundStyle(.white)
                        .keyboardType(.numbersAndPunctuation)
                        .submitLabel(.go)
                        .onSubmit(seek)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .padding(6)
                        .frame(width: 100)
                        .background(
                            .blue.mix(with: .black, by: 0.9),
                            in: .rect(cornerRadius: 12)
                        )
                        Button(action: seek) {
                            Text("Go")
                                .fontWeight(.bold)
                                .foregroundStyle(.black)
                                .padding(6)
                                .padding(.horizontal, 4)
                                .background(
                                    .yellow,
                                    in: .rect(cornerRadius: 12)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(Self.parseTime(seconds) == nil)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color(white: 0.12))
                    }

                    Button {
                        sendAction {
                            try await remoteClient.sendPlayRequest(
                                id: Int(result.id),
                                name: result.name ?? result.title ?? "",
                                mediaType: result.mediaType,
                                season: season,
                                episode: episode
                            )
                            sent = true
                        }
                    } label: {
                        HStack(alignment: .center) {
                            Image(systemName: "airplayvideo")
                                .foregroundStyle(.yellow)
                                .fontWeight(.bold)

                            Text("Send Play Request")
                                .foregroundStyle(.white)
                                .fontWeight(.medium)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.gray)
                                .fontWeight(.bold)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 28)
                                .fill(Color(white: 0.12))
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.yellow)
                            .frame(width: 76, height: 76)
                            .background(
                                .yellow.opacity(0.12),
                                in: .rect(cornerRadius: 22)
                            )

                        Text("No Server Connected")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Open Settings and pick a device to start controlling playback.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color(white: 0.12))
                    }
                }
            }
            .disabled(isSending)
            .padding()
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .top
            )
        }
    }

    private func remoteButton(
        _ symbol: String,
        size: CGFloat = 28,
        highlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(highlighted ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 76)
                .background {
                    if highlighted {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .yellow.mix(with: .white, by: 0.35),
                                        .yellow
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(.white.opacity(0.06))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func seek() {
        // Invalid input does nothing.
        guard let time = Self.parseTime(seconds) else { return }
        sendAction { try await remoteClient.seek(to: time) }
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
