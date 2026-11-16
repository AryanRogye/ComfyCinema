// macOS favorites widget configuration.
#if os(macOS)
import SwiftUI
import SwiftData
import WidgetKit
import MoviesAPIData

private enum FavoriteSlot: Int, CaseIterable, Identifiable {
    case first, second, third, fourth
    var id: Int {
        rawValue
    }
    var number: Int {
        rawValue + 1
    }
    var keyPath: ReferenceWritableKeyPath<WidgetFavorites, Int?> {
        switch self {
        case .first: \.favorite1ID
        case .second: \.favorite2ID
        case .third: \.favorite3ID
        case .fourth: \.favorite4ID
        }
    }
}

struct WidgetFavoriteConfigView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Favorite.name) private var favorites: [Favorite]
    @State private var configuration: WidgetFavorites?
    @State private var activeSlot: FavoriteSlot?
    @State private var loadError: String?
    @State private var saveError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Favorites widget", bundle: #bundle)
                        .font(.largeTitle.bold())
                    Text(
                        "Choose up to four favorites. Click a slot to change what appears on your widget.",
                        bundle: #bundle
                    )
                    .foregroundStyle(.secondary)
                }
                if let loadError {
                    ContentUnavailableView {
                        Label(
                            "Unable to load widget settings",
                            systemImage: "exclamationmark.triangle"
                        )
                    } description: {
                        Text(verbatim: loadError)
                    } actions: {
                        Button("Retry") {
                            loadConfiguration()
                        }
                    }
                } else if let configuration {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 16
                    ) {
                        ForEach(FavoriteSlot.allCases) { slot in
                            let id = configuration[keyPath: slot.keyPath]
                            let favorite = favorites.first { $0.id == id }
                            WidgetFavoriteSlotView(
                                number: slot.number,
                                favorite: favorite,
                                isMissing: id != nil && favorite == nil
                            ) {
                                activeSlot = slot
                            } clear: {
                                save(nil, in: slot)
                            }
                        }
                    }
                    Text(
                        "Changes save automatically and refresh the Favorites widget.",
                        bundle: #bundle
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                } else {
                    ProgressView("Loading widget settings…")
                }
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle("Favorites widget")
        .task {
            loadConfiguration()
        }
        .sheet(item: $activeSlot) { slot in
            WidgetFavoritePicker(
                slotNumber: slot.number,
                selectedID: configuration?[keyPath: slot.keyPath]
            ) { id in
                save(id, in: slot)
            }
        }
        .alert(
            "Unable to save selection",
            isPresented: Binding(
                get: {
                    saveError != nil
                },
                set: { isPresented in
                    if !isPresented {
                        saveError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                saveError = nil
            }
        } message: {
            Text(verbatim: saveError ?? "")
        }
    }

    private func loadConfiguration() {
        loadError = nil
        do {
            var descriptor = FetchDescriptor<WidgetFavorites>()
            descriptor.fetchLimit = 1
            if let existing = try context.fetch(descriptor).first {
                configuration = existing
            } else {
                let created = WidgetFavorites()
                context.insert(created)
                do {
                    try context.save()
                    configuration = created
                } catch {
                    context.delete(created)
                    throw error
                }
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func save(_ id: Int?, in slot: FavoriteSlot) {
        guard let configuration else {
            return
        }
        let previous = configuration[keyPath: slot.keyPath]
        configuration[keyPath: slot.keyPath] = id
        do {
            try context.save()
            activeSlot = nil
            WidgetCenter.shared.reloadTimelines(ofKind: "FavoriteWidget")
        } catch {
            configuration[keyPath: slot.keyPath] = previous
            activeSlot = nil
            saveError = error.localizedDescription
        }
    }
}

#endif
