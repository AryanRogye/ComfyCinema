//
//  HistoryRow.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/15/26.
//

import SwiftUI
import MoviesAPIData

struct HistoryRow: View {
    let history: History
    let isResolving: Bool

    private let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter
    }()

    var body: some View {
        HStack(spacing: 14) {
            artwork

            VStack(alignment: .leading, spacing: 5) {
                name

                HStack(spacing: 5) {
                    mediaDescription

                    Text("•")

                    TimelineView(.periodic(from: .now, by: 1)) { context in

                        let seconds = max(0, Int(context.date.timeIntervalSince(history.watchedAt)))
                        let minutes = seconds / 60
                        let hours = minutes / 60

                        let calendar = Calendar.current

                        let days = calendar.dateComponents(
                            [.day],
                            from: calendar.startOfDay(for: history.watchedAt),
                            to: calendar.startOfDay(for: context.date)
                        ).day ?? 0

                        Group {
                            if days >= 1 {
                                Text("\(days)d ago")
                            } else if hours >= 1 {
                                Text("\(hours)h ago")
                            } else if minutes >= 1 {
                                Text("\(minutes)m ago")
                            } else {
                                Text("\(seconds)s ago")
                            }
                        }
                        .contentTransition(.numericText())
                        .animation(.snappy, value: seconds)
                    }

                    if let lastStoppedAt = history.lastStoppedAt {

                        Text("•")

                        Text(durationFormatter.string(from: lastStoppedAt) ?? "")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            playButton
        }
        .padding(4)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .contentShape(Rectangle())
        .padding(.horizontal, 16)
        .overlay {
            if isResolving {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black.opacity(0.1))
            }
        }
    }

    private var name: some View {
        Text(history.name)
            .font(.headline)
            .lineLimit(1)
    }

    // MARK: - Artwork
    private var artwork: some View {
        Group {
            if let posterPath = history.posterPath,
               let url = URL(
                string: "https://image.tmdb.org/t/p/w500\(posterPath)"
               ) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    posterPlaceholder
                }
            } else {
                posterPlaceholder
            }
        }
        .frame(width: 48, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var posterPlaceholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(
                    systemName: history.mediaType == .movie
                    ? "film"
                    : "play.rectangle"
                )
                .font(.title3)
                .foregroundStyle(.secondary)
            }
    }
    
    @ViewBuilder
    private var mediaDescription: some View {
        if let season = history.season,
           let episode = history.episode {
            Text("S\(season) E\(episode)")
        } else {
            Text("Movie")
        }
    }

    // MARK: - Play Button
    private var playButton: some View {
        Image(systemName: "play.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
    }
}
