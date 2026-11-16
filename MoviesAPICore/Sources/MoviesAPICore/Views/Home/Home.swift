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
                .ignoresSafeArea(edges: .top)
            case .liveTV:
                LiveTVView(
                    error: $error,
                    showError: $showError
                )
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
#if os(macOS)
        .navigationTitle("Home")
#endif
        .toolbarBackground(.hidden, for: .automatic)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                Text("Home")
                    .font(.title2)
                    .fontWeight(.bold)
                    .fixedSize()
                    .frame(minWidth: 100, alignment: .leading)
            }
            .sharedBackgroundVisibility(.hidden)
#endif

#if os(macOS)
            ToolbarSpacer(.flexible)
#endif
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("", selection: $homeOption) {
                    ForEach(HomeOption.allCases, id: \.self) { option in
                        Text(option.rawValue)
                            .tag(option)
                            .foregroundStyle(.yellow)
                    }
                }
                .pickerStyle(.menu)
                .tint(.yellow)
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
