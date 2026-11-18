//
//  RemoteServerView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/17/26.
//

#if os(macOS)
import SwiftUI

struct RemoteServerView: View {

    @Environment(RemoteServer.self) private var remoteServer
    @State private var editedIP = ""
    @State private var editedPort = ""
    @State private var editedName = ""
    @State private var validationError: String?

    private var hasChanges: Bool {
        editedIP != remoteServer.remoteControlIp ||
        editedPort != String(remoteServer.remoteControlPort) ||
        editedName != remoteServer.remoteControlName
    }

    var body: some View {
        @Bindable var remoteServer = remoteServer
        Form {
            Toggle("Enable Remote Server", isOn: $remoteServer.enableRemoteControl)
                .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 12) {
                TextField(
                    "Name:",
                    text: $editedName,
                    prompt: Text(remoteServer.advertisedName)
                )
                .textFieldStyle(.roundedBorder)

                TextField(
                    "Host:",
                    text: $editedIP,
                    prompt: Text("127.0.0.1")
                )
                .textFieldStyle(.roundedBorder)

                TextField(
                    "Port:",
                    text: $editedPort,
                    prompt: Text("1080")
                )
                .textFieldStyle(.roundedBorder)

                if let error = validationError ?? remoteServer.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Spacer()

                Button("Save") {
                    saveSettings()
                }
                .disabled(!hasChanges)
            }
        }
        .onAppear {
            editedIP = remoteServer.remoteControlIp
            editedPort = String(remoteServer.remoteControlPort)
            editedName = remoteServer.remoteControlName
        }
        .formStyle(.grouped)
#if os(macOS)
        .scrollContentBackground(.hidden)
        .background(.clear)
#endif
    }

    private func saveSettings() {
        guard let port = Int(editedPort),
              (1024...65535).contains(port) else {
            validationError = "Port must be between 1024 and 65535."
            return
        }

        guard !editedIP.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationError = "Host cannot be empty."
            return
        }

        validationError = nil

        remoteServer.remoteControlIp = editedIP
        remoteServer.remoteControlPort = port
        remoteServer.remoteControlName = editedName
    }
}

#endif
