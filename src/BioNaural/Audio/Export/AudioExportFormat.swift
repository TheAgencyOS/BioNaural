// AudioExportFormat.swift
// BioNaural
//
// Container audio formats supported by the offline composition renderer.
// v1 ships WAV only (decision recorded in the export plan). M4A/AAC is
// planned for v2 — the enum keeps the door open without requiring a
// rewrite. MP3 is intentionally excluded: AVFoundation has no native
// MP3 encoder and pulling in LAME adds GPL/LGPL friction with no real
// gain over M4A.
//
// No SwiftUI imports. Pure value types. All numeric values come from
// Theme.Audio.Export tokens.

import AVFoundation

public enum AudioExportFormat: String, CaseIterable, Identifiable, Sendable {

    case wav

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .wav: return "WAV"
        }
    }

    public var fileExtension: String {
        switch self {
        case .wav: return "wav"
        }
    }

    /// Settings dictionary suitable for `AVAudioFile(forWriting:settings:)`.
    /// All sample-rate / channel-count values flow through Theme tokens.
    public var audioSettings: [String: Any] {
        switch self {
        case .wav:
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: Theme.Audio.Export.sampleRate,
                AVNumberOfChannelsKey: Int(Theme.Audio.Export.channelCount),
                AVLinearPCMBitDepthKey: Theme.Audio.Export.wavBitDepth,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        }
    }
}
