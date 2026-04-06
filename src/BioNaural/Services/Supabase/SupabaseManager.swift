// SupabaseManager.swift
// BioNaural
//
// Central Supabase client wrapper. Provides authenticated access to
// the BioNaural backend for content delivery, profile sync, session
// ingestion, and generation job management.
//
// Uses the anonymous key for client-side operations (RLS-protected).
// The service role key is NEVER embedded in the client — it lives
// only in server-side Edge Functions and workers.

import AuthenticationServices
import BioNauralShared
import Foundation
import os.log
import Supabase

// MARK: - SupabaseManager

@Observable
public final class SupabaseManager: @unchecked Sendable {

    // MARK: - Properties

    private let client: SupabaseClient
    private let logger = Logger(subsystem: "com.bionaural", category: "Supabase")

    /// The authenticated user's internal BioNaural user ID (from `users` table).
    private(set) var userId: UUID?

    /// Whether the user is currently authenticated.
    var isAuthenticated: Bool { userId != nil }

    /// Current subscription tier.
    private(set) var subscriptionTier: String = "free"

    // MARK: - Init

    public init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: Theme.Supabase.url)!,
            supabaseKey: Theme.Supabase.anonKey
        )
    }

    /// Exposed for services that need direct Supabase access.
    var supabaseClient: SupabaseClient { client }

    // MARK: - Authentication (Sign in with Apple)

    /// Sign in with an Apple ID credential. Creates a Supabase auth session
    /// linked to the Apple ID. The `handle_new_user` trigger auto-creates
    /// a row in the `users` table on first sign-in.
    public func signInWithApple(
        idToken: String,
        nonce: String
    ) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )

        logger.info("Signed in as \(session.user.id)")
        await fetchUserRecord()
    }

    /// Attempt to restore an existing session on app launch.
    public func restoreSession() async {
        do {
            let session = try await client.auth.session
            logger.info("Session restored for \(session.user.id)")
            await fetchUserRecord()
        } catch {
            logger.info("No existing session to restore")
            userId = nil
        }
    }

    /// Sign out and clear local state.
    public func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            logger.error("Sign out error: \(error.localizedDescription)")
        }
        userId = nil
        subscriptionTier = "free"
    }

    // MARK: - User Record

    /// Fetch the internal user record from the `users` table.
    /// Called after successful auth to get `userId` and `subscriptionTier`.
    private func fetchUserRecord() async {
        do {
            struct UserRow: Decodable {
                let id: UUID
                let subscription_tier: String
            }

            let rows: [UserRow] = try await client
                .from("users")
                .select("id, subscription_tier")
                .limit(1)
                .execute()
                .value

            if let user = rows.first {
                self.userId = user.id
                self.subscriptionTier = user.subscription_tier
                logger.info("User record loaded: \(user.id), tier: \(user.subscription_tier)")
            }
        } catch {
            logger.error("Failed to fetch user record: \(error.localizedDescription)")
        }
    }

    /// Update device metadata on the user record (called on app launch).
    public func updateDeviceInfo(
        deviceModel: String,
        iosVersion: String,
        appVersion: String
    ) async {
        guard userId != nil else { return }

        do {
            try await client
                .from("users")
                .update([
                    "device_model": deviceModel,
                    "ios_version": iosVersion,
                    "app_version": appVersion,
                ])
                .execute()
        } catch {
            logger.error("Failed to update device info: \(error.localizedDescription)")
        }
    }
}
