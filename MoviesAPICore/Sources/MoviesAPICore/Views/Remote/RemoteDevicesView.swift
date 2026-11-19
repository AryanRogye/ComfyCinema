//
//  RemoteDevicesView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/16/26.
//

#if os(iOS)

import SwiftUI

struct RemoteDevicesView: View {

    @Environment(RemoteClient.self) var remoteClient
    @State private var showingDetail: ResolvedServer?
    @State private var error: String?
    @State private var showError: Bool = false

    var body: some View {
        ScrollView {
            RemoteClientView()

            VStack {
                if let error = remoteClient.error {
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                }

                Text("Devices")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(remoteClient.discoveredDevices, id: \.self) { device in
                    Button {
                        showingDetail = device
                    } label: {
                        HStack {
                            Image(systemName: "tv")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(width: 48, height: 48)
                                .background(
                                    .white.opacity(0.07),
                                    in: .rect(cornerRadius: 14)
                                )

                            Text(device.service.name)
                                .font(.body)
                                .foregroundStyle(.white)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(white: 0.12))
                        }
                        .contentShape(.rect)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .sheet(item: $showingDetail) { item in
            RemoteDeviceDetailView(server: item) {
                connect(item: item)
            } alwaysConnectSelected: {
                remoteClient.setAlwaysConnect(to: item)
                connect(item: item)
            }
            .presentationDetents([.medium])
        }
    }
    private func connect(item: ResolvedServer) {
        do {
            try remoteClient.connect(to: item)
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
        self.showingDetail = nil
    }
}

struct RemoteDeviceDetailView: View {

    let server: ResolvedServer
    /// returns back if we did connect or cancel
    let onDismiss: () -> Void
    let alwaysConnectSelected: () -> Void

    var isValidConnection: Bool {
        server.hostname != nil && server.port != nil
    }

    var body: some View {
        Form {
            Section("Information") {
                LabeledContent("Name", value: server.service.name)
                LabeledContent("HostName", value: server.hostname ?? "Unknown Hostname")
                LabeledContent("Port", value: "\(server.port, default: "Unknown Port")")
            }
            Section {
                Button {
                    alwaysConnectSelected()
                } label: {
                    Text("Always Connect")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
            } footer: {
                Text("Automatically connect to this device when it's available.")
                    .multilineTextAlignment(.center)
            }

            Section {
                Button {
                    onDismiss()
                } label: {
                    Text("Connect")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
            }
        }
        .formStyle(.grouped)
        .listStyle(.insetGrouped)
        .padding(.vertical)
    }
}

#endif
