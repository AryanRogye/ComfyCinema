//
//  HistoryStats.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 10/27/26.
//

import SwiftUI

struct HistoryStatsView: View {
    private let historyStats: HistoryStats

    init(history: [History]) {
        self.historyStats = HistoryStats(from: history)
    }

    @State private var appeared = false

    // MARK: Derived

    private var totalHours: Double { historyStats.totalSeconds / 3600 }
    private var days: Int { Int(historyStats.totalSeconds / 86_400) }
    private var hours: Int { Int(historyStats.totalSeconds.truncatingRemainder(dividingBy: 86_400) / 3600) }
    private var minutes: Int { Int(historyStats.totalSeconds.truncatingRemainder(dividingBy: 3600) / 60) }
    private var maxCount: Int { max(historyStats.topShows.map(\.count).max() ?? 1, 1) }

    // MARK: Body

    var body: some View {
        layout
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.08))
            )
            .opacity(appeared ? 1 : 0)
            .offset(x: appeared ? 0 : -24)
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .onAppear {
                withAnimation(.easeOut(duration: 1.4)) { appeared = true }
            }
    }

    @ViewBuilder
    private var layout: some View {
#if os(macOS)
        HStack(spacing: 28) {
            VStack(spacing: 28) {
                hero
                statCards
            }
            if !historyStats.topShows.isEmpty { topShowsSection }
        }
#else
        VStack(spacing: 28) {
            hero
            statCards
            if !historyStats.topShows.isEmpty { topShowsSection }
        }
#endif
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 10) {
            Text("YOU'VE WATCHED")
                .font(.caption.weight(.semibold))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.6))

            CountingText(value: appeared ? totalHours : 0)
                .font(.system(size: 84, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text("hours")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))

            Text(breakdown)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
                .padding(.top, 6)
        }
        .padding(.vertical, 8)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    private var breakdown: String {
        var parts: [String] = []
        if days > 0 { parts.append("\(days) day\(days == 1 ? "" : "s")") }
        parts.append("\(hours) hr")
        parts.append("\(minutes) min")
        return parts.joined(separator: " · ")
    }

    // MARK: Stat Cards

    private var statCards: some View {
        HStack(spacing: 12) {
            StatCard(icon: "film.fill", value: historyStats.movieCount, label: "Movies",
                     tint: .orange, appeared: appeared, delay: 0.0)
            StatCard(icon: "play.rectangle.fill", value: historyStats.episodeCount, label: "Episodes",
                     tint: .cyan, appeared: appeared, delay: 0.1)
            StatCard(icon: "tv.fill", value: historyStats.uniqueShowsCount, label: "Shows",
                     tint: .pink, appeared: appeared, delay: 0.2)
        }
    }

    // MARK: Top Shows

    private var topShowsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Top Shows")
                    .font(.title3.weight(.bold))
                Spacer()
                Text("by episodes")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            VStack(spacing: 10) {
                ForEach(Array(historyStats.topShows.enumerated()), id: \.offset) { index, show in
                    ShowRow(
                        rank: index + 1,
                        name: show.name,
                        posterURL: Self.posterURL(from: show.poster),
                        count: show.count,
                        fraction: Double(show.count) / Double(maxCount),
                        appeared: appeared,
                        delay: 0.3 + Double(index) * 0.08
                    )
                }
            }
        }
    }

    /// Accepts a full URL or a TMDB-style path like "/abc123.jpg".
    private static func posterURL(from poster: String?) -> URL? {
        guard let poster, !poster.isEmpty else { return nil }
        if poster.hasPrefix("http") { return URL(string: poster) }
        return URL(string: "https://image.tmdb.org/t/p/w342\(poster)")
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let icon: String
    let value: Int
    let label: String
    let tint: Color
    let appeared: Bool
    let delay: Double

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
            }

            CountingText(value: appeared ? Double(value) : 0)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: 150)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.04)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: appeared)
    }
}

// MARK: - Show Row

private struct ShowRow: View {
    let rank: Int
    let name: String
    let posterURL: URL?
    let count: Int
    let fraction: Double
    let appeared: Bool
    let delay: Double

    private var accent: Color {
        .secondary
    }

    var body: some View {
        HStack(spacing: 14) {
            Text("\(rank)")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(accent)
                .frame(width: 22)

            poster

            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Capsule()
                        .fill(.white.opacity(0.08))
                        .frame(height: 6)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(LinearGradient(colors: [accent, accent.opacity(0.5)],
                                                     startPoint: .leading, endPoint: .trailing))
                                .scaleEffect(x: appeared ? max(fraction, 0.04) : 0, anchor: .leading)
                                .animation(.easeOut(duration: 1.0).delay(delay + 0.15), value: appeared)
                        }

                    Text("\(count) eps")
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(rank == 1 ? 0.10 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(rank == 1 ? accent.opacity(0.4) : .white.opacity(0.08))
        )
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -24)
        .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(delay), value: appeared)
    }

    private var poster: some View {
        AsyncImage(url: posterURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    LinearGradient(colors: [.purple.opacity(0.4), .blue.opacity(0.3)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "film")
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .frame(width: 46, height: 69)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
    }
}

// MARK: - Count-up Text

/// Animates smoothly between numeric values.
private struct CountingText: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(Int(value.rounded()), format: .number)
            .monospacedDigit()
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
