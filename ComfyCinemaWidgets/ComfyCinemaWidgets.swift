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
import AppIntents

#if os(macOS)
typealias SystemImage = NSImage
#elseif os(iOS)
typealias SystemImage = UIImage
#endif

struct HistoryInfo: TimelineEntry {
    let date: Date
    let systemImage: SystemImage?
    let color: SystemColor?
    let history: History
}

private struct HistorySnapshot: Sendable {
    let resultId: Int
    let name: String
    let mediaType: HistoryMediaType
    let posterPath: String?
    let season: Int?
    let episode: Int?
    let updatedAt: Date
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "ComfyCinema Configuration"
}

struct Provider: AppIntentTimelineProvider {

    static func loadImage(from posterPath: String?) async throws -> SystemImage? {
        guard let posterPath else { return nil }
        guard let url = URL(    string: "https://image.tmdb.org/t/p/w500\(posterPath)") else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)

        print("Poster response:", response)
        print("Poster bytes:", data.count)

#if os(macOS)
        return NSImage(data: data)
#else
        return UIImage(data: data)
#endif
    }

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


    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> HistoryInfo {
        let image = try? await Self.loadImage(from: "/9JCQtDCSpPR2ld55yNlEg1VwcQo.jpg")
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

    @MainActor
    private func fetchLatestHistory(
        from container: ModelContainer
    ) throws -> HistorySnapshot? {
        let context = container.mainContext

        var descriptor = FetchDescriptor<History>(
            sortBy: [
                SortDescriptor(\.watchedAt, order: .reverse)
            ]
        )
        descriptor.fetchLimit = 1

        guard let history = try context.fetch(descriptor).first else {
            return nil
        }

        return HistorySnapshot(
            resultId: history.resultId,
            name: history.name,
            mediaType: history.mediaType,
            posterPath: history.posterPath,
            season: history.season,
            episode: history.episode,
            updatedAt: history.watchedAt
        )
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<HistoryInfo> {

        guard let identifier = Bundle.main.object(
            forInfoDictionaryKey: "AppGroup"
        ) as? String else {
            fatalError("AppGroup not found")
        }
        if identifier.isEmpty {
            fatalError("AppGroup Empty")
        }


        let history: HistorySnapshot?
        do {
            history = try await MainActor.run {
                let schema = Schema(versionedSchema: MoviesSchemaV2.self)
                let configuration = ModelConfiguration(
                    schema: schema,
                    groupContainer: .identifier(identifier),
                    cloudKitDatabase: .none
                )
                let container = try ModelContainer(for: schema, configurations: configuration)
                return try fetchLatestHistory(from: container)
            }
        } catch {
            print("Could not load widget history:", error)
            return Timeline(entries: [], policy: .after(.now.addingTimeInterval(15 * 60)))
        }
        guard let history else {
            return Timeline(entries: [], policy: .never)
        }

        let image = try? await Self.loadImage(from: history.posterPath)
        let entry = HistoryInfo(
            date: .now,
            systemImage: image,
            color: image == nil ? nil : ColorExtractor.getDominantColor(from: image!),
            history: .init(
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

    var foregroundColor: Color {
        if widgetRenderingMode == .accented {
            return .white
        }
        if backgroundColor.isDark() {
            return .white
        } else {
            return .black
        }
    }

    var oppositeForegroundColor: Color {
        if widgetRenderingMode == .accented {
            return .black
        }
        if backgroundColor.isDark() {
            return .black
        } else {
            return .white
        }
    }

    var body: some View {
        ZStack {

            backgroundColor.ignoresSafeArea()

            VStack {
                HistoryImage(image: entry.systemImage)

                HStack {
                    Text(entry.history.name)
                        .font(
                            .system(
                                size: 11,
                                weight: .medium,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(foregroundColor)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)

                    Spacer()

                    Button {} label: {
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
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

private struct HistoryImage: View {

    let image: SystemImage?

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
#elseif os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                    .clipped()
                    .clipShape(.rect(cornerRadius: 12))
#endif
            }
        } else {
            Text("No Image Found")
        }
    }
}

struct ComfyCinemaWidgets: Widget {

    let kind: String = "ComfyCinemaWidgets"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in

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
        }
        .supportedFamilies([
            .systemSmall
        ])
    }
}

#Preview(as: .systemSmall) {
    ComfyCinemaWidgets()
} timeline: {
    let image = try? await Provider.loadImage(from: "/9JCQtDCSpPR2ld55yNlEg1VwcQo.jpg")
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

    let image = try? await Provider.loadImage(
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

    let image = try? await Provider.loadImage(
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
            posterPath: posterPath,
            updatedAt: .now
        )
    )
}
