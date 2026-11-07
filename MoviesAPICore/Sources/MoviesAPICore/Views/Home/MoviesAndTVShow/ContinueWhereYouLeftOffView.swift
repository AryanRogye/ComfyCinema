//
//  ContinueWhereYouLeftOffView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/5/26.
//

import SwiftUI
import SwiftData

struct ContinueWhereYouLeftOffView: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(PlaybackSession.self) private var playbackSession
    @AppStorage("DisplayServer") private var displayServerRawValue = KTDisplayServer.moviesApi.rawValue

    private var displayServerBinding: Binding<KTDisplayServer> {
        Binding(
            get: { KTDisplayServer.entries.first { $0.rawValue == displayServerRawValue } ?? .moviesApi },
            set: { displayServerRawValue = $0.rawValue }
        )
    }

    @Query(sort: \History.watchedAt, order: .reverse)
    private var history: [History]

    @State private var searchResult: KTSearchResult?
    @State private var resolveTask: Task<Void, Never>?
    @State private var selectedHistory: History?
    @State private var resolvingHistory: History?
    @State private var isResolving: Bool = false
    @State private var goToDetail: Bool = false

    @State private var error: String?
    @State private var showError: Bool = false

    var body: some View {
        if !history.isEmpty {
            let uniqueHistory = Array(
                history.reduce(into: [History]()) { result, item in
                    guard !result.contains(where: { $0.resultId == item.resultId && $0.mediaType == item.mediaType }) else {
                        return
                    }
                    result.append(item)
                }
                    .prefix(5)
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("Continue Watching", bundle: .module)
                    .font(.title2.bold())
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 20) {
                        ForEach(uniqueHistory, id: \.id) { item in
                            Button {
                                resolve(item)
                            } label: {
                                ContinueRow(
                                    history: item,
                                    isResolving: resolvingHistory?.id == item.id
                                )
                            }
                            .buttonStyle(ContinueCardButtonStyle())
                            .disabled(isResolving)
                            .accessibilityLabel(Text("Resume \(item.name)", bundle: .module))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .scrollClipDisabled()
            }
            .navigationDestination(isPresented: $goToDetail) {
                if let searchResult, let selectedHistory {
                    if selectedHistory.mediaType == .episode,
                       let season = selectedHistory.season,
                       let episode = selectedHistory.episode {
                        TVDetailView(
                            displayServer: displayServerBinding,
                            result: searchResult,
                            seasonNumber: season,
                            episodeNumber: episode
                        )
                    } else {
                        WatchDetailView(result: searchResult)
                    }
                }
            }
            .alert("Unable to Resume", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error ?? "Please try again.")
            }
            .onDisappear {
                resolveTask?.cancel()
            }
        }
    }

    private func resolve(_ history: History) {
        if isResolving { return }

        resolvingHistory = history
        isResolving = true
        resolveTask = Task {

            defer {
                isResolving = false
                resolvingHistory = nil
            }

            do {
                try await tmdbManager.search(history.name)

                try Task.checkCancellation()
                let mediaType: KTMediaType = history.mediaType == .movie ? .movie : .tv
                if let result = tmdbManager.searchResults.first(
                    where: { $0.id == history.resultId && $0.mediaType == mediaType }
                ) {
                    playbackSession.stop()
                    searchResult = result
                    selectedHistory = history
                    goToDetail = true
                } else {
                    error = "This title could not be found. Please try again."
                    showError = true
                }

                tmdbManager.clearSearchResults()
            } catch is CancellationError {
                return
            } catch {
                self.error = error.localizedDescription
                showError = true
            }
        }
    }

}


private struct ContinueRow: View {
    let history: History
    var isResolving = false

#if os(macOS)
    private let cardWidth: CGFloat = 320
#else
    private let cardWidth: CGFloat = 280
#endif

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ContinueArtwork(
                resultID: history.resultId,
                mediaType: history.mediaType,
                imagePath: history.backdropPath ?? history.posterPath,
                watchedAt: history.watchedAt
            )
            .frame(width: cardWidth, height: cardWidth * 9 / 16)
            .clipped()
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .center, endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(.white)
                        if isResolving {
                            ProgressView()
                                .controlSize(.small)
                                .environment(\.colorScheme, .light)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.body.weight(.bold))
                                .foregroundStyle(.black)
                                .offset(x: 1)
                        }
                    }
                    .frame(width: 36, height: 36)

                    Spacer(minLength: 0)

                    if let seconds = history.lastStoppedAt, seconds.isFinite, seconds > 0 {
                        Text(Duration.seconds(seconds), format: .time(pattern: .hourMinuteSecond))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.55), in: Capsule())
                    }
                }
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(history.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if history.mediaType == .episode,
                   let season = history.season, let episode = history.episode {
                    Text("Season \(season) · Episode \(episode)", bundle: .module)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Movie", bundle: .module)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(width: cardWidth, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

private struct ContinueArtwork: View {
    let resultID: Int
    let mediaType: HistoryMediaType
    let imagePath: String?
    let watchedAt: Date
    @State private var snapshot: SystemImage?

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            Image(systemName: "play.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            if let snapshot {
#if os(macOS)
                Image(nsImage: snapshot).resizable().scaledToFill()
#else
                Image(uiImage: snapshot).resizable().scaledToFill()
#endif
            } else if let imagePath,
                      let url = URL(string: "https://image.tmdb.org/t/p/w780\(imagePath)") {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    }
                }
            }
        }
        .accessibilityHidden(true)
        .task(id: "\(mediaType)-\(resultID)-\(watchedAt.timeIntervalSince1970)") {
            snapshot = nil
            if let data = ContentImageStore.load(
                forID: Int32(resultID),
                mediaType: mediaType == .movie ? .movie : .tv
            ) {
                snapshot = SystemImage(data: data)
            }
        }
    }
}

private struct ContinueCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .smooth(duration: 0.15), value: configuration.isPressed)
    }
}
