// RenderProgress.swift
// BioNaural
//
// MainActor-isolated observable that publishes the offline render's
// progress to SwiftUI views. The render task runs on a detached
// background task; it hops to MainActor to mutate this object so
// SwiftUI's @Observable tracking sees coherent updates.
//
// No SwiftUI imports — Observation is a separate framework.

import AVFoundation
import Observation

@MainActor
@Observable
public final class RenderProgress {

    public private(set) var framesRendered: AVAudioFrameCount = 0
    public private(set) var totalFrames: AVAudioFrameCount = 0

    public init() {}

    public var fraction: Double {
        guard totalFrames > 0 else { return 0 }
        return min(1.0, Double(framesRendered) / Double(totalFrames))
    }

    public func setTotal(_ total: AVAudioFrameCount) {
        totalFrames = total
        framesRendered = 0
    }

    public func update(rendered: AVAudioFrameCount) {
        framesRendered = rendered
    }
}
