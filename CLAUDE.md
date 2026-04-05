# CLAUDE.md — BioNaural

## CRITICAL DEVELOPMENT RULES (NON-NEGOTIABLE)

1. **Use native iOS navigation and UI elements ALWAYS.** UINavigationController, NavigationStack, TabView, native sheets, alerts, and pickers. No custom navigation frameworks. No third-party navigation libraries. Native or nothing.

2. **Hard coding is STRICTLY PROHIBITED.** All values — colors, spacing, fonts, durations, frequencies, thresholds — must come from the Theme/design token system or configuration. If a value appears as a magic number in code, it's wrong.

3. **Use existing tokens whenever possible.** Before creating a new constant, check the Theme system (colors, spacing, typography, animation, opacity, radius). The design language doc defines the token system. Reuse before creating.

4. **No patching.** If something is broken, find and fix the root cause. Do not add workarounds, hacks, shims, or duct tape. If a fix feels like a patch, stop and rethink the approach.

5. **Never assume. Research if not 100% clear.** If you're unsure about an API, behavior, or design decision, look it up. Read the docs. Check the research files in this folder. Ask the user. Guessing leads to rework. Certainty leads to shipping.

6. **Gather context before building.** Before writing any new view or component, scan the existing codebase to identify the highest-quality design components and patterns already in use. Study how existing screens render cards, sections, navigation, animations, and glass treatments. Build new UI to match the established quality bar — never introduce a pattern that looks worse than what already exists.

7. **Prioritize existing tokens over creating new ones.** Before adding a new Theme constant, exhaustively check Theme.Colors, Theme.Spacing, Theme.Typography, Theme.Radius, Theme.Opacity, Theme.Animation, and all sub-enums (Theme.Compose, Theme.CardWave, Theme.Particles, Theme.Nebula, etc.). Only create a new token when no existing one serves the purpose. Duplicate or near-duplicate tokens are tech debt.

8. **All research produces a document.** When researching an API, framework, design pattern, competitor, or technical approach, ALWAYS create a markdown doc in the project folder capturing the findings. No research lives only in conversation — it must be persisted as a reference doc for the team. Name it clearly (e.g., `Tech-FoundationModels.md`, `Science-IsochronicTones.md`, `Strategy-Growth.md`).

9. **Audit checkpoints are mandatory gates.** The build plan has 6 checkpoints (CP1-CP6) at section boundaries. Each checkpoint audits for: hardcoded values, non-native UI, patching, and doc drift. **You cannot proceed past a checkpoint until it passes.** See Build-Plan-Detailed.md for the full checkpoint schedule and audit criteria.

10. **Update docs as you go.** When implementation diverges from a spec doc, update the doc immediately — not "later." At each checkpoint, verify all relevant docs match the code. CLAUDE.md is the single source of truth. If CLAUDE.md and a spec doc disagree, CLAUDE.md wins.

---

## MANDATORY: Token-First Build Protocol

**You MUST complete steps 1-3 before writing ANY SwiftUI view or component code. Skipping ahead to code is a rule violation. No exceptions.**

### Step 1 — Scan tokens
Read the token/theme files and list what's currently available:
- Read `Design/Theme.swift` → list all enums: Colors, Spacing, Typography, Radius, Opacity, Animation, and any sub-enums (Compose, CardWave, Particles, Nebula, etc.)
- If you haven't read Theme.swift in this conversation, read it now. Do not work from memory.

### Step 2 — Create a token map
Before writing a single line of view code, produce a token map as a fenced code block:

```
Token Map for [ViewName]:
- Background: Theme.Colors.surfacePrimary
- Title font: Theme.Typography.headline
- Card padding: Theme.Spacing.md (16)
- Corner radius: Theme.Radius.lg (16)
- Accent: Theme.Colors.periwinkle
- Animation: Theme.Animation.smooth
... (every value the view will use)
```

Every visual value in the view must appear in this map. If it's not in the map, it can't be in the code.

### Step 3 — Identify gaps
If a value you need has NO existing token:
- Say so explicitly: "No token exists for X. I need to create Theme.Y.Z = value."
- Wait for approval OR create the token in Theme.swift FIRST, before using it in view code.
- Never use a raw value as a placeholder "until the token is created." The token comes first.

### Step 4 — Write code
Now write the view. Every value must trace back to your token map from Step 2.

### Step 5 — Self-audit
After writing, search your own output for violations:
- Any raw number in `.frame()`, `.padding()`, `.font(.system(size:))`, or `.cornerRadius()`
- Any `Color(` literal, hex string, or `.opacity(0.X)` not from Theme
- Any string not wrapped in `String(localized:)` (if user-facing)
- Any duration, frequency, or threshold as a magic number

If you find ANY, fix them before presenting the code. Do not present code that fails self-audit.

---

## What Is BioNaural?

An always-learning iOS app that generates adaptive binaural beats layered with AI-curated melodic content, driven by real-time biometrics and a continuously improving user model. The app learns from everything — sleep patterns, movement, mood check-ins, biometric responses, and session outcomes — to deliver increasingly personalized audio experiences.

**Four modes:** Focus, Relaxation, Sleep, Energize.
**Two session modes:** Manual (time-based arcs + check-in) and Adaptive (biometric-driven + check-in).
**Three audio layers:** Entrainment (science — binaural beats v1, isochronic tones v1.1+), Ambient (texture), Melodic (the experience).
**Always learning:** Every session, every check-in, every biometric reading makes the next session smarter.

The adaptive audio engine reads heart rate and HRV, maps them to audio parameters (beat frequency, carrier, amplitude, ambient mix) through a deterministic control system (EMA smoothing, sigmoid mapping, slew rate limiting), and delivers the sound through AVAudioEngine.

**The product is the feedback loop.** Auditory brainwave entrainment (binaural beats + isochronic tones) is the mechanism. The biometric adaptation is the differentiator. No competitor does both well. See Science-IsochronicTones.md for the full isochronic research and integration plan.

---

## Tech Stack

- **Platform:** iOS 17+ / watchOS 10+ (Swift, SwiftUI)
- **Architecture:** MVVM + @Observable. Protocol-based services. DI via SwiftUI Environment.
- **Audio:** AVAudioEngine + AVAudioSourceNode. Real-time synthesis via phase accumulators. Lock-free atomic parameter passing (swift-atomics).
- **Biometrics:** HealthKit (read + write). HKWorkoutSession on Watch for real-time HR. WatchConnectivity for Watch→iPhone streaming.
- **Persistence:** SwiftData for sessions and user profile. HealthKit for health data (never duplicate).
- **Design:** Dark-first. Satoshi font + SF Mono. Periwinkle accent (#6E7CF7). 8pt grid. The Orb + Wavelength as session visuals.
- **Shared code:** Local Swift Package (BioNauralShared) across iPhone, Watch, Widget targets.

---

## Project Structure

```
BioNaural/
├── App/                    # AppState, Dependencies (DI), Navigation
├── Features/               # Organized by screen (Session/, ModeSelection/, History/, etc.)
├── Design/                 # Theme tokens, animation constants, reusable components
├── Audio/                  # NO SwiftUI imports. AudioEngine, BinauralBeatNode, AmbienceLayer
├── Biometrics/             # NO SwiftUI imports. BiometricProcessor, AdaptationEngine, Analyzers
├── Services/               # HealthKit, WatchConnectivity, Persistence, Haptics (all protocol-based)
├── Models/                 # SwiftData @Model (FocusSession, UserProfile, FocusMode)
├── Utilities/              # Extensions, Constants, Logger
BioNauralWatch/             # watchOS target
BioNauralWidgets/           # Widget + Live Activity extension
BioNauralShared/            # Local Swift Package (shared models, types, frequency math)
```

**Rules:**
- `Audio/` and `Biometrics/` never import SwiftUI
- Features organized by screen, not file type
- Protocol-based services with mock implementations for testing

---

## Three Concurrency Domains

| Domain | Technology | Rules |
|--------|-----------|-------|
| Audio render thread | C callback, raw pointers, atomics | No locks, no malloc, no ARC, no async/await |
| Biometric processing | Swift actor | Can allocate, lock, await. Writes to audio via atomics. |
| UI | @MainActor, @Observable | SwiftUI reads from ViewModel |

The bridge between Swift and the audio thread is `AudioParameters` — lock-free atomics from swift-atomics. The BiometricProcessor writes. The render callback reads. No locks cross this boundary.

---

## Adaptive Algorithm Summary

1. Watch sends HR at ~1 Hz via WCSession.sendMessage
2. BiometricProcessor applies dual-EMA smoothing (fast α=0.4, slow α=0.1)
3. Trend detection: HR_fast - HR_slow (MACD-style)
4. State classification with hysteresis + 5s dwell time (Calm/Focused/Elevated/Peak)
5. Mode-dependent sigmoid mapping: HR_normalized → beat frequency
   - Focus: negative feedback (HR up → frequency down to calm)
   - Relaxation: gentle downward bias toward alpha (8-11 Hz)
   - Sleep: continuous theta→delta ramp (6→2 Hz over 25 min)
   - Energize: upward bias toward high-beta/low-gamma (18-30 Hz), reinforces arousal
6. Slew rate limiting: max 0.3 Hz/sec beat change (imperceptible transitions)
7. Proportional + feedforward control (Kp=0.1, Kff=0.5)

---

## Two Session Modes

| Mode | Input Source | Who Uses It | Experience |
|------|------------|-------------|-----------|
| **Manual** | Pre-session check-in (mood/stress/goal) + time-based arc + user preferences | Free tier users, no-Watch users, users who prefer manual control | First-class experience — NOT a fallback. Time-based arcs + melodic evolution + check-in personalization. |
| **Adaptive** | Real-time biometrics (Watch/BLE HR) + check-in + learned preferences | Premium users with HR sensor | Everything in Manual PLUS biometric-driven real-time adaptation. |

**Pre-session check-in (both modes):** 2-tap flow before every session: (1) "How are you feeling?" [Wired→Calm scale], (2) "What are you trying to do?" [Focus/Unwind/Sleep]. Sets starting parameters and initial melodic selection. Skippable after 5+ similar sessions ("Use your usual settings?"). In Adaptive mode, biometrics override the check-in once the session starts.

---

## Audio Engine — Three Layers

| Layer | What | Source | Volume |
|-------|------|--------|--------|
| **Entrainment** | Hz frequency (binaural beats v1; isochronic tones v1.1+ for Focus/Energize) | Real-time synthesis (AVAudioSourceNode) | -12 to -6 dB binaural; -14 to -10 dB isochronic (must be more audible) |
| **Ambient** | Texture (rain, noise, wind) | Bundled files (AVAudioPlayerNode) | 0 dB (loudest) |
| **Melodic** | Musical content (pads, piano, strings) | Curated from tagged sound library | -6 to -3 dB |

- Entrainment: phase accumulators (Double precision), mode-dependent carrier (Focus 300-450, Relaxation 150-250, Sleep 100-200, Energize 350-500 Hz). v1 = binaural beats only. v1.1+ adds isochronic tones (amplitude-modulated single tone) for Focus/Energize modes where higher frequencies (beta/gamma) favor stronger cortical response. The adaptive engine selects the optimal method per mode, frequency target, and user preference.
- Melodic: AI-curated from tagged library based on biometrics + user preferences + learned outcomes. Changes at most every 3-5 min with 10-15s crossfades.
- Three user sliders: Ambient, Melodic, Beats
- Per-sample exponential smoothing on all binaural parameters (5ms amplitude, 20ms frequency)
- Spatial Audio MUST be disabled: `outputNode.spatializationEnabled = false`
- Background audio: `.playback` category, `UIBackgroundModes: audio`

## Feedback & Learning Loop

Three learning signals per session:
1. **Pre-session check-in** — mood/stress self-report (subjective state + intent)
2. **Biometric outcomes** — HR delta, HRV delta, time to calm/sleep, session completion (objective)
3. **Post-session thumbs** — did they like it? (preference)

The system also learns from **background data between sessions:**
- HealthKit: sleep quality, resting HR trends, HRV trends, activity/movement patterns
- CoreMotion: daily movement rhythm, sedentary vs. active patterns
- AirPods: head stillness trends during sessions (focus practice improvement)
- Check-in history: mood patterns by day of week, time of day

**This builds a full behavioral model** — the app learns how this user's mood and metrics change with movement, sleep, time of day, and session history. After 50 sessions, it knows both what the user SAYS they need and what their body ACTUALLY needs — and when those differ.

- v1: rule-based weight updates + full data logging (training data for v1.5)
- v1.5: ML contextual bandit on Core ML learns optimal sound selections + beat frequencies per user
- Every interaction makes the model smarter. **This is the moat.**

---

## Key Design Decisions

- **Apple Watch standalone: YES.** Full sessions run on Watch without iPhone — audio to AirPods, adaptive algorithm on-Watch, data syncs later. Massive Apple featuring angle.
- **Pomodoro timer: YES.** Focus mode supports optional 25/5 Pomodoro cycles with auto-mode-switching between Focus and Relaxation.
- **SharePlay for Co-Focus Rooms: YES.** v1.1 — native to FaceTime + Messages. The invitation IS the referral.
- **CarPlay: NO.** Explicitly blocked. Binaural beats + driving = drowsiness risk = liability.
- **Offline: Full support.** Architecture is on-device-first. All audio, adaptation, persistence work without network.
- **"Doesn't work for me" UX: YES.** Honest off-ramp after 5-10 poor sessions. Suggestions, then acknowledgment. Never blame the user.
- **Battery warning: YES.** Warn if Watch < 20% before long sessions.
- **Data export: YES.** GDPR-compliant JSON export + delete-my-data option in Settings.

---

## Apple Featuring Strategy

**Lead with Apple ecosystem. Always.**

- Apple Watch app is the hero in screenshots and description
- HealthKit is the universal adapter (silently supports Oura, WHOOP, Garmin, etc.)
- Never put competitor wearable logos in App Store screenshots
- Adopt every Apple platform feature: Live Activities, Widgets, Shortcuts, Focus Filters, Accessibility
- Target May (Mental Health Awareness Month) for editorial pitch
- Adopt new WWDC APIs immediately for fall launch featuring

---

## Wearable Hierarchy

**Real-time biometric sources (for live adaptation):**

| Priority | Source | Data | Real-Time? |
|----------|--------|------|-----------|
| 1 | Apple Watch | HR (1 Hz), HRV, motion | Yes — primary |
| 2 | Polar BLE SDK | HR, RR intervals (true HRV) | Yes — best non-Watch option |
| 3 | Any BLE HR (0x180D) | HR | Yes — generic chest straps |

**Context sources (for pre-session personalization and fusion):**

| Source | Data | Role |
|--------|------|------|
| HealthKit (universal) | HR, HRV, sleep from any syncing wearable | Silent adapter — supports Oura, WHOOP, Garmin automatically |
| AirPods | Head motion, stillness (10-20 Hz) | Relaxation depth proxy during sessions |
| iPhone | Activity type, motion, camera PPG (one-time) | Baseline context, no-Watch fallback |
| Oura/WHOOP APIs (v2) | Readiness scores, detailed sleep/HRV | Pre-session recommendations |

**Tier system (user experience):**
- Tier 1: Watch + AirPods + iPhone = full biometric + head tracking (100%)
- Tier 2: Watch + iPhone = full biometric, no head tracking (~85%)
- Tier 3: AirPods + iPhone = activity + head stillness, no HR (~50%)
- Tier 4: iPhone only = activity + optional camera PPG (~25%)

---

## Monetization

- $5.99/mo, $49.99/yr, $149.99 lifetime
- Free tier: 2 modes (Focus + Relaxation), 3 sessions/day, time-based adaptation (not biometric)
- Premium: all 4 modes (Focus, Relaxation, Sleep, Energize), biometric adaptation (Watch/Polar/BLE HR), unlimited, analytics, all sounds, offline
- Never interrupt a session with a paywall
- No ads. Ever.

---

## In-App Science

Two layers:
1. **Contextual cards** — mode selection screens, post-session results, duration tooltips. 2-3 sentences, honest, "research suggests" tone.
2. **Dedicated "The Science" section** — 6 cards covering mechanism, brainwave bands, adaptive advantage, individual differences. Lead with "The Honest Truth" (small but real effects, the adaptive engine is where the real science lives).

---

## Legal Guardrails

- Stay within FDA "general wellness" language
- Never name a disease (ADHD, anxiety disorder, insomnia)
- Frame as personalization, not treatment
- Epilepsy disclaimer in onboarding (require acknowledgment)
- On-device processing for all health data
- HealthKit data cannot be used for advertising or sold

---

## ML Strategy

- **v1:** Signal quality scoring (Core ML, ~50KB logistic regression) + rule-based sound selection (melodic layer picks sounds using tags + biometric state + user preferences) + feedback logging (thumbs + biometric outcomes recorded every session). Adaptive weight updates on sound preferences (not ML — exponential weight adjustment from outcomes).
- **v1.5 (3-6 months):** ML contextual bandit on Core ML learns which sounds → best biometric outcomes per user. Per-user beat frequency personalization (Bayesian optimization). Sleep onset prediction (logistic regression). The feedback loop becomes genuinely intelligent.
- **v2+:** Generative MIDI melodies through sampled instruments (rule-based composition, infinite variety). LLM coaching (opt-in, aggregated summaries). Cross-user collaborative filtering.
- Architecture: `ParameterSelector` (entrainment — selects beat frequency, carrier, AND entrainment method) and `SoundSelector` (melodic) are separate protocol-based systems. Both start deterministic at v1, swap to ML at v1.5 without refactoring. At v1.5, the ML contextual bandit optimizes entrainment method (binaural vs isochronic) as an additional parameter per user/context.

---

## Research Library

All docs organized under `docs/`:

```
docs/
├── science/          — 8 docs: Neuroscience, Focus, Exercise, Relaxation, Relaxation-Mode,
│                       Sleep, AdaptiveAudio, IsochronicTones
├── tech/             — 16 docs: AVAudioEngine, AudioEngine, AdaptiveAlgorithm, WatchPipeline,
│                       BackgroundAudio, Architecture, MultiDevice, Wearables, OuraIntegration,
│                       AI, MelodicLayer, FeedbackLoop, MLModels, SoundFontSynthesis,
│                       SpessaSynth, ACEStep
├── strategy/         — 6 docs: AppleFeaturing, Apple-Featuring-Deep-Dive, Growth,
│                       Monetization, AppStore-ASO, Legal-Regulatory
├── product/          — 9 docs: Concept, Validation, DesignLanguage, Focus-Categories,
│                       HealthKit-Research, Decisions-Resolved, KillerFeatures-Brainstorm,
│                       Compose-Tab-Plan, InApp-Science
├── execution/        — 7 docs: Build-Phases, Build-Plan-Detailed (48 phases + 12 post-launch),
│                       Onboarding-Flow, Sound-Asset-Pipeline, Testing-Strategy,
│                       Retention-Engagement, AUDIT_REPORT
├── design/           — 3 docs: AppIcon-Design, Sound-Design-Brief, Apple-HIG-Reference
└── archive/          — Superseded docs
```

Other folders: `mockups/` (HTML prototypes), `assets/icon/` (SVGs), `sounds/`, `src/` (Xcode project).

**Confirmed four modes:** Focus, Relaxation, Sleep, Energize. All docs have been updated to reflect this.

**Read these before building.** They contain specific API names, code patterns, study references, and design decisions that inform every part of the app.
