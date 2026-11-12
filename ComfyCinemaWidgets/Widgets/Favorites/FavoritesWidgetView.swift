//
//  FavoritesWidgetView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 11/9/26.
//

/// TODO: Remove ifdefs and use entry seperate params
import SwiftUI
import WidgetKit
import MoviesAPIData

struct FavoritesWidgetView: View {

    let entry: FavoritesProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(spacing: 0) {
            if entry.favorite1 == nil && entry.favorite2 == nil
                && entry.favorite3 == nil && entry.favorite4 == nil {
                Link(destination: URL(string: "comfycinema://favorite")!) {
                    VStack(spacing: 8) {
                        Image(systemName: "star")
                            .font(.title2)
                        Text("Favorites unavailable")
                            .font(.headline)
                        Text("Open ComfyCinema to check your widget selections.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
            } else {
                switch family {
                case .systemSmall:
                    if let favorite1 = entry.favorite1 {
                        FavoriteWidgetView(favorite: favorite1)
                    } else {
                        Rectangle()
                    }
                case .systemMedium:
                    HStack(spacing: 0) {
                        if let favorite1 = entry.favorite1 {
                            FavoriteWidgetView(favorite: favorite1)
                        } else {
                            Rectangle()
                        }

                        if let favorite2 = entry.favorite2 {
                            FavoriteWidgetView(favorite: favorite2)
                        } else {
                            Rectangle()
                        }
                    }
                case .systemLarge:
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            if let favorite1 = entry.favorite1 {
                                FavoriteWidgetView(favorite: favorite1)
                            } else {
                                Rectangle()
                            }

                            if let favorite2 = entry.favorite2 {
                                FavoriteWidgetView(favorite: favorite2)
                            } else {
                                Rectangle()
                            }
                        }
                        HStack(spacing: 0) {
                            if let favorite3 = entry.favorite3 {
                                FavoriteWidgetView(favorite: favorite3)
                            } else {
                                Rectangle()
                            }

                            if let favorite4 = entry.favorite4 {
                                FavoriteWidgetView(favorite: favorite4)
                            } else {
                                Rectangle()
                            }
                        }
                    }
                default:
                    EmptyView()
                }
            }
        }
        .clipShape(.rect(cornerRadius: 12))
    }
}

private struct FavoriteWidgetView: View {

    let favorite: FavoriteContainer
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    var backgroundColor: Color {
        if widgetRenderingMode == .accented {
            return .clear
        }
        if let color = favorite.color {
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

            FavoriteBackground(systemImage: favorite.image)

            HStack {

                FavoriteDescription(
                    favorite: favorite,
                    foregroundColor: foregroundColor
                )

                Spacer()

                FavoritePlayButton(
                    favorite: favorite,
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
private struct FavoriteImage: View {

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
private struct FavoriteBackground: View {

    let systemImage: SystemImage?
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    var linearGradientColor: Color {
        return .black
    }

    var body: some View {
        ZStack {
            FavoriteImage(image: systemImage)

            FavoriteImage(image: systemImage)
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
private struct FavoriteDescription: View {

    let favorite: FavoriteContainer
    let foregroundColor: Color

    var body: some View {
        Text(favorite.favorite.name)
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
    }
}

// MARK: - Most Recent History

private struct FavoritePlayButton: View {

    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    let favorite: FavoriteContainer
    let foregroundColor: Color
    let oppositeForegroundColor: Color

    var body: some View {
        Link(destination: favorite.watchURL) {
            playIcon
        }
        .buttonStyle(.plain)
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
