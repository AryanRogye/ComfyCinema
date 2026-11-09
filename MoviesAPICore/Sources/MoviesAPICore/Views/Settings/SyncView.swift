//
//  SyncView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/7/26.
//

import SwiftUI
import CloudKit
import SwiftData

struct SyncView: View {

    @Environment(CloudKitSyncService.self) var cloudKitSync
    @Environment(\.modelContext) private var ctx
    @Query private var history: [History]

    @State private var error: String?
    @State private var showError: Bool = false

    var body: some View {
        @Bindable var cloudKitSync = cloudKitSync
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.yellow)

                    Text("iCloud Sync")
                        .font(.title2.bold())

                    Text("Keep your watch history up to date across all your Apple devices.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowBackground(Color.clear)
            }

            Toggle(isOn: $cloudKitSync.enabledCloudSave) {
                Label("Sync Watch History", systemImage: "clock.arrow.circlepath")
            }

            if cloudKitSync.enabledCloudSave {
                if let status = cloudKitSync.resolveStatus {
                    Text(status)
                }
                Button("Sync With iCloud") {
                    Task {
                        do {
                            try await cloudKitSync.saveToCloud()
                        } catch {
                            self.error = error.localizedDescription
                            self.showError = true
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
#if os(macOS)
        .scrollContentBackground(.hidden)
        .background(.clear)
#endif
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
    }
}
