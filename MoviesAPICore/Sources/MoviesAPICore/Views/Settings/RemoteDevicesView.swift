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
        List {
            if let error = remoteClient.error {
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
            }
            ForEach(remoteClient.discoveredDevices, id: \.self) { device in
                Button {
                    showingDetail = device
                } label: {
                    Text(device.service.name)
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .sheet(item: $showingDetail) { item in
            RemoteDeviceDetailView(server: item) { didConnect in
                do {
                    try remoteClient.connect(to: item)
                } catch {
                    self.error = error.localizedDescription
                    self.showError = true
                }
                self.showingDetail = nil
            }
        }
    }
}

struct RemoteDeviceDetailView: View {

    let server: ResolvedServer
    /// returns back if we did connect or cancel
    let onDismiss: (Bool) -> Void

    var isValidConnection: Bool {
        server.hostname != nil && server.port != nil
    }

    var body: some View {
        Form {
            Text(server.service.name)
            Text(server.hostname ?? "Unknown Hostname")
            Text("\(server.port, default: "Unknown Port")")

            Button("Connect") {
                onDismiss(true)
            }
        }
        .formStyle(.grouped)
    }
}

#endif
