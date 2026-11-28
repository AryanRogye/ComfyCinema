//
//  MovieDetailView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import SwiftData
import WebKit
import MoviesAPIData

enum MovieSelectedOption: String, CaseIterable {
    case collection = "Collection"
    case moreLikeThis = "More Like This"
    case ratingsAndReviews = "Reviews"
}

public struct MovieDetailView: View {

#if os(macOS)
    @Environment(RemoteServer.self) private var remoteServer
#endif

    @Environment(\.modelContext) var modelContext
    @Environment(PlaybackSession.self) var playbackSession
    @Environment(CloudKitSyncService.self) var cloudKitSyncService
    @Environment(TMDBManager.self) var tmdbManager
    @Environment(\.dismiss) var dismiss

    @Query private var history: [History]
    @Binding private var displayServer: KTDisplayServer
    @State private var movieInfo: KTMovieInfo?
    @State private var optionSelected: MovieSelectedOption = .moreLikeThis
    let result: KTSearchResult
    /// Load once the view is installed; `@Query`/`modelContext` aren't usable inside `init`.
    private let loadOnAppear: Bool

    public init(
        displayServer: Binding<KTDisplayServer>,
        result: KTSearchResult,
        restoredURL: URL? = nil,
        loadingMovie: Bool = false
    ) {
        self._displayServer = displayServer
        self.result = result
        self._movieUrl = State(initialValue: restoredURL)
        self._hasLoadedMovie = State(initialValue: restoredURL != nil)
        self.loadOnAppear = loadingMovie
    }

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var movieUrl: URL?
    @State private var hasLoadedMovie: Bool = false
    @State private var reloadID = UUID()

    @State private var showCreateCollection: Bool = false
    @State private var collectionName: String = ""
    @State private var collectionResultToAdd: KTSearchResult?
#if os(iOS)
    @State private var showRemoteSheet = false
#endif

    @State var webviewModel: EmbeddedMovieViewModel = .init()
    @State private var screenshotter = EmbeddedMovieScreenshoter()
    @State private var currentHistory: History?

#if os(macOS)
    @State private var window: NSWindow?
#endif

    private var titleLineLimit: Int {
        if let title = result.title {
            title.count <= 25 ? 1 : 2
        } else {
            1
        }
    }

    private var imagePath: String? {
        movieInfo?.backdropPath
    }

#if os(iOS)
    var overviewFont: UIFont {
        let descriptor = UIFontDescriptor
            .preferredFontDescriptor(withTextStyle: .subheadline)
            .withDesign(.serif)!
            .addingAttributes([
                .traits: [
                    UIFontDescriptor.TraitKey.weight: UIFont.Weight.medium
                ]
            ])

        return UIFont(descriptor: descriptor, size: 0)
    }
#elseif os(macOS)
    var overviewFont: NSFont {
        let size = NSFont.preferredFont(forTextStyle: .subheadline).pointSize

        let descriptor = NSFontDescriptor
            .preferredFontDescriptor(forTextStyle: .subheadline)
            .withDesign(.serif)!
            .addingAttributes([
                .traits: [
                    NSFontDescriptor.TraitKey.weight: NSFont.Weight.medium
                ]
            ])

        return NSFont(descriptor: descriptor, size: size)!
    }
#endif

    public var body: some View {
        GeometryReader { proxy in
            ScrollView {
                if let movieUrl {
#if os(iOS)
                    EmbeddedMovieView(url: movieUrl, vm: webviewModel, onWKWebView: { webView in
                        /// schedule to take a screenshot every 2 mins
                        screenshotter.scheduleWebViewScreenshot(webView: webView, for: result)
                    })
                    .id(reloadID)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .padding(.horizontal, 10)
#elseif os(macOS)
                    EmbeddedMovieView(url: movieUrl, vm: webviewModel, onWKWebView: { webView in
                        /// schedule to take a screenshot every 2 mins
                        screenshotter.scheduleWebViewScreenshot(webView: webView, for: result)
                        /// Attach here: `webviewModel.webView` is weak + ObservationIgnored, so onChange can miss it
                        remoteServer.attachWebViewFunctions(webView)

                    })
                    .id(reloadID)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
#endif
                } else {
                    MovieImageView(
                        result: result,
                        imagePath: imagePath
                    )
                    MovieInfoDetailView(
                        result: result,
                        movieInfo: movieInfo
                    )

                    MoviewPlayButton { loadMovie() }

                    MovieOverviewView(
                        result: result,
                    )

                    HStack(spacing: 12) {
                        ForEach(MovieSelectedOption.allCases.filter {
                            if $0 == .collection {
                                return movieInfo?.belongsToCollection != nil
                            }

                            return true
                        }, id: \.self) { option in
                            let isSelected = optionSelected == option

                            Text(option.rawValue)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .layoutPriority(1)
                                .foregroundStyle(
                                    isSelected ? .primary : .secondary
                                )
                                .frame(height: 30, alignment: .bottom)
                                .overlay(alignment: .top) {
                                    Rectangle()
                                        .fill(isSelected ? .yellow : .clear)
                                        .frame(height: 4)
                                        .scaleEffect(
                                            x: isSelected ? 1 : 0,
                                            y: 1,
                                            anchor: .leading
                                        )
                                        .animation(.easeInOut(duration: 0.25), value: isSelected)
                                }
                                .contentShape(.rect)
                                .onTapGesture {
                                    withAnimation(.spring) {
                                        optionSelected = option
                                    }
                                }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    switch optionSelected {
                    case .collection:
                        MovieCollectionView(movieInfo: movieInfo)
                    case .moreLikeThis:
                        MovieMoreLikeThis(result: result)
                    case .ratingsAndReviews:
                        RatingsAndReviews(result: result, type: .tv)
                    }
                }
            }
        }
#if os(macOS)
        .resizeWindow(width: 850, height: 860) { window in
            self.window = window
        }
#endif
        .navigationBarBackButtonHidden()
        .frame(maxWidth: .infinity)
        .task {
            do {
                self.movieInfo = try await tmdbManager.infoOnMovie(for: result.id)
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
            if loadOnAppear && !hasLoadedMovie {
                loadMovie()
            }
        }
        .onChange(of: displayServer) {
            if hasLoadedMovie {
                screenshotter.stop()
                movieUrl = nil
                reloadID = UUID()
                loadMovie()
            }
        }
#if os(iOS)
        .sheet(isPresented: $showRemoteSheet) {
            RemoteClientView(result: result)
        }
#endif
        .toolbar{
            #if os(macOS)
            MovieDetailToolbar(
                result: result,
                history: currentHistory,
                movieUrl: $movieUrl,
                showCreateCollection: $showCreateCollection,
                collectionName: $collectionName,
                collectionResultToAdd: $collectionResultToAdd,
                displayServer: $displayServer,
                window: $window,
                reloadID: $reloadID,
                webViewModel: webviewModel,
                screenshotter: screenshotter,
                onDismiss: {
                    cloudKitSyncService.syncSaveToCloud()
                    dismiss()
                }
            )
            #elseif os(iOS)
            MovieDetailToolbar(
                result: result,
                history: currentHistory,
                movieUrl: $movieUrl,
                showCreateCollection: $showCreateCollection,
                collectionName: $collectionName,
                collectionResultToAdd: $collectionResultToAdd,
                displayServer: $displayServer,
                showRemoteSheet: $showRemoteSheet,
                screenshotter: screenshotter,
                onDismiss: {
                    cloudKitSyncService.syncSaveToCloud()
                    dismiss()
                }
            )
            #endif
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .modifier(CreateCollectionViewModifier(
            showCreateCollection: $showCreateCollection,
            collectionName: $collectionName,
            collectionResultToAdd: $collectionResultToAdd
        ))
#if os(macOS)
        .onAppear {
            remoteServer.attachKTDisplayServerFunctions(
                onSetServer: { server in
                    self.displayServer = server
                },
                onGetServer: {
                    return self.displayServer
                }
            )
            remoteServer.attachOnBackServerFunction {
                screenshotter.stop()
                remoteServer.clearClosures()
                webviewModel.stopPlayback()

                movieUrl = nil
                hasLoadedMovie = false

                cloudKitSyncService.syncSaveToCloud()
                dismiss()
            }
        }
        .onChange(of: webviewModel.webView, initial: true) { _, webView in
            guard let webView else {
                remoteServer.clearClosures(avoidingKTDisplayServer: true)
                return
            }
            remoteServer.attachWebViewFunctions(webView)
        }
#endif
        .onDisappear {
            screenshotter.stop()
#if os(macOS)
            webviewModel.stopPlayback()
            remoteServer.clearClosures()
#endif
        }
    }

    private func loadMovie() {
        do {
            let movieUrlString = displayServer.loadMovie(movieId: result.id)
            guard let url = URL(string: movieUrlString) else {
                throw DisplayServerError.cantConstructURL
            }

            if let history = history.first(where: {
                $0.resultId == Int(result.id) &&
                $0.mediaType == .movie
            }) {
                history.watchedAt = .now
                history.updatedAt = history.watchedAt
                currentHistory = history
                cloudKitSyncService.syncSaveToCloud()
            } else {
                let history = History(
                    resultId: Int(result.id),
                    name: result.title ?? result.name ?? "",
                    mediaType: .movie,
                    posterPath: result.posterPath
                )

                currentHistory = history
                modelContext.insert(history)
                cloudKitSyncService.addToHistoryThenSync(history)
            }

            playbackSession.startMovie(result: result, url: url)
            movieUrl = url
            hasLoadedMovie = true
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }
}

#Preview {
    @Previewable @State var tmdbManager: TMDBManager?

    if let tmdbManager {
        NavigationStack {
            MovieDetailView(
                displayServer: .constant(.moviesApi),
                result: KTSearchResult(
                    id: 969681,
                    mediaType: .movie,
                    title: "Spider-Man: Brand New Day",
                    name: nil,
                    posterPath: "/bjiS5ipwxb9JFy3XRRN4OAilSeX.jpg",
                    profile_path: nil,
                    overview: """
                Fighting crime full-time as Spider-Man in a world that doesn't remember him—and the pressure of seeing his old friends move on without him—sparks a change in Peter Parker he may not have the power to control. But that transformation might also be the only thing that can stop a shocking new threat to the city and those he loves - a powerful villain no one can even see.
                """,
                    releaseDate: nil,
                    firstAirDate: nil,
                    logoPath: nil,
                    heroPosterPath: nil
                )
            )
            .environment(tmdbManager)
            .environment(BlockingService())
        }
    } else {
        ProgressView()
            .task {
                tmdbManager = try? .init(defaultsManager: DefaultsManager())
            }
    }
}
