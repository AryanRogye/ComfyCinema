//
//  Home.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/16/26.
//

import SwiftUI
import SwiftData

private enum HomeOption: String, CaseIterable {
    case moviesAndTVShows = "Discover"
    case liveTV = "Live TV"
}

public struct Home: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(\.modelContext) var modelContext

    @State private var error: String?
    @State private var showError: Bool = false

    public init() {}


    @AppStorage("home.homeOption")
    private var homeOption: HomeOption = .moviesAndTVShows

    public var body: some View {
        Group {
            switch homeOption {
            case .moviesAndTVShows:
                MoviesAndTVShowsView(
                    error: $error,
                    showError: $showError
                )
            case .liveTV:
                LiveTVView(
                    error: $error,
                    showError: $showError
                )
            }
        }
        .navigationTitle("Home")
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .toolbar {

#if os(macOS)
            ToolbarSpacer(.flexible)
#endif

            ToolbarItemGroup(placement: .principal) {
                Picker("", selection: $homeOption) {
                    ForEach(HomeOption.allCases, id: \.self) { option in
                        Text(option.rawValue)
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }
        }
        .task {
            do {
                try await tmdbManager.trending()
                try? await Task.sleep(for: .seconds(1))
                try await tmdbManager.nowPlaying()
                try? await Task.sleep(for: .seconds(1))
                try await tmdbManager.popularTV()
                try? await Task.sleep(for: .seconds(1))
                try await tmdbManager.popularMovie()
                try? await Task.sleep(for: .seconds(1))
                try await tmdbManager.topRatedTV()
                try? await Task.sleep(for: .seconds(1))
                try await tmdbManager.topRatedMovie()
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}
