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

public struct MovieDetailView: View {

#if os(macOS)
    @Environment(RemoteServer.self) private var remoteServer
#endif

    @Environment(\.modelContext) var modelContext
    @Environment(PlaybackSession.self) var playbackSession
    @Environment(CloudKitSyncService.self) var cloudKitSyncService
    @Environment(\.dismiss) var dismiss

    @Query var history: [History]
    @Binding var displayServer: KTDisplayServer
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
        ZStack {
            if let movieUrl {
#if os(iOS)
                GeometryReader { proxy in
                    EmbeddedMovieView(url: movieUrl, vm: webviewModel, onWKWebView: { webView in
                        /// schedule to take a screenshot every 2 mins
                        screenshotter.scheduleWebViewScreenshot(webView: webView, for: result)
                    })
                    .id(reloadID)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .padding(.horizontal, 10)
                }
                .frame(height: 200)
#elseif os(macOS)
                EmbeddedMovieView(url: movieUrl, vm: webviewModel, onWKWebView: { webView in
                    /// schedule to take a screenshot every 2 mins
                    screenshotter.scheduleWebViewScreenshot(webView: webView, for: result)

                })
                .id(reloadID)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
#endif
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 0) {
                            Color.black
                                .ignoresSafeArea()
                                .overlay {
                                    MovieImageBackground(imagePath: result.posterPath)
                                        .ignoresSafeArea()
                                }
                                .overlay(alignment: .bottomLeading) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(result.title ?? "")
                                            .font(.system(.largeTitle, design: .serif))
                                            .fontWeight(.semibold)
                                            .lineLimit(titleLineLimit)
                                            .minimumScaleFactor(0.8)
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.white, .white.opacity(0.7)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)


                                        ExpandableText(
                                            text: result.overview ?? "",
                                            tintColor: .yellow,
                                            font: overviewFont,
                                            background: .black,
                                            foregroundStyle: .white.opacity(0.65)
                                        )
                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                                        Button {
                                            loadMovie()
                                        } label: {
                                            Label("Play Movie", systemImage: "play.fill")
                                                .font(.body)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                                .padding(.vertical, 10)
                                                .padding(.horizontal, 20)
                                                .glassEffect(.clear.tint(.yellow.opacity(0.1).mix(with: .black, by: 0.8)), in: .capsule)
                                        }
                                        .buttonStyle(.plain)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding()
                                }
                                .frame(height: geometry.size.height)


                            MovieMoreInfo(result: result)
                                .padding(.top, 32)
                        }
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
        .navigationTitle(result.name ?? result.title ?? "")
        .frame(maxWidth: .infinity)
        .task {
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
            RemoteClientSheet(result: result)
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
        .onChange(of: webviewModel.webView, initial: true) { _, webView in
            guard let webView else {
                remoteServer.clearClosures()
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
                    overview: """
                Fighting crime full-time as Spider-Man in a world that doesn't remember him—and the pressure of seeing his old friends move on without him—sparks a change in Peter Parker he may not have the power to control. But that transformation might also be the only thing that can stop a shocking new threat to the city and those he loves - a powerful villain no one can even see.
                """,
                    releaseDate: nil,
                    firstAirDate: nil
                )
            )
            .environment(tmdbManager)
            .environment(BlockingService())
        }
    } else {
        ProgressView()
            .task {
                tmdbManager = try? .init(defaultManager: DefaultManager())
            }
    }
}
