# Tech-WatchCompanion.md — Definitive Build Specification

> The Watch app is a **standalone biometric audio instrument** — not a remote control.
> It runs full sessions independently, learns the user's patterns, and becomes
> the most personal surface BioNaural touches.

---

## Table of Contents

1. [Vision & Design Philosophy](#1-vision--design-philosophy)
2. [Two Operating Modes](#2-two-operating-modes)
3. [Screen Specifications](#3-screen-specifications)
4. [Audio Engine (watchOS)](#4-audio-engine-watchos)
5. [Biometric Pipeline (Standalone)](#5-biometric-pipeline-standalone)
6. [WatchConnectivity (Companion Mode)](#6-watchconnectivity-companion-mode)
7. [Smart Suggestions & Learning](#7-smart-suggestions--learning)
8. [Complications](#8-complications)
9. [Platform Integration](#9-platform-integration)
10. [Build Phases](#10-build-phases)
11. [Testing Strategy](#11-testing-strategy)
12. [Constraints & Limitations](#12-constraints--limitations)
13. [File Structure](#13-file-structure)

---

## 1. Vision & Design Philosophy

### The Watch Is the Product's Soul

The iPhone app is where the full audio experience lives. The Watch app is where the
**relationship** lives. It's the surface that knows your heart rate at 2pm on a Tuesday,
that noticed your HRV dropped after poor sleep, that learned your best Focus sessions
happen in the morning. The Watch app should feel like a quiet, observant companion —
never pushy, always ready, increasingly accurate.

### Design Principles

1. **Wavelength over Orb.** The Orb needs space to breathe — at 40mm it would feel
   cramped. The Wavelength reads beautifully on the wrist: a single glowing line
   carrying biometric meaning across the full watch face width.

2. **Music player, not dashboard.** Session controls follow watchOS Now Playing
   conventions: pause/play, stop, timer. Users have muscle memory for this. Digital
   Crown controls entrainment volume.

3. **Tap to reveal.** HR and biometric state are earned information. During a session,
   the screen shows only the Wavelength, mode label, and transport controls. Tap the
   Wavelength to briefly reveal HR + state ("64 bpm · Calm"), auto-hide after 3 seconds.
   This respects the focus state.

4. **The app gets smarter.** The idle screen evolves from generic ("Try a Focus session")
   to personal ("Focus. You're ready. Mornings like this are your best sessions.").
   A visible learning indicator (dots → ring) communicates this progression.

5. **Dark-first, mode-colored.** Canvas is `#080C15`. The only color comes from the
   active mode. Sleep mode dims the entire UI. Energize mode pulses with amber energy.

6. **Standalone first, companion second.** The Watch app must function completely
   without an iPhone in range. Audio plays to AirPods/Bluetooth. Adaptation runs
   on-Watch. Data syncs later.

### Visual Language Consistency

The Watch shares the iPhone's design tokens exactly. Never create Watch-specific
color values or animation curves — use the same Theme tokens, scaled for the wrist.

| Token | iPhone | Watch | Rule |
|-------|--------|-------|------|
| Canvas | `#080C15` | `#080C15` | Identical |
| Mode colors | Focus `#5B6ABF`, Relax `#4EA8A6`, Sleep `#9080C4`, Energize `#F5A623` | Identical | Identical |
| Signal colors | Calm `#4EA8A6`, Focused `#6E7CF7`, Elevated `#D4954A`, Peak `#D46A5A` | Identical | Identical |
| Text primary | `#E2E6F0` | `#E2E6F0` | Identical |
| Text secondary | 55% opacity | 55% opacity | Identical |
| Text tertiary | 30% opacity | 30% opacity | Identical |
| Spacing grid | 8pt base | 8pt base | Same grid, smaller values used |
| Glass fill | 12% opacity | 12% opacity | Identical |
| Glass stroke | 20% opacity | 20% opacity | Identical |

---

## 2. Two Operating Modes

### Standalone Mode (Watch-Only)

User starts session from Watch. iPhone may be in another room or off.

```
Watch HR Sensor → HKWorkoutSession (1 Hz)
       ↓
BiometricProcessor (on-Watch) → AdaptationEngine
       ↓
AudioParameters (atomics, lock-free)
       ↓
WatchAudioEngine (AVAudioEngine on watchOS)
       ↓
AirPods / Bluetooth headphones
```

- Full adaptive algorithm runs on-Watch (dual-EMA, state classification, sigmoid mapping)
- Audio synthesis via `AVAudioSourceNode` (watchOS 10+)
- Bundled subset of ambient/melodic audio (see §4)
- Session data saved locally, synced to iPhone via `transferUserInfo` on reconnection
- Breathing haptics active for Relaxation/Sleep modes

### Companion Mode (iPhone-Driven)

User starts session from iPhone. Watch streams biometrics.

```
Watch HR Sensor → HKWorkoutSession (1 Hz)
       ↓
WCSession.sendMessage → iPhone
       ↓
iPhone BiometricProcessor → iPhone AudioEngine
       ↓
iPhone speaker/headphones (full audio experience)
```

Watch displays:
- Live session state (mode, timer, wavelength visualization)
- Current HR (tap to reveal)
- Pause/stop controls (mirrored to iPhone)

### Mode Detection

```swift
var isStandaloneMode: Bool {
    !WCSession.default.isReachable || !isIPhoneSessionActive
}
```

Standalone activates when:
- iPhone not reachable (Bluetooth out of range)
- iPhone app not running a session
- User explicitly starts from Watch

Companion activates when:
- iPhone starts a session and sends `.start(mode)` command via WCSession
- Watch receives command and enters companion display mode

**Mid-session transition:** If iPhone becomes unreachable during a companion session,
Watch seamlessly transitions to standalone — starts local audio engine and adaptive
algorithm from last known HR state. No audio gap (< 2 second transition). The inverse
(standalone → companion) does NOT happen mid-session to avoid disruption.

---

## 3. Screen Specifications

### 3A. Idle Screen — First Use (Sessions 0–2)

```
┌──────────────────────────┐
│                          │
│  ● ○ ○ ○ ○              │  ← learning dots (1/5 filled)
│  LEARNING YOUR RHYTHM    │  ← 9pt, accent, 60% opacity
│                          │
│  Try a Focus session     │  ← 13pt, Satoshi Medium, primary
│  Your first session      │
│  helps me learn how      │  ← 9.5pt, tertiary
│  your body responds.     │
│                          │
│  ┌──────────────────┐    │
│  │   ▶ Start Focus  │    │  ← mode-colored button
│  └──────────────────┘    │
│                          │
│  🧠  🍃  🌙  ⚡        │  ← quick-start row
│                          │
└──────────────────────────┘
```

**Learning dots:** 5 dots, each representing ~10 sessions of data. Fill incrementally:
- 0–2 sessions: 1 dot
- 3–9 sessions: 2 dots
- 10–19 sessions: 3 dots
- 20–34 sessions: 4 dots
- 35+ sessions: 5 dots → transitions to "Tuned to you" ring

**Suggestion logic (cold start):** Default to Focus (most common first use). If
time-of-day is 9pm+, suggest Sleep. If user just finished a workout (HealthKit
activity detected), suggest Relaxation.

**Quick-start row:** Four mode icons (SF Symbols in mode-colored rounded squares).
Tap any to start immediately with default duration. Long-press for duration picker.

| Mode | Icon | Background |
|------|------|-----------|
| Focus | `brain.head.profile` | Focus color at 15% |
| Relaxation | `leaf.fill` | Relaxation color at 15% |
| Sleep | `moon.fill` | Sleep color at 15% |
| Energize | `bolt.fill` | Energize color at 15% |

Icon size: 13pt. Square size: 28×28pt, corner radius 8pt.

### 3B. Idle Screen — Learning (Sessions 3–19)

```
┌──────────────────────────┐
│                          │
│  ● ● ● ○ ○              │  ← 3/5 dots filled
│  5 SESSIONS IN           │
│                          │
│  Relaxation looks right  │  ← 13pt, primary
│  HR 78 · Slightly        │
│  elevated for 2pm.       │  ← 9.5pt, tertiary (HR value in elevated color)
│  A short reset could     │
│  help.                   │
│                          │
│  ┌──────────────────┐    │
│  │ ▶ Start Relaxation│   │
│  └──────────────────┘    │
│                          │
│  🧠  🍃  🌙  ⚡        │
│                          │
│  1 session · 22 min      │  ← today summary, 9pt, tertiary
└──────────────────────────┘
```

**Suggestion logic (learning):** Uses available data:
- Current HR (from background HealthKit or recent workout session)
- Time of day
- Day of week patterns (if enough data)
- Last session mode and time
- Recent sleep quality (HealthKit)

**Context line:** Brief, data-grounded reason. Always references something measurable:
- "HR 78 · Slightly elevated for 2pm"
- "HRV trending up · Good recovery window"
- "3 hours since your last session"
- "Slept 5.8h last night"

The HR/HRV value in the context line uses the biometric signal color (calm=teal,
elevated=amber).

**Today summary:** Shows at bottom when user has had at least 1 session today.
Format: `{count} session(s) · {total_minutes} min today`

### 3C. Idle Screen — Confident (Sessions 20+)

```
┌──────────────────────────┐
│                          │
│  ◉ TUNED TO YOU          │  ← filled ring icon + label, accent, 80%
│                          │
│  Focus. You're ready.    │  ← 15pt, Satoshi Medium, primary
│  HRV is high · resting   │
│  HR is 4 below your      │  ← 9.5pt, tertiary
│  average. Mornings like  │
│  this are your best      │
│  sessions.               │
│                          │
│  ┌─ ♡ 58 · Calm ────┐   │  ← biometric pill (calm color bg at 12%)
│  └───────────────────┘   │
│                          │
│  ┌──────────────────┐    │
│  │▶ Start Focus·25m │    │  ← includes suggested duration
│  └──────────────────┘    │
│                          │
│  🧠  🍃  🌙  ⚡        │
│                          │
│  3-day streak · 1h 12m   │  ← streak + weekly total
└──────────────────────────┘
```

**"Tuned to you" indicator:** Replaces learning dots. Small filled circle (accent
color) with ring. Communicates: "I know you now."

**Suggestion logic (confident):** Full personalization:
- Cross-references time of day + day of week + current biometrics + sleep + activity
- References **personal patterns**: "Mornings like this are your best sessions"
- Suggests specific duration based on user's typical session length for this mode
- Can suggest non-obvious modes: "Your HRV says rest, even though you feel fine"

**Biometric pill:** Inline badge showing current HR + state. Background color at 12%
opacity of the state color. Text in state color. Heart icon (♡) before HR value.

**Suggested duration:** Derived from median of user's last 10 sessions in this mode,
rounded to nearest 5 minutes.

**Streak + weekly total:** Replaces "today summary" once user has multi-day history.
Format: `{streak}-day streak · {weekly_total}` or `{count} sessions · {total} this week`

### 3D. Session Screen — Active (All Modes)

```
┌──────────────────────────┐
│                          │
│         FOCUS            │  ← 11pt, mode color, uppercase, 50% opacity
│                          │
│                          │
│                          │
│∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿│  ← Wavelength, full width
│                          │
│                          │
│                          │
│                          │
│                          │
│     ┌──────────────┐     │
│     │ ❚❚  12:34  ■ │     │  ← glass pill: pause + timer + stop
│     └──────────────┘     │
│                          │
└──────────────────────────┘
```

**Mode label:** Centered, uppercase, mode color at 50% opacity. 11pt Satoshi Medium,
letter-spacing 1.5pt.

**Wavelength:** Single wave spanning full watch width. Edge-to-edge with opacity
fade at left/right edges (transparent → visible over 15% of width on each side).

Wave parameters derive from biometric state:

| State | Cycles | Amplitude | Stroke | Color | Opacity |
|-------|--------|-----------|--------|-------|---------|
| Calm | ~1.5 | ±8pt | 1.2pt | Mode color | 25% → 35% gradient |
| Focused | ~2.5 | ±14pt | 1.5pt | Mode color | 30% → 40% gradient |
| Elevated | ~3.5 | ±20pt | 1.8pt | Shifts warm (blend toward elevated signal color) | 35% → 45% gradient |
| Peak | ~5 | ±28pt | 2.0pt | Warm (peak signal color) | 40% → 50% gradient |

Wave rendering:
- Single `Canvas` view with Catmull-Rom interpolation (alpha 0.5)
- Continuous horizontal scroll at 15 pts/sec (slower than iPhone's 20 — battery)
- Gaussian blur radius: 4pt (lighter than iPhone's 8pt — performance)
- Secondary ghost wave at 40% scale, 10% opacity, offset 2pt vertically (depth)
- Vertical position: centered in screen (50% from top)

**Energize-specific wave:** Tighter cycles (~5+), higher amplitude (±30pt), 2.0pt
stroke, secondary harmonic wave at 50% opacity. Amber color with warm glow.

**Sleep-specific wave:** Very gentle (~0.8 cycles), low amplitude (±6pt), 1.0pt
stroke. Violet color. The wave should feel like barely perceptible breathing.

**Background:** Radial gradient from mode color at 8% opacity (center) to canvas
(edges). Gradient center at 45% from top (slightly above center, where wave sits).

**Glass pill controls:**

```
┌─────────────────────────┐
│  ❚❚    12:34    ■       │
│  ↑       ↑       ↑      │
│  Pause   Timer   Stop   │
└─────────────────────────┘
```

- Capsule shape, `background: rgba(226,230,240,0.08)`, `border: rgba(226,230,240,0.12)` 1pt
- Pause/play button: 30×30pt circle, clear background, `❚❚` or `▶` in text-secondary
- Timer: SF Mono 13pt, text-secondary, monospacedDigit, `contentTransition(.numericText())`
- Stop button: 30×30pt circle, red at 20% opacity background, `■` in red
- Spacing between elements: 12pt
- Pill padding: 7pt vertical, 14pt horizontal
- Pill corner radius: 20pt (Capsule)
- Position: 18pt from bottom of screen

**Digital Crown:** Controls entrainment (binaural/isochronic) layer volume.
Maps 0–100% range. Haptic detent every 10%. Show brief volume indicator (thin
horizontal bar above the pill) that fades after 1.5 seconds.

### 3E. Session Screen — Tap to Reveal

When user taps the Wavelength area during an active session:

```
┌──────────────────────────┐
│                          │
│         FOCUS            │
│                          │
│                          │
│          64              │  ← 36pt, SF Mono Light, mode color
│          bpm             │  ← 11pt, mode color, 50% opacity
│          ● Calm          │  ← 10pt, state color, filled circle + label
│                          │
│∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿∿│  ← wave dims to 30% opacity
│                          │
│     ┌──────────────┐     │
│     │ ❚❚  18:42  ■ │     │
│     └──────────────┘     │
│                          │
└──────────────────────────┘
```

**Behavior:**
1. Tap anywhere in the Wavelength zone (middle 60% of screen)
2. Wave dims to 30% opacity
3. HR value fades in at center: 36pt SF Mono Light, mode color
4. "bpm" label below: 11pt, mode color at 50%
5. Biometric state below that: filled circle (●) in state color + state name
6. Auto-hides after 3 seconds with 0.5s fade out
7. Wave returns to full opacity

**Animation:** Fade in 0.3s (spring, bounce 0.2), hold 3s, fade out 0.5s.

**If no HR data available:** Show "–– bpm" with tertiary color. State shows "Connecting..."

### 3F. Session Screen — Mode Variations

**Relaxation — Breathing Indicator:**
Below the Wavelength, show a subtle breathing cue when `WatchBreathingHaptics`
is active:

```
         ○ Breathe          ← 8pt, relaxation color, 40% opacity
```

Small open circle (14×14pt SVG, fill at 30% opacity) + "Breathe" label. Pulses
gently in sync with haptic inhale/exhale cycle. Positioned 8pt below Wavelength
vertical center.

**Sleep — Progressive Dimming:**
- Mode label opacity starts at 50%, decreases to 25% over session
- Wave opacity decreases to 15% as delta deepens
- Controls opacity decreases to 40%
- Background gradient opacity decreases to 4%
- At 15+ minutes into session, entire screen is near-black with barely visible wave
- If sleep onset detected (sustained calm + low HR + low motion), fade controls to 20%

**Energize — Intensity:**
- Wave uses double harmonics (primary + secondary wave at offset phase)
- Background gradient stronger: mode color at 14% → canvas
- Controls stop button uses energize color instead of red (amber at 20% bg)
- Wave amplitude at peak state reaches ±30pt (most dramatic visual)

### 3G. Always-On Display (AOD)

When `isLuminanceReduced == true`:

```
┌──────────────────────────┐
│                          │
│         FOCUS            │  ← mode label, 35% opacity
│                          │
│                          │
│─────────────────────────│  ← static horizontal line, mode color, 15% opacity
│                          │
│         12:34            │  ← timer, SF Mono, 40% opacity
│                          │
│                          │
│                          │
└──────────────────────────┘
```

**Rules:**
- No animations (watchOS requirement for AOD battery)
- Wavelength replaced with static horizontal line at 15% opacity
- No controls visible (user must raise wrist to interact)
- Timer visible at 40% opacity (still useful at a glance)
- Mode label at 35% opacity
- Pure black background (OLED power saving)
- Update timer via `TimelineView(.periodic(every: 1))` (system-managed)

### 3H. Post-Session Summary

Shown immediately after session ends:

```
┌──────────────────────────┐
│                          │
│  SESSION COMPLETE        │  ← 9pt, tertiary, uppercase
│  25:00                   │  ← 28pt, SF Mono Light, primary
│  FOCUS                   │  ← 10pt, mode color, uppercase
│                          │
│  ┌─────────┬─────────┐  │
│  │ AVG HR  │ HR Δ    │  │
│  │ 62      │ -6      │  │  ← metrics grid
│  ├─────────┼─────────┤  │
│  │ ADAPTED │ DEEP    │  │
│  │ 4×      │ 18m     │  │
│  └─────────┴─────────┘  │
│                          │
│       👎      👍         │  ← feedback buttons
│                          │
└──────────────────────────┘
```

**Metrics grid:** 2×2, each cell:
- Label: 7.5pt, uppercase, letter-spacing 0.6pt, tertiary
- Value: 14pt, SF Mono Medium, mode color
- Cell padding: 8pt
- Cell background: surface color
- Cell border: 1pt, primary at 6% opacity
- Cell corner radius: 10pt (continuous)
- Grid gap: 6pt

**Metric definitions per mode:**

| Mode | Cell 1 | Cell 2 | Cell 3 | Cell 4 |
|------|--------|--------|--------|--------|
| Focus | Avg HR | HR Delta | Adaptations | Deep Focus time |
| Relaxation | Avg HR | HR Delta | Time to Calm | HRV Delta |
| Sleep | Avg HR | HR Delta | Time to Sleep | Deep Sleep est. |
| Energize | Avg HR | HR Delta | Adaptations | Peak time |

**Feedback buttons:** Two circles (36×36pt), centered horizontally with 16pt gap.
- Default: surface background, 1pt border at 8% opacity
- Selected: mode color at 15% bg, mode color border at 30%
- Thumbs icons: system emoji (👎 👍), 16pt

**After feedback:** Brief "Thanks" label fades in (accent color, 10pt), then
auto-dismiss to idle screen after 2 seconds.

**Data persistence:** `SessionOutcome` saved to local storage immediately.
Synced to iPhone via `transferUserInfo` when WCSession available.

### 3I. Duration Picker (Long-Press on Quick Mode)

Presented as a `.sheet` when user long-presses any mode in the quick-start row
or the main start button:

```
┌──────────────────────────┐
│                          │
│  FOCUS DURATION          │  ← 10pt, mode color, uppercase
│                          │
│  ┌──────────────────┐    │
│  │    ◄  15 min  ►  │    │  ← Digital Crown picker
│  └──────────────────┘    │
│                          │
│  ┌──────────────────┐    │
│  │     Start         │   │  ← mode-colored button
│  └──────────────────┘    │
│                          │
└──────────────────────────┘
```

**Picker:** Native `Picker` with `.wheel` style. Range: 5–60 minutes in 5-minute steps.
Default: user's median duration for this mode (or 15 min if no history).

### 3J. Paused State

When user taps pause:

```
┌──────────────────────────┐
│                          │
│         FOCUS            │  ← unchanged
│                          │
│                          │
│                          │
│─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─│  ← dashed line replaces wave (mode color, 20%)
│                          │
│        PAUSED            │  ← 11pt, text-secondary, uppercase, letter-spacing 2pt
│                          │
│                          │
│     ┌──────────────┐     │
│     │ ▶  12:34  ■  │     │  ← play replaces pause
│     └──────────────┘     │
│                          │
└──────────────────────────┘
```

- Wavelength animation stops, replaced with dashed horizontal line
- "PAUSED" label appears below the line
- Audio engine pauses (amplitude ramp to 0 over 500ms, then engine pause)
- HealthKit workout session continues (HR still sampled)
- Timer freezes
- Resume: tap play, audio fades back in over 500ms, wave animation restarts

---

## 4. Audio Engine (watchOS)

### Strategy: Hybrid Synthesis + Bundled Assets

watchOS 10+ supports `AVAudioEngine` with `AVAudioSourceNode`. The binaural/isochronic
entrainment layer is pure real-time synthesis (trivial CPU cost — two sine oscillators).
Ambient and melodic layers use bundled audio files.

### Audio Graph (watchOS)

```
AVAudioSourceNode (entrainment: binaural or isochronic)
       ↓
AVAudioMixerNode
       ↑
AVAudioPlayerNode (ambient bed — single player, looping)
       ↑
AVAudioPlayerNode (melodic layer — single player, looping)
       ↓
AVAudioOutputNode → AirPods / Bluetooth
```

Simpler than iPhone graph (no reverb unit, no stem layer, no A/B crossfading).

### What Ports Directly from iPhone

| Component | Portable? | Notes |
|-----------|-----------|-------|
| `BinauralBeatNode` | **YES — zero changes** | Phase accumulators, atomics, no platform deps |
| `AudioParameters` | **YES — zero changes** | Pure atomic storage, no SwiftUI |
| `BiometricProcessor` | **YES — zero changes** | Swift actor, pure logic |
| `HeartRateAnalyzer` | **YES — zero changes** | Pure signal processing |
| `AdaptationEngine` | **YES — zero changes** | Deterministic mappings |
| `FrequencyMath` | **YES — already in BioNauralShared** | Pure functions |
| `BiometricState` | **YES — already in BioNauralShared** | Enum |
| `FocusMode` | **YES — already in BioNauralShared** | Enum + frequency configs |

### What Needs a watchOS Variant

| Component | Why | Watch Variant |
|-----------|-----|---------------|
| `AudioEngine` | Different session management, simpler graph | `WatchAudioEngine` |
| `AmbienceLayer` | No A/B crossfading needed (simplify) | Inline in `WatchAudioEngine` |
| `MelodicLayer` | Reduced asset library, simpler playback | Inline in `WatchAudioEngine` |
| `HealthKitService` | Different authorization flow on watchOS | `WatchHealthKitService` (exists) |

### WatchAudioEngine Implementation

```swift
@Observable
final class WatchAudioEngine {

    // MARK: - Audio Graph
    private let engine = AVAudioEngine()
    private var entrainmentNode: AVAudioSourceNode?
    private var ambientPlayer: AVAudioPlayerNode?
    private var melodicPlayer: AVAudioPlayerNode?

    // MARK: - Parameters (lock-free bridge to render thread)
    let parameters = AudioParameters()

    // MARK: - State
    private(set) var isPlaying = false
    private var currentMode: FocusMode?

    // MARK: - Lifecycle

    func start(mode: FocusMode) {
        currentMode = mode
        configureSession()
        buildGraph(mode: mode)
        engine.prepare()
        try engine.start()
        isPlaying = true
    }

    func pause() {
        // Ramp amplitude to 0 over 500ms, then pause
        parameters.setAmplitude(0)
        Task {
            try await Task.sleep(for: .milliseconds(500))
            engine.pause()
            isPlaying = false
        }
    }

    func resume() {
        engine.prepare()
        try engine.start()
        // Ramp amplitude back up
        parameters.setAmplitude(previousAmplitude)
        isPlaying = true
    }

    func stop() {
        // Ramp amplitude to 0, wait, then stop
        parameters.setAmplitude(0)
        Task {
            try await Task.sleep(for: .milliseconds(500))
            engine.stop()
            entrainmentNode = nil
            ambientPlayer = nil
            melodicPlayer = nil
            isPlaying = false
        }
    }

    // MARK: - Session Configuration

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback)
        try session.setActive(true)
    }
}
```

### AVAudioSession on watchOS

- **Category:** `.playback` (same as iPhone)
- **Background audio:** Supported when `HKWorkoutSession` is active (the workout
  session keeps the app alive in background)
- **Route:** AirPods (A2DP), other Bluetooth headphones, or Watch speaker (warn if speaker)
- **Spatial Audio:** Set `outputNode.spatializationEnabled = false` on watchOS if available

### Bundled Audio Assets

The Watch app cannot access the iPhone's full sound library. Bundle a curated subset:

| Layer | Count | Format | Total Size |
|-------|-------|--------|------------|
| Ambient beds | 4 (1 per mode) | AAC 128kbps, 60s loops | ~4 MB |
| Melodic loops | 8 (2 per mode) | AAC 128kbps, 30-60s | ~6 MB |
| **Total** | 12 files | | **~10 MB** |

**Asset selection per mode:**

| Mode | Ambient | Melodic Options |
|------|---------|-----------------|
| Focus | Pink noise + light rain | Minimal pad, lo-fi texture |
| Relaxation | Ocean waves | Warm pad, acoustic guitar |
| Sleep | Brown noise + distant rain | Deep drone, minimal piano |
| Energize | White noise + wind | Rhythmic pad, upbeat texture |

Files live in the Watch app bundle, NOT shared via WatchConnectivity (too slow).
Encode at 128kbps AAC — balance quality vs. size for Watch storage.

### Audio Buffer & Performance

- **Buffer size:** 512 frames (11.6ms latency at 44.1kHz) — same as iPhone
- **CPU budget:** Binaural synthesis + 2 file players = < 5% CPU on Apple Watch S9
- **Memory:** ~15 MB peak (audio buffers + decoded assets)
- **Battery:** Audio playback ~8-12% per hour (acceptable with workout session)

---

## 5. Biometric Pipeline (Standalone)

### Heart Rate Acquisition

Identical to current `WatchHealthKitService` implementation:

1. Start `HKWorkoutSession` with `.mindAndBody` activity type
2. Start `HKLiveWorkoutBuilder`
3. Create `HKAnchoredObjectQuery` for `HKQuantityType(.heartRate)`
4. Update handler fires at ~1 Hz with `HKQuantitySample`
5. Extract BPM: `sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))`
6. Extract motion context: `sample.metadata?[HKMetadataKeyHeartRateMotionContext]`
7. Create `BiometricSample(bpm:, timestamp:, confidence:)` from motion context

### On-Watch Adaptive Processing

Port `BiometricProcessor` and `AdaptationEngine` to run on-Watch. Since both are
pure Swift (actor + structs), they compile for watchOS without changes.

**Control loop (10 Hz on Watch):**

```
Every 100ms:
1. Read latest HR sample from WatchHealthKitService callback
2. Artifact rejection (|HR_raw - HR_smooth| > 30 → reject)
3. Dual-EMA smoothing (fast α=0.4, slow α=0.1)
4. Trend detection (HR_fast - HR_slow, ±2 BPM deadband)
5. HR reserve normalization (Karvonen method)
6. State classification (hysteresis h=0.03, dwell 5s)
7. Mode-dependent sigmoid mapping → target audio parameters
8. Slew rate limiting (0.3 Hz/sec max beat frequency change)
9. Write targets to AudioParameters (atomics)
```

**Gains:** Kp = 0.1, Kff = 0.5 (same as iPhone)

**First session (no history):** HR_rest = 72, HR_max = 208 - 0.7 × age (or 185),
wider hysteresis (h=0.05), slower slew (0.15 Hz/sec).

### HRV on Watch

Apple Watch doesn't expose raw RR intervals during live `HKWorkoutSession`.

**Approximation strategy (same as iPhone):**
```swift
let rrInterval = 60000.0 / bpm  // Estimated RR from 1 Hz BPM
```

Compute RMSSD over 30-second sliding window. Lossy but directionally correct for
trends. Use for session-level modifier only — HR is the primary adaptive signal.

### Signal Quality Scoring

The ~50KB logistic regression Core ML model runs on-Watch (Core ML supported on
watchOS 10+). Scores each sample 0.0–1.0 confidence. When quality < 0.5, hold
current parameters rather than adapting to noise.

### Data Dropout (Watch Sensor Issues)

If no HR sample received for >10 seconds:
1. Hold current audio parameters (no change)
2. After 30 seconds: begin interpolating toward neutral (10 Hz, mode default carrier, 0.5 amplitude)
3. After 60 seconds: hold neutral parameters
4. Show subtle connection indicator on session screen (small dot, amber, top-right)
5. If HR resumes: restore from last HR_slow value, resume adaptive control

Never stop audio. Never make jarring changes. Protect the session.

---

## 6. WatchConnectivity (Companion Mode)

### Watch → iPhone (Biometric Streaming)

When iPhone is running a session and Watch is in companion mode:

```swift
// Watch sends HR to iPhone
let sample = BiometricSample(bpm: hr, timestamp: Date().timeIntervalSince1970, confidence: motionContext)
let message = WatchMessage.heartRate(sample)
if let dict = message.toDictionary() {
    WCSession.default.sendMessage(dict, replyHandler: nil)
}
```

- Rate: Every sample (~1 Hz) via `sendMessage` (50-200ms latency)
- Fallback: Buffer up to 500 samples when `isReachable == false`
- On reconnection: Flush buffer via `transferUserInfo` (guaranteed delivery)
- Heartbeat ping: Every 5 seconds to detect disconnection (3 consecutive failures = lost)

### iPhone → Watch (Session Commands)

```swift
// iPhone sends session command to Watch
let command = WatchMessage.sessionCommand(.start(.focus))
WCSession.default.sendMessage(command.toDictionary()!)
```

Commands:
- `.start(FocusMode)` — Watch enters companion display mode
- `.stop` — Watch returns to idle
- `.pause` — Watch shows paused state
- `.resume` — Watch shows active state

### iPhone → Watch (State Sync)

```swift
// iPhone periodically syncs state
let state = SessionStateUpdate(isActive: true, isPaused: false, mode: .focus, elapsed: 1234)
let message = WatchMessage.sessionState(state)
WCSession.default.updateApplicationContext(message.toDictionary()!)
```

State sync via `updateApplicationContext` (latest-only, no queue) at 1 Hz.
Watch displays the received state (mode, timer, playing/paused).

### Watch → iPhone (Session Data Sync)

After a standalone Watch session completes:

```swift
let outcome: SessionOutcome = /* built from session data */
let data = try JSONEncoder().encode(outcome)
WCSession.default.transferUserInfo(["sessionOutcome": data])
```

`transferUserInfo` guarantees delivery even if iPhone app isn't running.
iPhone receives in `session(_:didReceiveUserInfo:)` and persists to SwiftData.

---

## 7. Smart Suggestions & Learning

### The Learning Arc

The Watch app progresses through three stages of intelligence:

| Stage | Sessions | Indicator | Suggestion Quality |
|-------|----------|-----------|-------------------|
| **Cold Start** | 0–2 | 1/5 dots, "Learning your rhythm" | Time-of-day default + current activity |
| **Learning** | 3–19 | 2-4/5 dots, "{N} sessions in" | HR-aware + time + recent sleep |
| **Confident** | 20+ | Filled ring, "Tuned to you" | Full personalization + personal patterns |

### Data Sources for Suggestions

| Source | Available | Used For |
|--------|-----------|----------|
| Current HR | If recent HKWorkoutSession or background delivery | Mode suggestion + biometric pill |
| Current HRV | HealthKit background query | Recovery state assessment |
| Resting HR | HealthKit daily value | Baseline comparison ("4 below average") |
| Sleep data | HealthKit `sleepAnalysis` | "Slept 5.8h" context |
| Time of day | System clock | Circadian mode suggestion |
| Day of week | System clock | Pattern recognition |
| Session history | Local storage on Watch | "Mornings like this are your best" |
| Activity | HealthKit recent workouts, CMMotionActivity | Post-workout relaxation suggestion |

### Suggestion Algorithm

```swift
func computeSuggestion() -> WatchSuggestion {
    let hour = Calendar.current.component(.hour, from: Date())
    let currentHR = latestHeartRate
    let recentSleep = queryRecentSleep()
    let sessionHistory = loadSessionHistory()
    let restingHR = queryRestingHR()

    // 1. Time-of-day base mode
    var mode: FocusMode
    switch hour {
    case 5...9:   mode = .focus      // Morning focus window
    case 10...14: mode = .focus      // Midday productivity
    case 15...17: mode = .relaxation // Afternoon reset
    case 18...20: mode = .relaxation // Evening wind-down
    case 21...23: mode = .sleep      // Bedtime
    default:      mode = .sleep      // Late night
    }

    // 2. Override with biometric data (if available)
    if let hr = currentHR {
        let hrReserve = FrequencyMath.heartRateReserveNormalized(
            current: hr, resting: restingHR ?? 72, max: estimatedMaxHR
        )
        if hrReserve > 0.5 && hour < 20 {
            mode = .relaxation  // Elevated HR → cool down
        }
        if hrReserve < 0.15 && (6...10).contains(hour) {
            mode = .energize  // Very low morning HR → wake up
        }
    }

    // 3. Override with sleep data
    if let sleep = recentSleep, sleep.totalHours < 6.0 && hour < 12 {
        mode = .relaxation  // Poor sleep → recovery
    }

    // 4. Override with activity data
    if recentlyFinishedWorkout() {
        mode = .relaxation  // Post-workout cooldown
    }

    // 5. Duration suggestion (from history)
    let suggestedDuration = medianDuration(for: mode, from: sessionHistory) ?? 15

    // 6. Context text (from biometric data)
    let context = buildContextText(hr: currentHR, restingHR: restingHR,
                                    sleep: recentSleep, history: sessionHistory)

    return WatchSuggestion(mode: mode, duration: suggestedDuration,
                           context: context, confidence: sessionHistory.count)
}
```

### Context Text Generation

The context line grounds the suggestion in measurable data. It should feel
observant, not prescriptive.

**Templates by data availability:**

```
// HR available
"HR {value} · {comparison} for {time}"
→ "HR 78 · Slightly elevated for 2pm"
→ "HR 58 · Low and steady this morning"

// HRV available
"HRV is {high/low} · {implication}"
→ "HRV is high · Good recovery window"
→ "HRV trending down · Recovery session could help"

// Sleep data
"Slept {hours}h last night"
→ "Slept 5.8h · A short reset could help"

// Pattern recognition (20+ sessions)
"{Pattern observation}"
→ "Mornings like this are your best sessions"
→ "You usually do Focus around now"
→ "Your Tuesday pattern says Relaxation"

// Post-workout
"HR coming down from workout · Good time to cool down"

// No data
"Your first session helps me learn how your body responds"
```

**Rules:**
- Never use exclamation marks
- Never use "you should" — use "could" or frame as observation
- Always reference data, never feelings ("HR 78" not "you seem stressed")
- Max 2 lines on Watch screen
- HR/HRV values colored with their biometric state color

### Learning Data Persistence

On Watch, learning data stored in `UserDefaults` (lightweight, no SwiftData on Watch
for simplicity):

```swift
struct WatchLearningProfile: Codable {
    var totalSessions: Int
    var sessionsByMode: [FocusMode: Int]
    var averageDurationByMode: [FocusMode: TimeInterval]
    var sessionsByHourOfDay: [Int: Int]  // hour → count
    var sessionsByDayOfWeek: [Int: Int]  // 1-7 → count
    var restingHRHistory: [Double]       // Rolling window, last 14 values
    var lastSessionDate: Date?
    var streakDays: Int
    var weeklyMinutes: TimeInterval
}
```

Updated after every session. Synced to iPhone via `updateApplicationContext`.

---

## 8. Complications

### Complication Types

| Family | Content | Tap Action |
|--------|---------|-----------|
| **Circular** | Small pulsing dot in last-used mode color (or accent if no history). During session: filled circle in mode color. | Launch app → idle or active session |
| **Corner** (Graphic Corner) | Mode icon (SF Symbol) + mode name. During session: mode icon + timer. | Launch app |
| **Rectangular** (Graphic Rectangular) | Mini static wavelength (SVG path) + "Start Focus" or last session summary. During session: wavelength + timer + HR. | Launch app |
| **Inline** | "BioNaural · Focus" or "BioNaural · 12:34" during session | Launch app |

### Complication Data Provider

```swift
struct BioNauralComplicationProvider: TimelineProvider {

    func placeholder(in context: Context) -> BioNauralEntry {
        BioNauralEntry(date: .now, state: .idle(suggestion: .focus))
    }

    func getSnapshot(in context: Context, completion: @escaping (BioNauralEntry) -> Void) {
        let state = WatchSessionManager.shared.complicationState
        completion(BioNauralEntry(date: .now, state: state))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BioNauralEntry>) -> Void) {
        let state = WatchSessionManager.shared.complicationState
        let entry = BioNauralEntry(date: .now, state: state)
        // Refresh every 15 minutes idle, every 1 minute during session
        let refresh = state.isActive ? 60 : 900
        let timeline = Timeline(entries: [entry],
                                policy: .after(.now.addingTimeInterval(TimeInterval(refresh))))
        completion(timeline)
    }
}
```

### Complication States

```swift
enum ComplicationState {
    case idle(suggestion: FocusMode)
    case active(mode: FocusMode, elapsed: TimeInterval, heartRate: Double?)
    case postSession(mode: FocusMode, duration: TimeInterval)

    var isActive: Bool { /* ... */ }
}
```

### Rectangular Complication — Mini Wavelength

For the graphic rectangular complication, render a simplified static wavelength:

```swift
// Pre-computed SVG-style path for each state
static let calmWavePath = "M0,12 C8,10 16,8 24,9 C32,10 40,14 48,14 C56,14 64,10 72,9 C80,8 88,10 96,12"
static let activeWavePath = "M0,12 C6,6 12,4 18,8 C24,12 30,20 36,20 C42,20 48,8 54,4 C60,0 66,16 72,20 C78,24 84,8 90,4 C96,0 96,12"
```

Wave color matches suggested mode (idle) or active mode color.
Height: 24pt. Width: fills available space.

---

## 9. Platform Integration

### Haptics

| Event | Haptic | When |
|-------|--------|------|
| Session start | `.start` | Audio begins |
| Session end | `.stop` | Audio stops |
| Biometric state change | `.click` | State transitions (max 1 per 10s) |
| Mode card tap (idle) | Light impact | Pre-session interaction |
| Breathing cue (inhale) | `.click` × 4 taps per inhale | Relaxation/Sleep only |
| Digital Crown volume | `.click` | Each 10% detent |
| Sustained calm (60s) | `.success` | Breathing cues auto-stop |

Haptics work during background execution when `HKWorkoutSession` is active.

### Accessibility

| Feature | Implementation |
|---------|---------------|
| **VoiceOver** | Every interactive element has `accessibilityLabel`. Wavelength: "Session wavelength, tap to reveal heart rate." Controls: "Pause session", "Stop session, {elapsed} elapsed". |
| **Dynamic Type** | All text uses semantic styles (`.caption`, `.body`). Watch has limited Dynamic Type but must scale proportionally. |
| **Reduce Motion** | Wavelength replaced with static horizontal line. No scroll animation. Breathing indicator static. AOD line static (already is). |
| **Bold Text** | Responds to `legibilityWeight` environment value. |
| **VoiceOver rotor** | Mode selection navigable via rotor. Session controls grouped. |

### Battery Warning

Before starting a session, check Watch battery:

```swift
WKInterfaceDevice.current().batteryLevel  // 0.0 – 1.0
```

| Battery | Duration | Action |
|---------|----------|--------|
| > 30% | Any | Start normally |
| 20–30% | > 30 min | Warning: "Battery at {X}%. Estimated drain: ~{Y}%. Consider a shorter session." |
| < 20% | Any | Warning: "Low battery. Session may end unexpectedly." |
| < 10% | Any | Block: "Battery too low for a session. Charge your Watch first." |

Warning is non-blocking (except < 10%). User can dismiss and continue.

### CarPlay Detection

Not applicable on Watch, but if Watch receives a companion command while iPhone
is connected to CarPlay, Watch should ignore it (CarPlay sessions are explicitly
blocked in CLAUDE.md).

---

## 10. Build Phases

### Phase Order

These phases integrate into the existing build plan. They replace the current
Phase 36/36B/36C and expand into a complete Watch engineering sequence.

```
Phase W1: WatchAudioEngine — Core audio graph on watchOS
Phase W2: Standalone session lifecycle — Start/pause/resume/stop with audio
Phase W3: Wavelength view — Single-layer wave with biometric state response
Phase W4: Session screen — Full layout (mode label, wave, controls, AOD)
Phase W5: Tap-to-reveal — HR + state overlay with auto-hide
Phase W6: Idle screen — Three-stage suggestion UI (cold/learning/confident)
Phase W7: Smart suggestion engine — Algorithm + data sources
Phase W8: Post-session screen — Metrics grid + feedback
Phase W9: Companion mode — iPhone-driven session display
Phase W10: Complications — All four families
Phase W11: Breathing haptics integration — Wire existing service to session
Phase W12: Battery warning + pre-session checks
Phase W13: Accessibility pass — VoiceOver, Reduce Motion, Dynamic Type
Phase W14: Audio asset bundling — Curate and encode Watch sound library
Phase W15: Integration testing — Standalone + companion + transition scenarios
```

### Phase Details

#### Phase W1: WatchAudioEngine (2-3 days)

**Goal:** Audio plays on Watch through AirPods/Bluetooth.

**Tasks:**
1. Create `WatchAudioEngine.swift` in `BioNauralWatch/Audio/`
2. Port `BinauralBeatNode` render callback (copy from iPhone — zero changes needed)
3. Wire `AudioParameters` (copy from iPhone — zero changes needed)
4. Add `AVAudioPlayerNode` for ambient bed (single player, looping)
5. Add `AVAudioPlayerNode` for melodic layer (single player, looping)
6. Configure `AVAudioSession` (`.playback` category)
7. Test: start engine → hear binaural beat through AirPods

**Dependencies:**
- `BinauralBeatNode.swift` and `AudioParameters.swift` should be moved to
  `BioNauralShared` or duplicated in Watch target
- swift-atomics already in Watch target dependencies

**Acceptance:** Play a 10 Hz binaural beat at 200 Hz carrier through AirPods from
Apple Watch for 5 minutes without glitches.

#### Phase W2: Standalone Session Lifecycle (2 days)

**Goal:** Complete session flow — start, adapt, pause, resume, stop.

**Tasks:**
1. Port `BiometricProcessor` actor to Watch target (move to Shared or duplicate)
2. Port `AdaptationEngine` (move to Shared or duplicate)
3. Port `HeartRateAnalyzer` (move to Shared or duplicate)
4. Wire: `WatchHealthKitService` HR callback → `BiometricProcessor.ingest()` →
   `AdaptationEngine.computeTargets()` → `AudioParameters` atomics →
   `WatchAudioEngine` render callback
5. Implement session timer (elapsed seconds)
6. Implement pause/resume with amplitude ramp
7. Implement stop with amplitude ramp + session outcome creation

**Acceptance:** Start Focus session from Watch. HR changes → beat frequency adapts
visibly (monitor via debug overlay). Pause → silence. Resume → audio returns. Stop →
session ends cleanly.

#### Phase W3: Wavelength View (2 days)

**Goal:** Biometric-responsive wave rendering on Watch.

**Tasks:**
1. Create `WatchWavelengthView.swift` using SwiftUI `Canvas`
2. Implement Catmull-Rom spline interpolation (port from iPhone `WavelengthView`)
3. Single wave layer (not three like iPhone)
4. Parameters driven by biometric state: amplitude, cycle count, stroke width, color
5. Continuous horizontal scroll animation (15 pts/sec)
6. Edge fade (left/right opacity gradient)
7. Secondary ghost wave at 40% scale for depth
8. Gaussian blur (4pt)
9. Reduce Motion: static horizontal line

**Acceptance:** Wave renders smoothly at 60fps on Apple Watch S8+. Visibly responds
to biometric state changes (calm → elevated shows tighter, warmer wave).

#### Phase W4: Session Screen (2 days)

**Goal:** Complete active session UI.

**Tasks:**
1. Create `WatchSessionView.swift` (replace existing)
2. Layout: mode label (top), wavelength (center), glass pill controls (bottom)
3. Implement glass pill: pause/play + timer + stop
4. Background radial gradient (mode color at 8% → canvas)
5. Digital Crown volume control with visual indicator
6. Mode-specific variations:
   - Sleep: progressive dimming
   - Energize: double harmonics, stronger gradient
   - Relaxation: breathing indicator
7. AOD variant (`isLuminanceReduced`)
8. Paused state (dashed line, "PAUSED" label)

**Acceptance:** All four modes render correctly. AOD shows minimal display. Pause/resume
works. Digital Crown adjusts volume with haptic feedback.

#### Phase W5: Tap-to-Reveal (1 day)

**Goal:** HR + biometric state overlay on tap.

**Tasks:**
1. Add tap gesture to wavelength zone
2. Implement overlay: HR value (36pt SF Mono) + "bpm" label + state indicator
3. Wave dims to 30% opacity during reveal
4. Auto-hide after 3 seconds with 0.5s fade
5. Handle "no HR data" state (show "–– bpm" + "Connecting...")

**Acceptance:** Tap → HR appears → 3 seconds → fades away. Multiple taps reset timer.

#### Phase W6: Idle Screen (2-3 days)

**Goal:** Three-stage suggestion UI.

**Tasks:**
1. Create `WatchIdleView.swift` (replace existing `WatchMainView`)
2. Learning indicator component (dots → ring transition)
3. Suggestion text + context line
4. Start button (mode-colored)
5. Quick-start mode row (4 icons)
6. Duration picker sheet (long-press)
7. Today summary / streak display
8. Biometric pill component (confident stage)
9. Conditional layout based on `WatchLearningProfile.totalSessions`

**Acceptance:** Cold start shows "Learning your rhythm" with 1 dot. After 5 sessions,
shows contextual suggestion. After 20+, shows "Tuned to you" with personal insight.

#### Phase W7: Smart Suggestion Engine (2 days)

**Goal:** Contextual mode recommendation algorithm.

**Tasks:**
1. Create `WatchSuggestionEngine.swift`
2. Implement time-of-day base logic
3. Query HealthKit for current HR (if recent workout session data available)
4. Query HealthKit for recent sleep
5. Query HealthKit for resting HR baseline
6. Implement session history pattern recognition
7. Context text generation from templates
8. Duration suggestion from median history
9. Create `WatchLearningProfile` model with UserDefaults persistence
10. Update profile after each session

**Acceptance:** Suggestions change based on time of day. If HR data available,
suggestions reference it. After 20 sessions, patterns surface in context text.

#### Phase W8: Post-Session Screen (1 day)

**Goal:** Session summary with feedback.

**Tasks:**
1. Create `WatchPostSessionView.swift` (replace stubs)
2. Metrics grid (2×2) with mode-specific metrics
3. Thumbs feedback buttons
4. Auto-dismiss after feedback (2 second delay)
5. Create and persist `SessionOutcome`
6. Queue `transferUserInfo` for iPhone sync

**Acceptance:** Post-session shows correct metrics. Thumbs feedback saves to outcome.
Outcome syncs to iPhone when connected.

#### Phase W9: Companion Mode (2 days)

**Goal:** Watch displays iPhone session state.

**Tasks:**
1. Handle incoming `SessionCommand` messages in `WatchSessionManager`
2. Implement companion session view (same UI as standalone, but no local audio)
3. Forward Watch HR to iPhone via `sendMessage`
4. Display iPhone session state (mode, timer, playing/paused)
5. Mirror pause/stop controls → send commands back to iPhone
6. Handle disconnect → transition to standalone (start local audio engine)

**Acceptance:** Start session on iPhone → Watch shows session UI. Tap pause on Watch →
iPhone pauses. Walk away from iPhone → Watch starts local audio seamlessly.

#### Phase W10: Complications (2 days)

**Goal:** All four complication families.

**Tasks:**
1. Create `BioNauralComplicationProvider`
2. Implement circular, corner, rectangular, inline views
3. Mini wavelength path for rectangular
4. Active session state in all families
5. Timeline refresh (15 min idle, 1 min active)
6. Tap → launch app (idle → suggestion, active → session)

**Acceptance:** All four complication types render correctly on watch face. Update
during active sessions. Tapping launches to correct screen.

#### Phase W11: Breathing Haptics Integration (0.5 day)

**Goal:** Wire existing `WatchBreathingHaptics` to session lifecycle.

**Tasks:**
1. Start breathing haptics when Relaxation/Sleep session begins
2. Feed HR updates to haptics service
3. Auto-stop when sustained calm detected (60s)
4. Respect user preference toggle
5. Show/hide breathing indicator on session screen

**Acceptance:** Relaxation session → feel haptic breathing pattern. Pattern slows
as HR drops. Auto-stops after 60s of calm.

#### Phase W12: Battery Warning + Pre-Session Checks (0.5 day)

**Goal:** Safety checks before session start.

**Tasks:**
1. Check `WKInterfaceDevice.current().batteryLevel`
2. Display warning sheet for low battery
3. Block at < 10%
4. Check headphone connection (warn if Watch speaker)
5. Check HealthKit authorization (prompt if not granted)

**Acceptance:** Low battery shows warning. Very low battery blocks session. Speaker
shows headphone recommendation.

#### Phase W13: Accessibility Pass (1 day)

**Goal:** Full VoiceOver, Reduce Motion, Dynamic Type support.

**Tasks:**
1. Audit every view for `accessibilityLabel` and `accessibilityHint`
2. Test VoiceOver navigation flow (idle → mode selection → session → post)
3. Implement Reduce Motion variants (static line, no scroll)
4. Test Dynamic Type scaling
5. Add `accessibilityAddTraits` for buttons
6. Group related elements with `accessibilityElement(children: .combine)`

**Acceptance:** Complete VoiceOver navigation. Reduce Motion shows static visuals.
All text scales with Dynamic Type setting.

#### Phase W14: Audio Asset Bundling (1 day)

**Goal:** Curated Watch sound library.

**Tasks:**
1. Select 4 ambient beds (1 per mode) from full library
2. Select 8 melodic loops (2 per mode)
3. Encode at 128kbps AAC
4. Trim to clean loop points (seamless looping)
5. Add to Watch app bundle
6. Create `WatchSoundLibrary` catalog (maps mode → asset filenames)
7. Test looping on Watch hardware

**Acceptance:** Each mode plays appropriate ambient + melodic audio. Loops seamlessly.
Total bundle size < 12 MB.

#### Phase W15: Integration Testing (2-3 days)

**Goal:** End-to-end verification of all scenarios.

See §11 (Testing Strategy) for full test plan.

---

### Phase Summary

| Phase | Duration | Dependency |
|-------|----------|-----------|
| W1: WatchAudioEngine | 2-3 days | swift-atomics in Watch target |
| W2: Standalone lifecycle | 2 days | W1 |
| W3: Wavelength view | 2 days | None (can parallel W1-W2) |
| W4: Session screen | 2 days | W2, W3 |
| W5: Tap-to-reveal | 1 day | W4 |
| W6: Idle screen | 2-3 days | None (can parallel W1-W5) |
| W7: Suggestion engine | 2 days | W6 |
| W8: Post-session | 1 day | W4 |
| W9: Companion mode | 2 days | W4 |
| W10: Complications | 2 days | W6 (idle state), W4 (active state) |
| W11: Breathing haptics | 0.5 day | W4 |
| W12: Battery + checks | 0.5 day | W2 |
| W13: Accessibility | 1 day | W4, W6, W8 |
| W14: Audio assets | 1 day | W1 |
| W15: Integration testing | 2-3 days | All |
| **Total** | **~23-27 days** | |

### Parallelization

```
Week 1:  W1 (audio engine) ──────→ W2 (lifecycle) ──→
         W3 (wavelength)   ──────→ W6 (idle screen) →
         W14 (audio assets) ─────→

Week 2:  W4 (session screen) ────→ W5 (tap reveal) →
         W7 (suggestion engine) ─→
         W9 (companion mode) ────→

Week 3:  W8 (post-session) ──────→
         W10 (complications) ────→
         W11 (haptics) + W12 (checks) →

Week 4:  W13 (accessibility) ───→
         W15 (integration testing) ──────────────────→
```

**Critical path:** W1 → W2 → W4 → W5 (audio → lifecycle → screen → interaction).
Everything else can parallel.

---

## 11. Testing Strategy

### Unit Tests

| Test Area | What to Verify |
|-----------|---------------|
| **WatchAudioEngine** | Engine starts/stops cleanly. Amplitude ramp completes before stop. Format correct (stereo Float32, 44.1kHz). |
| **Binaural synthesis** | FFT left/right channels → correct carrier ± beat/2 frequencies within 1 Hz. Phase accumulators stable over 2 hours. |
| **Adaptive algorithm** | Focus mode: rising HR → decreasing beat frequency. Sleep mode: time-based ramp 6→2 Hz over 25 min. Slew rate: never exceeds 0.3 Hz/sec. |
| **State classification** | Hysteresis: HR oscillating at boundary stays in current state. Dwell time: transition requires 5s sustained. No skip-transitions. |
| **Suggestion engine** | 9am + calm HR → Focus. 10pm → Sleep. Post-workout → Relaxation. Poor sleep → Relaxation. |
| **Session outcome** | Correct biometricSuccessScore per mode formula. Overall score blends biometric (0.7) + thumbs (0.3). |
| **Learning profile** | Session count increments. Duration averages update. Streak calculates correctly across days. |

### Integration Tests

| Scenario | Steps | Expected |
|----------|-------|----------|
| **Standalone session** | Start Focus from Watch. Wait 5 min. Stop. | Audio plays through AirPods. HR adapts frequency. Post-session shows correct metrics. Outcome saved. |
| **Companion session** | Start Focus on iPhone. Verify Watch shows session. Tap pause on Watch. | Watch mirrors iPhone state. Pause command reaches iPhone. HR streams from Watch to iPhone. |
| **Standalone → companion** | N/A (does not happen mid-session) | Verify Watch does NOT transition to companion during active standalone session. |
| **Companion → standalone** | Start session on iPhone. Walk out of Bluetooth range. | Watch detects disconnect. Starts local audio within 2 seconds. Adaptation continues with on-Watch HR. |
| **Disconnect recovery** | Start standalone. Remove Watch briefly. Put back on. | HR drops for ~10s. Audio holds parameters. HR resumes. Adaptation resumes from last HR_slow. |
| **Sleep mode dimming** | Start Sleep session. Wait 15 minutes. | UI progressively dims. Wave amplitude decreases. Controls fade. |
| **Battery warning** | Set Watch to 15% battery (test environment). Start session. | Warning appears. User can dismiss and continue. |
| **Post-session sync** | Complete standalone session. Bring iPhone nearby. | SessionOutcome appears in iPhone's session history. |
| **Complication tap** | Tap rectangular complication. | App launches to idle screen with current suggestion. |
| **AOD** | Start session. Lower wrist. | Screen shows static line + timer + mode name. No animations. Raise wrist → full UI. |

### Performance Tests

| Metric | Target | How to Measure |
|--------|--------|---------------|
| CPU during 30-min session | < 8% average | Xcode Instruments on Watch hardware |
| Memory during 30-min session | No growth (no leaks) | Instruments allocations |
| Battery per hour (standalone) | < 15% | Full session test on hardware |
| Audio glitches per 30-min session | Zero | Listen test + Instruments audio |
| Wavelength render FPS | > 55 FPS sustained | Instruments Core Animation |
| HR sample → audio param latency | < 200ms | Timestamp logging |
| Session start → audio playback | < 2 seconds | Stopwatch |

### Hardware Test Matrix

| Watch | Chip | Test Priority |
|-------|------|---------------|
| Series 8 | S8 | Minimum supported (baseline) |
| Series 9 | S9 | Primary development target |
| SE (2nd gen) | S8 | Budget model (performance floor) |
| Ultra 2 | S9 | Large screen (49mm layout) |
| Series 10 | S10 | Latest (if available) |

---

## 12. Constraints & Limitations

### watchOS Platform Constraints

| Constraint | Impact | Mitigation |
|-----------|--------|-----------|
| No raw RR intervals during live workout | HRV is approximate | Use BPM → estimated RR → RMSSD. Directionally correct. |
| Limited audio assets in Watch bundle | Smaller sound library | Curate best 12 files (~10 MB). Quality over quantity. |
| No reverb/EQ audio units on Watch | Simpler audio character | Binaural beats are the science layer — they don't need reverb. Ambient/melodic files include their own processing. |
| No Metal shaders on Watch | No organic background | Use simple radial gradient. The Wavelength is the hero visual. |
| Battery drain with audio + HR | ~12-15% per hour | Battery warning. Suggest shorter sessions. Max 90 min with warning. |
| 64 MB memory limit (Watch apps) | Constrain audio buffers | Use streaming playback (AVAudioPlayerNode), not preloaded buffers. Keep decoded audio to 1 file at a time. |
| No SwiftData on Watch (practical) | Use UserDefaults + Codable | Learning profile and session history as Codable structs in UserDefaults. Sync to iPhone for SwiftData persistence. |
| No `AVAudioUnitReverb` on watchOS | Dry entrainment signal | Acceptable — the ambient bed provides spatial character |
| Vortex (particle library) build issue | No particles on Watch | Not needed — Wavelength is the visual, not Orb+particles |

### Known Xcode Issues

The Watch target is currently **disabled** in the build scheme due to a Vortex
watchOS build issue. Resolution:

1. Remove Vortex from Watch target dependencies (particles not used on Watch)
2. Conditionally compile any Vortex references with `#if os(iOS)`
3. Re-enable Watch target in scheme

### Screen Sizes

| Watch | Screen Size | Content Area (approx) |
|-------|-------------|----------------------|
| 41mm | 352×430 px (176×215 pt) | 170×200 pt usable |
| 45mm | 396×484 px (198×242 pt) | 190×224 pt usable |
| 49mm (Ultra) | 410×502 px (205×251 pt) | 198×233 pt usable |

Design for 45mm (198×242 pt). Test on 41mm (ensure nothing clips) and 49mm
(ensure nothing floats awkwardly).

---

## 13. File Structure

### Target: BioNauralWatch

```
BioNauralWatch/
├── BioNauralWatchApp.swift          # @main entry, WCSession activation
├── Audio/
│   └── WatchAudioEngine.swift       # AVAudioEngine graph for watchOS
├── Services/
│   ├── WatchSessionManager.swift    # Session lifecycle + mode detection (exists, update)
│   ├── WatchHealthKitService.swift  # HR streaming via HKWorkoutSession (exists, update)
│   ├── WatchBreathingHaptics.swift  # Adaptive breathing cues (exists, keep)
│   └── WatchSuggestionEngine.swift  # Smart suggestion algorithm
├── Views/
│   ├── WatchIdleView.swift          # Three-stage idle screen
│   ├── WatchSessionView.swift       # Active session (wavelength + controls)
│   ├── WatchPostSessionView.swift   # Post-session metrics + feedback
│   └── Components/
│       ├── WatchWavelengthView.swift # Canvas-based wave rendering
│       ├── WatchGlassPill.swift      # Transport controls pill
│       ├── WatchBiometricPill.swift  # HR + state inline badge
│       └── WatchLearningIndicator.swift # Dots → ring progression
├── Models/
│   ├── WatchLearningProfile.swift   # UserDefaults-persisted learning data
│   ├── WatchSuggestion.swift        # Suggestion result model
│   └── WatchSoundLibrary.swift      # Mode → asset filename mapping
├── Complications/
│   └── BioNauralComplicationProvider.swift
└── Resources/
    └── Sounds/                      # Bundled ambient + melodic assets (AAC)
```

### Shared Code (BioNauralShared)

These files must be accessible to both iPhone and Watch targets. Currently in
BioNauralShared or should be moved there:

```
BioNauralShared/
├── FocusMode.swift              # ✅ Already shared
├── BiometricState.swift         # ✅ Already shared
├── BiometricSample.swift        # ✅ Already shared
├── WatchMessage.swift           # ✅ Already shared
├── SessionOutcome.swift         # ✅ Already shared
├── FrequencyMath.swift          # ✅ Already shared
├── AudioParameters.swift        # ⬆️ Move from BioNaural/Audio/
├── BinauralBeatNode.swift       # ⬆️ Move from BioNaural/Audio/
├── HeartRateAnalyzer.swift      # ⬆️ Move from BioNaural/Biometrics/
├── AdaptationEngine.swift       # ⬆️ Move from BioNaural/Biometrics/
├── BiometricProcessor.swift     # ⬆️ Move from BioNaural/Biometrics/
└── AudioTargets.swift           # ⬆️ Move from BioNaural/Biometrics/
```

Moving these to Shared eliminates code duplication and ensures the adaptive algorithm
is identical on both platforms. The iPhone targets import from Shared the same way.

---

## Appendix A: Mockup Reference

See `mockups/watch-companion.html` for 10 pixel-perfect HTML renders of all screens
described in this document. Top 3 screens for Apple featuring:

1. **Screen 3 (Confident Idle)** — Demonstrates the learning loop payoff
2. **Screen 4 (Focus · Calm)** — The radical emptiness of the session screen
3. **Screen 8 (Sleep)** — Progressive dimming as a design statement

---

## Appendix B: Key Design Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Wavelength over Orb | Wavelength | Orb needs space; wave spans full width beautifully |
| Single wave layer (not three) | Single + ghost | Battery, performance, visual clarity on small screen |
| Tap-to-reveal HR | Yes | Respects focus state; keeps session screen minimal |
| Learning dots → ring | Yes | Communicates "the app is getting smarter" visually |
| Standalone audio on Watch | Hybrid (synthesis + files) | Entrainment is trivial CPU; ambient/melodic need real audio |
| No reverb on Watch | Acceptable | Ambient files provide spatial character; entrainment doesn't need it |
| UserDefaults (not SwiftData) | Simpler, sufficient | Watch needs lightweight persistence; sync to iPhone for full DB |
| No Vortex particles | Not needed | Wavelength replaces Orb as hero visual on Watch |
| 12 bundled audio files | 4 ambient + 8 melodic | ~10 MB total, covers all modes adequately |
| 15 pts/sec scroll (not 20) | Slower than iPhone | Battery savings, still reads as animated on smaller screen |

---

## Appendix C: Apple Featuring Angles

The Watch companion enables several Apple editorial pitch points:

1. **"Uses Apple Watch as a biometric instrument"** — real-time HR drives audio adaptation
2. **"Standalone watchOS experience"** — full sessions without iPhone, audio to AirPods
3. **"HealthKit deeply integrated"** — reads HR/HRV/sleep, writes mindful sessions
4. **"The app learns you"** — visible progression from "Learning your rhythm" to "Tuned to you"
5. **"Respects your attention"** — tap-to-reveal, progressive dimming, minimal UI during session
6. **"Accessibility-first"** — VoiceOver, Reduce Motion, Dynamic Type across all screens
7. **"Complications as utility"** — glanceable session state and personalized suggestions on watch face

Mental Health Awareness Month (May) editorial pitch should lead with the Watch app
as the hero surface — "Your Watch knows when you need to breathe."
