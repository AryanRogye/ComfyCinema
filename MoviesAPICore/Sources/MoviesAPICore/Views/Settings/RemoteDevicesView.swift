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

    var body: some View {
        List(remoteClient.discoveredDevices, id: \.self) { device in
            Text(device.name)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
