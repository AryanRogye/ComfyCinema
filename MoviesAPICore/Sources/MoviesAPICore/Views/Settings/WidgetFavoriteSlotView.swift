#if os(macOS)

import SwiftUI
import SwiftData
import MoviesAPIData

struct WidgetFavoriteSlotView: View {
    let number: Int
    let favorite: Favorite?
    let isMissing: Bool
    let choose: () -> Void
    let clear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Slot \(number)", bundle: #bundle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if favorite != nil || isMissing {
                    Button(action: clear) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Clear slot \(number)")
                    .accessibilityLabel("Clear slot \(number)")
                }
            }
            Button(action: choose) {
                HStack(spacing: 14) {
                    WidgetFavoritePoster(path: favorite?.posterPath)
                        .frame(width: 68, height: 102)
                    VStack(alignment: .leading, spacing: 6) {
                        if let favorite {
                            Text(verbatim: favorite.name)
                                .font(.headline)
                                .lineLimit(3)
                            Text(
                                favorite.mediaType == "movie" ? "Movie" : "TV show",
                                bundle: #bundle
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "plus.circle")
                                .font(.title2)
                                .foregroundStyle(.tint)
                            Text(
                                isMissing ? "Choose a replacement" : "Choose a favorite",
                                bundle: #bundle
                            )
                            .font(.headline)
                            if isMissing {
                                Text(
                                    "This title is no longer in your favorites.",
                                    bundle: #bundle
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Choose a favorite for slot \(number)")
            .accessibilityLabel("Slot \(number): \(favorite?.name ?? "Choose a favorite")")
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }
}

#endif
