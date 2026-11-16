//
//  StorageView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/3/26.
//

import SwiftUI
import WebKit

struct StorageView: View {

    @State private var librarySize: String = ""
    @State private var isClearing: Bool = false
    @State private var clearTask: Task<Void, Never>?

    var body: some View {
        Form {
            if !librarySize.isEmpty {
                Text(librarySize)
            }
            HStack {
                Button("Clear Data") {
                    clearData()
                }
                Spacer()

                if isClearing {
                    ProgressView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
#if os(macOS)
            ToolbarSpacer(.flexible)
#endif
        }
        .formStyle(.grouped)
#if os(macOS)
        .scrollContentBackground(.hidden)
        .background(.clear)
#endif
        .task {
            librarySize = iOSStorageStore.getLibrarySize()
        }
        .onDisappear {
            clearTask?.cancel()
            clearTask = nil
        }
    }

    private func clearData() {
        if isClearing { return }
        clearTask = Task {
            isClearing = true
            defer { isClearing = false }
            await WKWebsiteDataStore.default().removeData(
                ofTypes: [WKWebsiteDataTypeFetchCache],
                modifiedSince: .distantPast
            )
            librarySize = iOSStorageStore.getLibrarySize()
        }
    }
}
