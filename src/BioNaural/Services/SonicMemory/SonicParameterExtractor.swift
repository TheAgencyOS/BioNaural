// SonicParameterExtractor.swift
// BioNaural
//
// Takes a user's natural language description of a meaningful sound or
// memory and extracts audio parameters for personalized soundscape
// generation. All processing happens on-device using the NaturalLanguage
// framework — no network calls, no data leaves the device.
//
// Architecture: actor-based for thread safety. All keyword-to-parameter
// mappings live in ExtractionConfig — zero hardcoded values in the
// extraction logic.

import Foundation
import NaturalLanguage

// MARK: - EmotionalTag

public enum EmotionalTag: String, Codable, CaseIterable, Sendable {
    case calm, focused, energized, nostalgic, safe, joyful

    public var displayName: String { rawValue.capitalized }
}

// MARK: - SonicParameters

public struct SonicParameters: Codable, Sendable, Equatable {
    /// 0 (cool/clinical) to 1 (warm/cozy)
    public let warmth: Double
    /// 0 (static/ambient) to 1 (rhythmic/pulsing)
    public let rhythm: Double
    /// 0 (sparse/minimal) to 1 (dense/layered)
    public let density: Double
    /// 0 (dark/muted) to 1 (bright/airy)
    public let brightness: Double
    /// BPM if rhythm-relevant, nil for ambient
    public let tempo: Double?
    /// Instrument families matched from the description
    public let preferredInstruments: [String]
    /// Ambient texture tags matched from the description
    public let preferredAmbientTags: [String]
    /// Primary emotional association derived from keyword analysis
    public let emotionalAssociation: EmotionalTag
    /// 0-1, how confident the extraction is based on keyword coverage
    public let confidence: Double
}

// MARK: - ExtractionConfig

/// All keyword-to-parameter mappings for sonic parameter extraction.
/// No extraction logic lives here — only data. Every value the extractor
/// uses comes from this enum.
enum ExtractionConfig {

    // MARK: Neutral Baseline

    /// Starting value for all four primary axes before keyword adjustments.
    static let neutralBaseline: Double = 0.5

    // MARK: Adjustment Magnitudes

    /// Amount added to an axis when a positive keyword matches.
    static let positiveAdjustment: Double = 0.3
    /// Amount subtracted from an axis when a negative keyword matches.
    static let negativeAdjustment: Double = 0.2

    // MARK: Confidence Thresholds

    /// Confidence when zero keywords match.
    static let confidenceBaseline: Double = 0.2
    /// Confidence increment per keyword match, up to the cap.
    static let confidencePerMatch: Double = 0.14
    /// Maximum confidence value.
    static let confidenceCap: Double = 0.9
    /// Number of matches required to reach the confidence cap.
    static let confidenceCapMatchCount: Int = 5

    // MARK: Warmth Keywords

    static let warmKeywords: Set<String> = [
        "cabin", "fire", "fireplace", "cozy", "blanket",
        "warm", "wood", "grandma", "kitchen", "home", "candle"
    ]

    static let coolKeywords: Set<String> = [
        "library", "lab", "office", "clinical", "sharp",
        "crisp", "winter", "ice", "metal"
    ]

    // MARK: Rhythm Keywords

    static let rhythmicKeywords: Set<String> = [
        "beats", "hip hop", "lo-fi", "lofi", "drum",
        "pulse", "tick", "clock", "train", "heartbeat"
    ]

    static let staticKeywords: Set<String> = [
        "drone", "hum", "white noise", "silence",
        "still", "ambient", "pad"
    ]

    // MARK: Density Keywords

    static let denseKeywords: Set<String> = [
        "orchestra", "full", "rich", "layered",
        "symphony", "complex"
    ]

    static let sparseKeywords: Set<String> = [
        "minimal", "simple", "quiet", "single", "solo", "one"
    ]

    // MARK: Brightness Keywords

    static let brightKeywords: Set<String> = [
        "piano", "bells", "chimes", "bright", "sparkle",
        "crystal", "glass", "high"
    ]

    static let darkKeywords: Set<String> = [
        "bass", "deep", "low", "dark", "rumble",
        "thunder", "cello", "heavy"
    ]

    // MARK: Instrument Mappings

    /// Maps trigger words to canonical instrument family names.
    static let instrumentMappings: [(triggers: Set<String>, tag: String)] = [
        (["piano", "keys"], "piano"),
        (["guitar"], "guitar"),
        (["strings", "violin", "cello"], "strings"),
        (["pads", "synth", "electronic"], "pads"),
        (["flute", "wind"], "woodwind")
    ]

    // MARK: Ambient Tag Mappings

    /// Maps trigger words to canonical ambient texture tags.
    static let ambientTagMappings: [(triggers: Set<String>, tag: String)] = [
        (["rain", "rainy", "storm"], "rain"),
        (["ocean", "waves", "beach", "sea"], "ocean"),
        (["forest", "birds", "trees", "nature"], "forest"),
        (["fire", "fireplace", "crackling"], "fire"),
        (["wind", "breeze"], "wind"),
        (["cafe", "coffee shop", "bustling"], "cafe"),
        (["library", "quiet", "hum"], "brown-noise"),
        (["city", "urban"], "city")
    ]

    // MARK: Emotional Association Keywords

    /// Maps each emotional tag to its trigger keywords.
    static let emotionalKeywords: [(tag: EmotionalTag, keywords: Set<String>)] = [
        (.calm, ["calm", "peaceful", "serene", "relaxing", "quiet", "still", "gentle"]),
        (.focused, ["focus", "study", "work", "concentrate", "productive", "library"]),
        (.energized, ["energy", "pump", "workout", "dance", "upbeat", "exciting"]),
        (.nostalgic, ["remember", "childhood", "used to", "grandma", "mom", "dad", "old", "memory"]),
        (.safe, ["home", "safe", "comfort", "cozy", "warm", "familiar", "blanket"]),
        (.joyful, ["happy", "joy", "love", "fun", "smile", "laugh", "celebrate"])
    ]

    /// Default emotional tag when no keywords match.
    static let defaultEmotionalTag: EmotionalTag = .calm

    // MARK: Tempo Mappings

    /// Maps trigger words to BPM values. A nil BPM means no tempo (ambient).
    static let tempoMappings: [(triggers: Set<String>, bpm: Double?)] = [
        (["lo-fi", "lofi", "chill"], 75),
        (["ambient", "slow"], nil),
        (["upbeat", "energetic"], 120),
        (["moderate", "walking"], 100)
    ]

    // MARK: Follow-Up Question Templates

    static let noInstrumentsQuestion =
        "Any particular instruments you associate with this?"
    static let noAmbientQuestion =
        "Is there a natural sound in this memory — rain, ocean, wind?"
    static let neutralRhythmQuestion =
        "Is this more of a still, ambient feeling or does it have a beat?"
    /// How close to the neutral baseline rhythm must be to trigger the question.
    static let neutralRhythmThreshold: Double = 0.1
}

// MARK: - Protocol

/// Extraction interface for converting natural language descriptions
/// into audio synthesis parameters for personalized soundscapes.
///
/// Protocol-based to support mock implementations in previews and tests,
/// per the project's DI architecture.
public protocol SonicParameterExtractorProtocol: AnyObject, Sendable {

    /// Extract audio parameters from a natural language description.
    func extract(from description: String) async -> SonicParameters

    /// Suggest follow-up questions to refine an extraction.
    func suggestFollowUpQuestions(from parameters: SonicParameters) async -> [String]
}

// MARK: - SonicParameterExtractor

/// Extracts audio synthesis parameters from a natural language description
/// of a meaningful sound or memory.
///
/// All processing is on-device using Apple's NaturalLanguage framework
/// for tokenization. Keyword matching drives parameter adjustments from
/// a neutral baseline — every mapping lives in ``ExtractionConfig``.
///
/// Thread safety: this type is an actor. All mutable state (the cached
/// tokenizer) is isolated.
public actor SonicParameterExtractor: SonicParameterExtractorProtocol {

    // MARK: - Cached Resources

    /// NLTokenizer reused across extraction calls.
    private let tokenizer: NLTokenizer

    // MARK: - Init

    public init() {
        let tokenizer = NLTokenizer(unit: .word)
        self.tokenizer = tokenizer
    }

    // MARK: - Public API

    /// Extract audio parameters from a natural language description.
    ///
    /// Algorithm:
    /// 1. Lowercase and tokenize the description using NLTokenizer.
    /// 2. Scan for keyword matches across all categories.
    /// 3. Start with neutral values for warmth/rhythm/density/brightness.
    /// 4. Apply keyword adjustments (additive, clamped to 0-1).
    /// 5. Pick the emotional tag with the most keyword hits.
    /// 6. Collect all matched instrument and ambient tags.
    /// 7. Calculate confidence from total keyword match count.
    /// 8. Return assembled SonicParameters.
    public func extract(from description: String) -> SonicParameters {
        let lowered = description.lowercased()
        let tokens = tokenize(lowered)

        // Start at neutral baseline
        var warmth = ExtractionConfig.neutralBaseline
        var rhythm = ExtractionConfig.neutralBaseline
        var density = ExtractionConfig.neutralBaseline
        var brightness = ExtractionConfig.neutralBaseline
        var totalMatches = 0

        // Warmth
        let warmHits = countMatches(in: lowered, tokens: tokens, keywords: ExtractionConfig.warmKeywords)
        let coolHits = countMatches(in: lowered, tokens: tokens, keywords: ExtractionConfig.coolKeywords)
        warmth += Double(warmHits) * ExtractionConfig.positiveAdjustment
        warmth -= Double(coolHits) * ExtractionConfig.negativeAdjustment
        totalMatches += warmHits + coolHits

        // Rhythm
        let rhythmicHits = countMatches(in: lowered, tokens: tokens, keywords: ExtractionConfig.rhythmicKeywords)
        let staticHits = countMatches(in: lowered, tokens: tokens, keywords: ExtractionConfig.staticKeywords)
        rhythm += Double(rhythmicHits) * ExtractionConfig.positiveAdjustment
        rhythm -= Double(staticHits) * ExtractionConfig.negativeAdjustment
        totalMatches += rhythmicHits + staticHits

        // Density
        let denseHits = countMatches(in: lowered, tokens: tokens, keywords: ExtractionConfig.denseKeywords)
        let sparseHits = countMatches(in: lowered, tokens: tokens, keywords: ExtractionConfig.sparseKeywords)
        density += Double(denseHits) * ExtractionConfig.positiveAdjustment
        density -= Double(sparseHits) * ExtractionConfig.negativeAdjustment
        totalMatches += denseHits + sparseHits

        // Brightness
        let brightHits = countMatches(in: lowered, tokens: tokens, keywords: ExtractionConfig.brightKeywords)
        let darkHits = countMatches(in: lowered, tokens: tokens, keywords: ExtractionConfig.darkKeywords)
        brightness += Double(brightHits) * ExtractionConfig.positiveAdjustment
        brightness -= Double(darkHits) * ExtractionConfig.negativeAdjustment
        totalMatches += brightHits + darkHits

        // Clamp all axes to 0-1
        warmth = clamp(warmth)
        rhythm = clamp(rhythm)
        density = clamp(density)
        brightness = clamp(brightness)

        // Instruments
        let instruments = matchTags(in: lowered, tokens: tokens, mappings: ExtractionConfig.instrumentMappings)
        totalMatches += instruments.count

        // Ambient tags
        let ambientTags = matchTags(in: lowered, tokens: tokens, mappings: ExtractionConfig.ambientTagMappings)
        totalMatches += ambientTags.count

        // Emotional association — pick tag with most keyword hits
        let emotionalTag = resolveEmotionalTag(from: lowered, tokens: tokens, totalMatches: &totalMatches)

        // Tempo
        let tempo = resolveTempo(from: lowered, tokens: tokens, totalMatches: &totalMatches)

        // Confidence
        let confidence = calculateConfidence(totalMatches: totalMatches)

        return SonicParameters(
            warmth: warmth,
            rhythm: rhythm,
            density: density,
            brightness: brightness,
            tempo: tempo,
            preferredInstruments: instruments,
            preferredAmbientTags: ambientTags,
            emotionalAssociation: emotionalTag,
            confidence: confidence
        )
    }

    /// Suggest follow-up questions to refine an extraction.
    ///
    /// Returns targeted questions based on gaps in the extracted parameters:
    /// - No instruments matched → ask about instruments
    /// - No ambient tags matched → ask about natural sounds
    /// - Rhythm near neutral → ask about beat vs. ambient preference
    public func suggestFollowUpQuestions(from parameters: SonicParameters) -> [String] {
        var questions: [String] = []

        if parameters.preferredInstruments.isEmpty {
            questions.append(ExtractionConfig.noInstrumentsQuestion)
        }

        if parameters.preferredAmbientTags.isEmpty {
            questions.append(ExtractionConfig.noAmbientQuestion)
        }

        let rhythmDeviation = abs(parameters.rhythm - ExtractionConfig.neutralBaseline)
        if rhythmDeviation < ExtractionConfig.neutralRhythmThreshold {
            questions.append(ExtractionConfig.neutralRhythmQuestion)
        }

        return questions
    }

    // MARK: - Tokenization

    /// Tokenize text into individual words using NLTokenizer.
    private func tokenize(_ text: String) -> [String] {
        tokenizer.string = text
        let range = text.startIndex..<text.endIndex
        var tokens: [String] = []

        tokenizer.enumerateTokens(in: range) { tokenRange, _ in
            tokens.append(String(text[tokenRange]))
            return true
        }

        return tokens
    }

    // MARK: - Keyword Matching

    /// Count how many keywords from the set appear in the text.
    ///
    /// Uses both substring matching on the full text (for multi-word
    /// keywords like "hip hop" or "coffee shop") and token matching
    /// for single-word keywords.
    private func countMatches(
        in lowered: String,
        tokens: [String],
        keywords: Set<String>
    ) -> Int {
        var count = 0
        for keyword in keywords {
            if keyword.contains(" ") {
                // Multi-word keyword — substring match
                if lowered.contains(keyword) {
                    count += 1
                }
            } else {
                // Single-word keyword — token match
                if tokens.contains(keyword) {
                    count += 1
                }
            }
        }
        return count
    }

    /// Match instrument or ambient tag mappings, returning canonical tag names.
    private func matchTags(
        in lowered: String,
        tokens: [String],
        mappings: [(triggers: Set<String>, tag: String)]
    ) -> [String] {
        var matched: [String] = []
        for mapping in mappings {
            let hits = countMatches(in: lowered, tokens: tokens, keywords: mapping.triggers)
            if hits > 0 && !matched.contains(mapping.tag) {
                matched.append(mapping.tag)
            }
        }
        return matched
    }

    // MARK: - Emotional Tag Resolution

    /// Resolve the best emotional tag by counting keyword hits per tag.
    /// The tag with the most hits wins. Ties go to the first tag in
    /// ``ExtractionConfig.emotionalKeywords`` order. If nothing matches,
    /// falls back to ``ExtractionConfig.defaultEmotionalTag``.
    private func resolveEmotionalTag(
        from lowered: String,
        tokens: [String],
        totalMatches: inout Int
    ) -> EmotionalTag {
        var bestTag = ExtractionConfig.defaultEmotionalTag
        var bestCount = 0

        for entry in ExtractionConfig.emotionalKeywords {
            let hits = countMatches(in: lowered, tokens: tokens, keywords: entry.keywords)
            if hits > bestCount {
                bestCount = hits
                bestTag = entry.tag
            }
        }

        totalMatches += bestCount
        return bestTag
    }

    // MARK: - Tempo Resolution

    /// Resolve tempo from keyword matches. First match wins.
    /// Returns nil if no tempo keywords are found or if the match
    /// explicitly maps to nil (ambient/slow).
    private func resolveTempo(
        from lowered: String,
        tokens: [String],
        totalMatches: inout Int
    ) -> Double? {
        for mapping in ExtractionConfig.tempoMappings {
            let hits = countMatches(in: lowered, tokens: tokens, keywords: mapping.triggers)
            if hits > 0 {
                totalMatches += hits
                return mapping.bpm
            }
        }
        return nil
    }

    // MARK: - Confidence

    /// Calculate extraction confidence from total keyword match count.
    ///
    /// - 0 matches → baseline confidence
    /// - Linear ramp from baseline to cap over `confidenceCapMatchCount` matches
    /// - 5+ matches → cap confidence
    private func calculateConfidence(totalMatches: Int) -> Double {
        guard totalMatches > 0 else {
            return ExtractionConfig.confidenceBaseline
        }

        let effectiveMatches = min(totalMatches, ExtractionConfig.confidenceCapMatchCount)
        let range = ExtractionConfig.confidenceCap - ExtractionConfig.confidenceBaseline
        let progress = Double(effectiveMatches) / Double(ExtractionConfig.confidenceCapMatchCount)
        return ExtractionConfig.confidenceBaseline + range * progress
    }

    // MARK: - Utilities

    /// Clamp a value to the 0-1 range.
    private func clamp(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }
}
