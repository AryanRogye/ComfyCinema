//
//  SearchIntent.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/4/26.
//

import AppIntents
import SwiftUI

@available(iOS 27.3, macOS 27.3, *)
struct SearchEntity: AppEntity {

    let id: Int
    let image: DisplayRepresentation.Image?
    let imageData: Data?

    @Property(title: "Search Title")
    var title: String?

    @Property(title: "Search Name")
    var name: String?

    @Property(title: "Media Type")
    var mediaType: String

    @Property(title: "PosterPath")
    var posterPath: String?

    @Property(title: "First Air Date")
    var firstAirDate: String?

    @Property(title: "Overview")
    var overview: String?

    @Property(title: "releaseDate")
    var releaseDate: String?


    static let typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "Search Result Item")

    var displayRepresentation: DisplayRepresentation {
        if let imageData {
            return DisplayRepresentation(
                title: "\(title ?? name ?? "") (\(mediaType))",
                image: {
                    return DisplayRepresentation.Image(
                        data: imageData,
                        isTemplate: false
                    )
                }
            )
        } else {
            return DisplayRepresentation(title: "\(title ?? name ?? "") (\(mediaType))")
        }
    }

    static var defaultQuery: SearchQuery {
        SearchQuery()
    }

    init(searchResult: KTSearchResult) async {
        self.id = Int(searchResult.id)
        if let posterPath = searchResult.posterPath,
           let url = URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)") {
            (self.image, self.imageData) = await Self.loadImage(from: url)
        } else {
            self.image = nil
            self.imageData = nil
        }
        self.title = searchResult.title
        self.name = searchResult.name
        self.mediaType = searchResult.mediaType.rawValue
        self.posterPath = searchResult.posterPath
        self.firstAirDate = searchResult.firstAirDate
        self.overview = searchResult.overview
        self.releaseDate = searchResult.releaseDate
    }

    static func loadImage(from url: URL) async -> (DisplayRepresentation.Image?, Data?) {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let response = response as? HTTPURLResponse,
                  response.statusCode == 200 else {
                await SettingLogs.shared.add("""
                SearchEntity: Invalid poster response: \(response)
                """)
                return (nil, nil)
            }

            await SettingLogs.shared.add("""
            SearchEntity: Downloaded poster: \(data.count) bytes
            """)

            return (DisplayRepresentation.Image(data: data), data)
        } catch {
            await SettingLogs.shared.add("""
            SearchEntity: Poster download failed: \(error)
            """)
            return (nil, nil)
        }
    }

}

@available(iOS 27.3, macOS 27.3, *)
struct SearchQuery: EntityQuery {
    func entities(
        for identifiers: [SearchEntity.ID]
    ) async throws -> [SearchEntity] {

        let tmdbManager = try await TMDBManager(
            defaultManager: DefaultManager()
        )
        await tmdbManager.clearSearchResults()

        let query = UserDefaults.standard.string(
            forKey: "lastSearchQuery"
        ) ?? ""
        try await tmdbManager.search(query)

        var results: [SearchEntity] = []
        for result in await tmdbManager.searchResults {
            await results.append(.init(searchResult: result))
        }

        return results.filter({ identifiers.contains($0.id) })
    }

    func displayRepresentations(
        for identifiers: [SearchEntity.ID]
    ) async throws -> [SearchEntity.ID: DisplayRepresentation] {
        await SettingLogs.shared.add(
            "SearchQuery: displayRepresentations requested for \(identifiers)"
        )

        let entities = try await entities(for: identifiers)

        var representations: [SearchEntity.ID: DisplayRepresentation] = [:]
        for entity in entities {
            representations[entity.id] = entity.displayRepresentation
        }
        return representations
    }
}

@available(iOS 27.3, macOS 27.3, *)
struct OpenSearchIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Search Result"

    @Parameter(title: "Search Item")
    var target: SearchEntity

    static var openAppWhenRun: Bool = true
    static var supportedModes: IntentModes = .foreground

    @Dependency
    private var appRouter: AppRouter

    @MainActor
    func perform() async throws -> some IntentResult {

        appRouter.searchTriggered = .init(
            id: Int32(target.id),
            mediaType: target.mediaType == "tv" ? .tv : .movie,
            title: target.title,
            name: target.name,
            posterPath: target.posterPath,
            overview: target.overview,
            releaseDate: target.releaseDate,
            firstAirDate: target.firstAirDate
        )

        return .result()
    }

}

@available(iOS 27.3, macOS 27.3, *)
@AppIntent(.tool)
struct ContentSearchIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Content"

    static let description = IntentDescription(
    """
    Search ComfyCinema for movies and TV shows by title.
    Use this when the user asks to find, look up, or search
    for a movie or TV show in ComfyCinema.
    """
    )

    @Parameter(
        title: "Search Query",
        description: "The movie or TV show title to search for."
    )
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[SearchEntity]> & ShowsSnippetView {
        let tmdbManager = try TMDBManager(
            defaultManager: DefaultManager()
        )
        tmdbManager.clearSearchResults()
        try await tmdbManager.search(query)


        var results: [SearchEntity] = []
        for result in tmdbManager.searchResults {
            await results.append(.init(searchResult: result))
        }

        /// Store Last Query
        UserDefaults.standard.set(query, forKey: "lastSearchQuery")

        return .result(
            value: results,
            view: SearchResultsSnippet(results: results)
        )
    }
}

@available(iOS 27.3, macOS 27.3, *)
private struct SearchResultsSnippet: View {
    let results: [SearchEntity]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if results.isEmpty {
                Text("No results found.")
            }
            ForEach(Array(results.prefix(3)), id: \.id) { result in
                HStack {
                    #if os(iOS)
                    if let imageData = result.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 66)
                    } else {
                        Image(systemName: "film")
                    }
                    #elseif os(macOS)
                    if let imageData = result.imageData, let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 66)
                    } else {
                        Image(systemName: "film")
                    }
                    #endif
                    Text(result.title ?? result.name ?? "")
                    Spacer()
                }
            }
        }
    }
}
