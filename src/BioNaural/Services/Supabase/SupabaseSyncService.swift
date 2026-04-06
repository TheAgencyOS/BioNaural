// SupabaseSyncService.swift
// BioNaural
//
// Handles bidirectional sync between on-device ML models/preferences
// and the Supabase backend. Syncs:
// - Sonic profile (learned sound preferences)
// - ML model parameters (Thompson Sampling, GP, Markov, etc.)
// - Session outcomes (for cross-user learning)
// - Population model weights (server-trained priors for cold-start)

import BioNauralShared
import Foundation
import os.log

// MARK: - SupabaseSyncService

public final class SupabaseSyncService: @unchecked Sendable {

    private let supabase: SupabaseManager
    private let logger = Logger(subsystem: "com.bionaural", category: "SyncService")

    private var functionsURL: String {
        Theme.Supabase.url + "/functions/v1"
    }

    public init(supabase: SupabaseManager) {
        self.supabase = supabase
    }

    // MARK: - Profile & ML Parameter Sync

    /// Bidirectional sync of sonic profile and ML model parameters.
    /// Returns any server-side updates the client should adopt.
    public func syncProfile(
        sonicProfile: SyncableSonicProfile?,
        mlParameters: [SyncableMLParam],
        lastSyncAt: Date?
    ) async throws -> SyncProfileResponse {
        guard supabase.isAuthenticated else {
            throw SyncError.notAuthenticated
        }

        let body = SyncProfileRequest(
            sonic_profile: sonicProfile,
            ml_parameters: mlParameters,
            last_sync_at: lastSyncAt?.ISO8601Format()
        )

        return try await invokeFunction("sync-profile", body: body)
    }

    // MARK: - Session Outcome Ingestion

    /// Upload a completed session outcome for ML training.
    /// The server anonymizes biometric data before adding to
    /// aggregate_outcomes for cross-user learning.
    public func ingestSession(_ session: SyncableSessionOutcome) async throws {
        guard supabase.isAuthenticated else {
            throw SyncError.notAuthenticated
        }

        let body = IngestSessionRequest(session: session)
        let _: IngestSessionResponse = try await invokeFunction("ingest-session", body: body)
    }

    // MARK: - Population Models (Cold-Start)

    /// Fetch server-trained population model weights.
    /// Called on app launch and weekly to update cold-start priors.
    public func fetchPopulationModels(
        mode: FocusMode? = nil,
        modelType: String? = nil
    ) async throws -> [PopulationModel] {
        guard supabase.isAuthenticated else {
            throw SyncError.notAuthenticated
        }

        var queryItems: [URLQueryItem] = []
        if let mode { queryItems.append(URLQueryItem(name: "mode", value: mode.rawValue)) }
        if let modelType { queryItems.append(URLQueryItem(name: "model_type", value: modelType)) }

        let response: PopulationModelsResponse = try await invokeFunction(
            "population-models",
            method: "GET",
            queryItems: queryItems
        )

        return response.models
    }

    // MARK: - Edge Function Invocation

    private func invokeFunction<T: Decodable>(
        _ name: String,
        method: String = "POST",
        body: (any Encodable)? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        var urlComponents = URLComponents(string: "\(functionsURL)/\(name)")!
        if let queryItems, !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw SyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if let session = try? await supabase.supabaseClient.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(Theme.Supabase.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body, method == "POST" {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
            throw SyncError.serverError(code, errorBody)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Syncable Types (Codable wrappers for on-device models)

/// Profile data suitable for server sync.
public struct SyncableSonicProfile: Codable, Sendable {
    public let instrument_weights: [String: Double]
    public let energy_preference: [String: Double]
    public let brightness_preference: Double
    public let density_preference: Double
    public let warmth_preference: Double?
    public let tempo_affinity: Double?
    public let key_preference: String?
    public let profile_hash: String?
    public let updated_at: String

    public init(
        instrumentWeights: [String: Double],
        energyPreference: [String: Double],
        brightnessPreference: Double,
        densityPreference: Double,
        warmthPreference: Double?,
        tempoAffinity: Double?,
        keyPreference: String?,
        profileHash: String?,
        updatedAt: Date
    ) {
        self.instrument_weights = instrumentWeights
        self.energy_preference = energyPreference
        self.brightness_preference = brightnessPreference
        self.density_preference = densityPreference
        self.warmth_preference = warmthPreference
        self.tempo_affinity = tempoAffinity
        self.key_preference = keyPreference
        self.profile_hash = profileHash
        self.updated_at = updatedAt.ISO8601Format()
    }
}

/// ML model parameters suitable for server sync.
public struct SyncableMLParam: Codable, Sendable {
    public let model_type: String
    public let parameters: [String: AnyCodable]
    public let version: Int
    public let training_session_count: Int?

    public init(
        modelType: String,
        parameters: [String: AnyCodable],
        version: Int,
        trainingSessionCount: Int? = nil
    ) {
        self.model_type = modelType
        self.parameters = parameters
        self.version = version
        self.training_session_count = trainingSessionCount
    }
}

/// Session outcome data for server ingestion.
public struct SyncableSessionOutcome: Codable, Sendable {
    public let id: String
    public let mode: String
    public let start_date: String
    public let end_date: String?
    public let duration_seconds: Int
    public let hr_start: Double?
    public let hr_end: Double?
    public let hr_delta: Double?
    public let hrv_start: Double?
    public let hrv_end: Double?
    public let hrv_delta: Double?
    public let average_heart_rate: Double?
    public let average_hrv: Double?
    public let time_to_calm_seconds: Double?
    public let time_to_sleep_seconds: Double?
    public let adaptation_count: Int
    public let sustained_deep_state_minutes: Double
    public let entrainment_method: String?
    public let beat_frequency_start: Double
    public let beat_frequency_end: Double
    public let carrier_frequency: Double
    public let ambient_bed_id: String?
    public let melodic_layer_ids: [String]
    public let stem_pack_id: String?
    public let was_completed: Bool
    public let thumbs_rating: String?
    public let feedback_tags: [String]?
    public let check_in_mood: Double?
    public let check_in_goal: String?
    public let check_in_skipped: Bool
    public let biometric_success_score: Double?
    public let overall_score: Double?
    public let time_of_day: String?
    public let day_of_week: Int?
}

// MARK: - Response Types

public struct SyncProfileResponse: Decodable, Sendable {
    public let sonic_profile: SyncableSonicProfile?
    public let ml_parameters: [SyncableMLParam]?
    public let population_models: [PopulationModel]?
}

public struct PopulationModel: Decodable, Sendable {
    public let model_type: String
    public let mode: String?
    public let parameters: [String: AnyCodable]
    public let version: Int
    public let training_session_count: Int?
    public let training_user_count: Int?
    public let trained_at: String?
    public let cross_validation_score: Double?
}

// MARK: - Internal Request Types

private struct SyncProfileRequest: Encodable {
    let sonic_profile: SyncableSonicProfile?
    let ml_parameters: [SyncableMLParam]
    let last_sync_at: String?
}

private struct IngestSessionRequest: Encodable {
    let session: SyncableSessionOutcome
}

private struct IngestSessionResponse: Decodable {
    let ok: Bool
}

private struct PopulationModelsResponse: Decodable {
    let models: [PopulationModel]
}

// MARK: - Errors

public enum SyncError: Error, LocalizedError {
    case notAuthenticated
    case invalidURL
    case serverError(Int, String)
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated for sync."
        case .invalidURL:
            return "Invalid sync URL."
        case .serverError(let code, let body):
            return "Sync error (\(code)): \(body)"
        case .decodingError(let detail):
            return "Failed to decode sync response: \(detail)"
        }
    }
}

// MARK: - AnyCodable (type-erased JSON value)

/// A type-erased Codable value for representing arbitrary JSON in ML parameters.
public struct AnyCodable: Codable, @unchecked Sendable, Equatable {

    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode AnyCodable"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                .init(codingPath: container.codingPath, debugDescription: "Cannot encode \(type(of: value))")
            )
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Simple equality for common types
        switch (lhs.value, rhs.value) {
        case (let l as Bool, let r as Bool): return l == r
        case (let l as Int, let r as Int): return l == r
        case (let l as Double, let r as Double): return l == r
        case (let l as String, let r as String): return l == r
        case (is NSNull, is NSNull): return true
        default: return false
        }
    }
}
