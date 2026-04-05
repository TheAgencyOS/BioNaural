// BodyMusicRecorder.swift
// BioNaural
//
// Captures periodic snapshots of live audio parameters during a session,
// producing an adaptation timeline that enables faithful "Body Music" replay.
// Descoped for v1: record and replay only (no editing, no sharing).

import Foundation
import BioNauralShared
import OSLog

// MARK: - Recorder Configuration

/// Configuration constants for snapshot capture during Body Music recording.
///
/// All timing and capacity values are centralised here — nothing is hardcoded
/// inside the actor.
enum RecorderConfig {

    /// How often a snapshot is captured (seconds).
    static let snapshotIntervalSeconds: TimeInterval = 5.0

    /// Maximum snapshots per session (1 hour at 5-second intervals).
    static let maxSnapshotsPerSession: Int = 720

    /// Whether timeline data is compressed before storage.
    static let compressionEnabled: Bool = true

    /// Date format used to auto-generate a default track name from the
    /// session's start date.
    static let defaultTrackNameFormat: String = "yyyy-MM-dd HH:mm"
}

// MARK: - Protocol

/// Recording interface for capturing audio-parameter snapshots during
/// a live Body Music session.
///
/// Protocol-based to support mock implementations in previews and tests,
/// per the project's DI architecture.
public protocol BodyMusicRecorderProtocol: AnyObject, Sendable {

    /// Begins capturing snapshots from the given audio parameter store.
    func startRecording(audioParameters: AudioParameters) async

    /// Updates the heart rate value stamped onto subsequent snapshots.
    func updateHeartRate(_ hr: Double) async

    /// Stops recording and returns all captured snapshots.
    func stopRecording() async -> [AdaptationSnapshot]
}

// MARK: - BodyMusicRecorder

/// Captures periodic audio-parameter snapshots during a live session.
///
/// Start the recorder when a session begins. Every `snapshotIntervalSeconds`
/// the actor reads the current values from the lock-free `AudioParameters`
/// store and appends an `AdaptationSnapshot`. When the session ends, call
/// `stopRecording()` to retrieve the accumulated timeline.
///
/// Thread safety is guaranteed by Swift actor isolation — all mutable state
/// is confined to this actor. Reads from `AudioParameters` are lock-free
/// (relaxed atomic ordering) and safe from any isolation context.
actor BodyMusicRecorder: BodyMusicRecorderProtocol {

    // MARK: - Private State

    private var snapshots: [AdaptationSnapshot] = []
    private var isRecording: Bool = false
    private var recordingTask: Task<Void, Never>?

    /// Latest heart rate supplied externally (e.g., from BiometricProcessor).
    /// Stamped onto the next captured snapshot.
    private var latestHeartRate: Double?

    /// Timestamp when the current recording started, used to compute
    /// relative snapshot timestamps.
    private var recordingStartDate: Date?

    // MARK: - Recording Lifecycle

    /// Begins capturing snapshots from the given audio parameter store.
    ///
    /// Starts an internal `Task` that wakes every `snapshotIntervalSeconds`,
    /// reads the current beat frequency, carrier frequency, and amplitude
    /// from `audioParameters`, pairs them with the latest heart rate, and
    /// appends the result. Recording stops automatically when
    /// `maxSnapshotsPerSession` is reached or `stopRecording()` is called.
    ///
    /// - Parameter audioParameters: The lock-free parameter store shared
    ///   with the audio render thread.
    func startRecording(audioParameters: AudioParameters) {
        guard !isRecording else {
            Logger.session.warning("BodyMusicRecorder: startRecording called while already recording")
            return
        }

        snapshots.removeAll()
        latestHeartRate = nil
        isRecording = true
        recordingStartDate = Date()

        guard let startDate = recordingStartDate else {
            Logger.session.error("BodyMusicRecorder: recordingStartDate is nil after assignment")
            isRecording = false
            return
        }
        let interval = RecorderConfig.snapshotIntervalSeconds
        let maxSnapshots = RecorderConfig.maxSnapshotsPerSession

        recordingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))

                guard !Task.isCancelled else { break }
                guard let self else { break }

                let stillRecording = await self.isRecording
                guard stillRecording else { break }

                let snapshot = AdaptationSnapshot(
                    timestamp: Date().timeIntervalSince(startDate),
                    beatFrequency: audioParameters.beatFrequency,
                    carrierFrequency: audioParameters.carrierFrequency,
                    amplitude: audioParameters.amplitude,
                    heartRate: await self.latestHeartRate
                )

                await self.appendSnapshot(snapshot)

                let count = await self.snapshots.count
                if count >= maxSnapshots {
                    Logger.session.info("BodyMusicRecorder: max snapshots reached (\(maxSnapshots))")
                    await self.setRecording(false)
                    break
                }
            }
        }

        Logger.session.info("BodyMusicRecorder: recording started")
    }

    /// Updates the heart rate value stamped onto subsequent snapshots.
    ///
    /// Call this whenever a new heart rate reading arrives from the
    /// biometric pipeline. The value is stored until the next snapshot
    /// capture, then included in that snapshot.
    ///
    /// - Parameter hr: Latest heart rate in BPM.
    func updateHeartRate(_ hr: Double) {
        latestHeartRate = hr
    }

    /// Stops recording and returns all captured snapshots.
    ///
    /// Cancels the internal capture task and returns the accumulated
    /// adaptation timeline. The recorder can be started again for a new
    /// session after this call.
    ///
    /// - Returns: The ordered array of `AdaptationSnapshot` values captured
    ///   during the session.
    func stopRecording() -> [AdaptationSnapshot] {
        isRecording = false
        recordingTask?.cancel()
        recordingTask = nil
        recordingStartDate = nil

        let result = snapshots
        snapshots.removeAll()

        Logger.session.info("BodyMusicRecorder: recording stopped — \(result.count) snapshots captured")
        return result
    }

    // MARK: - Private Helpers

    private func appendSnapshot(_ snapshot: AdaptationSnapshot) {
        snapshots.append(snapshot)
    }

    private func setRecording(_ value: Bool) {
        isRecording = value
    }

    // MARK: - SavedTrack Factory

    /// Builds a `SavedTrack` from a completed session and its captured
    /// adaptation snapshots.
    ///
    /// The track name is auto-generated from the session's start date
    /// using `RecorderConfig.defaultTrackNameFormat`. The adaptation
    /// timeline is JSON-encoded and stored as `Data` on the model.
    ///
    /// - Parameters:
    ///   - session: The completed `FocusSession` to save from.
    ///   - snapshots: The adaptation snapshots captured during the session.
    /// - Returns: A new `SavedTrack` ready for persistence.
    static func createSavedTrack(
        from session: FocusSession,
        snapshots: [AdaptationSnapshot]
    ) -> SavedTrack {
        let formatter = DateFormatter()
        formatter.dateFormat = RecorderConfig.defaultTrackNameFormat

        let name = formatter.string(from: session.startDate)
        let timelineData = encodeTimeline(snapshots)

        return SavedTrack(
            sessionID: session.id,
            name: name,
            mode: session.mode,
            durationSeconds: session.durationSeconds,
            averageHeartRate: session.averageHeartRate,
            beatFrequencyStart: session.beatFrequencyStart,
            beatFrequencyEnd: session.beatFrequencyEnd,
            carrierFrequency: session.carrierFrequency,
            ambientBedID: session.ambientBedID,
            melodicLayerIDs: session.melodicLayerIDs,
            adaptationTimeline: timelineData
        )
    }

    // MARK: - Timeline Codec

    /// Encodes an array of adaptation snapshots to JSON `Data`.
    ///
    /// - Parameter snapshots: The snapshots to encode.
    /// - Returns: Encoded `Data`, or `nil` if encoding fails.
    static func encodeTimeline(_ snapshots: [AdaptationSnapshot]) -> Data? {
        do {
            let encoder = JSONEncoder()
            return try encoder.encode(snapshots)
        } catch {
            Logger.session.error("BodyMusicRecorder: failed to encode timeline — \(error.localizedDescription)")
            return nil
        }
    }

    /// Decodes an array of adaptation snapshots from JSON `Data`.
    ///
    /// - Parameter data: The encoded timeline data.
    /// - Returns: Decoded snapshots, or an empty array if decoding fails.
    static func decodeTimeline(_ data: Data) -> [AdaptationSnapshot] {
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([AdaptationSnapshot].self, from: data)
        } catch {
            Logger.session.error("BodyMusicRecorder: failed to decode timeline — \(error.localizedDescription)")
            return []
        }
    }
}
