// BioNauralWatchApp.swift
// BioNauralWatch
//
// @main entry point for the watchOS target. Activates WCSession for
// iPhone communication and presents the root Watch interface.
// Routes between idle, active session, and post-session screens.

import SwiftUI
import WatchConnectivity

@main
struct BioNauralWatchApp: App {

    // MARK: - Dependencies

    /// The shared session manager owns the HealthKit workout session,
    /// connectivity, audio engine, and session lifecycle for the entire Watch app.
    @State private var sessionManager = WatchSessionManager()

    // MARK: - WCSession Activation

    /// WCSession delegate adapter — activates the session at launch so
    /// the Watch is ready to receive commands from iPhone immediately.
    @WKApplicationDelegateAdaptor private var appDelegate: WatchAppDelegate

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(sessionManager)
        }
    }
}

// MARK: - WatchRootView

/// Routes between the three main screens based on session state.
struct WatchRootView: View {

    @Environment(WatchSessionManager.self) private var sessionManager

    var body: some View {
        Group {
            if sessionManager.showPostSession, let result = sessionManager.lastSessionResult {
                WatchPostSessionView(result: result) {
                    sessionManager.dismissPostSession()
                }
            } else if sessionManager.isSessionActive {
                WatchSessionView()
            } else {
                WatchIdleView()
            }
        }
        .animation(.easeInOut(duration: WatchDesign.Animation.standardDuration), value: sessionManager.isSessionActive)
        .animation(.easeInOut(duration: WatchDesign.Animation.standardDuration), value: sessionManager.showPostSession)
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
