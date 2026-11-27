//
//  TMDBManager.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import Foundation
import Defaults
#if os(iOS)
import UIKit
#endif

enum TMDBError: LocalizedError {
    case noToken
    case tokenEmpty

    var errorDescription: String? {
        switch self {
        case .noToken:
            "No Token in Info.plist"
        case .tokenEmpty:
            "Token is empty"
        }
    }
}

@Observable
@MainActor
public final class TMDBManager {

    private let tmdbClient: TMDBClientProviding
    private let defaultsManager: DefaultsManager
    private let token: String

    private var fullTrendingResults: [KTTrendingResult] = []
    private var fullPopularMovieResults: [KTMovieListResult] = []
    private var fullTopRatedMovieResults: [KTMovieListResult] = []
    private var fullNowPlayingMovieResults: [KTMovieListResult] = []

#if os(iOS)
    var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
#endif

    public var trendingResults: [KTTrendingResult] {
        fullTrendingResults.filter { result in
            includeAdult || !result.adult
        }
    }
    public var popularMovies: [KTMovieListResult] {
        fullPopularMovieResults.filter { result in
            includeAdult || !result.adult
        }
    }
    public var topRatedMovies: [KTMovieListResult] {
        fullTopRatedMovieResults.filter { result in
            includeAdult || !result.adult
        }
    }
    public var nowPlayingMovies: [KTMovieListResult] {
        fullNowPlayingMovieResults.filter { result in
            includeAdult || !result.adult
        }
    }

    public private(set) var popularTV: [KTTVListResult] = []
    public private(set) var topRatedTV: [KTTVListResult] = []
    public private(set) var searchResults: [KTSearchResult] = []

    var includeAdult: Bool {
        defaultsManager.includeAdult
    }

    public init(
        tmdbClient: TMDBClientProviding = TMDBClient(),
        defaultsManager: DefaultsManager,
        token tokenOverride: String? = nil
    ) throws {
        if let tokenOverride {
            self.tmdbClient = tmdbClient
            self.defaultsManager = defaultsManager
            self.token = tokenOverride
            return
        }

        guard let token = Bundle.main.object(
            forInfoDictionaryKey: "APIReadAccessToken"
        ) as? String else {
            throw TMDBError.noToken
        }
        if token.isEmpty {
            throw TMDBError.tokenEmpty
        }

        self.defaultsManager = defaultsManager
        self.tmdbClient = tmdbClient
        self.token = token
    }

    public func clearSearchResults() {
        self.searchResults = []
    }

    public func trending() async throws {
        let response = try await tmdbClient.trending(token: token)

        self.fullTrendingResults = response.results.filter { result in
            includeAdult || !result.adult
        }.deduplicatedByMediaIdentity()
    }

    var pagesForDevice: Int {
#if os(iOS)
        return isPad ? 2 : 1
#elseif os(macOS)
        return 2
#endif
    }

    private func perform<Element>(count: Int, action: (Int32) async throws -> [Element]) async throws -> [Element] {
        guard count > 0 else { return [] }

        var results: [Element] = []

        for page in 1...count {
            results.append(contentsOf: try await action(Int32(page)))
        }

        return results
    }

    public func nowPlaying() async throws {
        fullNowPlayingMovieResults = try await perform(count: pagesForDevice) { [weak self] page in
            guard let self else { return [] }
            return try await tmdbClient.nowPlayingMovies(
                token: token,
                page: page
            ).results
        }.deduplicatedByMediaIdentity()
    }

    public func popularMovie() async throws {
        fullPopularMovieResults = try await perform(count: pagesForDevice) { [weak self] page in
            guard let self else { return []}
            return try await tmdbClient.popularMovies(
                token: token,
                page: page
            ).results
        }.deduplicatedByMediaIdentity()
    }

    public func popularTV() async throws {
        popularTV = try await perform(count: pagesForDevice) { [weak self] page in
            guard let self else { return [] }
            return try await tmdbClient.popularTV(
                token: token,
                page: page
            ).results
        }.deduplicatedByMediaIdentity()
    }

    public func topRatedMovie() async throws {
        fullTopRatedMovieResults = try await perform(count: pagesForDevice) { [weak self] page in
            guard let self else { return [] }
            return try await tmdbClient.topRatedMovies(
                token: token,
                page: page
            ).results
        }.deduplicatedByMediaIdentity()
    }

    public func topRatedTV() async throws {
        topRatedTV = try await perform(count: pagesForDevice) { [weak self] page in
            guard let self else { return [] }
            return try await tmdbClient.topRatedTV(
                token: token,
                page: page
            ).results
        }.deduplicatedByMediaIdentity()
    }

    public func seasonInfo(for id: Int, seasonNumber: Int) async throws -> KTSeasonInfo {
        return try await tmdbClient.seasonInfo(
            id: Int32(id),
            seasonNumber: Int32(seasonNumber),
            token: token
        )
    }

    public func ratingsAndReviewsForMovie(for id: Int32) async throws -> KTRatingsAndReviews {
        try await tmdbClient.ratingsAndReviewsForMovie(id: id, token: token)
    }

    public func reviewsForMovie(for id: Int32, page: Int32) async throws -> KTReviewResponse {
        try await tmdbClient.reviewsForMovie(id: id, token: token, page: page)
    }

    public func ratingsAndReviewsForTV(for id: Int32) async throws -> KTRatingsAndReviews {
        try await tmdbClient.ratingsAndReviewsForTV(id: id, token: token)
    }

    public func reviewsForTV(for id: Int32, page: Int32) async throws -> KTReviewResponse {
        try await tmdbClient.reviewsForTV(id: id, token: token, page: page)
    }

    public func infoOnTV(for id: Int) async throws -> KTTVShow {
        return try await tmdbClient.infoOnTV(id: Int32(id), token: token)
    }

    public func infoOnMovie(for id: Int32) async throws -> KTMovieInfo {
        return try await tmdbClient.infoOnMovie(id: id, token: token)
    }

    public func recommendationsForMovie(for id: Int32, page: Int32 = 1) async throws -> KTMovieListResponse {
        return try await tmdbClient.recommendationsForMovie(id: id, token: token, page: page)
    }

    public func recommendationsForTV(for id: Int32) async throws -> KTTVListResponse {
        return try await tmdbClient.recommendationsForTV(id: id, token: token, page: 1)
    }

    public func creditsForPerson(id: Int32) async throws -> [KTSearchResult] {
        return try await tmdbClient.creditsForPerson(id: id, token: token).results
    }

    public func collectionInfo(collectionId: Int32) async throws -> KTCollectionResponse {
        return try await tmdbClient.collectionInfo(collectionId: collectionId, token: token)
    }

    /// Function to search for tv,movie,person
    public func search(_ text: String) async throws {
        let results = try await tmdbClient.search(query: text, token: token, includeAdult: includeAdult)
        self.searchResults = results.results
    }
}
