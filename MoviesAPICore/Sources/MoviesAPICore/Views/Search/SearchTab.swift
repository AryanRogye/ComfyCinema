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
    @Query private var searchQueries: [MoviesAPIData.SearchQuery]
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
        // Most recently inserted first (no timestamp on the model, so rely on insertion order).
        let all = Array(searchQueries.reversed())
        guard !text.isEmpty else { return all }
        return all.filter { $0.query.localizedCaseInsensitiveContains(text) }
    }

    public var body: some View {
        ScrollView {
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
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredSearchQueries) { query in
                        HStack {
                            Button {
                                searchText = query.query
                                submit()
                            } label: {
                                Label(query.query, systemImage: "clock.arrow.circlepath")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                modelContext.delete(query)
                            } label: {
                                Image(systemName: "xmark")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
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
        .safeAreaInset(edge: .top) {
            HStack(spacing: 4) {
                TextField("Search movies, TV, and people", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .submitLabel(.search)
                    .onSubmit { submit() }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .padding(.horizontal, 12)
                    .glassEffect(.clear, in: .rect(cornerRadius: 24))
                if focused || !tmdbManager.searchResults.isEmpty {
                    Image(systemName: "xmark")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 50, height: 50)
                        .glassEffect(.clear, in: Circle())
                        .onTapGesture {
                            focused = false
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .clipped()
            .padding(.bottom, 4)
            .padding(.horizontal)
            .animation(.smooth, value: focused)
        }
    }

    /// Saves the query to history unless an equal one (ignoring case) already exists.
    private func saveQuery(_ query: String) {
        let exists = searchQueries.contains {
            $0.query.caseInsensitiveCompare(query) == .orderedSame
        }
        guard !exists else { return }
        modelContext.insert(MoviesAPIData.SearchQuery(query: query))
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
                saveQuery(query)
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}
