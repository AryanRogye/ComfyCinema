//
//  PeopleDetailView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/19/26.
//

import SwiftUI

struct PeopleDetailView: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(PlaybackSession.self) var playbackSession
    @Environment(\.dismiss) var dismiss

    @Binding var displayServer: KTDisplayServer
    let result: KTSearchResult

    @State private var results: [KTSearchResult] = []
    @State private var error: String?
    @State private var showError: Bool = false

    @State private var searchResult: KTSearchResult?

    var body: some View {
        ScrollView {
            ForEach(results) { result in
                SearchResultsRow(result: result)
                    .onTapGesture {
                        playbackSession.stop()
                        searchResult = result
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                }
            }
        }
        .navigationDestination(item: $searchResult) { searchResult in
            WatchDetailView(result: searchResult)
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .task {
            do {
                results = try await tmdbManager.creditsForPerson(id: result.id)
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}
