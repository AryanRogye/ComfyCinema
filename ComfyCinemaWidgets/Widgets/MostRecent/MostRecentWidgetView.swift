//
//  MostRecentWidgetView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 11/9/26.
//

import SwiftUI
import WidgetKit
import MoviesAPIData

struct MostRecentWidgetView : View {

    let entry: MostRecentProvider.Entry
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

            RecentHistoryBackground(systemImage: entry.systemImage)

            HStack {

                RecentHistoryDescription(
                    entry: entry,
                    foregroundColor: foregroundColor
                )

                Spacer()

                MostRecentHistoryPlayButton(
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

// MARK: - HistoryImage
private struct RecentHistoryImage: View {

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

// MARK: - HistoryBackground
private struct RecentHistoryBackground: View {

    let systemImage: SystemImage?
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    var linearGradientColor: Color {
        return .black
    }

    var body: some View {
        ZStack {
            RecentHistoryImage(image: systemImage)

            RecentHistoryImage(image: systemImage)
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

// MARK: - HistoryDescription
private struct RecentHistoryDescription: View {

    let entry: MostRecentProvider.Entry
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

// MARK: - Most Recent History

private struct MostRecentHistoryPlayButton: View {

    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    let entry: MostRecentProvider.Entry
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
