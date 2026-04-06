 // CloudKitSyncService.swift
// BioNaural
//
// Monitors iCloud sync status and exposes it to the UI.
// SwiftData handles the actual sync automatically via
// NSPersistentCloudKitContainer — this service observes
// the import/export notifications and surfaces sync state.

import CloudKit
import Combine
import Foundation
import OSLog
import SwiftUI

// MARK: - Sync Status

/// Observable sync state for the UI layer.
public enum CloudSyncStatus: Sendable {
    /// iCloud is available and data is up to date.
    case synced
    /// A sync operation is currently in progress.
    case syncing
    /// iCloud is unavailable (signed out, no network, restricted).
    case unavailable(reason: String)
    /// A sync error occurred. Contains a user-facing description.
    case error(String)
    /// Sync has not been attempted yet.
    case idle
}

// MARK: - Protocol

/// Contract for CloudKit sync status observation.
@MainActor
public protocol CloudKitSyncServiceProtocol: AnyObject {
    /// Current sync status, observable by SwiftUI views.
    var syncStatus: CloudSyncStatus { get }

    /// Whether iCloud is available on this device.
    var isCloudAvailable: Bool { get }

    /// Checks the current iCloud account status and updates state.
    func checkAccountStatus() async
}

// MARK: - CloudKitSyncService

/// Observes Core Data / SwiftData CloudKit sync notifications
/// and translates them into a simple status enum for the UI.
@Observable
@MainActor
public final class CloudKitSyncService: CloudKitSyncServiceProtocol {

    // MARK: - Public State

    public private(set) var syncStatus: CloudSyncStatus = .idle
    public private(set) var isCloudAvailable: Bool = false

    // MARK: - Private State

    private let containerIdentifier: String
    private var notificationObservers: [Any] = []
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.bionaural",
        category: "CloudKitSync"
    )

    // MARK: - Initialization

    public init(containerIdentifier: String = "iCloud.com.bionaural.BioNaural") {
        self.containerIdentifier = containerIdentifier
        observeSyncNotifications()

        Task {
            await checkAccountStatus()
        }
    }

    // MARK: - Account Status

    public func checkAccountStatus() async {
        #if targetEnvironment(simulator)
        isCloudAvailable = false
        syncStatus = .unavailable(reason: String(localized: "iCloud sync is not available in the simulator."))
        logger.info("Skipping CloudKit account check on simulator.")
        #else
        do {
            let container = CKContainer(identifier: containerIdentifier)
            let status = try await container.accountStatus()

            switch status {
            case .available:
                isCloudAvailable = true
                if case .unavailable = syncStatus {
                    syncStatus = .synced
                }

            case .noAccount:
                isCloudAvailable = false
                syncStatus = .unavailable(reason: String(localized: "Sign in to iCloud in Settings to sync your data across devices."))

            case .restricted:
                isCloudAvailable = false
                syncStatus = .unavailable(reason: String(localized: "iCloud access is restricted on this device."))

            case .couldNotDetermine:
                isCloudAvailable = false
                syncStatus = .unavailable(reason: String(localized: "Unable to determine iCloud status."))

            case .temporarilyUnavailable:
                isCloudAvailable = false
                syncStatus = .unavailable(reason: String(localized: "iCloud is temporarily unavailable. Your data will sync when it reconnects."))

            @unknown default:
                isCloudAvailable = false
                syncStatus = .unavailable(reason: String(localized: "iCloud is not available."))
            }

            logger.info("iCloud account status: \(String(describing: status)), available: \(self.isCloudAvailable)")
        } catch {
            isCloudAvailable = false
            syncStatus = .error(error.localizedDescription)
            logger.error("Failed to check iCloud account: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Sync Notifications

    /// Observes NSPersistentCloudKitContainer event notifications to
    /// track import/export progress.
    private func observeSyncNotifications() {
        let nc = NotificationCenter.default

        // SwiftData/CoreData posts these when CloudKit sync events occur.
        let eventName = NSNotification.Name("NSPersistentCloudKitContainerEventChangedNotification")

        let observer = nc.addObserver(
            forName: eventName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract values before crossing isolation boundary
            // to avoid sending non-Sendable Notification.
            let event = notification.userInfo?["event"] as? NSObject
            let endDate = event?.value(forKey: "endDate") as? Date
            let succeeded = event?.value(forKey: "succeeded") as? Bool ?? true
            let errorMessage = (event?.value(forKey: "error") as? NSError)?.localizedDescription

            Task { @MainActor in
                self?.handleSyncEvent(endDate: endDate, succeeded: succeeded, errorMessage: errorMessage)
            }
        }

        notificationObservers.append(observer)

        // Also observe iCloud account changes.
        let accountObserver = nc.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAccountStatus()
            }
        }

        notificationObservers.append(accountObserver)
    }

    private func handleSyncEvent(endDate: Date?, succeeded: Bool, errorMessage: String?) {
        if endDate == nil {
            // Sync in progress
            syncStatus = .syncing
        } else if succeeded {
            syncStatus = .synced
            logger.debug("CloudKit sync completed successfully.")
        } else {
            let message = errorMessage ?? String(localized: "Sync encountered an issue. Your data is safe locally.")
            syncStatus = .error(message)
            logger.warning("CloudKit sync event failed: \(message)")
        }
    }

    // MARK: - Cleanup

    /// Removes all notification observers. Call before releasing.
    func removeObservers() {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
    }
}

// MARK: - Mock

/// Mock sync service for previews and tests.
@Observable
@MainActor
public final class MockCloudKitSyncService: CloudKitSyncServiceProtocol {
    public var syncStatus: CloudSyncStatus = .synced
    public var isCloudAvailable: Bool = true

    public init() {}

    public func checkAccountStatus() async {
        // No-op in tests.
    }
}
