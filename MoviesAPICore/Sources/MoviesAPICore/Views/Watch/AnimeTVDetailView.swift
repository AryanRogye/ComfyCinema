//
//  AnimeTVDetailView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 10/14/26.
//

import SwiftUI

struct AnimeTVDetailView: View {

    @Environment(PlaybackSession.self) var playbackSession

    let result: Anime

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var selectedEpisode: Int?
    @State private var animeEpisodeResponse: AnimeEpisodeResponse?

    @State private var tvUrl: URL?
    @State private var reloadID = UUID()
    @State var webviewModel: EmbeddedMovieViewModel = .init()

    var body: some View {
        GeometryReader { geometry in
            ScrollView {

                if let tvUrl {
                    EmbeddedMovieView(url: tvUrl, vm: webviewModel) { timeInfo in
//                        receiveTimeInfo(timeInfo, playerID: playerID, season: seasonNumber, episode: episodeNumber)
//
//                        if waitingForAutoPlayLoad,
//                           timeInfo.currentTime < 10,
//                           timeInfo.duration > 0 {
//                            waitingForAutoPlayLoad = false
//                        }
                    } iFrameLogs: { log in
//                        addLog(log)
                    } videoFrameLogs: { log in
//                        addVideoLog(log)
                    } navigationLogs: { log in
//                        addNavigationLog(log)
                    }
                    .id(reloadID)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .padding(.horizontal, 10)
                }
                AnimeEpisodesView(
                    animeEpisodeResponse: $animeEpisodeResponse,
                    selectedEpisode: $selectedEpisode
                )
                .padding(.bottom, 24)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let tvUrl {
                    Button {
                        playbackSession.webView?.load(tvUrl)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }

            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        /// First thing we do is get the episode info
        .task {
            do {
                animeEpisodeResponse = try await AniListManager.getEpisodeInfo(on: result.id)
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
        /// On Change of the selectedEpisode now we get the url for this
        .onChange(of: selectedEpisode) { _, newValue in
            /// for now we'll see if it has a dub or not
            guard let selectedEpisode = newValue else { return }
            guard let animeEpisodeResponse else { return }
            guard let episode = animeEpisodeResponse.episodes.first(where: { $0.number == selectedEpisode }) else { return }

            if episode.dub {
                tvUrl = URL(string: "https://api.aniweeb.net/embed/ani/\(result.id)/\(episode.number)?track=dub")
//                tvUrl = URL(string: "https://api.aniweeb.net/embed/ani/\(result.id)/\(episode.number)?track=dub&server=2")
            }
        }
    }
}

struct AnimeEpisodesView: View {

    @Binding var animeEpisodeResponse: AnimeEpisodeResponse?
    @Binding var selectedEpisode: Int?

    @Namespace private var nm

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        if let animeEpisodeResponse {
            VStack(alignment: .leading) {
                Text("Episodes")
                    .font(.title2)
                    .fontWeight(.bold)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(animeEpisodeResponse.episodes, id: \.self) { episode in
                        let isSelected = selectedEpisode == episode.number

                        Text("Episode \(episode.number)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(
                                isSelected ? .primary : .secondary
                            )
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(.yellow.opacity(0.16))
                                        .background {
                                            Capsule()
                                                .stroke(
                                                    .yellow.opacity(0.6),
                                                    style: .init(lineWidth: 1)
                                                )
                                        }
                                        .shadow(
                                            color: .yellow,
                                            radius: 8
                                        )
                                        .matchedGeometryEffect(
                                            id: "ACTIVE_ANIME_EPISODE_PILL",
                                            in: nm
                                        )
                                } else {
                                    Capsule()
                                        .fill(.white.opacity(0.06))
                                }
                            }
                            .onTapGesture {
                                withAnimation(
                                    .spring(
                                        response: 0.3,
                                        dampingFraction: 0.7
                                    )
                                ) {
                                    selectedEpisode = episode.number
                                }
                            }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
        }
    }
}
