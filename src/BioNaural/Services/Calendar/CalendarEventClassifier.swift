// CalendarEventClassifier.swift
// BioNaural
//
// Classifies calendar events by stress level using on-device
// NaturalLanguage framework + keyword matching. Maps each event
// to a suggested FocusMode, session duration, and prep window.

import Foundation
import NaturalLanguage
import BioNauralShared

// MARK: - StressLevel

public enum StressLevel: String, Codable, CaseIterable, Comparable, Sendable {
    case low, moderate, high, critical

    public static func < (lhs: StressLevel, rhs: StressLevel) -> Bool {
        let order: [StressLevel] = [.low, .moderate, .high, .critical]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

// MARK: - ClassifiedEvent

public struct ClassifiedEvent: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let stressLevel: StressLevel
    public let suggestedMode: FocusMode
    public let suggestedSessionMinutes: Int
    public let suggestedPrepMinutesBefore: Int
    public let keywords: [String]
}

// MARK: - ClassifierConfig

enum ClassifierConfig {

    // MARK: Keyword Sets

    static let criticalKeywords: Set<String> = [
        "exam", "final", "defense", "board review", "certification"
    ]
    static let highStressKeywords: Set<String> = [
        "presentation", "interview", "pitch", "deadline",
        "review", "demo", "audit"
    ]
    static let moderateKeywords: Set<String> = [
        "meeting", "call", "sync", "standup",
        "1:1", "check-in", "workshop"
    ]
    static let energyKeywords: Set<String> = [
        "workout", "gym", "run", "game",
        "practice", "training", "match"
    ]
    static let recoveryKeywords: Set<String> = [
        "lunch", "break", "walk", "coffee"
    ]

    // MARK: Prep Windows (minutes before event)

    static let criticalPrepMinutes: Int = 120
    static let highPrepMinutes: Int = 90
    static let moderatePrepMinutes: Int = 60

    // MARK: Suggested Session Durations

    static let criticalSessionMinutes: Int = 20
    static let highSessionMinutes: Int = 15
    static let moderateSessionMinutes: Int = 10

    // MARK: Mode Mapping

    static let criticalMode: FocusMode = .relaxation
    static let highMode: FocusMode = .focus
    static let moderateMode: FocusMode = .focus
    static let energyMode: FocusMode = .energize
    static let recoveryMode: FocusMode = .relaxation

    // MARK: Semantic Similarity

    /// Seed words for NLEmbedding similarity when keyword matching fails.
    static let stressSeedWords: [String] = [
        "stress", "pressure", "urgent", "critical", "tense"
    ]

    /// Minimum cosine distance to consider a title stress-related.
    static let semanticSimilarityThreshold: Double = 0.6
}

// MARK: - Protocol

/// Classification interface for mapping calendar events to stress levels
/// and suggested BioNaural session parameters.
///
/// Protocol-based to support mock implementations in previews and tests,
/// per the project's DI architecture.
public protocol CalendarEventClassifierProtocol: AnyObject, Sendable {

    /// Classify a single calendar event by stress level and map to
    /// a suggested FocusMode, session duration, and prep window.
    func classify(_ event: CalendarEvent) async -> ClassifiedEvent

    /// Classify a batch of calendar events.
    func classifyBatch(_ events: [CalendarEvent]) async -> [ClassifiedEvent]

    /// Filter events within a time window that are moderate stress or higher.
    func upcomingStressors(
        from events: [CalendarEvent],
        within hours: Int
    ) async -> [ClassifiedEvent]
}

// MARK: - CalendarEventClassifier

/// Thread-safe classifier that assigns a `StressLevel` and suggested
/// BioNaural session parameters to each calendar event.
///
/// All processing happens on-device using `NaturalLanguage` framework
/// (NLTagger for name detection, NLEmbedding for semantic similarity).
public actor CalendarEventClassifier: CalendarEventClassifierProtocol {

    // MARK: - Cached Resources

    /// Word embedding loaded once and reused across classifications.
    private let embedding: NLEmbedding?

    // MARK: - Init

    public init() {
        self.embedding = NLEmbedding.wordEmbedding(for: .english)
    }

    // MARK: - Public API

    /// Classify a single calendar event by stress level and map to
    /// a suggested FocusMode, session duration, and prep window.
    public func classify(_ event: CalendarEvent) -> ClassifiedEvent {
        let lowered = event.title.lowercased()
        var matchedKeywords: [String] = []

        // 1. Keyword matching — most-specific tier first
        if let match = firstMatch(in: lowered, from: ClassifierConfig.criticalKeywords) {
            matchedKeywords.append(match)
            return buildResult(
                event: event,
                stress: .critical,
                mode: ClassifierConfig.criticalMode,
                session: ClassifierConfig.criticalSessionMinutes,
                prep: ClassifierConfig.criticalPrepMinutes,
                keywords: matchedKeywords
            )
        }

        if let match = firstMatch(in: lowered, from: ClassifierConfig.highStressKeywords) {
            matchedKeywords.append(match)
            return buildResult(
                event: event,
                stress: .high,
                mode: ClassifierConfig.highMode,
                session: ClassifierConfig.highSessionMinutes,
                prep: ClassifierConfig.highPrepMinutes,
                keywords: matchedKeywords
            )
        }

        if let match = firstMatch(in: lowered, from: ClassifierConfig.moderateKeywords) {
            matchedKeywords.append(match)
            return buildResult(
                event: event,
                stress: .moderate,
                mode: ClassifierConfig.moderateMode,
                session: ClassifierConfig.moderateSessionMinutes,
                prep: ClassifierConfig.moderatePrepMinutes,
                keywords: matchedKeywords
            )
        }

        if let match = firstMatch(in: lowered, from: ClassifierConfig.energyKeywords) {
            matchedKeywords.append(match)
            return buildResult(
                event: event,
                stress: .low,
                mode: ClassifierConfig.energyMode,
                session: ClassifierConfig.moderateSessionMinutes,
                prep: ClassifierConfig.moderatePrepMinutes,
                keywords: matchedKeywords
            )
        }

        if let match = firstMatch(in: lowered, from: ClassifierConfig.recoveryKeywords) {
            matchedKeywords.append(match)
            return buildResult(
                event: event,
                stress: .low,
                mode: ClassifierConfig.recoveryMode,
                session: ClassifierConfig.moderateSessionMinutes,
                prep: 0,
                keywords: matchedKeywords
            )
        }

        // 2. NLTagger — detect person names (likely a 1:1 meeting)
        if containsPersonName(lowered) {
            return buildResult(
                event: event,
                stress: .moderate,
                mode: ClassifierConfig.moderateMode,
                session: ClassifierConfig.moderateSessionMinutes,
                prep: ClassifierConfig.moderatePrepMinutes,
                keywords: ["(person name detected)"]
            )
        }

        // 3. NLEmbedding — semantic similarity to stress seed words
        if let similarity = highestStressSimilarity(for: lowered),
           similarity >= ClassifierConfig.semanticSimilarityThreshold {
            return buildResult(
                event: event,
                stress: .moderate,
                mode: ClassifierConfig.moderateMode,
                session: ClassifierConfig.moderateSessionMinutes,
                prep: ClassifierConfig.moderatePrepMinutes,
                keywords: ["(semantic similarity: \(String(format: "%.2f", similarity)))"]
            )
        }

        // 4. Default — low stress, recovery mode
        return buildResult(
            event: event,
            stress: .low,
            mode: ClassifierConfig.recoveryMode,
            session: ClassifierConfig.moderateSessionMinutes,
            prep: 0,
            keywords: []
        )
    }

    /// Classify a batch of calendar events.
    public func classifyBatch(_ events: [CalendarEvent]) -> [ClassifiedEvent] {
        events.map { classify($0) }
    }

    /// Filter events within a time window that are moderate stress or higher.
    ///
    /// - Parameters:
    ///   - events: The full list of calendar events to evaluate.
    ///   - hours: The lookahead window in hours from now.
    /// - Returns: Classified events with stress >= `.moderate`, sorted by start date.
    public func upcomingStressors(
        from events: [CalendarEvent],
        within hours: Int
    ) -> [ClassifiedEvent] {
        let now = Date()
        let cutoff = now.addingTimeInterval(TimeInterval(hours) * 3600)

        return classifyBatch(events)
            .filter { $0.stressLevel >= .moderate && $0.startDate >= now && $0.startDate <= cutoff }
            .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Private Helpers

    /// Returns the first keyword from the set that appears in the lowercased title.
    private func firstMatch(in lowered: String, from keywords: Set<String>) -> String? {
        keywords.first { lowered.contains($0) }
    }

    /// Uses NLTagger to check whether the title contains a person name.
    private func containsPersonName(_ text: String) -> Bool {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var found = false
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace]
        ) { tag, _ in
            if tag == .personalName {
                found = true
                return false // stop enumeration
            }
            return true
        }
        return found
    }

    /// Computes the highest semantic similarity between the title words
    /// and the stress seed words using NLEmbedding.
    private func highestStressSimilarity(for text: String) -> Double? {
        guard let embedding else { return nil }

        let words = text.split(separator: " ").map(String.init)
        var best: Double = 0

        for word in words {
            for seed in ClassifierConfig.stressSeedWords {
                let distance = embedding.distance(between: word, and: seed)
                // NLEmbedding.distance returns cosine distance (0 = identical, 2 = opposite).
                // A distance of .greatestFiniteMagnitude means no vector for that word.
                guard distance < Double.greatestFiniteMagnitude else { continue }
                // Convert to similarity: 1 - (distance / 2).
                let similarity = 1.0 - (distance / 2.0)
                best = max(best, similarity)
            }
        }

        return best > 0 ? best : nil
    }

    /// Assemble a ClassifiedEvent from classification results.
    private func buildResult(
        event: CalendarEvent,
        stress: StressLevel,
        mode: FocusMode,
        session: Int,
        prep: Int,
        keywords: [String]
    ) -> ClassifiedEvent {
        ClassifiedEvent(
            id: event.id,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            stressLevel: stress,
            suggestedMode: mode,
            suggestedSessionMinutes: session,
            suggestedPrepMinutesBefore: prep,
            keywords: keywords
        )
    }
}
