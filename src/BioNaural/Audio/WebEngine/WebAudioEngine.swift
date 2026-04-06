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
import UIKit
import WebKit

// MARK: - WebAudioEngine

public final class WebAudioEngine: NSObject, WKScriptMessageHandler, WKNavigationDelegate {

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

    /// Base64-encoded SoundFont data to inject after page loads.
    /// We inject from Swift because JS fetch() can't access file:// on iOS.
    private var pendingSoundFontBase64: String?

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

        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        wv.isHidden = true
        wv.navigationDelegate = self

        // WKWebView MUST be in a window hierarchy to execute JS and play audio.
        var addedToWindow = false
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.addSubview(wv)
            addedToWindow = true
        }

        if !addedToWindow {
            logger.error("WebEngine: Could not add WKWebView to window hierarchy — JS will not execute")
        }

        // Load the bundled HTML+JS engine
        guard let bundleURL = Bundle.main.url(forResource: "webengine-index", withExtension: "html") else {
            logger.error("WebEngine HTML not found in app bundle")
            self.webView = wv
            return
        }

        let bundleDir = Bundle.main.bundleURL
        wv.loadFileURL(bundleURL, allowingReadAccessTo: bundleDir)

        self.webView = wv
        logger.info("WebAudioEngine setup — HTML loading, addedToWindow=\(addedToWindow)")

        // After page loads, inject the SoundFont as base64 data.
        // This bypasses the fetch() file:// restriction on iOS WKWebView.
        if let sf2URL = Bundle.main.url(forResource: "BioNaural-Melodic", withExtension: "sf2"),
           let sf2Data = try? Data(contentsOf: sf2URL) {
            let base64 = sf2Data.base64EncodedString()
            self.pendingSoundFontBase64 = base64
            logger.info("WebEngine: SoundFont loaded (\(sf2Data.count) bytes), will inject after page loads")
        } else {
            logger.error("WebEngine: BioNaural-Melodic.sf2 not found in bundle!")
        }
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

    // MARK: - WKNavigationDelegate

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logger.info("WebEngine: Page loaded successfully")

        // Inject the SoundFont as base64 data — bypasses fetch() file:// restriction.
        if let base64 = pendingSoundFontBase64 {
            let injectScript = """
            (async function() {
                try {
                    const b64 = "\(base64)";
                    const binary = atob(b64);
                    const bytes = new Uint8Array(binary.length);
                    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
                    window._injectedSF2 = bytes.buffer;
                    console.log('[Swift] SoundFont injected: ' + bytes.length + ' bytes');
                } catch(e) {
                    console.error('[Swift] SF2 injection failed:', e);
                }
            })();
            """
            webView.evaluateJavaScript(injectScript) { _, error in
                if let error {
                    self.logger.error("SF2 injection failed: \(error.localizedDescription)")
                } else {
                    self.logger.info("SF2 data injected into WebView")
                    self.pendingSoundFontBase64 = nil // Free memory
                }
            }
        }
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.error("WebEngine: Page load FAILED: \(error.localizedDescription)")
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        logger.error("WebEngine: Provisional navigation FAILED: \(error.localizedDescription)")
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
            self.logger.info("WebEngine start command: \(jsonStr)")
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
    /// Relaxation uses "lofi" (actual melody + chords) not "ambient" (static drones).
    private func defaultGenre(for mode: FocusMode) -> String {
        switch mode {
        case .sleep:       return "ambient"
        case .relaxation:  return "lofi"     // Lo-fi has actual melody; ambient is too static
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
            guard let wv = self?.webView else {
                self?.logger.error("WebView is nil — cannot evaluate JS")
                return
            }
            self?.logger.info("Evaluating JS: \(script.prefix(100))...")
            wv.evaluateJavaScript(script) { result, error in
                if let error {
                    self?.logger.error("JS eval error: \(error.localizedDescription)")
                }
                if let result {
                    self?.logger.info("JS eval result: \(String(describing: result))")
                }
            }
        }
    }
}
