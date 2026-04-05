// NowPlayingManager.swift
// BioNaural
//
// Manages the system Now Playing info center and remote command center so that
// BioNaural sessions display correct metadata on the lock screen, Control Center,
// and Dynamic Island, and respond to hardware/software media controls.
//
// No SwiftUI imports — uses UIKit + MediaPlayer only (Audio/ layer rule).

import BioNauralShared
import MediaPlayer
import UIKit

// MARK: - NowPlayingManager

/// Coordinates `MPNowPlayingInfoCenter` metadata and `MPRemoteCommandCenter`
/// handlers for the active BioNaural session.
///
/// Typical lifecycle:
/// ```
/// manager.configure(mode: .focus, duration: 1800)
/// manager.updatePlaybackState(isPlaying: true, elapsed: 0)
/// // … on timer tick or pause/resume …
/// manager.updateElapsed(120)
/// manager.updatePlaybackState(isPlaying: false, elapsed: 120)
/// // … session ends …
/// manager.teardown()
/// ```
///
/// All methods are `@MainActor` because `MPNowPlayingInfoCenter` and
/// `MPRemoteCommandCenter` must be accessed from the main thread.
@MainActor
final class NowPlayingManager {

    // MARK: - Types

    /// Actions the remote command center can trigger.
    /// The caller supplies concrete closures — NowPlayingManager never
    /// imports or references the session ViewModel directly.
    struct CommandHandlers {
        /// Resume audio playback.
        var play: () -> Void
        /// Pause audio playback.
        var pause: () -> Void
        /// End the session entirely.
        var stop: () -> Void
        /// Toggle between playing and paused.
        var togglePlayPause: () -> Void
    }

    // MARK: - Constants

    /// Artist name displayed in Now Playing info.
    private static let artistName = "BioNaural"

    // MARK: - Artwork Generation Constants

    private enum ArtworkLayout {
        /// Size (in points) of the generated artwork image.
        static let imageSize: CGFloat = 600

        /// Radius of the mode-colored circle relative to the image size.
        static let circleFraction: CGFloat = 0.35

        /// Radius of the soft bloom behind the circle, relative to the image size.
        static let bloomFraction: CGFloat = 0.45

        /// Opacity of the bloom gradient's outermost color stop.
        static let bloomEdgeOpacity: CGFloat = 0.0

        /// Opacity of the bloom gradient's center color stop.
        static let bloomCenterOpacity: CGFloat = 0.35
    }

    // MARK: - Private State

    private var commandHandlers: CommandHandlers?
    private var cachedArtwork: MPMediaItemArtwork?
    private var currentMode: FocusMode?
    private var currentDuration: TimeInterval = .zero

    // MARK: - Configuration

    /// Sets up Now Playing metadata and registers remote command handlers.
    ///
    /// Call once when a session starts. Subsequent calls reconfigure from scratch.
    ///
    /// - Parameters:
    ///   - mode: The session's focus mode (determines title and artwork color).
    ///   - duration: Target session duration in seconds.
    ///   - handlers: Closures invoked by remote command events.
    func configure(
        mode: FocusMode,
        duration: TimeInterval,
        handlers: CommandHandlers
    ) {
        currentMode = mode
        currentDuration = duration
        commandHandlers = handlers

        // Generate artwork for this mode.
        let modeColor = uiColor(for: mode)
        cachedArtwork = generateArtwork(modeColor: modeColor)

        // Populate initial Now Playing info.
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = mode.displayName
        info[MPMediaItemPropertyArtist] = Self.artistName
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = TimeInterval.zero
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        if let artwork = cachedArtwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Register remote commands.
        registerCommands(handlers: handlers)
    }

    // MARK: - Playback State Updates

    /// Updates the Now Playing info to reflect a play/pause state change.
    ///
    /// The system interpolates elapsed time automatically when the playback
    /// rate is `1.0`, so you only need to call this on state transitions —
    /// not every second.
    ///
    /// - Parameters:
    ///   - isPlaying: Whether audio is currently playing.
    ///   - elapsed: Current elapsed session time in seconds.
    func updatePlaybackState(isPlaying: Bool, elapsed: TimeInterval) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Updates only the elapsed playback time without changing the playback rate.
    ///
    /// Use this for periodic corrections (e.g., timer re-syncs) while playback
    /// continues. The system interpolates between updates, so calling this every
    /// few seconds is sufficient.
    ///
    /// - Parameter elapsed: Current elapsed session time in seconds.
    func updateElapsed(_ elapsed: TimeInterval) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Teardown

    /// Removes all Now Playing metadata and disables remote command handlers.
    ///
    /// Call when the session ends or the user navigates away from the session screen.
    func teardown() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        let commandCenter = MPRemoteCommandCenter.shared()

        // Remove targets from enabled commands.
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.stopCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)

        // Disable all commands.
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.stopCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false

        // Re-disable track/seek commands (defensive).
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false

        commandHandlers = nil
        cachedArtwork = nil
        currentMode = nil
        currentDuration = .zero
    }

    // MARK: - Private: Remote Command Registration

    private func registerCommands(handlers: CommandHandlers) {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Enable session-relevant commands.
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.commandHandlers?.play()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.commandHandlers?.pause()
            return .success
        }

        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { [weak self] _ in
            self?.commandHandlers?.stop()
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.commandHandlers?.togglePlayPause()
            return .success
        }

        // Explicitly disable track/seek commands so the system does not
        // display skip/scrub controls that have no meaning for a session.
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
    }

    // MARK: - Private: Artwork Generation

    /// Generates a mode-colored circle artwork image for the Now Playing info.
    ///
    /// The image is a dark background with a centered circle in the mode color,
    /// surrounded by a soft bloom (radial gradient). Generated via
    /// `UIGraphicsImageRenderer` — no bundled assets required.
    ///
    /// - Parameter modeColor: The `UIColor` for the current session mode.
    /// - Returns: An `MPMediaItemArtwork` wrapping the generated image.
    private func generateArtwork(modeColor: UIColor) -> MPMediaItemArtwork {
        let size = ArtworkLayout.imageSize
        let bounds = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        let renderer = UIGraphicsImageRenderer(bounds: bounds)

        let image = renderer.image { context in
            let cgContext = context.cgContext
            let center = CGPoint(x: size / 2, y: size / 2)

            // Dark background (matches Theme.Colors.Hex.canvasDark).
            let backgroundColor = UIColor(
                red: CGFloat((Theme.Colors.Hex.canvasDark >> 16) & 0xFF) / 255.0,
                green: CGFloat((Theme.Colors.Hex.canvasDark >> 8) & 0xFF) / 255.0,
                blue: CGFloat((Theme.Colors.Hex.canvasDark) & 0xFF) / 255.0,
                alpha: 1.0
            )
            backgroundColor.setFill()
            cgContext.fill(bounds)

            // Soft bloom — radial gradient from mode color to transparent.
            let bloomRadius = size * ArtworkLayout.bloomFraction
            let bloomCenterColor = modeColor.withAlphaComponent(
                ArtworkLayout.bloomCenterOpacity
            ).cgColor
            let bloomEdgeColor = modeColor.withAlphaComponent(
                ArtworkLayout.bloomEdgeOpacity
            ).cgColor

            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [bloomCenterColor, bloomEdgeColor] as CFArray,
                locations: [0.0, 1.0]
            ) {
                cgContext.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: bloomRadius,
                    options: .drawsAfterEndLocation
                )
            }

            // Centered circle in mode color.
            let circleRadius = size * ArtworkLayout.circleFraction
            let circleRect = CGRect(
                x: center.x - circleRadius,
                y: center.y - circleRadius,
                width: circleRadius * 2,
                height: circleRadius * 2
            )
            modeColor.setFill()
            cgContext.fillEllipse(in: circleRect)
        }

        return MPMediaItemArtwork(boundsSize: bounds.size) { _ in image }
    }

    // MARK: - Private: Mode Color Resolution

    /// Resolves a `FocusMode` to its `UIColor` using Theme hex constants.
    ///
    /// This avoids importing SwiftUI and keeps the Audio/ layer clean.
    /// Colors are sourced from `Theme.Colors.Hex` — never hardcoded.
    ///
    /// - Parameter mode: The focus mode to resolve.
    /// - Returns: The corresponding `UIColor`.
    private func uiColor(for mode: FocusMode) -> UIColor {
        let hex: UInt
        switch mode {
        case .focus:       hex = Theme.Colors.Hex.focus
        case .relaxation:  hex = Theme.Colors.Hex.relaxation
        case .sleep:       hex = Theme.Colors.Hex.sleep
        case .energize:    hex = Theme.Colors.Hex.energizeDark
        }

        return UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
