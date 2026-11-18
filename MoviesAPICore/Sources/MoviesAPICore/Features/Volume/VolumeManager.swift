//
//  VolumeManager.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/17/26.
//

#if os(macOS)

import Foundation
import AVFoundation

@Observable
final class VolumeManager {
    var currentVolume: Float = 0

    init() {}

    public func setVolume(_ value: Float) {

        print("Received volume:", value)

        let percentage = Int((min(max(value, 0), 1) * 100).rounded())

        print("AppleScript percentage:", percentage)

        let script = NSAppleScript(
            source: "set volume output volume \(percentage)"
        )

        var error: NSDictionary?
        script?.executeAndReturnError(&error)

        if let error {
            print("Failed to set volume: \(error)")
            return
        }

        currentVolume = Float(percentage) / 100
    }

    // MARK: - Get System Volume (hard way)
    @concurrent
    public func getCurrentSystemVolume() async {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &defaultOutputDeviceID
        )

        guard status == noErr else {
            checkVolumeAppleScript()
            return
        }

        // Check if the device supports volume control
        guard hasVolumeControl(deviceID: defaultOutputDeviceID) else {
            checkVolumeAppleScript()
            return
        }

        propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var volume: Float32 = 0
        dataSize = UInt32(MemoryLayout<Float32>.size)

        let status2 = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &volume
        )

        guard status2 == noErr else {
            checkVolumeAppleScript()
            return
        }

        DispatchQueue.main.async {
            self.currentVolume = volume
        }
    }

    private func checkVolumeAppleScript() {
        let script = "output volume of (get volume settings)"
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            if let output = scriptObject.executeAndReturnError(&error).stringValue {
                if let vol = Float(output) {
                    self.currentVolume = vol / 100.0
                }
            }
        } else {
            self.currentVolume = 0
        }
    }

    private func hasVolumeControl(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        return AudioObjectHasProperty(deviceID, &propertyAddress)
    }
}
#endif
