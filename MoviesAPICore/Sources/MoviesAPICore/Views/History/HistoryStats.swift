//
//  HistoryStats.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 10/27/26.
//

import SwiftUI
import MoviesAPIData

struct HistoryStatsView: View {
    private let stats: HistoryStats

    init(history: [History]) {
        stats = HistoryStats(from: history)
    }

    var body: some View {
#if os(macOS)
        HStack(alignment: .top, spacing: 40) {
            WatchTimeSummary(
                totalSeconds: stats.totalSeconds,
                movieCount: stats.movieCount,
                episodeCount: stats.episodeCount
            )
            .frame(width: 220, alignment: .leading)

            if !stats.topShows.isEmpty {
                TopShowsList(shows: stats.topShows, horizontal: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
#else
        VStack(alignment: .leading, spacing: 32) {
            WatchTimeSummary(
                totalSeconds: stats.totalSeconds,
                movieCount: stats.movieCount,
                episodeCount: stats.episodeCount
            )

            if !stats.topShows.isEmpty {
                TopShowsList(shows: stats.topShows)
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
#endif
    }
}

private struct WatchTimeSummary: View {
    let totalSeconds: Double
    let movieCount: Int
    let episodeCount: Int

    private var hours: Double { totalSeconds / 3600 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Watch time")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(hours, format: .number.precision(.fractionLength(0...1)))
                    .font(.largeTitle.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("hours")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Text("\(movieCount) movies · \(episodeCount) episodes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TopShowsList: View {
    let shows: [(name: String, poster: String?, count: Int)]
    var horizontal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Most watched shows")
                .font(.headline)
                .padding(.bottom, 12)

            if horizontal {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 24) {
                        ForEach(Array(shows.enumerated()), id: \.offset) { _, show in
                            ShowRow(
                                name: show.name,
                                posterURL: Self.posterURL(from: show.poster),
                                count: show.count,
                                horizontal: true
                            )
                            .frame(width: 140, alignment: .leading)
                        }
                    }
                }
            } else {
                ForEach(Array(shows.enumerated()), id: \.offset) { index, show in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 68)
                    }

                    ShowRow(
                        name: show.name,
                        posterURL: Self.posterURL(from: show.poster),
                        count: show.count
                    )
                }
            }
        }
    }

    private static func posterURL(from poster: String?) -> URL? {
        guard let poster, !poster.isEmpty else { return nil }
        if poster.hasPrefix("http") { return URL(string: poster) }
        return URL(string: "https://image.tmdb.org/t/p/w342\(poster)")
    }
}

private struct ShowRow: View {
    let name: String
    let posterURL: URL?
    let count: Int
    var horizontal = false

    var body: some View {
        Group {
        if horizontal {
            VStack(alignment: .leading, spacing: 8) {
                poster
                showDetails
            }
        } else {
            HStack(spacing: 14) {
            poster
                showDetails
                Spacer(minLength: 0)
            }
        }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private var showDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.body.weight(.medium))
                .lineLimit(2)

            Text("\(count) episodes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var poster: some View {
        AsyncImage(url: posterURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "film")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: horizontal ? 72 : 54, height: horizontal ? 102 : 76)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .accessibilityHidden(true)
    }
}

struct HistoryStats {
    let totalSeconds: Double
    let movieCount: Int
    let episodeCount: Int
    let uniqueShowsCount: Int
    let topShows: [(name: String, poster: String?, count: Int)]

    init(from history: [History]) {
        self.totalSeconds = history.compactMap(\.lastStoppedAt).reduce(0, +)
        self.movieCount = history.filter { $0.mediaType == .movie }.count

        let episodes = history.filter { $0.mediaType == .episode }
        self.episodeCount = episodes.count

        let groupedShows = Dictionary(grouping: episodes, by: \.resultId)
        self.uniqueShowsCount = groupedShows.count

        self.topShows = groupedShows.values.compactMap { items in
            guard let first = items.first else { return nil }
            return (name: first.name, poster: first.posterPath, count: items.count)
        }
        .sorted { $0.count > $1.count }
        .prefix(5)
        .map { $0 }
    }
}
