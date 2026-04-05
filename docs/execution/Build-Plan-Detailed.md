# BioNaural — Detailed Build Plan

> Every phase has a clear deliverable, dependencies, and acceptance criteria. Work top to bottom. Don't skip ahead.

---

## MANDATORY AUDIT CHECKPOINTS

**Every checkpoint MUST pass before proceeding to the next section.** Checkpoints enforce the three non-negotiable development rules from CLAUDE.md. Failing a checkpoint means going back and fixing before moving forward.

### What Each Audit Checks

| Check | Rule | How to Verify |
|-------|------|--------------|
| **No hardcoded values** | All colors, spacing, fonts, durations, frequencies, thresholds come from Theme tokens or config | Search code for raw hex values (#), raw pixel numbers outside Theme.Spacing, raw font sizes outside Theme.Typography, raw animation durations outside Theme.Animation, raw audio values outside Theme.Audio |
| **Native iOS UI only** | NavigationStack, TabView, .sheet, .alert, native pickers, SF Symbols. No custom nav, no third-party UI | Search for any custom navigation controller, any third-party UI imports, any non-native navigation pattern |
| **No patching** | Every fix addresses root cause. No workarounds, shims, hacks, or band-aids | Search for "workaround", "hack", "patch", "shim", "temporary", "TODO: fix later", force-unwraps used as shortcuts |
| **Docs updated** | All affected docs reflect the current state of the code | Compare implemented features against CLAUDE.md, DesignLanguage.md, and relevant Tech-*.md docs. Flag any drift. |

### Checkpoint Schedule

| Checkpoint | After Phase | Gate For | Pass Criteria |
|-----------|------------|---------|---------------|
| **CP1** | Phase 8 (Foundation complete) | Audio Engine work | All Theme tokens exist. Navigation is native. No hardcoded values in any view. Docs: CLAUDE.md and DesignLanguage.md reflect implemented tokens. |
| **CP2** | Phase 18 (Audio Engine complete) | Biometric Pipeline work | All audio parameters reference Theme.Audio tokens. No hardcoded frequencies, durations, or mix levels in the audio engine. No patching in audio route handling. Docs: Tech-AVAudioEngine.md and Tech-AudioEngine.md match implementation. |
| **CP3** | Phase 28C (Biometrics + Feedback complete) | UI work | All biometric thresholds (HR zones, hysteresis bands, slew rates) come from config, not magic numbers. Signal quality model integrated cleanly (not patched in). Feedback loop records correctly. Docs: Tech-AdaptiveAlgorithm.md, Tech-FeedbackLoop.md match implementation. |
| **CP4** | Phase 36C (UI + Watch complete) | Platform Integration | All UI uses native navigation. All spacing/color/type from Theme. Orb and Wavelength animations use Theme.Animation tokens. Watch app uses native watchOS patterns. No hardcoded values anywhere in UI layer. Docs: DesignLanguage.md, Onboarding-Flow.md match implementation. |
| **CP5** | Phase 42J (Platform + Retention complete) | Polish phase | Live Activities, Widgets, Shortcuts all use native frameworks. Analytics events match taxonomy. Retention features use existing data models (no patched-in schemas). Docs: all Tech-*.md and Strategy-*.md current. |
| **CP6** | Phase 48 (Pre-submission) | App Store submission | FULL audit of entire codebase. Zero hardcoded values. Zero non-native UI. Zero patches. All docs match shipped code. CLAUDE.md is the single source of truth and accurately describes the app. |

### Audit Process

1. Run automated checks (grep for hex values, raw numbers, non-native imports)
2. Manual code review of each file changed since last checkpoint
3. Compare code against relevant doc specs
4. Update any docs that have drifted from implementation
5. Log audit results with pass/fail per check
6. **If ANY check fails: fix before proceeding. No exceptions.**

### Doc Update Requirements

At each checkpoint, update these docs to match current implementation:

| Checkpoint | Docs to Verify/Update |
|-----------|----------------------|
| CP1 | CLAUDE.md, DesignLanguage.md (confirm all tokens implemented) |
| CP2 | Tech-AVAudioEngine.md, Tech-AudioEngine.md, Tech-MelodicLayer.md |
| CP3 | Tech-AdaptiveAlgorithm.md, Tech-FeedbackLoop.md, Tech-WatchPipeline.md |
| CP4 | DesignLanguage.md, Onboarding-Flow.md, Tech-Architecture.md |
| CP5 | Tech-BackgroundAudio.md, Strategy-AppleFeaturing.md, Retention-Engagement.md |
| CP6 | ALL docs. Full sweep. CLAUDE.md is authoritative and accurate. |

---

## FOUNDATION (Phases 1-8)

### Phase 1: Xcode Project Scaffold
**Depends on:** Nothing
**Deliverable:** Xcode project with all targets compiling

- Create Xcode project with iOS 17+ deployment target
- Add targets: iPhone app, watchOS app, Widget extension
- Create BioNauralShared local Swift Package
- Add shared models to package: `FocusMode` enum (focus, relaxation, sleep), `BiometricSample`, `WatchMessage`
- Configure App Groups for shared data between app and widget
- Configure signing, bundle IDs, entitlements
- Add `UIBackgroundModes: audio` to Info.plist
- Add HealthKit entitlement + usage descriptions (`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`)
- **Acceptance:** All 4 targets compile. Clean build. No warnings.

---

### Phase 2: Theme System — Design Tokens
**Depends on:** Phase 1
**Deliverable:** Complete token system from DesignLanguage.md as Swift constants

- Create `Theme.swift` with nested enums/structs
- Colors: canvas (#080C15), surface, surfaceRaised, divider, textPrimary/Secondary/Tertiary, accent (#6E7CF7), accentWash/Light/Strong, mode colors (Focus: #5B6ABF, Relaxation: #4EA8A6, Sleep: #9080C4), biometric signal colors
- Spacing: 8pt grid (xxs through mega, all values from design doc)
- Typography: Satoshi type scale (display 40pt through small 11pt) + SF Mono (timer 32pt, data 20pt, dataSmall 14pt)
- Animation: spring presets (press 0.12s, standard 0.25s, sheet 0.35s)
- Opacity: full token set from design doc
- Corner radii: all values, continuous squircle
- Light mode variants
- **Acceptance:** Every token from DesignLanguage.md exists as a Swift constant. No magic numbers.

---

### Phase 3: Custom Font Setup — Satoshi
**Depends on:** Phase 2
**Deliverable:** Satoshi renders correctly at all Dynamic Type sizes

- Download Satoshi Variable font from Fontshare
- Save license terms alongside font file
- Add to app bundle, register in Info.plist (`UIAppFonts`)
- Create `Font` extension mapping Satoshi to the type scale
- Verify rendering at all Dynamic Type sizes (xSmall through AX5)
- Implement fallback to SF Pro if Satoshi fails to load
- **Acceptance:** All text in the app uses Satoshi. Dynamic Type scales. Fallback works.

---

### Phase 4: Navigation Shell
**Depends on:** Phases 2-3
**Deliverable:** Can navigate the full happy path with placeholder views

- Create `AppState` (@Observable) with navigation state
- Create `NavigationStack` with `NavigationPath`
- Placeholder views: ModeSelectionView, SessionView, PostSessionView, SettingsView, ScienceView
- Mode selection → tap card → session screen → stop → summary → done → back to selection
- Tab or simple navigation (decide: tabbed vs. single-stack)
- Dark mode as default appearance
- **Acceptance:** Full navigation flow works with placeholder content. Back/forward. No crashes.

---

### Phase 5: Mode Selection Screen
**Depends on:** Phase 4
**Deliverable:** Three mode cards with design language styling

- Three cards: Focus (indigo left border), Relaxation (teal), Sleep (violet)
- Card layout from DesignLanguage.md (3pt left border, surface background, mode icon + name + subtitle)
- Glass material on iOS 26+ / solid surface fallback
- Tap card → navigate to session (one tap to start, as designed)
- Long-press for duration picker (default durations: Focus 25 min, Relaxation 15 min, Sleep 30 min)
- Watch connection status at bottom (tertiary opacity)
- **Acceptance:** Matches DesignLanguage.md wireframe. One tap starts session. Long-press shows options.

---

### Phase 6: Session Screen — Static Layout
**Depends on:** Phase 4
**Deliverable:** Session screen layout WITHOUT audio or biometrics

- Canvas background (Theme.Colors.canvas) with subtle radial mode color gradient (Theme.Opacity.accentWash)
- Mode name (Theme.Typography.display, Theme.Opacity.medium, above center)
- Timer (Theme.Typography.timer, Theme.Opacity.half, below center)
- Placeholder circle for Orb (center)
- Placeholder line for Wavelength (horizontal, through center)
- HR readout (SF Mono 14pt, 30% opacity, bottom)
- Stop button (small, recessive, bottom center)
- No navigation bar. No tab bar. Full void.
- Tap anywhere → reveal HR/HRV data for 3 seconds → auto-hide
- Timer counts up from 0:00
- **Acceptance:** Layout matches DesignLanguage.md session wireframe. Timer ticks. Tap-to-reveal works.

---

### Phase 7: Post-Session Summary Screen
**Depends on:** Phase 6
**Deliverable:** Summary screen with placeholder data

- Duration (SF Mono Light, hero metric)
- Mode name (caption, mode color)
- 2-column data: Avg HR, Avg HRV, Adaptation count, Peak focus duration
- Compressed wavelength timeline placeholder (horizontal bar with mode color gradient)
- "Done" button → returns to mode selection
- No congratulations. No "great job." Data speaks.
- **Acceptance:** Layout matches design. Displays placeholder data. Done button navigates back.

---

### Phase 8: Settings & Science Screens
**Depends on:** Phase 4
**Deliverable:** Settings and science section with real content

- Settings: mode defaults, duration preferences, sound preferences, connected devices, notifications toggle
- Settings → Safety: permanent epilepsy disclaimer (always accessible, not just onboarding)
- Settings → Sound Preferences: preferred instruments, energy preference per mode, learned profile display, "Reset preferences" option
- Settings → Connected Services: HealthKit status, Apple Watch status, future wearable connections
- Science section: 6 cards from InApp-Science.md (The Honest Truth, How Binaural Beats Work, Brainwave Bands, Adaptive Advantage, Individual Differences, 400 Hz Sweet Spot)
- Each card: hook (bold, visible), body (expands on tap), study reference (textSecondary, italic)
- Contextual science cards data structure (to be shown on mode selection later)
- Links to Privacy Policy and Terms of Service
- Settings → Privacy → Export My Data: generates JSON file (sessions, profile, preferences). Share via native share sheet.
- Settings → Privacy → Delete My Data: removes all SwiftData + resets preferences. Confirmation required.
- **Acceptance:** Science content matches InApp-Science.md. Cards expand/collapse. Settings persist. Safety disclaimer permanently accessible. Sound preferences display and reset. Data export produces valid JSON. Delete removes all data.

---

## --- CHECKPOINT CP1: Foundation Audit ---
> **STOP. Audit before proceeding.** Verify: all Theme tokens implemented (no hardcoded hex/pt/duration in any view), navigation is native NavigationStack, no third-party UI, docs (CLAUDE.md, DesignLanguage.md) match implementation. Fix any failures before continuing.

---

## AUDIO ENGINE (Phases 9-18)

### Phase 9: AVAudioSession Configuration
**Depends on:** Phase 1
**Deliverable:** Audio session correctly configured for background playback

- Configure `.playback` category, `.default` mode
- `setSupportsMultichannelContent(false)` — prevent Spatial Audio
- `setPreferredSampleRate(44100)` (or match hardware)
- `setPreferredIOBufferDuration(0.012)` (~512 frames)
- Activate session
- Register for `interruptionNotification` (handle began/ended, auto-resume when `.shouldResume`)
- Register for `routeChangeNotification` (pause on headphone disconnect)
- Register for `AVAudioEngineConfigurationChange`
- **Acceptance:** Audio plays in background. Survives lock screen. Pauses on headphone unplug. Resumes after phone call.

---

### Phase 10: Binaural Beat Generator — Basic Sine
**Depends on:** Phase 9
**Deliverable:** Two different frequencies playing, one per stereo channel

- Create `AVAudioEngine` instance
- Create `AVAudioSourceNode` with stereo non-interleaved Float32 format
- Implement phase accumulator (Double precision) for left and right channels
- Generate sine wave: `sample = amplitude * sin(2π * phase)`
- Left channel: `carrier - beatFreq/2`
- Right channel: `carrier + beatFreq/2`
- Phase wrapping: `if phase >= 1.0 { phase -= 1.0 }`
- Connect: source → mainMixerNode → outputNode
- Start engine
- **Acceptance:** Headphones produce two different tones (one per ear). Frequency analyzer confirms correct frequencies. Binaural "wobble" perceived in center of head.

---

### Phase 11: Atomic Parameter Passing
**Depends on:** Phase 10
**Deliverable:** Parameters change from main thread without clicks or locks

- Add `swift-atomics` package dependency
- Create `AudioParameters` class with `ManagedAtomic<UInt64>` for: baseFrequency, beatFrequency, amplitude, carrierFrequency
- Public API: `var beatFrequency: Double` (get/set using `.bitPattern`)
- Render callback reads from atomics (lock-free)
- Main thread writes to atomics (lock-free)
- **Acceptance:** Changing beatFrequency from a button on the UI thread produces no clicks, no pops, no audio artifacts.

---

### Phase 12: Per-Sample Smoothing
**Depends on:** Phase 11
**Deliverable:** All parameter changes are smooth and imperceptible

- Implement exponential smoothing in the render callback
- Amplitude smoothing: 5ms time constant (`coeff = 1.0 - exp(-1.0 / (0.005 * sampleRate))`)
- Frequency smoothing: 20ms time constant
- Current values chase target values per-sample
- Snap when within threshold (`abs(current - target) < 0.001`)
- **Acceptance:** Rapid parameter changes (e.g., beat freq from 6 to 18 Hz) produce a smooth glide, no audible stepping. Verified by ear and by recording + visual inspection.

---

### Phase 13: Mode-Dependent Carrier Frequencies
**Depends on:** Phase 12
**Deliverable:** Each mode sounds distinctly different

- Focus carrier: 350 Hz base (range 300-450 Hz)
- Relaxation carrier: 200 Hz base (range 150-250 Hz)
- Sleep carrier: 150 Hz base (range 100-200 Hz)
- Switching modes smoothly crossfades carrier frequency
- Mode also sets initial beat frequency: Focus 15 Hz, Relaxation 10 Hz, Sleep 6 Hz
- **Acceptance:** Focus sounds brighter/headier. Relaxation sounds warmer. Sleep sounds deepest. Transitions are smooth.

---

### Phase 14: Harmonic Layering
**Depends on:** Phase 13
**Deliverable:** Carrier is warm, not a clinical pure sine

- Add harmonics to the carrier in the render callback
- 2nd harmonic at -8 dB, 3rd at -14 dB (triangle wave character, -6 dB/octave rolloff)
- Harmonics applied per-channel independently (so binaural differences propagate through harmonics)
- Carrier drift: ±1.5 Hz slow random walk (prevents cochlear fatigue)
- LFO amplitude modulation: 3 unsynchronized LFOs (0.07, 0.13, 0.29 Hz) at ±2 dB depth
- **Acceptance:** 30-minute listening test — carrier sounds warm and organic, not fatiguing. No perceptible repeating pattern from LFOs.

---

### Phase 15: Reverb
**Depends on:** Phase 14
**Deliverable:** Spatial depth without smearing the binaural beat

- Add `AVAudioUnitReverb` to the audio graph
- Factory preset: `.mediumHall`
- wetDryMix: 15-25% (subtle)
- Parallel send architecture: split binaural source → dry path (for beat clarity) + wet path (for ambience)
- Both paths merge at mixer
- **Acceptance:** Audio has spatial depth. Binaural beat "wobble" is still clearly perceptible. Not muddy.

---

### Phase 16: Ambient Audio Layer — File Playback
**Depends on:** Phase 15
**Deliverable:** Nature sounds play alongside binaural beats

- Bundle 10 ambient beds (3 per mode + 1 silence option) per Sound-Asset-Pipeline.md (royalty-free/CC0)
- Create `AVAudioPlayerNode` for ambient playback
- Seamless looping (schedule next file play before current ends)
- Connect ambient player → mixer (separate from binaural source)
- Volume hierarchy: ambient at 0 dB (reference), binaural at -8 dB below
- Crossfade on mode change: fade out current bed (3s), fade in new bed (3s)
- **Acceptance:** Nature sounds play seamlessly on loop (no audible seam). Binaural beats sit underneath, felt more than heard. Mode change crossfades smoothly.

---

### Phase 16B: Sound Library & Tagging System
**Depends on:** Phase 1
**Deliverable:** Tagged catalog of melodic loops ready for selection

- Source 30-50 melodic loops (pads, piano, strings, bass, textures) per Sound-Asset-Pipeline.md
- License verification: CC0 or explicit commercial-use only. Maintain license log.
- Process each: trim to prime-number seconds, HP 35 Hz, LP 12 kHz, normalize to -18 LUFS, seamless loop
- Export as AAC 256kbps, 44100 Hz, stereo
- Tag each with metadata: energy (0-1), tempo (BPM or "free"), key, scale, instrument, brightness (0-1), density (0-1), mode_affinity ([focus, relaxation, sleep])
- Create `SoundLibrary.swift`: loads catalog from bundle, filters by tags, returns ranked candidates
- Separate from ambient beds (ambient = nature/noise textures, melodic = musical content)
- **Acceptance:** 30-50 tagged loops in bundle. SoundLibrary filters correctly by mode + energy + brightness. All loops play seamlessly on loop.

---

### Phase 16C: Melodic Layer — Playback & Crossfading
**Depends on:** Phases 15, 16B
**Deliverable:** Third audio layer plays curated musical content alongside binaural + ambient

- Two `AVAudioPlayerNode` instances (A/B) for seamless crossfading
- `MelodicLayer.swift`: manages selection, playback, and crossfade logic
- Connect both players → melodic submixer → master mixer
- Volume: -6 to -3 dB (underneath ambient, above binaural)
- Crossfade: when changing sounds, fade out Player A over 10-15s, fade in Player B simultaneously
- Selection triggered by: session start + biometric state changes (at most every 3-5 min)
- During sustained deep state (5+ min stable biometrics): DO NOT change sounds. Hold steady.
- **Acceptance:** Melodic loops play alongside binaural + ambient. Crossfades are smooth (no gap, no overlap volume spike). Three layers mix cleanly.

---

### Phase 16D: Sound Selection Rules (v1)
**Depends on:** Phases 16B, 16C
**Deliverable:** Rule-based melodic selection from tagged library

- `SoundSelector.swift` (protocol-based — deterministic v1, ML v1.5)
- Input: current mode + biometric state + user sound preferences
- Rules per mode (from Tech-MelodicLayer.md):
  - Focus: energy 0.3-0.5, brightness 0.3-0.5, density 0.2-0.4, pentatonic/major scales
  - Relaxation: energy 0.1-0.3, brightness 0.2-0.4, density 0.1-0.3, pentatonic/whole-tone
  - Sleep: energy 0.0-0.2, brightness 0.0-0.2, density 0.0-0.1, whole-tone/modal
- User preference weighting: rank filtered candidates by user's learned instrument/energy weights
- Key-matching: ensure selected loops are harmonically compatible
- **Acceptance:** Each mode selects audibly different melodic content. Focus sounds more present, Relaxation warmer, Sleep nearly silent. User preference weights shift selection ordering.

---

### Phase 16E: User Sound Preference Onboarding
**Depends on:** Phase 16D. Integrated into Phase 33 (Onboarding Flow) as Screen 10.
**Deliverable:** User's initial sound profile set during first launch

- Onboarding screen (after mode explanation, before first session):
  > "What kind of sounds do you prefer?"
  > [Nature-forward] [Musical] [Minimal] [Mix of everything]
- Sets initial weights in `SoundProfile` (stored in SwiftData):
  - Nature-forward: ambient layer dominant, melodic quiet
  - Musical: melodic layer prominent, ambient as texture
  - Minimal: both layers very quiet, binaural forward
  - Mix: balanced defaults
- Profile evolves via feedback loop (thumbs + biometric outcomes)
- Accessible in Settings → Sound Preferences for manual adjustment
- **Acceptance:** Preference selection works. "Musical" users hear more melodic content. "Minimal" users hear mostly binaural.

---

### Phase 17: Session Arcs — Manual Mode & Adaptive Mode
**Depends on:** Phases 16, 16C
**Deliverable:** Sessions work beautifully with OR without biometric data

**Manual Mode (time-based — always available, no biometrics required):**

This is NOT a degraded fallback. It's a first-class experience. Users who choose Manual Mode, don't have a Watch, or are on the free tier get this.

- Focus arc: meet (Theme.Audio.focusMeetFreq, 1 min) → ramp to sustain frequency (4 min) → sustain (variable) → return (2 min) → close (fade out, 1 min)
- Relaxation arc: meet (Theme.Audio.relaxMeetFreq, 1 min) → ramp down (4 min) → sustain (variable) → gentle return (2 min) → close (1 min)
- Sleep arc: continuous ramp (Theme.Audio.sleepStartFreq → Theme.Audio.sleepEndFreq over 25 min) → hold → fade when timer ends
- Melodic layer: selects sounds based on mode + user preferences + time progression (no biometric input). Changes sounds at 5-min intervals with crossfades.
- The session arc itself provides the dynamic experience — frequency shifts, melodic evolution, volume arcs. The user still hears a journey, not a flat tone.
- **User can manually adjust beat intensity during session** — slider or +/- buttons to shift frequency up/down within the mode's range. This gives the user direct control when biometrics aren't driving.

**Adaptive Mode (biometric-driven — requires Watch or BLE HR):**

Everything in Manual Mode, PLUS:
- Biometric processor overrides the time-based arc with real-time HR/HRV-driven adaptation
- Melodic layer responds to biometric state changes (not just time)
- The session arc becomes a starting template that biometrics modify

**Pre-Session Check-In (Both Modes):**

Before every session starts, a quick 2-tap check-in:

Screen 1: "How are you feeling right now?"
- Slider or 5-point scale: [Wired/Anxious] → [Neutral] → [Calm/Tired]
- One tap, no typing

Screen 2: "What are you trying to do?"
- [Focus deeply] [Unwind & relax] [Fall asleep]
- This confirms or overrides the mode selection (user might tap Relaxation but say "fall asleep" — suggest Sleep mode)

**How the check-in feeds the engine:**
- In Manual Mode: the self-report IS the primary input. "Wired + Focus" → start at higher frequency, ramp down more aggressively, pick calming melodic content. "Calm + Sleep" → start at lower frequency, gentle ramp, minimal melodic.
- In Adaptive Mode: the self-report sets the starting parameters and initial melodic selection. Biometrics take over from there but the starting point is personalized by the check-in.
- If the user's self-report contradicts their biometrics (says "calm" but HR is 90), the adaptive engine trusts biometrics but notes the discrepancy — useful training data for the learning loop.

**Skip option:** "Skip — use defaults." Frequent users who do the same mode at the same time every day shouldn't be slowed down. After 5+ sessions with similar answers, offer to remember: "Use your usual settings?"

**Mode Toggle:**
- Settings → Session Mode: [Adaptive (requires HR sensor)] [Manual]
- If Watch/BLE HR is connected: defaults to Adaptive
- If no HR sensor detected: defaults to Manual (no prompt, no degraded feeling)
- User can always switch manually. Some users may prefer Manual even with a Watch.

**Free tier = Manual Mode with 2 modes (Focus + Relaxation) + check-in.**
**Premium = Adaptive Mode + all 4 modes + all sounds + biometric-driven adaptation.**

- Amplitude fade-in (first 30s) and fade-out (last 30s) on all modes, both modes
- Timer tracks session progress and drives the arc
- Amplitude fade-in (first 30s) and fade-out (last 30s) on all modes
- Timer tracks session progress and drives the arc
- **Pomodoro mode (Focus only):** Optional toggle. 25 min focus (beta) → haptic tap → 5 min relaxation break (alpha) → haptic tap → repeat. User sets cycle count (default: 4 = 2 hours). Audio seamlessly crossfades between modes at each transition. Timer shows cycle progress ("Cycle 2 of 4 — Focus — 12:30"). Post-session summary shows per-cycle biometric data.
- **Acceptance:** Each mode feels like a journey, not a flat tone. Start is gentle, middle is sustained, end is graceful. Sleep mode clearly descends over time. Pomodoro mode cycles correctly between Focus and Relaxation with smooth audio transitions.

---

### Phase 18: Headphone Detection & Spatial Audio Warning
**Depends on:** Phase 9
**Deliverable:** User is warned if setup is wrong

- Check `AVAudioSession.currentRoute` for headphone types
- If `.builtInSpeaker`: show "Headphones required" alert, prevent session start
- If AirPods detected (port name contains "AirPods"):
  - Set `engine.outputNode.spatializationEnabled = false`
  - Set `session.setSupportsMultichannelContent(false)`
  - Flag for Spatial Audio test tone in onboarding
- If `.carPlay` detected: block playback entirely. Alert: "BioNaural is not available during CarPlay for safety. Binaural beats can cause drowsiness."
- Monitor `routeChangeNotification` mid-session: if headphones unplug → pause audio, show alert. If CarPlay activates mid-session → pause and warn.
- **Acceptance:** Speaker playback blocked. CarPlay blocked with safety message. AirPods trigger Spatial Audio mitigation. Mid-session unplug pauses gracefully.

---

## --- CHECKPOINT CP2: Audio Engine Audit ---
> **STOP. Audit before proceeding.** Verify: all audio parameters (frequencies, durations, mix levels, smoothing constants) reference Theme.Audio tokens. No hardcoded Hz values, no hardcoded dB levels, no hardcoded time constants in the render callback or audio graph. Audio route handling is clean (no patches). Update Tech-AVAudioEngine.md, Tech-AudioEngine.md, Tech-MelodicLayer.md if implementation diverged.

---

## BIOMETRIC PIPELINE (Phases 19-28)

### Phase 19: HealthKit Service — Authorization & Queries
**Depends on:** Phase 1
**Deliverable:** Can read HR, HRV, resting HR, sleep from HealthKit

- Create `HealthKitService` with `HealthKitServiceProtocol`
- Authorization flow: request read (heartRate, heartRateVariabilitySDNN, restingHeartRate, sleepAnalysis, oxygenSaturation) + write (mindfulSession)
- Query methods: `latestRestingHR()`, `latestHRV()`, `lastNightSleep()`
- All queries async/await using `HKSampleQueryDescriptor`
- Graceful degradation: return nil when unavailable or denied
- Create `MockHealthKitService` for testing
- **Acceptance:** Reads real data from a device with HealthKit data. Returns nil gracefully when denied. Mock works in unit tests.

---

### Phase 20: Watch App — HKWorkoutSession
**Depends on:** Phase 1 (Watch target)
**Deliverable:** Watch starts a workout session and receives ~1 Hz HR

- WatchOS app entry point
- Create `HKWorkoutConfiguration` with `.mindAndBody` activity type, `.indoor` location
- Start `HKWorkoutSession` + `HKLiveWorkoutBuilder`
- Set up `HKAnchoredObjectQuery` for heartRate
- Update handler fires for each new HR sample
- Display HR on Watch face
- Always On Display support (`isLuminanceReduced` → simplified view)
- **Acceptance:** Watch starts workout, green LED stays on, HR updates appear at ~1 Hz, works with screen off.

---

### Phase 21: Watch → iPhone Communication
**Depends on:** Phase 20
**Deliverable:** HR streams from Watch to iPhone in real time

- Activate `WCSession` on both sides (Watch + iPhone)
- Watch: send HR samples via `WCSession.default.sendMessage` at 1 Hz
- Message format: `["type": "heartRate", "bpm": Double, "timestamp": TimeInterval]`
- iPhone: `WCSessionDelegate.didReceiveMessage` on background queue
- Buffer on Watch when `isReachable == false`
- Flush buffer via `transferUserInfo` on reconnection
- Heartbeat ping every 5 seconds for connection health
- **Acceptance:** HR appears on iPhone within 200ms of Watch reading. Survives brief disconnects. Buffer/flush works.

---

### Phase 22: BiometricProcessor — Smoothing & Trends
**Depends on:** Phase 21
**Deliverable:** Raw HR becomes smooth, trend-aware biometric state

- Create `BiometricProcessor` as Swift actor
- Dual-EMA smoothing: HR_fast (α=0.4), HR_slow (α=0.1)
- Trend detection: `HR_trend = HR_fast - HR_slow` with ±2 BPM deadband
- HR normalization using Heart Rate Reserve: `(HR - HR_rest) / (HR_max - HR_rest)`
- Artifact rejection: reject samples where `|HR_raw - HR_smooth| > 30 BPM`
- RMSSD approximation from 1 Hz BPM (acknowledge: directionally correct, numerically approximate)
- Publish state via `AsyncStream<BiometricState>`
- **Acceptance:** Feed simulated HR sequences → verify smooth output, correct trend detection, artifact rejection catches spikes.

---

### Phase 23: State Classification
**Depends on:** Phase 22
**Deliverable:** Continuous HR maps to discrete states without rapid toggling

- State machine: Calm (0-0.20), Focused (0.20-0.45), Elevated (0.45-0.70), Peak (0.70-1.0)
- Hysteresis band: h=0.03 on each boundary
- Minimum dwell time: 5 seconds per state
- No skip-transitions (Calm → Elevated forbidden)
- State published as part of `BiometricState`
- **Acceptance:** Feed HR oscillating at boundary → no rapid toggling. Feed clear transitions → correct state progression. Dwell time enforced.

---

### Phase 24: Adaptive Algorithm — Mode-Dependent Mapping
**Depends on:** Phases 22-23 + Phase 12
**Deliverable:** Biometrics drive audio parameters in real time

- Focus mode: negative feedback sigmoid (HR up → beat freq down toward alpha/theta)
- Relaxation mode: gentle downward bias toward alpha (8-11 Hz), floor at 8 Hz
- Sleep mode: time-based ramp (6→2 Hz) with biometric modifiers (HR dropping → accelerate ramp)
- Carrier frequency modulated by HR trend: `mode_base + 50 × tanh(HR_trend / 5)`
- Amplitude peaks in responsive middle range (inverted parabola)
- Ambient level inversely correlated with activation
- All mappings use per-sample slew rate limiting (0.3 Hz/sec max for beat freq)
- **Acceptance:** In Focus mode, deliberately elevating HR (stand up, walk) → audio audibly shifts to calming. In Relaxation mode, settling into a chair → audio maintains or deepens alpha. Transitions are smooth and imperceptible.

---

### Phase 25: Signal Quality Model (Core ML v1)
**Depends on:** Phase 22
**Deliverable:** ML model scores sample reliability

- Train logistic regression on synthetic + TestFlight data
- Input features: HR delta, HR variance (10s window), motion proxy, time since last sample
- Output: 0.0-1.0 confidence weight
- Export as Core ML model (~50KB)
- Integrate into BiometricProcessor: `adaptation_strength = base × signal_quality`
- Low quality → engine holds current parameters (doesn't chase noise)
- High quality → full adaptation responsiveness
- **Acceptance:** Feed noisy simulated data → low scores. Feed clean data → high scores. Adaptation is visibly more stable with the model vs. without.

---

### Phase 26: Baseline Calibration
**Depends on:** Phases 22-24
**Deliverable:** Session starts with personalized baselines

- First 2 minutes of each session: collect resting HR and HRV
- Compute `HR_baseline = mean(samples)`, `HRV_baseline = RMSSD(samples)`
- Compare to historical 7-day median from HealthKit
- If session starts elevated (baseline > historical × 1.2) → use historical value
- First-ever session (no history): population defaults (HR 72, HRV lnRMSSD 3.5)
- Store calibration results in SwiftData UserProfile
- **Acceptance:** Calibration completes in 2 minutes. Reasonable baselines computed. Historical comparison works.

---

### Phase 27: Disconnect Handling & Graceful Degradation
**Depends on:** Phases 21, 24
**Deliverable:** Audio never interrupts, even when biometrics fail

- Detect data dropout (no HR sample for >10 seconds)
- On dropout: freeze current audio parameters
- Over 60 seconds: linearly interpolate toward neutral (10 Hz, mode carrier base)
- If data returns within 60s: resume from last known HR_slow
- If no data after 60s: hold neutral, show subtle reconnection indicator
- No-Watch mode: sessions use time-based arcs only (no biometric adaptation)
- **Acceptance:** Simulate Watch disconnect mid-session → audio holds steady → drifts to neutral → Watch reconnects → adaptation resumes. No audio interruption at any point.

---

### Phase 28: HealthKit Write-Back
**Depends on:** Phase 19
**Deliverable:** Sessions log to Apple Health

- On session completion: write `HKCategorySample` for `mindfulSession` (all modes)
- Duration = actual session duration
- Optionally write State of Mind (valence mapped to mode: Focus → focused, Relaxation → calm, Sleep → peaceful)
- **Acceptance:** After a BioNaural session, Apple Health shows a new mindful minutes entry with correct duration.

---

### Phase 28B: Feedback Loop — Outcome Recording
**Depends on:** Phases 24, 16D
**Deliverable:** Every session's sounds + biometric outcomes are recorded for learning

- Create `SessionOutcome` model (from Tech-FeedbackLoop.md):
  - Session metadata (mode, duration, timestamp, time of day)
  - Sound selections (ambient bed ID, melodic layer IDs, binaural frequency range)
  - Biometric outcomes (HR start/end/delta, HRV start/end/delta, time to calm, time to sleep, adaptation count, sustained deep state minutes)
  - User feedback (thumbs rating, optional tags)
  - Computed: `biometricSuccessScore` (0-1), `overallScore` (biometric 0.7 + thumbs 0.3)
- `SessionOutcomeRecorder.swift`: collects data throughout session, computes scores at end, persists to SwiftData
- On session end: update `SoundProfile` weights:
  - Thumbs up → increase weight for those sound tags by 10%
  - Thumbs down → decrease by 20%
  - Biometric success > 0.7 → increase sound weights by 15%
  - Biometric success < 0.3 → decrease by 10%
- **Acceptance:** After a session, SessionOutcome is persisted with correct data. SoundProfile weights shift measurably. Next session's sound selection is different (verifiably better-ranked).

---

### Phase 28C: Post-Session Thumbs UI
**Depends on:** Phase 28B, Phase 7 (summary screen)
**Deliverable:** Simple thumbs up/down on summary screen

- Add to post-session summary: "How was the sound?" [👍] [👎]
- Tapping records rating in SessionOutcome
- Tapping nothing (just "Done") = no explicit feedback, biometric outcomes still recorded
- On thumbs-down only: optional tags — [Too busy] [Too quiet] [Not my style] [Other]. Dismissible.
- Never show mid-session. Post-session only.
- **Acceptance:** Thumbs appear on summary. Tap records. Skip works. Tags appear on thumbs-down only.

---

## --- CHECKPOINT CP3: Biometric Pipeline Audit ---
> **STOP. Audit before proceeding.** Verify: all biometric thresholds (HR zones, hysteresis bands, EMA alphas, slew rates, sigmoid parameters) come from config/tokens, not magic numbers. Signal quality model integrated as a first-class component (not patched in). Feedback loop records SessionOutcome correctly. Thumbs UI works. Update Tech-AdaptiveAlgorithm.md, Tech-FeedbackLoop.md, Tech-WatchPipeline.md if implementation diverged.

---

## UI & EXPERIENCE (Phases 29-36)

### Phase 29: The Orb — Biometric-Reactive Visualization
**Depends on:** Phases 6, 24
**Deliverable:** Living, breathing visual center of the session screen

- Implement as SwiftUI Canvas or Metal shader
- Radial gradient with soft gaussian bloom
- Color: mode color, shifting toward biometric signal colors (calm=teal, elevated=amber)
- Size: pulses with breathing animation (0.95-1.05 scale, 4-6s cycle synced to beat freq)
- Biometric state changes Orb: calm=small/cool/slow, elevated=larger/warmer/faster
- Transitions: color shift 4-5s, size shift 3-4s (always smooth)
- Bloom extends beyond core as soft halo
- Reduce Motion: static soft gradient at resting opacity
- **Acceptance:** Orb breathes visibly. Deliberately changing HR (stand up) → Orb shifts color and size over several seconds. Beautiful on OLED.

---

### Phase 30: The Wavelength — Live Biometric Signal Line
**Depends on:** Phases 6, 24
**Deliverable:** Smooth sine wave spanning the screen, driven by biometrics

- SwiftUI Canvas or single `Path` drawn edge-to-edge horizontally
- Passes through center of Orb (Orb in front, Wavelength behind)
- Biometric mapping: calm=long slow waves (1 cycle/screen), elevated=shorter tighter waves (4-5 cycles)
- Amplitude: calm=±8pt, elevated=±22pt, peak=±30pt
- Scrolls continuously left-to-right at constant speed
- Subtle gaussian blur (1-2pt) — feels like light, not ink
- Stroke: 1.5-2pt in mode color at 15-25% opacity
- Transitions between states: 3-5 seconds, smooth interpolation
- Reduce Motion: static horizontal line at 15% opacity
- **Acceptance:** Wavelength responds to biometric changes. Smooth scrolling animation. Orb sits naturally on top. Combined composition is cohesive.

---

### Phase 31: Session Screen Integration
**Depends on:** Phases 29, 30, 24, 17
**Deliverable:** Complete session screen — audio + visuals + biometrics working together

- Wire up: BiometricProcessor → AudioParameters (adaptive engine)
- Wire up: BiometricProcessor → SessionViewModel (Orb + Wavelength state)
- Wire up: AudioParameters → Orb + Wavelength visuals (responds to audio state)
- Timer driven by session arc
- Tap to reveal HR/HRV overlay (3 second auto-hide)
- Stop button ends session → navigate to summary
- All elements visible, positioned, and responsive simultaneously
- **Acceptance:** Full end-to-end: Watch HR → iPhone processing → audio adapts → Orb and Wavelength respond → timer counts → user taps to see data → stop → summary. The complete experience works.

---

### Phase 32: Post-Session Summary — Real Data
**Depends on:** Phase 31
**Deliverable:** Summary shows actual session data

- Duration from timer
- Average HR, min/max HR from session
- Average HRV approximation
- Adaptation event count (number of state transitions)
- Compressed wavelength timeline: the session's wavelength frozen as a horizontal bar with color shifts
- Adaptation map image generation (for sharing)
- Share button → native share sheet with pre-formatted image (9:16 for Stories)
- "Done" → back to mode selection
- **Acceptance:** Real data from a real session populates all fields. Adaptation map looks beautiful. Share generates correct image.

---

### Phase 33: Onboarding Flow
**Depends on:** Phases 5, 18, 19
**Deliverable:** Complete first-run experience from Onboarding-Flow.md

- Screen 1: Welcome ("Your brain runs on rhythms")
- Screen 2: How it works (two tones → third rhythm)
- Screen 3: The adaptive difference
- Screen 4: Headphone check (detect route, block speaker)
- Screen 5: Spatial Audio test tone (MANDATORY for AirPods — 10s test, confirm wobble, instructions if not)
- Screen 6: Epilepsy disclaimer (tap to acknowledge, required)
- Screen 7: HealthKit permission (explain why, handle denial)
- Screen 8: Watch detection (paired + installed / paired + not installed / no watch)
- Screen 9: Optional calibration (2 min, skippable)
- Screen 10: First session launch → mode selection with contextual science card
- Resume from last screen on force-quit
- **Screen sequence (12 screens total):**
  - Screen 0: Age gate (13+ confirmation per COPPA, before anything else)
  - Screens 1-3: Welcome, How It Works, Adaptive Difference
  - Screen 4: Headphone check
  - Screen 5: Spatial Audio test tone (AirPods only)
  - Screen 6: Epilepsy disclaimer (tap to acknowledge)
  - Screen 7: HealthKit permission (request heartRate, heartRateVariabilitySDNN, restingHeartRate, sleepAnalysis, oxygenSaturation — matches Phase 19. Onboarding-Flow.md is stale on SpO2, override with Phase 19 list.)
  - Screen 8: Watch detection
  - Screen 9: Optional calibration
  - Screen 10: Sound preference ("Nature-forward / Musical / Minimal / Mix") — integrates Phase 16E content
  - Screen 11: First session launch with contextual science card
- **Acceptance:** All 12 screens work. Edge cases handled (no headphones, AirPods with Spatial Audio, denied HealthKit, no Watch, underage user). Epilepsy disclaimer requires tap. Test tone plays. Age gate blocks minors. Sound preference sets initial SoundProfile.

---

### Phase 34: Contextual Science Cards
**Depends on:** Phases 5, 8
**Deliverable:** Science cards appear at the right moments

- Focus mode card on first Focus selection
- Relaxation mode card on first Relaxation selection
- Sleep mode card on first Sleep selection
- Post-session HR/HRV explanation card (first session with biometric data)
- Duration tooltip when user selects < 15 minutes
- "Your session just adapted" card on first visible adaptation
- Each card shown once, then available in Science section
- Small, dismissible, non-blocking, mode color accent
- **Acceptance:** First-time user sees relevant science at each new touchpoint. Cards don't reappear after dismissal. All content matches InApp-Science.md.

---

### Phase 35: SwiftData Persistence
**Depends on:** Phases 31, 32
**Deliverable:** Sessions persist and display in history

- `FocusSession` @Model: id, startDate, endDate, mode, duration, avgHR, avgHRV, beatFreqStart, beatFreqEnd, adaptationEvents (Codable array), wasCompleted
- `UserProfile` @Model: baselineRestingHR, baselineHRV, preferredMode, preferredDuration, adaptationSensitivity
- Save session on completion (or on session stop/abandon)
- History view: list of past sessions, sorted by date
- Session detail: tap for full stats + adaptation map
- **Acceptance:** Complete a session → it appears in history. Kill app → relaunch → history persists. 50+ sessions → no performance issues.

---

### Phase 36: Watch App — Session UI
**Depends on:** Phases 20, 21
**Deliverable:** Watch shows useful info during sessions

- Active session view: large HR number, timer, mode color indicator, stop button
- Simplified Orb visualization (subtle color pulse matching mode)
- Always On Display: dimmed view (dark background, HR + timer only)
- Haptic feedback: `.start` on session begin, `.stop` on session end, `.click` on adaptation events
- Mode selection on Watch: pick mode + start session (sends command to iPhone)
- **Acceptance:** Watch displays correct HR and timer during session. Haptics fire at right moments. Always On Display works. Can start session from Watch.

---

### Phase 36B: Watch Standalone Sessions
**Depends on:** Phase 36
**Deliverable:** Full session runs on Watch without iPhone — audio to AirPods/Bluetooth headphones

- Port binaural beat synthesis to watchOS (AVAudioEngine + AVAudioSourceNode runs on watchOS 10+)
- Bundle subset of ambient beds + melodic loops in Watch app (3-5 beds, ~15-20 MB)
- Adaptive algorithm runs on-Watch: reads HR directly from on-Watch HealthKit (no WCSession needed)
- Audio routes to Bluetooth headphones (AirPods, etc.) via Watch
- Session data stored locally on Watch → syncs to iPhone via `transferUserInfo` when reconnected
- Mode selection on Watch → starts session entirely on-Watch
- Complication tap → direct session start (one tap from wrist)
- **Acceptance:** Put iPhone in another room. Start session from Watch. Audio plays through AirPods. HR adapts the binaural frequency. Session completes. Data syncs to iPhone later.

---

### Phase 36C: Battery Warning & Session Pre-Check
**Depends on:** Phase 36
**Deliverable:** User warned if Watch battery is too low for their session

- Before session start: check Watch battery level via WCSession application context
- If battery < 20% and session > 15 min: show warning with estimate
  > "Your Apple Watch battery is at [X]%. A [duration] session uses approximately [estimate]% battery. Continue anyway?"
  > [Continue] [Shorten Session]
- Estimate: ~5% per 15 min (conservative)
- Also check: headphones connected, Spatial Audio status (from Phase 18)
- **Acceptance:** Low-battery warning appears. User can continue or shorten. Warning doesn't appear when battery is sufficient.

---

## --- CHECKPOINT CP4: UI & Watch Audit ---
> **STOP. Audit before proceeding.** Verify: ALL UI uses native SwiftUI navigation (NavigationStack, .sheet, .alert — no custom nav). ALL colors/spacing/type/animation from Theme tokens (grep for raw hex, raw pt values, raw durations). Orb and Wavelength use Theme.Animation tokens. Watch app uses native watchOS patterns. Onboarding matches Onboarding-Flow.md. Update DesignLanguage.md, Onboarding-Flow.md, Tech-Architecture.md if implementation diverged.

---

## PLATFORM INTEGRATION (Phases 37-42)

### Phase 37: Live Activity & Dynamic Island
**Depends on:** Phase 31
**Deliverable:** Session shows on Lock Screen and Dynamic Island

- `FocusActivityAttributes` with `ContentState` (HR, mode, elapsed, isPlaying)
- Start Live Activity when session begins
- Compact: Orb icon (leading) + timer using `Text(timerInterval:)` (trailing)
- Expanded: session name, HR, timer, mode color accent
- Lock Screen: thin bar with mode color gradient + timer + mode name
- Update every 5 seconds (not more — system throttles)
- End activity on session completion (keep on lock screen 5 min)
- **Acceptance:** Live Activity appears during background playback. Dynamic Island shows compact view. Timer counts correctly. HR updates reflect Watch data.

---

### Phase 38: Widgets
**Depends on:** Phases 5, 35
**Deliverable:** Home Screen and Lock Screen widgets

- Small widget: Orb (static, mode color) + "Start Focus" label. Tap → deep link to session.
- Medium widget: 3 mode pills + last session summary (duration + time ago). Tap mode → start session.
- Lock Screen widget: last session's adaptation map (tiny) or quick-start icon.
- StandBy Mode: optimized widget for StandBy display (large, glanceable, dark background)
- Read from shared SwiftData container via App Group
- **Acceptance:** Widgets render correctly. Tapping deep-links to correct mode. Data refreshes after sessions. StandBy Mode widget renders properly on supported devices.

---

### Phase 39: Siri Shortcuts & App Intents
**Depends on:** Phase 31
**Deliverable:** "Hey Siri, start my focus session"

- `StartFocusSessionIntent: AppIntent` with mode and duration parameters
- `AppShortcutsProvider` with phrases: "Start a focus session in BioNaural", "Begin BioNaural session"
- `SetFocusFilterIntent` — BioNaural appears in iOS Focus mode settings
- Spotlight donations for recent sessions
- **Acceptance:** Siri voice command starts a session. Intent appears in Shortcuts app. BioNaural appears in Focus settings.

---

### Phase 40: Now Playing & Remote Commands
**Depends on:** Phase 9
**Deliverable:** Lock screen and Control Center show session info

- `MPNowPlayingInfoCenter`: title (mode name), artist ("BioNaural"), duration, elapsed, artwork (Orb image)
- `MPRemoteCommandCenter`: play, pause, stop handlers. Disable next/previous/skip.
- Update elapsed time on state changes
- **Acceptance:** Lock screen shows "Focus — BioNaural" with play/pause. Control Center media widget works. AirPods play/pause works.

---

### Phase 41: Watch Complications
**Depends on:** Phase 36
**Deliverable:** BioNaural on the Watch face

- Complication family: `.graphicCircular` (small Orb), `.graphicRectangular` (mode + last session)
- Show: current mode if in session, or last session time ago if idle
- Tap complication → opens BioNaural Watch app
- **Acceptance:** Complication renders on Watch face. Shows correct data. Tap launches app.

---

### Phase 42: Accessibility Pass
**Depends on:** All UI phases
**Deliverable:** Full accessibility compliance

- VoiceOver: every element has `accessibilityLabel` and `accessibilityHint`
- Orb described: "Adaptive audio visualization, currently in [calm/focused/elevated] state"
- Wavelength described: "Biometric signal visualization showing [steady/active/intense] pattern"
- Dynamic Type: all text scales. Session screen stacks vertically at larger sizes.
- Reduce Motion: Orb → static gradient. Wavelength → static horizontal line. All transitions instant.
- High Contrast: text opacity increases, card borders visible, Orb bloom intensifies
- Color blind safe: biometric states communicated through labels, never color alone
- **Acceptance:** Full VoiceOver navigation works. Enable Reduce Motion → no animations. Enable larger text → layout adapts. Enable high contrast → elements more visible.

---

## --- CHECKPOINT CP5: Platform Integration Audit ---
> **STOP. Audit before proceeding.** Verify: Live Activities, Widgets, Shortcuts all use native Apple frameworks (ActivityKit, WidgetKit, AppIntents). No third-party dependencies for platform features. Analytics event taxonomy matches spec. No hardcoded values in widget views or Live Activity layouts. Update Tech-BackgroundAudio.md, Strategy-AppleFeaturing.md if implementation diverged.

---

## RETENTION & DATA (Phases 42B-42J)

### Phase 42B: TelemetryDeck Analytics Integration
**Depends on:** Phase 1
**Deliverable:** Privacy-respecting analytics tracking all key events

- Add TelemetryDeck SDK
- Define event taxonomy: session_started, session_completed, session_abandoned, mode_selected, onboarding_screen_viewed, onboarding_completed, paywall_shown, paywall_converted, thumbs_up, thumbs_down, headphone_type, spatial_audio_test_result
- Track onboarding funnel drop-off per screen
- Track session completion rates by mode
- Track mode preference distribution
- **Acceptance:** Events fire correctly. Dashboard shows funnel, retention, and mode metrics.

---

### Phase 42C: Morning Sleep Report
**Depends on:** Phases 19 (HealthKit), 35 (SwiftData)
**Deliverable:** Post-sleep correlation between BioNaural sessions and Apple Watch sleep data

- On app open (morning detection via time of day + last session was Sleep mode):
  - Pull Apple Watch sleep data from HealthKit (sleepAnalysis with stages)
  - Correlate: time to fall asleep after session ended, total sleep, deep sleep %, sleep efficiency
- Display on home screen as a card: "Last night: 7h 12m. Deep sleep: 1h 18m. You fell asleep 14 min after your session."
- Over time: "On nights with BioNaural, you average 22% more deep sleep."
- **Acceptance:** Morning sleep report shows accurate data. Correlation calculations work across 5+ sessions.

---

### Phase 42D: Circadian Defaults & Mode Suggestions
**Depends on:** Phases 5 (mode selection), 35 (SwiftData)
**Deliverable:** Home screen suggests the right mode at the right time

- Track session start times in SwiftData
- After 5+ sessions: identify time-of-day patterns ("User does Focus at 9 AM, Relaxation at 6 PM")
- Mode selection screen shows suggested mode based on time: "Ready for your evening relaxation?"
- Widget updates to show contextually appropriate mode
- **Acceptance:** After a week of regular use, the home screen suggests the correct mode for the current time of day.

---

### Phase 42E: Session Trend Analytics View
**Depends on:** Phases 35 (SwiftData), 28B (SessionOutcome)
**Deliverable:** Visual trends over time (premium feature)

- Charts (Swift Charts): HR trend across sessions, HRV improvement, session frequency, adaptation patterns
- "Your average Focus HR has dropped 4 BPM over 2 weeks"
- "Relaxation sessions improve your HRV by 18% on average"
- Sound learning progress: "BioNaural has optimized from X sessions of data"
- **Acceptance:** Trend charts render with real data. Insights are accurate. Premium-gated.

---

### Phase 42F: Proactive Insights on Home Screen
**Depends on:** Phases 35, 42E
**Deliverable:** Rule-based insights surface on mode selection screen

- "You've used BioNaural 8 times this month. Here's what we've noticed..."
- "Your HRV improved 15% on days you did morning relaxation sessions"
- "Your Focus sessions are most effective between 9-11 AM"
- Generate from session history using 10-15 simple rules (no ML needed)
- Show as dismissible cards below mode selection
- **Acceptance:** After 2+ weeks of use, relevant insights appear. Insights are accurate and non-obvious.

---

### Phase 42G: Optional Notifications
**Depends on:** Phase 42D (circadian defaults), Phase 45 (Monthly Neural Summary — for the "summary ready" notification)
**Deliverable:** User-initiated session reminders and weekly summaries

- Settings → Notifications → OFF by default
- "Session reminder": user picks a time. One notification: "Ready for your [mode] session?" Deep-link to launch.
- "Weekly summary": Sunday evening. "This week: 5 sessions, 82 minutes. Your HRV trend is improving."
- "Monthly Neural Summary ready": 1st of month.
- UNUserNotificationCenter setup. Request permission ONLY when user enables in Settings.
- **Acceptance:** Notifications fire at set times. Deep-links work. Never sent unless user opted in.

---

### Phase 42H: Sleep Mode — Dark/Red Screen & Auto-Blank
**Depends on:** Phases 6 (session screen), 13 (mode carrier)
**Deliverable:** Sleep mode minimizes blue light emission

- Sleep mode: shift UI colors to red/amber tones (>600nm wavelength)
- Auto-dim screen to minimum brightness when Sleep session starts
- Auto-blank screen after 30 seconds of session playback (audio-only, screen off)
- Tap to wake screen briefly (5 seconds), then auto-blank again
- **Acceptance:** Sleep mode session screen is visibly darker/redder than other modes. Screen blanks automatically. Audio continues.

---

### Phase 42I: "It's Not Working For Me" Graceful UX
**Depends on:** Phases 28B (SessionOutcome), 34 (Science Cards)
**Deliverable:** Honest off-ramp for users who don't perceive binaural beat effects

- Track: sessions with no thumbs-up AND poor biometric outcomes (biometricSuccessScore < 0.3 for 5+ consecutive sessions)
- After session 5 with poor outcomes: show card with suggestions:
  > "Everyone's brain responds differently. Try: a different mode, increasing the Beats slider, longer sessions (20+ min), or re-running the Spatial Audio test."
- After session 10 still poor: show honest acknowledgment:
  > "Binaural beats work for most people, but not everyone — that's normal neuroscience. The melodic and ambient layers are still valuable for creating a focused/calm environment."
- Link to "Individual Differences" science card
- Never blame the user. Never oversell.
- **Acceptance:** Card triggers after 5 poor sessions. Suggestions are actionable. Session 10 card is honest. Users who DO respond well never see these cards.

---

### Phase 42J: Offline Mode Verification
**Depends on:** Phase 31 (Session Integration)
**Deliverable:** App works fully on airplane mode

- Verify: audio synthesis (local), ambient beds (bundled), melodic loops (bundled), session timer, SwiftData persistence — all work offline
- Verify: Watch HR streaming works (Bluetooth, not network-dependent)
- Verify: StoreKit entitlement cached locally (iOS caches for days)
- Verify: no hard network dependencies block session start or completion
- If network unavailable during subscription check: trust cached entitlement
- **Acceptance:** Enable airplane mode. Start and complete a full session with Watch adaptation. Session persists in history. No errors, no crashes, no degraded experience.

---

### Phase 42K: Background User Model (Always-Learning System)
**Depends on:** Phases 19 (HealthKit), 28B (SessionOutcome), 35 (SwiftData), 42B (Analytics)
**Deliverable:** App continuously builds a behavioral model of the user from all available data

- **HealthKit background queries** (periodic, not continuous):
  - Pull last night's sleep data on app launch (hours, stages, deep sleep %)
  - Pull resting HR trend (7-day rolling)
  - Pull HRV trend (7-day rolling)
  - Pull activity summary (steps, active energy, workouts) for the day
- **Session pattern tracking:**
  - When they typically use each mode (time of day, day of week)
  - Average session duration per mode
  - Biometric response curves: how fast their HR drops in Relaxation, how quickly they fall asleep
  - Check-in vs. biometric alignment score (how self-aware is this user?)
- **Cross-signal correlation engine** (rule-based v1, ML v1.5):
  - After workout days → what sounds work best for evening Relaxation?
  - After poor sleep → what Focus parameters produce the best outcomes?
  - On high-HRV mornings → does this user prefer more or less intensity?
  - Check-in mood patterns by day of week and time
- **User Model stored in SwiftData:**
  - `UserModel.swift`: sleep quality trends, activity patterns, response curves, mood patterns, self-awareness score, sound effectiveness history, time-of-day preferences
  - Updated after every session and on app launch (from HealthKit)
  - All on-device. Never leaves the phone.
- **Model feeds:**
  - Pre-session check-in defaults ("You usually feel wired on Monday mornings — correct?")
  - Circadian mode suggestions (Phase 42D)
  - Proactive insights (Phase 42F): "After days with 8000+ steps, your Sleep sessions work 40% faster"
  - Sound selection: the model IS the input to the sound selector alongside real-time biometrics
- **Acceptance:** After 2 weeks of daily use, the UserModel contains: sleep trends, activity patterns, mood patterns, biometric response curves, sound preference weights, and cross-signal correlations. Proactive suggestions reference real patterns. Model persists across app restarts. Model wipes on "Delete My Data."

---

## POLISH & SHIP (Phases 43-48)

### Phase 43: Sound Design Polish (All Three Layers)
**Depends on:** Phases 16, 16B, 16C
**Deliverable:** Three layers mix beautifully across all modes

- Source/license 10 ambient beds (3 per mode + silence) per Sound-Asset-Pipeline.md
- Source/license 30-50 melodic loops per Sound-Asset-Pipeline.md + Tech-MelodicLayer.md
- Process all: trim, filter, normalize, seamless loop, AAC 256kbps
- Volume balance tuning: ambient (0 dB) → melodic (-6 to -3 dB) → binaural (-12 to -6 dB)
- Three-layer mix testing per mode: do the layers complement, not compete?
- 30-minute listening tests per mode: no fatigue, no annoying patterns, no audible loop seams
- LFO and carrier drift parameters tuned by ear
- Melodic crossfade testing: transitions sound natural, no gaps, no volume spikes
- Sound selection rules produce mode-appropriate results (Focus = present, Relaxation = warm, Sleep = near-silence)
- **Acceptance:** Three people listen for 30 minutes each mode. The experience sounds like "ambient music that knows what I need," not clinical tones or random loops.

---

### Phase 44: StoreKit 2 — Paywall & Subscriptions
**Depends on:** Phases 5, 31
**Deliverable:** Free → premium conversion flow

- Configure in App Store Connect: monthly ($5.99), annual ($49.99), lifetime ($149.99)
- Single subscription group
- Introductory offer: 7-day free trial
- Paywall screen: shown after first completed session (soft, dismissible)
- Free tier: Focus + Relaxation, time-based arcs only, 3 sessions/day, 7-day history
- Premium: all 4 modes, biometric adaptation, unlimited, all sounds, offline, analytics
- `Transaction.currentEntitlements` for entitlement checks at launch
- `Transaction.updates` listener for real-time changes
- Family Sharing enabled
- Win-back offers (iOS 18+): configure for lapsed subscribers in App Store Connect
- Promotional offer codes: set up for partnerships, influencers (150K codes/quarter)
- **Acceptance:** Free user hits session limit → sees paywall. Trial starts → full access for 7 days. Payment processes → unlocks premium. Restore purchases works. Win-back configured. Promo codes generated.

---

### Phase 45: Monthly Neural Summary
**Depends on:** Phase 35
**Deliverable:** BioNaural's "Wrapped" — shareable monthly report

- Generate on 1st of each month (or on-demand in history)
- Content: total hours per mode, session count, peak session, adaptation pattern type, biometric trends, time-of-day patterns, one surprising insight
- Visual: 3-4 swipeable cards, dark background, mode color accents, Orb as anchor
- Pre-formatted for sharing: 9:16 (Stories) and 16:9 (Twitter/X)
- Share button → native share sheet
- Available, never prompted
- **Acceptance:** After 1 month of sessions, summary generates with real data. Visual is beautiful. Share produces correctly formatted image.

---

### Phase 46: Privacy, Legal & Compliance
**Depends on:** All above
**Deliverable:** Legally ready for App Store

- Privacy Policy (from Legal-Regulatory.md): HealthKit disclosure, data collection itemized, GDPR/CCPA compliance
- Terms of Service: medical disclaimer, epilepsy warning, limitation of liability, subscription terms
- App Privacy nutrition labels in App Store Connect: declare all data types
- `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` with clear language
- In-app links to both documents (Settings)
- Pre-launch legal checklist:
  - Freedom-to-operate (FTO) patent search ($3-8K) — verify no conflict with Brain.fm patents
  - Trademark search for "BioNaural" ($500-1500)
  - FDA regulatory consult (1-2 hours, $500-1500)
  - Attorney review of privacy policy + ToS ($2-5K)
- **Acceptance:** Privacy policy covers all required disclosures. ToS includes medical disclaimer. Nutrition labels accurate. Review notes for Apple explain HealthKit usage. FTO search completed. Trademark clear.

---

### Phase 47: TestFlight Beta
**Depends on:** All above
**Deliverable:** Validated by real users

- Recruit 50-100 beta testers (r/productivity, r/biohacking, r/AppleWatch, personal network)
- 50% Apple Watch owners, 50% iPhone-only
- 2-week beta period
- Collect: audio quality ratings, adaptation perception, Spatial Audio flow, session completion rates, bugs
- Post-week-1 feedback form (from Testing-Strategy.md)
- Fix critical + high bugs
- Verify: AirPods Spatial Audio test tone works for real users
- **Acceptance:** No critical bugs. Audio quality rated 4+ by 80% of testers. 70%+ of Watch users report perceiving adaptation. Spatial Audio flow prevents confusion.

---

## --- CHECKPOINT CP6: Pre-Submission Full Audit ---
> **STOP. FULL CODEBASE AUDIT before submitting to App Store.** This is the final gate.
> - Grep entire codebase for hardcoded hex values, raw pixel values, raw duration values — ZERO allowed
> - Verify every view uses native SwiftUI navigation — ZERO custom nav
> - Search for "workaround", "hack", "patch", "TODO", "FIXME" — ZERO allowed in shipping code
> - Verify ALL docs match shipped code. CLAUDE.md is authoritative. Update any doc that drifted.
> - Run full accessibility audit (VoiceOver, Dynamic Type, Reduce Motion, High Contrast)
> - Run 2-hour continuous session stability test (no audio drift, no memory leak, no crash)
> - Verify offline mode works (airplane mode, full session, data persists)
> - **If ANY check fails: fix before submitting. No exceptions. No "we'll patch it after launch."**

---

### Phase 48: App Store Submission
**Depends on:** All above + CP6 PASS
**Deliverable:** App approved and live

- App Store listing from AppStore-ASO.md: title, subtitle, keywords, description
- 6-8 screenshots (Apple Watch hero, Live Activity, session screen, modes, science, history)
- 30-second app preview video with actual binaural beat audio
- Category: Health & Fitness (primary), Productivity (secondary)
- Pricing: free with in-app purchases
- Submit to Apple Review
- Submit editorial pitch to developer.apple.com/contact/app-store/promote/
- **Acceptance:** App approved. Live on the App Store. Editorial pitch submitted.

---

## POST-LAUNCH PHASES (Future)

| Phase | Version | Feature |
|-------|---------|---------|
| 49 | v1.1 | Co-Focus Rooms via **SharePlay** (growth loop / referral mechanic — native to FaceTime + Messages) |
| 50 | v1.1 | Standard BLE Heart Rate (0x180D) via CoreBluetooth |
| 51 | v1.1 | Polar BLE SDK integration (real-time HR + RR intervals) |
| 52 | v1.1 | Additional ambient beds (2 more per mode) + 20 more melodic loops |
| 53 | v1.1 | Expanded sound preference onboarding (instrument previews, energy slider) |
| 54 | v1.5 | **ML sound curation** — contextual bandit on Core ML learns which sounds → best biometric outcomes per user |
| 55 | v1.5 | Core ML per-user beat frequency personalization (Bayesian optimization) |
| 56 | v1.5 | Core ML sleep onset prediction |
| 57 | v1.5 | Oura Cloud API integration (readiness scores, detailed sleep) |
| 58 | v1.5 | Couples/Partner relaxation mode |
| 59 | v1.5 | **Demucs stem separation pipeline** — offline tool to separate licensed ambient tracks into stems (pads, texture, bass, rhythm). Produces bundled demo stem packs for StemAudioLayer testing. |
| 60 | v1.5 | **Bundled stem packs** — 2-3 hand-curated stem packs per mode, installed with app bundle. StemAudioLayer + BiometricStemMixer fully functional without server. |
| 61 | v2.0 | **ACE-Step 1.5 server pipeline** — server-side generation (ACE-Step) + separation (Demucs) + normalization + packaging. AIContentService hits live endpoints. |
| 62 | v2.0 | **Per-user personalized stem generation** — SonicProfilePromptBuilder converts SoundProfile into ACE-Step prompts. Server generates personalized ambient libraries. ContentPackManager downloads and caches. |
| 63 | v2.0 | **Content pack auto-refresh** — weekly check for new personalized content based on updated SoundProfile. "Your new personalized soundscapes are ready" notification. |
| 64 | v2.0 | **Generative MIDI melodies** — rule-based composition through sampled instruments (infinite variety, small file size) |
| 65 | v2.0 | LLM coaching (aggregated summaries to Claude, opt-in) |
| 66 | v2.0 | iPad app with expanded visualizations |
| 67 | v2.0 | Mac app for desktop focus |
| 68 | v2.0 | International localization (Japanese, German, Korean) |
| 69 | v2.0+ | Cross-user collaborative filtering (population-level sound recommendations, opt-in anonymous data) |
| 70 | v2.5 | **Biometric outcome-refined generation** — session outcome data feeds back into prompt refinement. ACE-Step generates better content based on what produces best HR/HRV outcomes per user. Closed loop on content itself. |
| 66 | v1.1 | **Sign in with Apple** — required for CloudKit sync and cross-device data |
| 67 | v1.1 | **CloudKit sync** — session history, user profile, sound preferences across devices |
| 68 | v1.1 | **Isochronic tones for Focus/Energize** — amplitude-modulated single tone at target frequency. Stronger cortical entrainment at beta/gamma (>13 Hz). No headphones required (speaker mode). Accessibility benefit for deaf/HoH users. Same `AVAudioSourceNode` render callback with branching on `entrainmentMethod`. |
| 69 | v1.1 | **Entrainment method selection UI** — user preference toggle (binaural vs isochronic) per mode. Smart defaults: isochronic for Focus/Energize, binaural for Relaxation/Sleep. |
| 70 | v1.5 | **ML entrainment optimization** — contextual bandit learns optimal entrainment method per user/mode/context from `SessionOutcome.entrainmentMethod` + biometric outcomes. |

**Conscious Deferrals (v1 does NOT include):**
- Sign in with Apple / CloudKit sync — not needed for single-device v1. Add in v1.1 when cross-device becomes valuable.
- Isochronic tones — research supports them strongly for Focus/Energize (beta/gamma), but binaural beats are the v1 foundation. Isochronic is the highest-priority v1.1 audio feature. See Science-IsochronicTones.md for full research.
- These are documented in Concept.md tech stack but intentionally deferred to avoid scope creep at launch.
