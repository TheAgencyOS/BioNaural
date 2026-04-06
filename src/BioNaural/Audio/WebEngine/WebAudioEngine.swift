// WebAudioEngine.swift
// BioNaural
//
// Hosts a WKWebView running SpessaSynth + Web Audio API for
// genre-aware, beat-locked musical content generation.
//
// Architecture:
//   Swift ──evaluateJavaScript──→ WKWebView (SpessaSynth engine)
//   Swift ←──messageHandlers────← WKWebView (status updates)
//
// The WebView handles ALL MIDI synthesis and scheduling.
// The native AVAudioEngine continues to handle binaural beats
// and ambient beds — those stay native for low-latency DSP.
//
// Communication:
//   start({mode, genre, key, bpm}) → JS generates music
//   stop() → JS stops all notes
//   setVolume(track, value) → JS adjusts per-track gain
//
// The SoundFont (GeneralUser_GS.sf2) is loaded by the JS engine
// from the WebView's local file server.

import BioNauralShared
import Foundation
import os.log
import WebKit

// MARK: - WebAudioEngine

public final class WebAudioEngine: NSObject, WKScriptMessageHandler {

    // MARK: - Properties

    private var webView: WKWebView?
    private var isReady = false
    private var pendingStart: (() -> Void)?
    private let parameters: AudioParameters

    private let logger = Logger(subsystem: "com.bionaural", category: "WebAudioEngine")

    /// Current genre selection.
    private(set) var currentGenre: String = "ambient"

    /// Whether the web engine is currently playing.
    private(set) var isPlaying = false

    // MARK: - Init

    public init(parameters: AudioParameters) {
        self.parameters = parameters
        super.init()
    }

    // MARK: - Setup

    /// Create and configure the WKWebView. Must be called on main thread.
    @MainActor
    public func setup() {
        guard webView == nil else { return }

        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsInlineMediaPlayback = true

        // Register message handlers for JS → Swift communication
        let contentController = config.userContentController
        contentController.add(self, name: "engineReady")
        contentController.add(self, name: "engineStatus")

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isHidden = true // Not visible — audio only

        // Load the bundled HTML+JS engine (files are in Resources root)
        guard let bundleURL = Bundle.main.url(forResource: "webengine-index", withExtension: "html") else {
            logger.error("WebEngine HTML not found in app bundle")
            self.webView = wv
            return
        }

        // Allow read access to the entire bundle directory so the JS can
        // load the SoundFont (BioNaural-Melodic.sf2) and engine bundle
        let bundleDir = Bundle.main.bundleURL
        wv.loadFileURL(bundleURL, allowingReadAccessTo: bundleDir)

        self.webView = wv
        logger.info("WebAudioEngine setup complete")
    }

    // MARK: - WKScriptMessageHandler

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        switch message.name {
        case "engineReady":
            isReady = true
            logger.info("WebAudioEngine JS engine ready")
            // Execute any pending start command
            if let pending = pendingStart {
                pending()
                pendingStart = nil
            }

        case "engineStatus":
            if let body = message.body as? String,
               let data = body.data(using: .utf8),
               let status = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                isPlaying = (status["playing"] as? Bool) ?? false
                if let bpm = status["bpm"] as? Double {
                    logger.info("WebEngine playing: \(self.isPlaying), BPM: \(bpm)")
                }
            }

        default:
            break
        }
    }

    // MARK: - Public API

    /// Start music generation for the given mode, genre, key, and BPM.
    public func start(
        mode: FocusMode,
        genre: String? = nil,
        key: String? = nil,
        bpm: Double? = nil
    ) {
        let tonality = SessionTonality(mode: mode)
        let genreId = genre ?? defaultGenre(for: mode)
        let rootKey = key ?? "\(tonality.root)"
        let tempo = bpm ?? tonality.tempo

        currentGenre = genreId

        let config: [String: Any] = [
            "mode": mode.rawValue,
            "genre": genreId,
            "key": rootKey,
            "bpm": tempo,
        ]

        let startCommand = { [weak self] in
            guard let self, let json = try? JSONSerialization.data(withJSONObject: config),
                  let jsonStr = String(data: json, encoding: .utf8) else { return }
            self.evaluateJS("window.BioNauralEngine.start(\(jsonStr))")
        }

        if isReady {
            startCommand()
        } else {
            pendingStart = startCommand
            logger.info("WebEngine not ready yet — queuing start command")
        }
    }

    /// Stop all music generation.
    public func stop() {
        evaluateJS("window.BioNauralEngine.stop()")
        isPlaying = false
    }

    /// Set volume for a specific track (melody, bass, drums, pad).
    public func setVolume(track: String, value: Double) {
        let clamped = max(0, min(1, value))
        evaluateJS("window.BioNauralEngine.setVolume('\(track)', \(clamped))")
    }

    /// Set master volume.
    public func setMasterVolume(_ value: Double) {
        let clamped = max(0, min(1, value))
        evaluateJS("window.BioNauralEngine.setMasterVolume(\(clamped))")
    }

    // MARK: - Genre Helpers

    /// Default genre for each mode (can be overridden by user preference).
    private func defaultGenre(for mode: FocusMode) -> String {
        switch mode {
        case .sleep:       return "ambient"
        case .relaxation:  return "ambient"
        case .focus:       return "lofi"
        case .energize:    return "electronic"
        }
    }

    /// Available genres for the user to choose from.
    public static let availableGenres: [(id: String, label: String, category: String)] = [
        ("ambient", "Ambient", "Therapeutic"),
        ("lofi", "Lo-Fi", "Therapeutic"),
        ("rock", "Rock", "Popular"),
        ("hiphop", "Hip Hop", "Popular"),
        ("jazz", "Jazz", "Popular"),
        ("blues", "Blues", "Popular"),
        ("reggae", "Reggae", "Popular"),
        ("classical", "Classical", "Popular"),
        ("latin", "Latin", "Popular"),
        ("electronic", "Electronic", "Popular"),
    ]

    // MARK: - Volume Sync

    /// Called by AudioEngine's volume sync timer to push slider values to JS.
    public func syncVolumes() {
        setVolume(track: "melody", value: parameters.melodicVolume)
        setVolume(track: "bass", value: parameters.bassVolume)
        setVolume(track: "drums", value: parameters.drumsVolume)
    }

    // MARK: - Private

    private func evaluateJS(_ script: String) {
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(script) { _, error in
                if let error {
                    self?.logger.error("JS eval error: \(error.localizedDescription)")
                }
            }
        }
    }
}
