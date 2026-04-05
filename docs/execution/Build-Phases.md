# BioNaural — Build Phases & Development Roadmap

> What gets built first, dependencies, and what constitutes a shippable product at each phase.

---

## Phase 0: Foundation (Week 1-2)

**Goal:** Project skeleton that compiles and runs.

| Task | Depends On | Acceptance Criteria |
|------|-----------|-------------------|
| Xcode project with iPhone + Watch + Widget targets | — | All targets compile |
| BioNauralShared Swift Package (shared models, FocusMode enum) | — | Package resolves in all targets |
| Theme system (colors, spacing, typography, animation tokens) | DesignLanguage.md | All tokens from design doc as Swift constants |
| Satoshi font bundled and loading | Theme system | Custom font renders at all Dynamic Type sizes |
| Navigation shell (NavigationStack + mode selection → session → summary) | Theme system | Can navigate full happy path with placeholder views |
| AVAudioSession configuration (.playback, background mode) | — | Audio plays in background, survives lock screen |

**No audio engine, no Watch, no HealthKit yet.** Just the skeleton.

---

## Phase 1: Audio Engine MVP (Week 3-5)

**Goal:** Binaural beats play through headphones and sound good.

| Task | Depends On | Acceptance Criteria |
|------|-----------|-------------------|
| AVAudioSourceNode with stereo binaural beat generation | Phase 0 | Two different frequencies, one per channel. Verified with frequency analyzer. |
| Phase accumulators (Double precision) | Audio node | Stable frequency over 2+ hour continuous playback |
| Atomic parameter passing (swift-atomics) | Audio node | Frequency/amplitude changes from main thread with zero clicks |
| Per-sample exponential smoothing (5ms amplitude, 20ms frequency) | Atomics | Smooth transitions, no audible artifacts on parameter change |
| Mode-dependent carrier frequencies (Focus: 300-450, Relaxation: 150-250, Sleep: 100-200) | Smoothing | Each mode sounds distinct |
| Ambient audio layer (AVAudioPlayerNode with bundled beds) | Audio node | Nature sounds play alongside binaural beats, crossfade on mode change |
| Harmonic layering on carrier (triangle wave shape) | Audio node | Warmer than pure sine, not fatiguing over 30 min |
| Reverb (AVAudioUnitReverb, subtle hall, parallel send) | Audio node | Spatial depth without smearing the beat |
| Headphone detection + Spatial Audio warning | AVAudioSession | Detects AirPods, warns about Spatial Audio, test tone flow |
| Session timer with arc (meet → ramp → sustain → return → close) | Audio engine | Focus and Relaxation arcs work. Sleep ramp works. |

**Ship blocker:** The audio must sound good enough for a 30-minute session. If the sound is fatiguing or clinical, nothing else matters.

**Extensibility note:** Audio engine architecture must support future entrainment methods (isochronic tones, monaural beats) without refactoring the render callback. The `AVAudioSourceNode` should branch on an entrainment method parameter, not be hardcoded to binaural-only.

---

## Phase 2: Biometric Pipeline (Week 6-8)

**Goal:** Apple Watch streams HR to iPhone, adaptive engine responds.

| Task | Depends On | Acceptance Criteria |
|------|-----------|-------------------|
| watchOS app with HKWorkoutSession (.mindAndBody) | Phase 0 Watch target | Watch starts workout, green LED stays on, HR at ~1 Hz |
| HKAnchoredObjectQuery for individual HR samples | Watch workout | Each HR sample arrives with timestamp |
| WCSession.sendMessage streaming Watch → iPhone | Watch samples | HR arrives on iPhone within 200ms, 1 Hz steady |
| BiometricProcessor (actor) with dual-EMA smoothing | iPhone WCSession | HR_fast and HR_slow compute correctly from stream |
| Trend detection (HR_fast - HR_slow) | BiometricProcessor | Rising/falling/stable correctly identified |
| State classification with hysteresis + dwell time | Trend detection | Calm/Focused/Elevated/Peak states, no rapid toggling |
| Sigmoid mapping: HR → beat frequency (mode-dependent) | State classification | Focus: HR up → freq down. Relaxation: gentle downward bias. |
| Slew rate limiting (0.3 Hz/sec max) | Mapping | Audio parameter changes are imperceptible in the moment |
| Signal quality scoring (Core ML v1) | BiometricProcessor | Noisy samples reduce adaptation strength |
| Disconnect handling (buffer on Watch, graceful degradation on iPhone) | WCSession | Audio holds steady on disconnect, drifts to neutral over 60s |
| HealthKit authorization flow | HealthKitService | Request permissions, handle denial gracefully, app works without |
| RMSSD approximation from 1 Hz BPM | BiometricProcessor | Directional HRV trend for Relaxation mode (acknowledge: approximate) |

**Ship blocker:** The adaptation must be perceptible but smooth. The user should feel their session responding to their body within the first 5 minutes.

---

## Phase 3: UI & Experience (Week 9-11)

**Goal:** The app looks and feels like the design language doc.

| Task | Depends On | Acceptance Criteria |
|------|-----------|-------------------|
| The Orb (Metal shader or SwiftUI Canvas, biometric-reactive) | Phase 2 biometrics | Orb breathes, changes color/size with biometric state |
| The Wavelength (smooth sine wave, edge-to-edge, biometric-driven) | Phase 2 biometrics | Frequency/amplitude respond to HR. Scrolls continuously. |
| Session screen (Void + Orb + Wavelength + timer + hidden data) | Orb + Wavelength | Tap to reveal HR/HRV for 3 seconds. Full void otherwise. |
| Mode selection screen (3 cards with mode colors) | Theme system | One tap → session starts immediately |
| Post-session summary (duration, HR, HRV, adaptation count, wavelength timeline) | Session data | Clean, data-forward, no congratulations |
| Watch session view (HR, timer, simplified Orb, Always On Display) | Phase 2 Watch | Watch shows useful info during session, dims properly |
| In-app science cards (contextual + dedicated section) | InApp-Science.md | 8 contextual cards + 6 dedicated section cards |
| Onboarding flow (permissions, headphone check, Spatial Audio test tone, epilepsy disclaimer) | Onboarding-Flow.md | Full first-run experience works, handles all edge cases |
| Settings screen (mode defaults, sound preferences, connected devices) | — | Clean, minimal |

---

## Phase 4: Platform Integration (Week 12-13)

**Goal:** Full Apple ecosystem integration for featuring potential.

| Task | Depends On | Acceptance Criteria |
|------|-----------|-------------------|
| Live Activity / Dynamic Island (session timer, HR, mode) | Phase 3 UI | Shows during background playback, updates every 5s |
| WidgetKit widgets (small: quick-start, medium: mode selection + last session) | Phase 3 UI | Tap to launch session |
| Siri Shortcuts / App Intents ("Start focus session") | Session logic | Works from Shortcuts app and Siri voice |
| Focus Filters (SetFocusFilterIntent) | App Intents | BioNaural appears in iOS Focus settings |
| MPNowPlayingInfoCenter + MPRemoteCommandCenter | Audio engine | Lock screen shows session info, play/pause works |
| Watch complications | Watch app | Shows next session or current streak |
| HealthKit write (mindfulness minutes + State of Mind) | Session completion | Sessions log to Apple Health |
| Accessibility pass (VoiceOver, Dynamic Type, Reduce Motion, high contrast) | All UI | Full VoiceOver navigation, Orb described, Reduce Motion fallback |

---

## Phase 5: Polish & Ship (Week 14-16)

| Task | Depends On | Acceptance Criteria |
|------|-----------|-------------------|
| Sound design polish (final ambient beds, crossfade tuning, volume balance) | Audio engine | 30-minute sessions feel like ambient music, not medical equipment |
| Spatial Audio test tone flow (mandatory first session) | Onboarding | AirPods users confirm binaural effect before first real session |
| StoreKit 2 paywall (after first session, 7-day trial) | Monetization.md | Free → premium conversion flow works |
| Privacy policy + Terms of Service | Legal-Regulatory.md | Linked in app and App Store Connect |
| Epilepsy disclaimer in onboarding | Legal-Regulatory.md | Requires acknowledgment before first session |
| App Store listing (screenshots, preview video, description, keywords) | AppStore-ASO.md | All assets ready |
| TestFlight beta (50-100 users, 2 weeks) | All above | Collect feedback on audio quality, adaptation feel, UX friction |
| Bug fixes from beta | TestFlight | Critical and high issues resolved |
| App Store submission | All above | Approved and live |

---

## MVP Definition (Minimum Shippable Product)

**Phases 0-3 = MVP.** The app plays adaptive binaural beats that respond to Apple Watch HR in real time, with the Orb + Wavelength visual, four modes (Focus, Relaxation, Sleep, Energize), and a complete session flow.

**Phase 4 adds featuring potential.** Live Activities, Widgets, Shortcuts, and Accessibility are what get you Apple editorial consideration.

**Phase 5 is polish and ship.** Sound design, paywall, legal, App Store assets.

---

## Dependencies Map

```
Phase 0 (skeleton)
    ↓
Phase 1 (audio engine) ←── can demo without biometrics
    ↓
Phase 2 (biometric pipeline) ←── can demo without UI polish
    ↓
Phase 3 (UI & experience) ←── MVP complete here
    ↓
Phase 4 (platform integration) ←── featuring readiness
    ↓
Phase 5 (polish & ship) ←── App Store submission
```

**Critical path:** Audio engine → Biometric pipeline → Adaptive algorithm integration. Everything else can be parallelized around this spine.

---

## Post-Launch Roadmap

| Version | Timing | Features |
|---------|--------|----------|
| v1.0 | Launch | Focus + Relaxation + Sleep + Energize, Watch HR adaptation, Orb + Wavelength, adaptation map sharing, Monthly Neural Summary |
| v1.1 | +1 month | **Isochronic tones for Focus/Energize modes** (beta/gamma — stronger cortical entrainment, no headphones required), Co-Focus Rooms (growth loop), Polar BLE SDK, BLE HR (0x180D), additional ambient beds |
| v1.5 | +3-6 months | Core ML personalization (including per-user entrainment method optimization), sleep onset prediction, Oura API, couples/partner mode |
| v2.0 | +12 months | LLM coaching (opt-in), iPad/Mac, international localization |
