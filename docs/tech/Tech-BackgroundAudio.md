# BioNaural — iOS Background Audio & Platform Integration

> AVAudioSession, interruptions, lock screen, Live Activities, headphones, Spatial Audio, and Focus mode.

---

## AVAudioSession Configuration

**Category:** `.playback` — audio continues when screen locks or app backgrounds. This is the correct choice.

**Mix with others:** Off by default. Binaural beats require precise L/R frequency differences — overlaying music can mask the beat. Optional user toggle for those who want to layer with lo-fi playlists.

**Duck others:** Not recommended. Ducking would suppress other audio for the entire session.

```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playback, mode: .default, options: [])
try session.setActive(true)

// On session end:
try session.setActive(false, options: [.notifyOthersOnDeactivation])
```

**Background mode:** `UIBackgroundModes: audio` in Info.plist. No time limit on background audio as long as the engine is actively producing audio. If the app plays silence (no buffers flowing), iOS may suspend after ~30 seconds.

---

## Lock Screen & Now Playing

**MPNowPlayingInfoCenter** — populates lock screen, Control Center, and Dynamic Island:

```swift
var nowPlaying: [String: Any] = [
    MPMediaItemPropertyTitle: "Deep Focus",
    MPMediaItemPropertyArtist: "BioNaural",
    MPMediaItemPropertyPlaybackDuration: session.totalDuration,
    MPNowPlayingInfoPropertyElapsedPlaybackTime: session.elapsed,
    MPNowPlayingInfoPropertyPlaybackRate: 1.0,
    MPMediaItemPropertyArtwork: artwork
]
MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying
```

**MPRemoteCommandCenter** — register play, pause, stop. Disable next/previous/skip (not applicable). Without these handlers, lock screen controls won't appear.

---

## Interruption Handling

| Scenario | What Happens | Resume Behavior |
|----------|-------------|----------------|
| Phone call | `.began` fires, audio stops. After call: `.ended` with `.shouldResume`. | Auto-resume safe |
| Siri | `.began` → `.ended` with `.shouldResume` | Auto-resume safe |
| Another app plays audio | `.began`. When that app stops: `.ended` | Check `.shouldResume` |
| Notification sounds | Brief duck, no interruption notification fires | No action needed |
| Alarm / Timer | `.began` → `.ended` with `.shouldResume` | Auto-resume safe |

**Route change (headphones unplugged):** AVAudioEngine does NOT auto-pause like AVPlayer. Must handle `.oldDeviceUnavailable` manually to pause audio and warn that binaural beats require headphones.

---

## Live Activities & Dynamic Island

### ActivityAttributes

```swift
struct FocusSessionAttributes: ActivityAttributes {
    let sessionName: String
    let startTime: Date
    
    struct ContentState: Codable, Hashable {
        let elapsedTime: TimeInterval
        let currentPhase: String
        let heartRate: Int?
        let isPlaying: Bool
    }
}
```

### Dynamic Island Layout

- **Compact leading:** Small Orb icon (pulsing in mode color)
- **Compact trailing:** Timer (SF Mono, `Text(timerInterval:)`)
- **Expanded:** Session name, phase, timer, HR readout, Orb visualization
- **Lock Screen:** Thin bar with mode color gradient, timer + mode name

**Updates:** Since background audio keeps the app alive, update Live Activity directly via `activity.update()`. System may throttle to ~1/sec. Use `Text(timerInterval:)` for countdown so system handles rendering.

**End:** Keep on lock screen for 5 minutes post-session, then auto-dismiss.

---

## Background Processing

**WatchConnectivity in background:** Works while audio is playing. `sendMessage` delivers when both apps are active — with background audio, the iOS app IS active. Messages arrive on background queue.

**BGTaskScheduler:** Not needed for audio or biometric pipeline. Optional for data sync tasks.

**HealthKit queries:** Run fine while background audio is active. The app process is alive and can execute arbitrary code.

---

## Headphone Detection

```swift
func isHeadphonesConnected() -> Bool {
    let route = AVAudioSession.sharedInstance().currentRoute
    return route.outputs.contains { output in
        [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains(output.portType)
    }
}
```

| Port Type | Binaural Beats Work? | Notes |
|----------|---------------------|-------|
| `.headphones` (wired) | Yes — best | No latency, no codec artifacts |
| `.bluetoothA2DP` (AirPods, etc.) | Yes | AAC preserves stereo. ~40-80ms latency (irrelevant). |
| `.bluetoothHFP` | May be mono | Warn user |
| `.builtInSpeaker` | No | Must warn: "Binaural beats require headphones" |

Monitor `routeChangeNotification` for mid-session unplugging.

---

## Spatial Audio & AirPods (Critical Issue)

**The problem:** Apple Spatial Audio on AirPods Pro/Max spatializes stereo audio and applies head tracking. Both are **destructive to binaural beats** — they alter the L/R frequency split and rotate the stereo field as the user turns their head.

**No public API to disable Spatial Audio programmatically.** It's user-controlled.

**Mitigation:**
1. Detect AirPods by checking route output port name
2. Show warning: "Spatial Audio may interfere with binaural beats. We recommend disabling it."
3. Provide step-by-step: "Open Control Center → long-press volume → tap Spatialize Stereo to turn off"
4. Consider a "test tone" feature — play a known binaural beat and ask "Do you hear a pulsing/wobbling?" to verify correct setup

**AirPods features that may interfere:**
- **Conversation Awareness** — ducks audio when user speaks
- **Adaptive Transparency** — shouldn't affect the audio signal
- **ANC** — does not affect the digital audio signal, only external noise

---

## Focus Mode / Do Not Disturb

**Cannot trigger Focus mode programmatically.** Privacy boundary.

**What IS available:**
1. **AppIntents** — expose "Start BioNaural Session" as a Shortcut intent. User creates automation: "When BioNaural session starts → Turn on DND."
2. **SetFocusFilterIntent** — BioNaural appears in Focus settings. When user activates their "Deep Work" Focus → BioNaural can auto-start a session.
3. **Onboarding guidance** — "Create a Shortcut automation that turns on Do Not Disturb when you start a session."

This is the App-Store-safe approach. No private URL schemes.
