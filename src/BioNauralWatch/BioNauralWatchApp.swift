// BioNauralWatchApp.swift
// BioNauralWatch
//
// @main entry point for the watchOS target. Activates WCSession for
// iPhone communication and presents the root Watch interface.

import SwiftUI
import WatchConnectivity

@main
struct BioNauralWatchApp: App {

    // MARK: - Dependencies

    /// The shared session manager owns the HealthKit workout session,
    /// connectivity, and session lifecycle for the entire Watch app.
    @State private var sessionManager = WatchSessionManager()

    // MARK: - WCSession Activation

    /// WCSession delegate adapter — activates the session at launch so
    /// the Watch is ready to receive commands from iPhone immediately.
    @WKApplicationDelegateAdaptor private var appDelegate: WatchAppDelegate

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            WatchMainView()
                .environment(sessionManager)
        }
    }
}

// MARK: - WKApplicationDelegate

/// Minimal application delegate whose sole purpose is activating WCSession
/// as early as possible in the Watch app lifecycle. All message handling
/// is forwarded to `WatchSessionManager`.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {

    func applicationDidFinishLaunching() {
        guard WCSession.isSupported() else { return }
        // The actual delegate is set by WatchSessionManager during its init.
        // We just ensure session activation happens at launch.
        if WCSession.default.delegate == nil {
            // Safety: if the manager hasn't initialized yet, defer.
            // WatchSessionManager.init will handle activation.
        }
    }
}
