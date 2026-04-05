// AICoachService.swift
// BioNaural
//
// AI coaching integration layer. Protocol-based so AppDependencies can inject
// either the live Claude API service or the offline rule-based fallback.
//
// Privacy contract: ONLY aggregated summaries are sent to the API. Never raw
// HealthKit data, never timestamps, never device identifiers. The AICoachContext
// struct is the privacy boundary — nothing outside it leaves the device.
//
// v1 ships with OfflineAICoachService (rule-based, no network).
// v2 drop-in: set ANTHROPIC_API_KEY in environment or Keychain and swap to
// ClaudeAICoachService in AppDependencies. No other changes required.

import Foundation
import os.log

// MARK: - Protocol

/// Contract for the AI coaching service. Both online (Claude API) and
/// offline (rule-based) implementations conform to this protocol.
public protocol AICoachServiceProtocol: AnyObject, Sendable {

    /// Generates a personalized insight from aggregated session data.
    func generateInsight(from context: AICoachContext) async throws -> AICoachInsight

    /// Generates a natural-language session recommendation.
    func generateSessionRecommendation(from context: AICoachContext) async throws -> String

    /// Whether the service is configured and ready to accept requests.
    var isAvailable: Bool { get }
}

// MARK: - Context (Privacy Boundary)

/// Aggregated, anonymized context sent to the LLM. This struct IS the privacy
/// boundary — nothing beyond these fields ever leaves the device.
///
/// All values are pre-computed summaries. No raw HealthKit samples, no
/// timestamps, no user identifiers.
public struct AICoachContext: Codable, Sendable {

    /// Number of completed sessions in the current calendar week.
    public let sessionsThisWeek: Int

    /// Total session minutes across all modes this week.
    public let totalSessionMinutes: Int

    /// The mode the user has used most frequently this week.
    public let mostUsedMode: String

    /// Average session duration in minutes across all modes.
    public let averageSessionDuration: Int

    /// Directional HRV trend over the last 7 days.
    /// One of: "improving", "stable", "declining", "unknown".
    public let hrvTrend: String

    /// Directional sleep quality trend over the last 7 days.
    /// One of: "improving", "stable", "declining", "unknown".
    public let sleepQualityTrend: String

    /// The user's top 3 ambient sound tags by session frequency.
    public let topSounds: [String]

    /// Average biometric success score (0.0-1.0) across recent sessions.
    public let biometricSuccessAverage: Double

    /// Natural-language summary of mood check-in patterns.
    /// Example: "tends toward wired on Monday mornings, calm on weekends".
    public let moodPatterns: String

    /// The most recent rule-based insights already shown to the user.
    /// Sent so the LLM avoids repeating them.
    public let recentInsights: [String]

    public init(
        sessionsThisWeek: Int,
        totalSessionMinutes: Int,
        mostUsedMode: String,
        averageSessionDuration: Int,
        hrvTrend: String,
        sleepQualityTrend: String,
        topSounds: [String],
        biometricSuccessAverage: Double,
        moodPatterns: String,
        recentInsights: [String]
    ) {
        self.sessionsThisWeek = sessionsThisWeek
        self.totalSessionMinutes = totalSessionMinutes
        self.mostUsedMode = mostUsedMode
        self.averageSessionDuration = averageSessionDuration
        self.hrvTrend = hrvTrend
        self.sleepQualityTrend = sleepQualityTrend
        self.topSounds = topSounds
        self.biometricSuccessAverage = biometricSuccessAverage
        self.moodPatterns = moodPatterns
        self.recentInsights = recentInsights
    }
}

// MARK: - Insight Response

/// A structured insight returned by the coaching service.
public struct AICoachInsight: Codable, Sendable, Equatable {

    /// Short headline for the insight card (max ~60 chars).
    public let headline: String

    /// 2-3 sentence body explaining the insight.
    public let body: String

    /// Optional actionable suggestion (e.g., "Try a 15-minute Relaxation
    /// session before your afternoon meetings").
    public let suggestedAction: String?

    /// Confidence in the insight quality (0.0-1.0).
    /// Rule-based insights report their data-backed confidence.
    /// LLM insights default to 1.0 (the model self-regulates via prompt).
    public let confidence: Double

    public init(headline: String, body: String, suggestedAction: String?, confidence: Double) {
        self.headline = headline
        self.body = body
        self.suggestedAction = suggestedAction
        self.confidence = confidence
    }
}

// MARK: - Errors

/// Errors specific to the AI coaching layer.
public enum AICoachError: Error, LocalizedError {
    case noAPIKey
    case apiError(statusCode: Int, message: String)
    case rateLimited(retryAfterSeconds: Int?)
    case invalidResponse
    case encodingFailed
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "AI coaching is not configured. Set an API key to enable."
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .rateLimited(let retry):
            if let seconds = retry {
                return "Rate limited. Try again in \(seconds) seconds."
            }
            return "Rate limited. Try again later."
        case .invalidResponse:
            return "Received an invalid response from the AI service."
        case .encodingFailed:
            return "Failed to encode the request."
        case .networkUnavailable:
            return "Network is unavailable. Using offline insights."
        }
    }
}

// MARK: - Claude API Service (v2 Drop-In)

/// Production AI coaching service backed by the Anthropic Claude API.
///
/// Drop-in activation:
/// 1. Set `ANTHROPIC_API_KEY` in the environment, or pass the key directly.
/// 2. Swap `OfflineAICoachService` for `ClaudeAICoachService` in `AppDependencies`.
/// 3. That's it. The protocol surface is identical.
///
/// All requests use aggregated `AICoachContext` — no raw health data leaves the device.
public final class ClaudeAICoachService: AICoachServiceProtocol, @unchecked Sendable {

    // MARK: - Configuration

    private static let defaultEndpoint = "https://api.anthropic.com/v1/messages"
    private static let apiVersion = "2023-06-01"
    private static let model = "claude-sonnet-4-20250514"
    private static let maxInsightTokens = 300
    private static let maxRecommendationTokens = 200

    private let apiKey: String?
    private let endpoint: URL
    private let urlSession: URLSession
    private let logger = Logger(subsystem: "com.bionaural", category: "AICoach")

    // MARK: - System Prompts

    private static let insightSystemPrompt = """
        You are BioNaural's AI wellness coach. You analyze aggregated session \
        summaries (never raw health data) and provide personalized insights about \
        the user's focus, relaxation, sleep, and energy patterns.

        Rules:
        - Never make medical claims or diagnoses.
        - Use "research suggests" not "studies prove."
        - Be warm but direct. No filler.
        - Keep insights to 2-3 sentences maximum.
        - Suggest one specific, actionable next step.
        - Reference the user's actual data patterns — do not be generic.
        - Do not repeat insights listed in recentInsights.
        - Respond with valid JSON matching this schema:
          {"headline": "string", "body": "string", "suggestedAction": "string or null"}
        """

    private static let recommendationSystemPrompt = """
        You are BioNaural's session advisor. Based on the user's aggregated data, \
        suggest what kind of session they should do next and why.

        Rules:
        - One paragraph, 2-3 sentences maximum.
        - Be specific: mention mode, approximate duration, and timing.
        - Reference their patterns (e.g., "Your HRV has been declining — a \
          relaxation session before bed could help").
        - Never make medical claims. Use "research suggests" language.
        - Respond with plain text, no JSON.
        """

    // MARK: - Initialization

    /// Creates a Claude API coaching service.
    ///
    /// - Parameters:
    ///   - apiKey: Anthropic API key. Falls back to the `ANTHROPIC_API_KEY`
    ///     environment variable if nil.
    ///   - endpoint: Override for the API endpoint (useful for testing).
    ///   - urlSession: Override for the URL session (useful for testing).
    public init(
        apiKey: String? = nil,
        endpoint: URL? = nil,
        urlSession: URLSession = .shared
    ) {
        self.apiKey = apiKey ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        self.endpoint = endpoint ?? URL(string: Self.defaultEndpoint)!
        self.urlSession = urlSession
    }

    // MARK: - AICoachServiceProtocol

    public var isAvailable: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }

    public func generateInsight(from context: AICoachContext) async throws -> AICoachInsight {
        let contextJSON = try encodeContext(context)
        let userMessage = """
            Based on this user's recent aggregated data, provide one personalized insight.
            Respond ONLY with the JSON object — no markdown, no wrapping.

            \(contextJSON)
            """

        let responseText = try await callClaude(
            systemPrompt: Self.insightSystemPrompt,
            userMessage: userMessage,
            maxTokens: Self.maxInsightTokens
        )

        return try parseInsightResponse(responseText)
    }

    public func generateSessionRecommendation(from context: AICoachContext) async throws -> String {
        let contextJSON = try encodeContext(context)
        let userMessage = """
            Based on this user's recent aggregated data, suggest their next session.

            \(contextJSON)
            """

        return try await callClaude(
            systemPrompt: Self.recommendationSystemPrompt,
            userMessage: userMessage,
            maxTokens: Self.maxRecommendationTokens
        )
    }

    // MARK: - API Call

    private func callClaude(
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int
    ) async throws -> String {
        guard let apiKey, !apiKey.isEmpty else {
            throw AICoachError.noAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.addValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            throw AICoachError.encodingFailed
        }
        request.httpBody = httpBody

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            logger.error("Network request failed: \(error.localizedDescription)")
            throw AICoachError.networkUnavailable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AICoachError.invalidResponse
        }

        // Handle rate limiting with Retry-After.
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "retry-after")
                .flatMap(Int.init)
            logger.warning("Rate limited. Retry after: \(retryAfter ?? -1)s")
            throw AICoachError.rateLimited(retryAfterSeconds: retryAfter)
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            logger.error("API error \(httpResponse.statusCode): \(errorBody)")
            throw AICoachError.apiError(
                statusCode: httpResponse.statusCode,
                message: errorBody
            )
        }

        // Parse the Anthropic Messages API response.
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw AICoachError.invalidResponse
        }

        return text
    }

    // MARK: - Helpers

    private func encodeContext(_ context: AICoachContext) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(context)
        guard let json = String(data: data, encoding: .utf8) else {
            throw AICoachError.encodingFailed
        }
        return json
    }

    private func parseInsightResponse(_ text: String) throws -> AICoachInsight {
        // Strip any markdown code fences the model might add despite instructions.
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw AICoachError.invalidResponse
        }

        struct RawInsight: Decodable {
            let headline: String
            let body: String
            let suggestedAction: String?
        }

        do {
            let raw = try JSONDecoder().decode(RawInsight.self, from: data)
            return AICoachInsight(
                headline: raw.headline,
                body: raw.body,
                suggestedAction: raw.suggestedAction,
                confidence: 1.0
            )
        } catch {
            // If JSON parsing fails, treat the entire response as body text.
            logger.warning("Failed to parse structured insight, falling back to raw text.")
            return AICoachInsight(
                headline: "Weekly Insight",
                body: text.trimmingCharacters(in: .whitespacesAndNewlines),
                suggestedAction: nil,
                confidence: 0.8
            )
        }
    }
}

// MARK: - Offline Fallback Service (v1)

/// Rule-based coaching service that ships in v1. No API key, no network,
/// no privacy concerns. Generates insights from UserModelBuilder patterns
/// using deterministic rules.
///
/// This is NOT a degraded experience — it's the default. The LLM layer (v2)
/// adds nuance and natural language, but the offline service covers the
/// core insight patterns that matter.
public final class OfflineAICoachService: AICoachServiceProtocol, @unchecked Sendable {

    public var isAvailable: Bool { true }

    public init() {}

    // MARK: - AICoachServiceProtocol

    public func generateInsight(from context: AICoachContext) async throws -> AICoachInsight {
        // Evaluate rules in priority order. First match wins.

        // Rule 1: Declining HRV trend.
        if context.hrvTrend == "declining" {
            return AICoachInsight(
                headline: "HRV Trending Down",
                body: "Your heart rate variability has been declining this week. "
                    + "Research suggests that consistent relaxation practice can help "
                    + "support HRV recovery.",
                suggestedAction: "Try a 15-minute Relaxation session before bed tonight.",
                confidence: confidenceFromSessionCount(context.sessionsThisWeek)
            )
        }

        // Rule 2: Poor sleep quality trend.
        if context.sleepQualityTrend == "declining" {
            return AICoachInsight(
                headline: "Sleep Quality Dipping",
                body: "Your sleep quality has been declining recently. "
                    + "Evening sessions with calming sounds may help ease the "
                    + "transition to rest.",
                suggestedAction: "Try a Sleep session 30 minutes before your usual bedtime.",
                confidence: confidenceFromSessionCount(context.sessionsThisWeek)
            )
        }

        // Rule 3: High biometric success — positive reinforcement.
        if context.biometricSuccessAverage > 0.75 && context.sessionsThisWeek >= 3 {
            return AICoachInsight(
                headline: "Strong Week",
                body: "Your sessions are producing consistently good biometric responses. "
                    + "Your body is responding well to \(context.mostUsedMode) sessions "
                    + "with \(context.topSounds.first ?? "your current sounds").",
                suggestedAction: nil,
                confidence: confidenceFromSessionCount(context.sessionsThisWeek)
            )
        }

        // Rule 4: Low session count — encouragement.
        if context.sessionsThisWeek < 2 {
            return AICoachInsight(
                headline: "Room to Build",
                body: "You've had \(context.sessionsThisWeek) session\(context.sessionsThisWeek == 1 ? "" : "s") "
                    + "this week. Research suggests that regular short sessions are more "
                    + "effective than occasional long ones.",
                suggestedAction: "Even a 10-minute \(context.mostUsedMode) session can make a difference.",
                confidence: 0.5
            )
        }

        // Rule 5: Improving HRV — celebrate progress.
        if context.hrvTrend == "improving" {
            return AICoachInsight(
                headline: "HRV Improving",
                body: "Your heart rate variability has been trending up. Whatever you're "
                    + "doing is working — your nervous system is showing signs of better recovery.",
                suggestedAction: "Keep your current routine going.",
                confidence: confidenceFromSessionCount(context.sessionsThisWeek)
            )
        }

        // Rule 6: Default — session summary.
        return AICoachInsight(
            headline: "This Week So Far",
            body: "You've completed \(context.sessionsThisWeek) sessions totaling "
                + "\(context.totalSessionMinutes) minutes. Your most-used mode is "
                + "\(context.mostUsedMode) with an average duration of "
                + "\(context.averageSessionDuration) minutes.",
            suggestedAction: nil,
            confidence: confidenceFromSessionCount(context.sessionsThisWeek)
        )
    }

    public func generateSessionRecommendation(from context: AICoachContext) async throws -> String {
        // Time-agnostic recommendation based on patterns and trends.

        if context.hrvTrend == "declining" || context.sleepQualityTrend == "declining" {
            return "Your recent trends suggest your body could use some recovery. "
                + "A 15-minute Relaxation session with calming sounds would be a good choice."
        }

        if context.biometricSuccessAverage > 0.7 {
            return "Your \(context.mostUsedMode) sessions have been going well. "
                + "A \(context.averageSessionDuration)-minute session with "
                + "\(context.topSounds.first ?? "your preferred sounds") is a solid pick."
        }

        if context.sessionsThisWeek == 0 {
            return "You haven't had a session yet this week. "
                + "Starting with a short \(context.mostUsedMode) session can help "
                + "get you back into rhythm."
        }

        return "Based on your patterns, a \(context.averageSessionDuration)-minute "
            + "\(context.mostUsedMode) session would be a good fit right now."
    }

    // MARK: - Helpers

    /// Maps session count to a confidence score for rule-based insights.
    private func confidenceFromSessionCount(_ count: Int) -> Double {
        switch count {
        case 0...1: return 0.3
        case 2...4: return 0.6
        default:    return 0.8
        }
    }
}
