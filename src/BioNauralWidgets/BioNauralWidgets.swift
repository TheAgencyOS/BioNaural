// BioNauralWidgets.swift
// BioNauralWidgets
//
// @main WidgetBundle for the BioNaural widget extension.
// Registers all widget configurations: the Live Activity for Dynamic
// Island / Lock Screen, the home screen session summary widget, and
// the StandBy-optimized widget.

import SwiftUI
import WidgetKit
import BioNauralShared

@main
struct BioNauralWidgets: WidgetBundle {

    var body: some Widget {
        // Live Activity — Dynamic Island + Lock Screen during active sessions
        FocusLiveActivity()

        // Home screen widget — quick launch + last session summary
        SessionSummaryWidget()

        // Lock Screen widget — circular orb, rectangular info, inline status
        LockScreenWidget()

        // StandBy / always-on display widget
        StandByWidget()
    }
}
