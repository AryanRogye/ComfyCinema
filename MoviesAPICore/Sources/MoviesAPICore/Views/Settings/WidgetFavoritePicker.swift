#if os(macOS)

import SwiftUI
import SwiftData
import MoviesAPIData

struct WidgetFavoritePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Favorite.name) private var favorites: [Favorite]
    @State private var search = ""
    @State private var matches: [Favorite] = []
    let slotNumber: Int
    let selectedID: Int?
    let select: (Int) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if favorites.isEmpty {
                    ContentUnavailableView(
                        "No favorites yet",
                        systemImage: "star",
                        description: Text(
                            "Add movies or shows to your favorites in Library, then choose them here."
                        )
                    )
                } else if matches.isEmpty {
                    ContentUnavailableView.search(text: search)
                } else {
                    List(matches, id: \.persistentModelID) { favorite in
                        Button {
                            select(favorite.id)
                        } label: {
                            HStack(spacing: 12) {
                                WidgetFavoritePoster(path: favorite.posterPath)
                                    .frame(width: 36, height: 54)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(verbatim: favorite.name)
                                        .fontWeight(.medium)
                                    Text(
                                        favorite.mediaType == "movie" ? "Movie" : "TV show",
                                        bundle: #bundle
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if favorite.id == selectedID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                        .accessibilityLabel("Selected")
                                }
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $search, prompt: "Search favorites")
            .navigationTitle("Choose favorite for slot \(slotNumber)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
            .task(id: search) {
                matches = favorites.filter {
                    search.isEmpty || $0.name.localizedStandardContains(search)
                }
            }
            .onChange(of: favorites.map(\.persistentModelID)) {
                matches = favorites.filter {
                    search.isEmpty || $0.name.localizedStandardContains(search)
                }
            }
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 420, idealHeight: 540)
    }
}

#endif
