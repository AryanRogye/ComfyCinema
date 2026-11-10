//
//  MostRecentWidget.swift
//  ComfyCinemaWidgets
//
//  Created by Aryan Rogye on 11/9/26.
//

import WidgetKit
import SwiftUI
import SwiftData
import MoviesAPIData

struct HistoryInfo: TimelineEntry {
    let date: Date
    let systemImage: SystemImage?
    let color: SystemColor?
    let history: History

    var watchURL: URL {
        URL(string: "comfycinema://watch?id=\(history.id.uuidString)")!
    }
}

struct MostRecentProvider: TimelineProvider {
    /// placeholder WidgetKit displays when it needs a temporary representation of
    /// the widget before the actual data is available
    func placeholder(in context: Context) -> HistoryInfo {
        HistoryInfo(
            date: Date(),
            systemImage: nil,
            color: nil,
            history: .init(
                resultId: 969681,
                name: "Spider-Man: Brand New Day",
                mediaType: .movie,
                posterPath: "/9JCQtDCSpPR2ld55yNlEg1VwcQo.jpg",
                updatedAt: .now
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HistoryInfo) -> Void) {
        Task { completion(await snapshot()) }
    }

    private func snapshot() async -> HistoryInfo {
        let image = try? await TMDBImageLoader.loadImage(from: "/9JCQtDCSpPR2ld55yNlEg1VwcQo.jpg")
        return HistoryInfo(
            date: Date(),
            systemImage: image,
            color: image == nil ? nil : ColorExtractor.getDominantColor(from: image!),
            history: .init(
                resultId: 969681,
                name: "Spider-Man: Brand New Day",
                mediaType: .movie,
                posterPath: "/9JCQtDCSpPR2ld55yNlEg1VwcQo.jpg",
                updatedAt: .now
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HistoryInfo>) -> Void) {
        Task { completion(await timeline()) }
    }

    private func timeline() async -> Timeline<HistoryInfo> {
        let history: HistorySnapshot?
        do {
            history = try await MainActor.run {
                let container = try ModelConfigFetcher.fetch()
                return try HistoryHelper.fetchLatestHistory(from: container)
            }
        } catch {
            print("Could not load widget history:", error)
            return Timeline(entries: [], policy: .after(.now.addingTimeInterval(15 * 60)))
        }
        guard let history else {
            return Timeline(entries: [], policy: .never)
        }

        let image = try? await TMDBImageLoader.loadImage(from: history.posterPath)
        let entry = HistoryInfo(
            date: .now,
            systemImage: image,
            color: image == nil ? nil : ColorExtractor.getDominantColor(from: image!),
            history: .init(
                id: history.historyId,
                resultId: history.resultId,
                name: history.name,
                mediaType: history.mediaType,
                season: history.season,
                episode: history.episode,
                posterPath: history.posterPath,
                updatedAt: history.updatedAt
            )
        )

        return Timeline(
            entries: [entry],
            policy: .never
        )
    }
}

struct MostRecentWidget: Widget {

    let kind: String = "MostRecentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MostRecentProvider()) { entry in

            var color: Color? = nil
            if let c = entry.color {
                #if os(iOS)
                color = Color(uiColor: c)
                #elseif os(macOS)
                color = Color(nsColor: c)
                #endif
            }

            return MostRecentWidgetView(entry: entry)
                .contentMargins(.zero)
                .containerBackground(
                    color ?? .primary,
                    for: .widget
                )
                .background(.clear)
#if os(macOS)
                .widgetURL(entry.watchURL)
#endif
        }
        .configurationDisplayName("Continue Watching")
        .description("Pick up where you left off in ComfyCinema.")
        .supportedFamilies([
            .systemSmall
        ])
    }
}

#Preview(as: .systemSmall) {
    MostRecentWidget()
} timeline: {
    let image = try? await TMDBImageLoader.loadImage(from: "/9JCQtDCSpPR2ld55yNlEg1VwcQo.jpg")
    HistoryInfo(
        date: .now,
        systemImage: image,
        color: image == nil ? nil : ColorExtractor.getDominantColor(from: image!),
        history: History(
            resultId: 969681,
            name: "Spider-Man: Brand New Day",
            mediaType: .movie,
            posterPath: "/9JCQtDCSpPR2ld55yNlEg1VwcQo.jpg",
            updatedAt: .now
        )
    )
}


#Preview(as: .systemSmall) {
    MostRecentWidget()
} timeline: {
    let posterPath = "/4ssDuvEDkSArWEdyBl2X5EHvYKU.jpg"

    let image = try? await TMDBImageLoader.loadImage(
        from: posterPath
    )

    HistoryInfo(
        date: .now,
        systemImage: image,
        color: image == nil ? nil : ColorExtractor.getDominantColor(from: image!),
        history: History(
            resultId: 99861,
            name: "Avengers: Age of Ultron",
            mediaType: .movie,
            posterPath: posterPath,
            updatedAt: .now
        )
    )
}


#Preview(as: .systemSmall) {
    MostRecentWidget()
} timeline: {
    let posterPath = "/u6tICVagGwukuFPr0qBUwOqCKSn.jpg"

    let image = try? await TMDBImageLoader.loadImage(
        from: posterPath
    )

    HistoryInfo(
        date: .now,
        systemImage: image,
        color: image == nil ? nil : ColorExtractor.getDominantColor(from: image!),
        history: History(
            resultId: 61889,
            name: "Marvel's Daredevil",
            mediaType: .episode,
            season: 1,
            episode: 1,
            posterPath: posterPath,
            updatedAt: .now
        )
    )
}


#Preview(as: .systemSmall) {
    MostRecentWidget()
} timeline: {
    let posterPath = "/4ptpmWBVD9HY9hMh8Cbs6SMiy7p.jpg"

    let image = try? await TMDBImageLoader.loadImage(
        from: posterPath
    )

    HistoryInfo(
        date: .now,
        systemImage: image,
        color: image == nil ? nil : ColorExtractor.getDominantColor(from: image!),
        history: History(
            resultId: 60573,
            name: "Silicon Valley",
            mediaType: .episode,
            season: 2,
            episode: 4,
            posterPath: posterPath,
            updatedAt: .now
        )
    )
}
