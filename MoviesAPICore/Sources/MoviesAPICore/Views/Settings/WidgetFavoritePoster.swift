#if os(macOS)

import SwiftUI
import SwiftData
import MoviesAPIData

struct WidgetFavoritePoster: View {
    let path: String?
    var body: some View {
        AsyncImage(url: path.flatMap { URL(string: "https://image.tmdb.org/t/p/w185\($0)") }) {
            image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .accessibilityHidden(true)
    }
}
#endif
