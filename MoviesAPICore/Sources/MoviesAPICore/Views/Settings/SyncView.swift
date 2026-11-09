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

    @Environment(CloudKitManager.self) var cloudKitManager
    @Environment(\.modelContext) private var ctx
    @Query private var history: [History]

    @State private var error: String?
    @State private var showError: Bool = false
    @State private var iCloudStatus: CKAccountStatus?

    var body: some View {
        Form {
            Button("Sync With iCloud") {
                Task {
                    do {
                        if cloudKitManager.enabledCloudSave {
                            if let hist = try await cloudKitManager.resolveHistory(from: ctx) {

                                for existing in history {
                                    ctx.delete(existing)
                                }
                                for item in hist {
                                    ctx.insert(item)
                                }
                                try ctx.save()
                            }
                        }
                    } catch {
                        self.error = error.localizedDescription
                        self.showError = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                switch iCloudStatus {
                case .available:
                    Image(systemName: "checkmark")
                case .restricted, .couldNotDetermine, .noAccount, .temporarilyUnavailable:
                    Image(systemName: "xmark")
                case nil:
                    Text("Not Loaded")
                case .some(_):
                    Image(systemName: "xmark")
                }
            }
        }
        .task {
            do {
                self.iCloudStatus = try await cloudKitManager.checkConnection()
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}
