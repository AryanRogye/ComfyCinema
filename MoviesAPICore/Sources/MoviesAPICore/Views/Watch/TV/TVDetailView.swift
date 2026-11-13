//
//  TVDetailView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/17/26.
//

import SwiftUI
import SwiftData
import WebKit
import MoviesAPIData

public struct TVDetailView: View {

#if os(macOS)
    @Environment(WindowCoordinatorContainer.self) var windowContainer
#endif
    @Environment(TMDBManager.self) var tmdbManager
    @Environment(PlaybackSession.self) var playbackSession
    @Environment(CloudKitSyncService.self) var cloudKitSyncService
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @Query var history: [History]
    @Binding var displayServer: KTDisplayServer
    let result: KTSearchResult

    public init(
        displayServer: Binding<KTDisplayServer>,
        result: KTSearchResult,
        restoredPlayback: PlaybackSession.TVPlayback? = nil
    ) {
        self._displayServer = displayServer
        self.result = result
        self._selectedSeasonNumber = .init(initialValue: restoredPlayback?.seasonNumber)
        self._seasonInfo = .init(initialValue: restoredPlayback?.seasonInfo)
        self._selectedEpisode = .init(initialValue: restoredPlayback?.episode)
        self._tvUrl = .init(initialValue: restoredPlayback?.url)
    }
    public init(displayServer: Binding<KTDisplayServer>, result: KTSearchResult, seasonNumber: Int, episodeNumber: Int) {
        self._displayServer = displayServer
        self.result = result
        self._selectedSeasonNumber = .init(initialValue: seasonNumber)
        self._selectedEpisodeNumber = .init(initialValue: episodeNumber)
    }

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var tvShow: KTTVShow?
    @State private var selectedSeasonNumber: Int? = nil
    @State private var selectedEpisodeNumber: Int? = nil

    @State private var loadSeasonTask: Task<Void, Never>?
    @State private var isLoadingSeason = false

    @State private var seasonInfo: KTSeasonInfo?
    @State private var selectedEpisode: KTEpisode? = nil

    @State private var tvUrl: URL?
    @State private var reloadID = UUID()

    @State private var hideSeasonsAndEpisodes: Bool = false

    @State private var timeInfo: TimeInfo? = nil
    @State private var lastProgressSaveAt: Date?
    @State private var timeInfoTask: Task<Void, Never>?

    @State private var showingLogs = false
    @State private var iFrameLogs: [String] = []
    @State private var videoFrameLogs: [String] = []
    @State private var navigationLogs: [String] = []

    @State private var showCreateCollection: Bool = false
    @State private var collectionName: String = ""
    @State private var collectionResultToAdd: KTSearchResult?

    @State private var currentHistory: History?

    @State var webviewModel: EmbeddedMovieViewModel = .init()
    @State private var screenshotter = EmbeddedMovieScreenshoter()

    public var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if let tvUrl {
                    let playerID = reloadID
                    let seasonNumber = selectedSeasonNumber
                    let episodeNumber = selectedEpisode.map { Int($0.episodeNumber) }
#if os(iOS)
                    EmbeddedMovieView(url: tvUrl, vm: webviewModel) { timeInfo in
                        receiveTimeInfo(timeInfo, playerID: playerID, season: seasonNumber, episode: episodeNumber)
                    } iFrameLogs: { log in
                        addLog(log)
                    } videoFrameLogs: { log in
                        addVideoLog(log)
                    } navigationLogs: { log in
                        addNavigationLog(log)
                    }  onWKWebView: { webView in
                        /// schedule to take a screenshot every 2 mins
                        screenshotter.scheduleWebViewScreenshot(webView: webView, for: result)
                    }
                    .id(reloadID)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .padding(.horizontal, 10)
#elseif os(macOS)
                    EmbeddedMovieView(url: tvUrl, vm: webviewModel) { timeInfo in
                        receiveTimeInfo(timeInfo, playerID: playerID, season: seasonNumber, episode: episodeNumber)
                    } iFrameLogs: { log in
                        addLog(log)
                    } videoFrameLogs: { log in
                        addVideoLog(log)
                    } navigationLogs: { log in
                        addNavigationLog(log)
                    } onWKWebView: { webView in
                        /// schedule to take a screenshot every 2 mins
                        screenshotter.scheduleWebViewScreenshot(webView: webView, for: result)
                    }
                    .id(reloadID)
                    .frame(maxWidth: .infinity)
                    .frame(
                        height: hideSeasonsAndEpisodes
                        ? geometry.size.height - 50
                        : 400
                    )
                    .padding(.horizontal, 10)
                    .padding(.top, hideSeasonsAndEpisodes ? 0 : 50)
                    .padding(.vertical, hideSeasonsAndEpisodes ? 50 : 0)
#endif
                } else {
                    EpisodeImageView(
                        result: result,
                        tvShow: tvShow
                    )
                }

                if !hideSeasonsAndEpisodes {

                    TVShowInfo(
                        selectedEpisode: selectedEpisode
                    )

                    SeasonsView(
                        tvShow: tvShow,
                        isLoadingSeason: isLoadingSeason,
                        selectedSeasonNumber: $selectedSeasonNumber
                    )

                    EpisodesView(
                        seasonInfo: seasonInfo,
                        selectedEpisode: $selectedEpisode
                    )

                    TVMoreInfo(
                        selectedEpisode: selectedEpisode,
                        result: result
                    )
                    .padding(.bottom, 24)
                }
            }
        }
        .scrollDisabled(hideSeasonsAndEpisodes)
        .navigationBarBackButtonHidden()
        .navigationTitle(result.name ?? result.title ?? "")
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .onDisappear {
#if os(macOS)
            webviewModel.stopPlayback()
#endif
            saveCurrentPlaybackPosition()
        }
        .modifier(CreateCollectionViewModifier(
            showCreateCollection: $showCreateCollection,
            collectionName: $collectionName,
            collectionResultToAdd: $collectionResultToAdd
        ))
        .sheet(isPresented: $showingLogs) {
            NavigationStack {
                IFrameLogsView(
                    logs: $iFrameLogs,
                    videoLogs: $videoFrameLogs,
                    navigationLogs: $navigationLogs
                )
            }
            .frame(minWidth: 400, minHeight: 400)
        }
        .toolbar {
#if os(macOS)
            TVDetailToolbar(
                result: result,
                tvUrl: tvUrl,
                history: currentHistory,
                onShowLogs: { showingLogs = true },
                showCreateCollection: $showCreateCollection,
                collectionName: $collectionName,
                collectionResultToAdd: $collectionResultToAdd,
                displayServer: $displayServer,
                timeInfo: $timeInfo,
                lastProgressSaveAt: $lastProgressSaveAt,
                reloadID: $reloadID,
                hideSeasonsAndEpisodes: $hideSeasonsAndEpisodes,
                webViewModel: webviewModel,
                onSaveCurrentPlaybackPosition: saveCurrentPlaybackPosition,
                onDismiss: {
                    cloudKitSyncService.syncSaveToCloud()
                    screenshotter.stop()
                    dismiss()
                }
            )
#elseif os(iOS)
            TVDetailToolbar(
                result: result,
                tvUrl: tvUrl,
                history: currentHistory,
                onShowLogs: { showingLogs = true },
                showCreateCollection: $showCreateCollection,
                collectionName: $collectionName,
                collectionResultToAdd: $collectionResultToAdd,
                displayServer: $displayServer,
                timeInfo: $timeInfo,
                lastProgressSaveAt: $lastProgressSaveAt,
                onSaveCurrentPlaybackPosition: saveCurrentPlaybackPosition,
                onDismiss: {
                    cloudKitSyncService.syncSaveToCloud()
                    screenshotter.stop()
                    dismiss()
                }
            )
#endif
        }
        .onDisappear {
            timeInfoTask?.cancel()
            timeInfoTask = nil
            screenshotter.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                saveCurrentPlaybackPosition()
            }
        }
        /// If we pick a season number, we must clear out any existing values
        .onChange(of: selectedSeasonNumber) { _, newValue in
            if let newValue {
                saveCurrentPlaybackPosition()
                clearPlaybackPosition()
                seasonInfo = nil
                tvUrl = nil
                selectedEpisode = nil
                selectedEpisodeNumber = nil
                loadSeason(season: newValue)
            }
        }
        /// If we pick a episode number, we clear out any web values so the view is clear
        /// and start the tv show
        .onChange(of: selectedEpisode) { _, newValue in
            if let newValue, let selectedSeasonNumber {
                saveCurrentPlaybackPosition()
                clearPlaybackPosition()
                tvUrl = nil
                reloadID = UUID()
                loadTVShow(season: selectedSeasonNumber, episode: Int(newValue.episodeNumber))
            }
        }
        /// If we change a server, we must reload
        /// and load the tv show again
        .onChange(of: displayServer) {
            if let selectedSeasonNumber, let selectedEpisode {
                saveCurrentPlaybackPosition()
                clearPlaybackPosition()
                self.tvUrl = nil
                reloadID = UUID()
                loadTVShow(season: selectedSeasonNumber, episode: Int(selectedEpisode.episodeNumber))
            }
        }
        /// Attach history if we came including the tvUrl being nil and the currentHistory not being set
        .task {
            if tvUrl != nil,
               currentHistory == nil,
               let selectedSeasonNumber,
               let selectedEpisode {
                attachHistory(season: selectedSeasonNumber, episode: Int(selectedEpisode.episodeNumber))
            }
        }
        /// if we load in wtih selectedSeasonNumber and selectedEpisodeNumber
        /// we can load in the season right away
        .task {
            if let selectedSeasonNumber, let selectedEpisodeNumber {
                loadSeason(season: selectedSeasonNumber, pickingEpisode: selectedEpisodeNumber)
            }
        }
        /// Get TV Show Info on launch
        .task {
            do {
                tvShow = try await tmdbManager.infoOnTV(for: Int(result.id))
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }

    /// Function loads a TV Show based on a season and episode number
    private func loadTVShow(season: Int, episode: Int) {
        do {
            let tvUrlString = displayServer.loadTvShow(showId: result.id, season: Int32(season), episode: Int32(episode))
            guard let url = URL(string: tvUrlString) else {
                throw DisplayServerError.cantConstructURL
            }

            attachHistory(season: season, episode: episode)

            self.startPlaybackSession(with: url, season: season)
            self.tvUrl = url
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    /// Function loads the seasonInfo value of type `KTSeasonInfo?`
    private func loadSeason(season: Int, pickingEpisode: Int? = nil) {
        if isLoadingSeason { return }
        loadSeasonTask = Task {
            isLoadingSeason = true
            defer { isLoadingSeason = false }
            do {
                seasonInfo = try await tmdbManager.seasonInfo(for: Int(result.id), seasonNumber: season)

                /// if we're picking an episode, and seasonInfo does exist
                /// we pick that episode of the season
                /// should only get triggered if we came from history or playback
                if let pickingEpisode, let seasonInfo {
                    for episode in seasonInfo.episodes {
                        if (episode.episodeNumber == pickingEpisode) {
                            self.selectedEpisode = episode
                            return
                        }
                    }
                }
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }

    /// Function stores or replaces a history item and assigns the current history
    private func attachHistory(season: Int, episode: Int) {
        if let history = history.first(where: {
            $0.resultId == Int(result.id) &&
            $0.mediaType == .episode &&
            $0.season == season &&
            $0.episode == episode
        }) {
            history.watchedAt = .now
            history.updatedAt = history.watchedAt
            currentHistory = history
            cloudKitSyncService.syncSaveToCloud()
        } else {
            let history = History(
                resultId: Int(result.id),
                name: result.name ?? result.title ?? "",
                mediaType: .episode,
                season: season,
                episode: episode,
                posterPath: result.posterPath
            )
            currentHistory = history
            modelContext.insert(history)
            cloudKitSyncService.addToHistoryThenSync(history)
        }
    }

    /// Save current playback for the history item
    private func saveCurrentPlaybackPosition() {
        guard let timeInfo else { return }
        updateLastStoppedAt(with: timeInfo)
    }

    /// Clears the playback position when we change season, episode, or the display server
    private func clearPlaybackPosition() {
        timeInfo = nil
        lastProgressSaveAt = nil
        currentHistory = nil
    }

    /// Function updates the last time we stopped on this current video in the history
    private func updateLastStoppedAt(with timeInfo: TimeInfo) {
        guard let currentHistory else { return }
        currentHistory.lastStoppedAt = timeInfo.currentTime
        currentHistory.updatedAt = .now
        try? modelContext.save()
    }

    /// Function starts a playback session, this is only useful on iOS so that we can
    /// restore the session again
    private func startPlaybackSession(with url: URL, season: Int) {
        guard let seasonInfo, let selectedEpisode else { return }
        playbackSession.startEpisode(
            result: result,
            url: url,
            seasonInfo: seasonInfo,
            episode: selectedEpisode,
            seasonNumber: season
        )
    }

    /// Function is called by the `EmbeddedMovieView` when the time info we get is updated
    private func receiveTimeInfo(_ info: TimeInfo, playerID: UUID, season: Int?, episode: Int?) {
        guard playerID == reloadID,
              let currentHistory,
              currentHistory.season == season,
              currentHistory.episode == episode else { return }

        timeInfo = info
        let now = Date.now
        if info.currentTime > 0,
           lastProgressSaveAt.map({ now.timeIntervalSince($0) >= 10 }) ?? true {
            updateLastStoppedAt(with: info)
            lastProgressSaveAt = now
        }
    }

    /// Log Related

    func addNavigationLog(_ log: String) {
        navigationLogs.append(log)

        if navigationLogs.count > 200 {
            navigationLogs.removeFirst(navigationLogs.count - 200)
        }
    }

    func addVideoLog(_ log: String) {
        videoFrameLogs.append(log)

        if videoFrameLogs.count > 200 {
            videoFrameLogs.removeFirst(videoFrameLogs.count - 200)
        }
    }

    func addLog(_ log: String) {
        iFrameLogs.append(log)

        if iFrameLogs.count > 200 {
            iFrameLogs.removeFirst(iFrameLogs.count - 200)
        }
    }
}

#if DEBUG
#Preview {
    @Previewable @State var tmdbManager: TMDBManager?

    if let tmdbManager {
        NavigationStack {
            TVDetailView(
                displayServer: .constant(.moviesApi),
                result: KTSearchResult(
                    id: 38867,
                    mediaType: .tv,
                    title: nil,
                    name: "Lab Rats",
                    posterPath: "/lcQMvn9ZptPd3dxn0a17viRfi7Y.jpg",
                    overview: """
                    Leo is an ordinary teenager who has moved into a high-tech "smart" house with his mother, inventor stepfather and Eddy, the computer that runs the house. Leo's life becomes less ordinary when, one day, he discovers a secret underground lab that houses three experiments: superhuman teenagers. The trio -- Adam, the strong one, Bree, the fast one and Chase, the smart one -- convinces Leo and his parents to let them leave their lab and join Leo at school, where they try to fit in while having to manage their unpredictable bionic strengths. As Leo figures out a way to keep his new pals' bionic abilities a secret, they help him build self-confidence.
                    """,
                    releaseDate: nil,
                    firstAirDate: nil
                )
            )
            .environment(tmdbManager)
            .environment(PlaybackSession())
            .environment(BlockingService())
            .modelContainer(for: [Favorite.self, History.self], inMemory: true)
        }
    } else {
        ProgressView()
            .task {
                do {
                    tmdbManager = try .init(
                        tmdbClient: TMDBClientPreview(),
                        defaultManager: DefaultManager(),
                        token: "preview"
                    )
                } catch {
                    print(error.localizedDescription)
                }
            }
    }
}
#endif
