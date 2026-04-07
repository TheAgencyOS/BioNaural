// AudioEngineProtocol.swift
// BioNaural
//
// Protocol defining the public surface of the audio engine.

import Foundation
import BioNauralShared

/// Contract for the binaural-beat audio engine.
/// Implementations manage an `AVAudioEngine` graph and expose
/// thread-safe parameters for the render callback.
public protocol AudioEngineProtocol: AnyObject {

    /// Thread-safe parameter store shared with the render thread.
    var parameters: AudioParameters { get }

    /// Whether the engine is currently producing audible output.
    var isPlaying: Bool { get }

    /// Whether the underlying `AVAudioEngine` is running
    /// (may be true even while fading out).
    var isRunning: Bool { get }

    /// Learned sound preferences from Sound DNA + session outcomes.
    /// Set before calling `start()` to personalize melodic/ambient selection.
    var soundSelectionProfile: SoundSelectionProfile? { get set }

    /// User's preferred genre (from SoundProfile.genrePreferences).
    /// Used by MIDISequencePlayer to select genre-appropriate sequences.
    var genrePreference: String? { get set }

    /// Master tonality for the current session (key, scale, tempo).
    var sessionTonality: SessionTonality? { get }

    /// Build the audio graph and configure the audio session.
    /// Call once before first use.
    func setup() throws

    /// Begin playback for the given focus mode.
    /// Sets frequencies from Theme.Audio tokens and starts the engine.
    func start(mode: FocusMode) throws

    /// Gracefully stop — ramps amplitude to zero, then stops the engine.
    func stop()

    /// Pause playback (keeps the graph wired, pauses the engine).
    func pause()

    /// Resume a previously paused engine.
    func resume()

    /// Crossfade the ambient bed to the named soundscape.
    ///
    /// - Parameter bedName: The bundle filename (without extension) of the
    ///   ambient bed to crossfade to (e.g. "rain", "wind", "pink_noise").
    func selectSoundscape(_ bedName: String)
}
