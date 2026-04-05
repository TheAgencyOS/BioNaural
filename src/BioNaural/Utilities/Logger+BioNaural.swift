// Logger+BioNaural.swift
// BioNaural
//
// Typed os.Logger instances for each subsystem domain. Using dedicated
// categories keeps Console.app filterable and makes log analysis
// straightforward during development and field diagnostics.

import OSLog

// MARK: - Logger Categories

extension Logger {

    /// Bundle identifier used as the OSLog subsystem for all BioNaural loggers.
    private static let subsystem = "com.bionaural"

    /// Audio engine, synthesis, crossfades, sound selection.
    static let audio = Logger(subsystem: subsystem, category: "audio")

    /// Heart rate processing, HRV analysis, state classification, adaptation.
    static let biometrics = Logger(subsystem: subsystem, category: "biometrics")

    /// Sound profile updates, preference learning, outcome recording.
    static let learning = Logger(subsystem: subsystem, category: "learning")

    /// Session lifecycle: start, pause, resume, complete, abandon.
    static let session = Logger(subsystem: subsystem, category: "session")

    /// Watch connectivity, message passing, data sync.
    static let watch = Logger(subsystem: subsystem, category: "watch")

    /// Siri intent donations and Shortcuts integration.
    static let intents = Logger(subsystem: subsystem, category: "intents")

    /// AirPods head motion tracking and stillness scoring.
    static let headMotion = Logger(subsystem: subsystem, category: "headMotion")

    /// WeatherKit integration, barometric pressure tracking.
    static let weather = Logger(subsystem: subsystem, category: "weather")
}
