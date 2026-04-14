// SessionStyleMemory.swift
// BioNaural — v3 Composing Core
//
// Lightweight stylistic continuity between regenerated MusicPatterns.
// When biometrics change or the session arc advances to a new phase,
// the pipeline builds a fresh MusicPattern. Without a memory of what
// was just playing, each regeneration picks atoms from scratch and
// the listener hears the session jump to "a new idea" every time.
//
// The factor oracle approach (Assayag/Dubnov, OMax) is the textbook
// solution: build a suffix automaton over a symbol sequence, generate
// by random walk + suffix-link jumps. That's the right technique for
// long-form stylistic generation but the full implementation is
// substantial and overkill for our use case.
//
// This class is the pragmatic 80% version: a recency-weighted map
// of "atom names most used in the last few blocks." CompositionPlanner
// consults it to re-order candidate atoms so recently-played atoms
// come first — each regeneration is biased toward continuation while
// still honoring the current MusicalClass rules.
//
// Reference type so the same memory persists across successive
// plan() calls within one session.

import Foundation

public final class SessionStyleMemory: @unchecked Sendable {

    /// Per-role recent atom names, most-recent-last. Capped at
    /// `capacity` entries per role so memory stays bounded.
    private var recent: [TrackRole: [String]] = [:]

    /// How many recent atom names to remember per role. With the
    /// default 4-bar section × A/B split each block contributes up
    /// to ~8 atoms per track, so 32 gives ~4 blocks of history.
    private let capacity: Int

    public init(capacity: Int = 32) {
        self.capacity = max(1, capacity)
    }

    /// Record that an atom was used for a given role. Called by
    /// CompositionPlanner while assembling each molecule.
    public func record(role: TrackRole, atomName: String) {
        var list = recent[role] ?? []
        list.append(atomName)
        if list.count > capacity {
            list.removeFirst(list.count - capacity)
        }
        recent[role] = list
    }

    /// Return a recency score [0, 1] for a given atom name —
    /// 1.0 = used most recently, 0.0 = never used. Callers sort
    /// candidate atoms by `recency(...)` descending to bias toward
    /// continuation.
    public func recency(role: TrackRole, atomName: String) -> Double {
        guard let list = recent[role], !list.isEmpty else { return 0.0 }
        // Find the MOST recent occurrence by iterating from the end.
        var latestIndex: Int? = nil
        for i in stride(from: list.count - 1, through: 0, by: -1) {
            if list[i] == atomName {
                latestIndex = i
                break
            }
        }
        guard let position = latestIndex else { return 0.0 }
        return Double(position + 1) / Double(list.count)
    }

    /// True if this role has no history yet.
    public func isEmpty(for role: TrackRole) -> Bool {
        (recent[role] ?? []).isEmpty
    }

    /// Clear all memory for a clean restart.
    public func reset() {
        recent.removeAll()
    }
}
