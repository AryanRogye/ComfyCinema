//
//  VersionedSchemaDeviceDetail.swift
//  MoviesAPIData
//
//  Created by Aryan Rogye on 11/21/26.
//

import SwiftData

protocol VersionedSchemaDeviceDetail: VersionedSchema {
    static var didChangeOnPhone: Bool { get }
    static var didChangeOnMac: Bool { get }
}
