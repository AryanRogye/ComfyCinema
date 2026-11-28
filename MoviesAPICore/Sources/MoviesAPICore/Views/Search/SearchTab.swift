//
//  SearchTab.swift
//  MoviesAPIClient
//

import SwiftUI
import SwiftData
import MoviesAPIData

public struct SearchTab: View {

    @Environment(TMDBManager.self) private var tmdbManager
    @Environment(\.modelContext) private var modelContext
    /// Most recent first. Rows saved before `date` existed have nil dates and sort last.
    @Query(sort: \MoviesAPIData.SearchQuery.date, order: .reverse)
    private var searchQueries: [MoviesAPIData.SearchQuery]
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false

    @State private var error: String?
    @State private var showError: Bool = false
    @State private var didSubmit: Bool = false
    @FocusState private var focused

    public init() {}

    /// All saved queries when `searchText` is empty, otherwise only those whose text contains it.
    private var filteredSearchQueries: [MoviesAPIData.SearchQuery] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return searchQueries }
        return searchQueries.filter { $0.query.localizedCaseInsensitiveContains(text) }
    }

    public var body: some View {
        ScrollView {
            SearchTextField(
                searchText: $searchText,
                focused: $focused,
                showXMark: focused || !tmdbManager.searchResults.isEmpty,
                onSubmit: submit
            )

            if tmdbManager.searchResults.isEmpty && didSubmit {
                ContentUnavailableView.search
            }
            else if didSubmit {
                SearchResultsView(searchResults: tmdbManager.searchResults) {
                    focused = false
                }
            } else if filteredSearchQueries.isEmpty {
                ContentUnavailableView(
                    "No Recent Searches",
                    systemImage: "clock",
                    description: Text("Your searches will show up here.")
                )
            } else {
                RecentSearchQueries(queries: filteredSearchQueries) { query in
                    searchText = query
                    submit()
                }
            }
        }
        .navigationTitle("Search")
        .onChange(of: searchText) { _, newValue in
            didSubmit = false
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .onTapGesture {
            focused = false
        }
        .onDisappear {
            focused = false
        }
    }

    private func submit() {
        guard !searchText.isEmpty else { return }
        guard !isSearching else { return }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            tmdbManager.clearSearchResults()
            return
        }

        isSearching = true
        Task {
            defer { isSearching = false }
            do {
                try await tmdbManager.search(query)
                didSubmit = true
                if let existing = searchQueries.first(where: {
                    $0.query.caseInsensitiveCompare(query) == .orderedSame
                }) {
                    // Bump it back to the top.
                    existing.date = .now
                    return
                }
                modelContext.insert(MoviesAPIData.SearchQuery(query: query))

            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}

struct RecentSearchQueries: View {

    @Environment(\.modelContext) private var modelContext
    let queries: [MoviesAPIData.SearchQuery]
    let onSubmit: (String) -> Void


    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(queries.enumerated()), id: \.element.id) { index, query in
                HStack {
                    Button {
                        onSubmit(query.query)
                    } label: {
                        HStack {
                            Text(query.query)
                                .foregroundStyle(.primary)
                                .font(.body.weight(.semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if let date = query.date {
                                dateView(date)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)

                    Button {
                        modelContext.delete(query)
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                            .font(.caption.weight(.semibold))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .frame(minHeight: 44)
                .padding(.horizontal)

                if index < queries.count - 1 {
                    Divider()
                        .padding(.leading)
                }
            }
        }
    }

    private func dateView(_ date: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in

            let seconds = max(0, Int(context.date.timeIntervalSince(date)))
            let minutes = seconds / 60
            let hours = minutes / 60

            let calendar = Calendar.current

            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: date),
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

    }
}
