//
//  CloudSavePrompt.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/8/26.
//

import Defaults
import SwiftUI

struct CloudSavePrompt: View {

    @Bindable var cloudKitManager: CloudKitManager

    @Default(.hasShownCloudSavePrompt)
    private var hasShownCloudSavePrompt

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.blue)

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

            Section {
                Toggle(isOn: $cloudKitManager.enabledCloudSave) {
                    Label("Sync Watch History", systemImage: "clock.arrow.circlepath")
                }
            } footer: {
                Text("Your watch history is stored privately in your iCloud account.")
            }

            Section {
                Button {
                    hasShownCloudSavePrompt = true
                } label: {
                    Text("Save Changes")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }
        }
        .formStyle(.grouped)
    }
}
