// OnDeviceCoachService.swift
// BioNaural
//
// On-device AI coaching powered by Apple Foundation Models (iOS 26+).
// Generates personalized session recommendations and post-session insights
// entirely on-device — zero API cost, zero data leaves the device.
//
// This service is additive. The app functions fully without it. When
// Foundation Models is unavailable (wrong OS, Apple Intelligence disabled,
// model not downloaded), every method returns nil and callers fall back
// to rule-based logic in OfflineAICoachService.
//
// Voice: calm researcher. No exclamation marks. No "great job." Scientific
// confidence — "research suggests", "your data indicates", "this pattern
// is consistent with".

import Foundation
import os.log
import BioNauralShared

// MARK: - Generable Output Structs (iOS 26+)

// These structs use @Generable so LanguageModelSession can produce them
// as structured output. They are internal to this file — callers interact
// through the protocol types (OnDeviceRecommendation, OnDevicePostSessionInsight).

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable
struct GeneratedRecommendation {
    /// Recommended session mode: one of "focus", "relaxation", "sleep", "energize".
    @Guide(description: "Session mode. Must be one of: focus, relaxation, sleep, energize.")
    var mode: String

    /// Recommended duration in minutes, between 5 and 60.
    @Guide(description: "Session duration in minutes. Between 5 and 60.")
    var durationMinutes: Int

    /// Optional ambient sound bed identifier from the user's history, or empty string if no preference.
    @Guide(description: "Ambient bed ID from user history, or empty string for no preference.")
    var ambientBedID: String

    /// A 1-2 sentence explanation. Scientific tone, no exclamation marks, no "great job."
    @Guide(description: "1-2 sentence explanation. Use calm researcher tone. No exclamation marks. Use 'research suggests' language.")
    var explanation: String
}

@available(iOS 26.0, *)
@Generable
struct GeneratedInsight {
    /// A 1-3 sentence scientific-tone insight about the session outcome.
    @Guide(description: "1-3 sentence insight about session outcome. Calm researcher tone. No exclamation marks. Reference specific data points.")
    var insight: String
}
#endif

// MARK: - On-Device Coach Service

/// AI coaching service backed by Apple Foundation Models (iOS 26+).
///
/// All generation happens on-device via `LanguageModelSession`. The service
/// checks model availability at init and before every call. If the system
/// language model is not available for any reason, methods return `nil`.
///
/// Thread safety: This class is `Sendable`. Each generation call creates
/// its own `LanguageModelSession` instance, which is lightweight and
/// designed for single-use conversations.
public final class OnDeviceCoachService: OnDeviceCoachProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.bionaural", category: "OnDeviceCoach")

    // MARK: - Initialization

    public init() {}

    // MARK: - OnDeviceCoachProtocol

    public var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return Self.checkAvailability()
        }
        #endif
        return false
    }

    public func generateRecommendation(
        from sessions: [OnDeviceSessionSummary],
        context: OnDeviceCurrentContext
    ) async -> OnDeviceRecommendation? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return await generateRecommendationImpl(from: sessions, context: context)
        }
        #endif
        logger.info("Foundation Models not available on this OS version.")
        return nil
    }

    public func generatePostSessionInsight(
        from input: OnDevicePostSessionInput
    ) async -> OnDevicePostSessionInsight? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return await generatePostSessionInsightImpl(from: input)
        }
        #endif
        logger.info("Foundation Models not available on this OS version.")
        return nil
    }

    // MARK: - Implementation (iOS 26+)

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func checkAvailability() -> Bool {
        let availability = SystemLanguageModel.default.availability
        switch availability {
        case .available:
            return true
        case .unavailable:
            return false
        @unknown default:
            return false
        }
    }

    @available(iOS 26.0, *)
    private func generateRecommendationImpl(
        from sessions: [OnDeviceSessionSummary],
        context: OnDeviceCurrentContext
    ) async -> OnDeviceRecommendation? {
        guard Self.checkAvailability() else {
            logger.info("System language model not available. Skipping recommendation.")
            return nil
        }

        let prompt = buildRecommendationPrompt(from: sessions, context: context)

        do {
            let session = LanguageModelSession(
                instructions: Self.recommendationSystemInstructions
            )

            let response = try await session.respond(
                to: prompt,
                generating: GeneratedRecommendation.self
            )

            let result = response.content
            let ambientID = result.ambientBedID.isEmpty ? nil : result.ambientBedID

            // Validate mode is one of the known modes.
            let validModes = FocusMode.allCases.map(\.rawValue)
            let mode = validModes.contains(result.mode.lowercased())
                ? result.mode.lowercased()
                : "focus"

            // Clamp duration to reasonable range.
            // Note: upper bound (60) is an AI output validation clamp, distinct from
            // Constants.maxSessionMinutes (120) which is the app-wide maximum.
            let duration = min(max(result.durationMinutes, Constants.minimumSessionMinutes), 60)

            logger.debug("On-device recommendation generated: \(mode) for \(duration) min.")

            return OnDeviceRecommendation(
                mode: mode,
                durationMinutes: duration,
                ambientBedID: ambientID,
                explanation: result.explanation
            )
        } catch {
            logger.error("Failed to generate on-device recommendation: \(error.localizedDescription)")
            return nil
        }
    }

    @available(iOS 26.0, *)
    private func generatePostSessionInsightImpl(
        from input: OnDevicePostSessionInput
    ) async -> OnDevicePostSessionInsight? {
        guard Self.checkAvailability() else {
            logger.info("System language model not available. Skipping post-session insight.")
            return nil
        }

        let prompt = buildPostSessionPrompt(from: input)

        do {
            let session = LanguageModelSession(
                instructions: Self.postSessionSystemInstructions
            )

            let response = try await session.respond(
                to: prompt,
                generating: GeneratedInsight.self
            )

            let result = response.content

            logger.debug("On-device post-session insight generated.")

            return OnDevicePostSessionInsight(insight: result.insight)
        } catch {
            logger.error("Failed to generate on-device insight: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - System Instructions

    @available(iOS 26.0, *)
    private static let recommendationSystemInstructions = """
        You are BioNaural's on-device wellness advisor. You analyze a user's recent \
        session history and current state to recommend their next binaural beats session.

        Voice rules:
        - Calm researcher tone. Never use exclamation marks.
        - Use "research suggests" or "your data indicates", never "studies prove."
        - No filler phrases like "great job" or "keep it up."
        - Be specific: reference actual patterns from the data provided.
        - Explanations should be 1-2 sentences, scientifically grounded.

        Session modes available: focus, relaxation, sleep, energize.
        Duration range: 5 to 60 minutes.
        Consider time of day, sleep quality, heart rate, and session history patterns.
        """

    @available(iOS 26.0, *)
    private static let postSessionSystemInstructions = """
        You are BioNaural's on-device session analyst. You provide a brief, \
        scientific-tone insight about a just-completed binaural beats session.

        Voice rules:
        - Calm researcher tone. Never use exclamation marks.
        - Use "research suggests" or "your data indicates", never "studies prove."
        - No filler phrases like "great job" or "well done."
        - Reference specific data points (HR delta, HRV change, duration).
        - Keep insights to 1-3 sentences.
        - Frame observations, not judgments. "Your heart rate decreased by X BPM" \
          not "You did a great job relaxing."
        """
    #endif

    // MARK: - Prompt Construction

    private func buildRecommendationPrompt(
        from sessions: [OnDeviceSessionSummary],
        context: OnDeviceCurrentContext
    ) -> String {
        var lines: [String] = []

        lines.append("Current state:")
        lines.append("- Time of day: \(Self.timeOfDayLabel(for: context.currentHour))")

        if let sleepQuality = context.lastNightSleepQuality {
            let qualityLabel = Self.sleepQualityLabel(for: sleepQuality)
            lines.append("- Last night's sleep: \(qualityLabel) (\(String(format: "%.0f", sleepQuality * 100))%)")
        } else {
            lines.append("- Last night's sleep: unknown")
        }

        if let restingHR = context.currentRestingHR {
            lines.append("- Current resting HR: \(String(format: "%.0f", restingHR)) BPM")
        } else {
            lines.append("- Current resting HR: unknown")
        }

        if sessions.isEmpty {
            lines.append("\nNo previous sessions available. Recommend a suitable first session.")
        } else {
            lines.append("\nRecent session history (most recent first):")
            for (index, session) in sessions.prefix(10).enumerated() {
                let scoreStr: String
                if let score = session.biometricSuccessScore {
                    scoreStr = String(format: "%.0f%%", score * 100)
                } else {
                    scoreStr = "n/a"
                }

                let soundStr: String
                if let ambient = session.ambientBedID {
                    soundStr = ambient
                } else if let first = session.melodicLayerIDs.first {
                    soundStr = first
                } else {
                    soundStr = "none"
                }

                lines.append(
                    "  \(index + 1). \(session.mode) | \(session.durationMinutes) min | "
                    + "\(Self.timeOfDayLabel(for: session.hourOfDay)) | "
                    + "success: \(scoreStr) | sound: \(soundStr)"
                )
            }
        }

        lines.append("\nRecommend the best next session based on these patterns.")

        return lines.joined(separator: "\n")
    }

    private func buildPostSessionPrompt(from input: OnDevicePostSessionInput) -> String {
        var lines: [String] = []

        lines.append("Just-completed session:")
        lines.append("- Mode: \(input.mode)")
        lines.append("- Duration: \(input.durationMinutes) minutes")

        if let hrDelta = input.heartRateDelta {
            let direction = hrDelta < 0 ? "decreased" : (hrDelta > 0 ? "increased" : "unchanged")
            lines.append("- Heart rate \(direction) by \(String(format: "%.1f", abs(hrDelta))) BPM")
        } else {
            lines.append("- Heart rate data: unavailable")
        }

        if let hrvDelta = input.hrvDelta {
            let direction = hrvDelta > 0 ? "increased" : (hrvDelta < 0 ? "decreased" : "unchanged")
            lines.append("- HRV \(direction) by \(String(format: "%.1f", abs(hrvDelta))) ms")
        } else {
            lines.append("- HRV data: unavailable")
        }

        if let score = input.biometricSuccessScore {
            lines.append("- Biometric success score: \(String(format: "%.0f", score * 100))%")
        }

        let sounds = [input.ambientBedID].compactMap { $0 } + input.melodicLayerIDs
        if !sounds.isEmpty {
            lines.append("- Sounds used: \(sounds.joined(separator: ", "))")
        }

        lines.append("\nProvide a brief scientific insight about this session outcome.")

        return lines.joined(separator: "\n")
    }

    // MARK: - Label Helpers

    private static func timeOfDayLabel(for hour: Int) -> String {
        switch hour {
        case 5..<9:    return "early morning"
        case 9..<12:   return "morning"
        case 12..<14:  return "midday"
        case 14..<17:  return "afternoon"
        case 17..<20:  return "evening"
        case 20..<23:  return "late evening"
        default:       return "night"
        }
    }

    private static func sleepQualityLabel(for score: Double) -> String {
        switch score {
        case 0.0..<0.3:  return "poor"
        case 0.3..<0.5:  return "below average"
        case 0.5..<0.7:  return "moderate"
        case 0.7..<0.85: return "good"
        default:         return "excellent"
        }
    }
}
