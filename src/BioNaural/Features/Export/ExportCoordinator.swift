// ExportCoordinator.swift
// BioNaural
//
// MainActor-isolated coordinator that owns the export task, the
// progress object, and the resulting file URL. The sheet view
// observes this coordinator; it owns nothing transient itself.
//
// Surfaces three terminal states:
//   - .idle         (initial; user hasn't tapped Render)
//   - .rendering    (Task is running; progress is updating)
//   - .completed(URL) (file ready for ShareLink)
//   - .failed(Error)  (render failed for a reason worth showing)
//   - .cancelled    (user backed out; suppress UI noise)

import BioNauralShared
import Foundation
import Observation

@MainActor
@Observable
final class ExportCoordinator {

    enum Phase {
        case idle
        case rendering
        case completed(URL)
        case failed(Error)
        case cancelled
    }

    private(set) var phase: Phase = .idle
    let progress = RenderProgress()

    let compositionName: String
    let isAdaptive: Bool
    let suggestedDurationMinutes: Int
    let mode: FocusMode

    private let request: CompositionRenderRequest
    private var renderTask: Task<Void, Never>?

    /// Fails when the source composition has no valid focus mode —
    /// returning `nil` here lets the caller fall back gracefully rather
    /// than presenting an export sheet that can never succeed.
    init?(composition: CustomComposition) {
        guard let request = CompositionRenderRequest(composition: composition) else {
            return nil
        }
        self.request = request
        self.compositionName = composition.name
        self.isAdaptive = composition.isAdaptive
        self.mode = request.mode
        self.suggestedDurationMinutes = min(
            composition.durationMinutes,
            Theme.Audio.Export.durationCapMinutes
        )
    }

    var maxDurationMinutes: Int { Theme.Audio.Export.durationCapMinutes }

    func start(format: AudioExportFormat, durationMinutes: Int, mix: RenderMix) {
        guard renderTask == nil else { return }
        phase = .rendering

        let request = self.request
        let progress = self.progress

        renderTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let url = try await CompositionRenderEngine.render(
                    request: request,
                    mix: mix,
                    format: format,
                    durationMinutes: durationMinutes,
                    progress: progress
                )
                await MainActor.run {
                    self?.phase = .completed(url)
                    self?.renderTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.phase = .cancelled
                    self?.renderTask = nil
                }
            } catch {
                await MainActor.run {
                    self?.phase = .failed(error)
                    self?.renderTask = nil
                }
            }
        }
    }

    func cancel() {
        renderTask?.cancel()
    }
}
