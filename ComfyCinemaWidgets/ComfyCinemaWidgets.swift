//
//  ComfyCinemaWidgets.swift
//  ComfyCinemaWidgets
//
//  Created by Aryan Rogye on 11/9/26.
//

import WidgetKit
import SwiftUI
import SwiftData
import MoviesAPIData

internal struct HistoryInfo: TimelineEntry {
    let date: Date
    let systemImage: SystemImage?
    let color: SystemColor?
    let history: History

    var watchURL: URL {
        URL(string: "comfycinema://watch?id=\(history.id.uuidString)")!
    }
}

struct Provider: TimelineProvider {
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
        let image = try? await HistoryHelper.loadHistoryImage(from: "/9JCQtDCSpPR2ld55yNlEg1VwcQo.jpg")
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

        let image = try? await HistoryHelper.loadHistoryImage(from: history.posterPath)
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

private struct HistoryImage: View {

    let image: SystemImage?
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    var body: some View {
        if let image {
            GeometryReader { geo in
#if os(iOS)
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                    .clipped()
                    .clipShape(.rect(cornerRadius: 12))
                    .opacity(widgetRenderingMode == .accented ? 0.5 : 1)
#elseif os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                    .clipped()
                    .clipShape(.rect(cornerRadius: 12))
                    .opacity(widgetRenderingMode == .accented ? 0.5 : 1)
#endif
            }
        } else {
            Text("No Image Found")
        }
    }
}

private struct HistoryBackground: View {

    let systemImage: SystemImage?
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    var linearGradientColor: Color {
        return .black
    }

    var body: some View {
        ZStack {
            HistoryImage(image: systemImage)

            HistoryImage(image: systemImage)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .blur(radius: 15)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(
                                color: .clear,
                                location: 0.75
                            ),
                            .init(
                                color: linearGradientColor.opacity(
                                    widgetRenderingMode == .accented
                                    ? 0.3
                                    : 0.5
                                ),
                                location: 0.8
                            ),
                            .init(
                                color: linearGradientColor.opacity(
                                    widgetRenderingMode == .accented
                                    ? 0.5
                                    : 1
                                ),
                                location: 1
                            )
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipShape(.rect(cornerRadius: 12))

            LinearGradient(
                stops: [
                    .init(
                        color: .clear,
                        location: 0.75
                    ),
                    .init(
                        color: linearGradientColor.opacity(
                            widgetRenderingMode == .accented
                            ? 0.10
                            : 0.35
                        ),
                        location: 0.8
                    ),
                    .init(
                        color: linearGradientColor.opacity(
                            widgetRenderingMode == .accented
                            ? 0.25
                            : 0.65
                        ),
                        location: 1
                    ),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(.rect(cornerRadius: 12))
        }
    }
}

private struct HistoryDescription: View {

    let entry: Provider.Entry
    let foregroundColor: Color

    var body: some View {
        ViewThatFits {
            VStack(alignment: .leading) {
                Text(entry.history.name)
                    .font(
                        .system(
                            size: 7,
                            weight: .medium,
                            design: .default
                        )
                    )
                    .foregroundStyle(foregroundColor)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                if let season = entry.history.season, let episode = entry.history.episode {
                    Text("S\(season)E\(episode)")
                        .font(
                            .system(
                                size: 5,
                                weight: .bold,
                                design: .monospaced
                            )
                        )
                        .foregroundStyle(foregroundColor.opacity(0.5))
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }

            Text(entry.history.name)
                .font(
                    .system(
                        size: 7,
                        weight: .bold,
                        design: .default
                    )
                )
                .foregroundStyle(foregroundColor)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
        }
    }
}

private struct HistoryPlayButton: View {

    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    let entry: Provider.Entry
    let foregroundColor: Color
    let oppositeForegroundColor: Color

    var body: some View {
#if os(macOS)
        playIcon
#else
        Link(destination: entry.watchURL) {
            playIcon
        }
        .buttonStyle(.plain)
#endif
    }

    private var playIcon: some View {
        Circle()
            .fill(foregroundColor)
            .frame(width: 25, height: 25)
            .overlay {
                Image(systemName: "play.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(
                        widgetRenderingMode == .accented
                        ? .black
                        : oppositeForegroundColor
                    )
                    .blendMode(
                        widgetRenderingMode == .accented
                        ? .destinationOut
                        : .normal
                    )
            }
            .compositingGroup()
    }
}

struct ComfyCinemaWidgetsEntryView : View {

    var entry: Provider.Entry
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    var backgroundColor: Color {
        if widgetRenderingMode == .accented {
            return .clear
        }
        if let color = entry.color {
#if os(macOS)
            return Color(nsColor: color)
#elseif os(iOS)
            return Color(uiColor: color)
#endif
        } else {
            return .white
        }
    }

    var oppositeForegroundColor: Color {
        if widgetRenderingMode == .accented {
            return .white
        }
        return .black
    }

    var foregroundColor: Color {
        .white
    }

    var body: some View {
        ZStack {

            backgroundColor.ignoresSafeArea()

            HistoryBackground(systemImage: entry.systemImage)

            HStack {

                HistoryDescription(
                    entry: entry,
                    foregroundColor: foregroundColor
                )

                Spacer()

                HistoryPlayButton(
                    entry: entry,
                    foregroundColor: foregroundColor,
                    oppositeForegroundColor: oppositeForegroundColor
                )
            }
            .padding(4)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

struct ComfyCinemaWidgets: Widget {

    let kind: String = "ComfyCinemaWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in

            var color: Color? = nil
            if let c = entry.color {
                #if os(iOS)
                color = Color(uiColor: c)
                #elseif os(macOS)
                color = Color(nsColor: c)
                #endif
            }

            return ComfyCinemaWidgetsEntryView(entry: entry)
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
        .supportedFamilies([
            .systemSmall
        ])
    }
}

#Preview(as: .systemSmall) {
    ComfyCinemaWidgets()
} timeline: {
    let image = try? await HistoryHelper.loadHistoryImage(from: "/9JCQtDCSpPR2ld55yNlEg1VwcQo.jpg")
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
    ComfyCinemaWidgets()
} timeline: {
    let posterPath = "/4ssDuvEDkSArWEdyBl2X5EHvYKU.jpg"

    let image = try? await HistoryHelper.loadHistoryImage(
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
    ComfyCinemaWidgets()
} timeline: {
    let posterPath = "/u6tICVagGwukuFPr0qBUwOqCKSn.jpg"

    let image = try? await HistoryHelper.loadHistoryImage(
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
    ComfyCinemaWidgets()
} timeline: {
    let posterPath = "/4ptpmWBVD9HY9hMh8Cbs6SMiy7p.jpg"

    let image = try? await HistoryHelper.loadHistoryImage(
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
