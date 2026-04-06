# BioNaural — Launch Slam Dunk Plan

> The gap between "code complete" and "category definer." Everything here sits between Phase 43 (sound polish) and Phase 48 (App Store submission) in Build-Plan-Detailed.md. These are the moves that turn a good app into an untouchable one.

---

## Current State (April 2026)

**What's production-ready:**
- Audio engine: binaural synthesis + harmonics + LFO + ambient + melodic layers (3,853 LOC)
- Biometric processor: dual-EMA, state classification, Energize safety with 7 guardrails (1,570 LOC)
- Adaptive algorithm: mode-dependent sigmoid mapping, slew rate limiting, proportional + feedforward control
- All four modes: Focus, Relaxation, Sleep, Energize
- 42 feature views, all native SwiftUI, all using Theme tokens
- Design system: zero hardcoded values (4,454 LOC)
- Session flow: onboarding → mode selection → pre-check-in → session → post-session → history
- Morning Brief: MorningBriefView + MorningBriefGenerator (931 LOC combined)
- SoundDNA, SonicMemory, BodyMusic, ContextTracks — all built
- HealthKit read/write, Calendar integration, Notification service
- 148 Swift files, 57,715 lines of code

**What's missing or incomplete:**
- Watch app source code (not in /src/)
- StoreKit 2 subscription wiring (gates exist, payment doesn't)
- Sound asset quality (needs professional audio content)
- Study Track creation flow (architecture supports it, no dedicated UI)
- Post-session share card export
- Localization (English hardcoded)
- Live Activities

---

## PRIORITY 1: Ship Blockers (Must Complete Before TestFlight)

### 1A. Wire StoreKit 2 Subscriptions
**Phase alignment:** Expands Phase 44
**Timeline:** 2-3 days
**Why it's critical:** No revenue without this. Launch free-only and you lose the highest-conversion window (post-first-session).

**Tasks:**
- [ ] Configure in App Store Connect:
  - Monthly: `com.bionaural.app.pro.monthly` — $5.99/mo
  - Annual: `com.bionaural.app.pro.annual` — $49.99/yr
  - Lifetime: `com.bionaural.app.pro.lifetime` — $149.99
- [ ] Single subscription group "BioNaural Premium"
- [ ] Introductory offer: 7-day free trial on monthly and annual
- [ ] Wire `SubscriptionManager.swift`:
  - `Transaction.currentEntitlements` at app launch
  - `Transaction.updates` async listener for real-time status changes
  - `Product.products(for:)` to load pricing dynamically
- [ ] Connect `PremiumGate` modifier to live entitlement status (currently stubbed)
- [ ] Wire `PaywallView` to actual purchase flow:
  - Show pricing pulled from StoreKit (not hardcoded)
  - Handle purchase, restore, error states
  - Dismiss on successful purchase with confirmation haptic
- [ ] Paywall trigger: after first completed session (soft, always dismissible)
- [ ] Free tier enforcement:
  - Focus + Relaxation only (Sleep/Energize locked)
  - Time-based arcs only (no biometric adaptation)
  - 3 sessions per day
  - 7 days of session history
- [ ] Enable Family Sharing
- [ ] Configure win-back offers (iOS 18+)
- [ ] Generate 100 promotional offer codes for beta/influencer distribution
- [ ] Sandbox testing: full purchase → restore → cancel → re-subscribe cycle

**Acceptance:** Free user completes session → paywall appears → trial starts → full access 7 days → payment processes → premium unlocked. Restore works. Family Sharing works.

---

### 1B. Build the Apple Watch Companion App
**Phase alignment:** Expands Phase 36B (Watch app)
**Timeline:** 1-2 weeks
**Why it's critical:** The Watch app is the entire pitch. Without real-time HR streaming, the adaptive engine runs on nothing. This is BioNaural's #1 differentiator and #1 Apple featuring angle.

**Minimum viable Watch app:**
- [ ] Create watchOS target in Xcode (BioNauralWatch)
- [ ] Import BioNauralShared package for shared types
- [ ] `HKWorkoutSession` for continuous ~1 Hz HR sampling
  - Workout type: `.other` (not running/cycling)
  - Location type: `.unknown`
  - Request HealthKit authorization on Watch
- [ ] `HKAnchoredObjectQuery` for individual `HKQuantitySample` objects
- [ ] `WCSession.sendMessage` to stream HR to iPhone (50-200ms latency)
  - Message format: `["hr": Double, "ts": TimeInterval]`
  - Fallback to `transferUserInfo` on disconnect (queue up to 60s of samples)
- [ ] Circular ring buffer for disconnect buffering (from Tech-WatchPipeline.md)
- [ ] Watch UI (3 screens):
  - **Now Playing:** Current mode icon, session timer, HR value, play/pause/stop
  - **Mode Selection:** Simple list of 4 modes → tap to start on iPhone
  - **Battery Warning:** Alert if Watch < 20% before session start
- [ ] Complication: current session timer (WidgetKit)
- [ ] Background session support: workout session keeps HR streaming when wrist is down
- [ ] Graceful degradation: if WCSession disconnects, iPhone falls back to time-based arc (no crash, no data loss)

**Stretch (v1.1):**
- [ ] Standalone Watch sessions (audio to AirPods, full adaptive engine on-Watch, sync later)
- [ ] Rich complications (HR + mode + timer)

**Acceptance:** Start session on iPhone with Watch paired → HR values appear in BiometricProcessor within 2 seconds → adaptive engine responds → session screen shows live HR → post-session summary includes biometric data. Disconnect mid-session → falls back gracefully → reconnection resumes streaming.

---

### 1C. Professional Sound Assets
**Phase alignment:** Expands Phase 43 (sound design polish)
**Timeline:** 1-2 weeks (parallel with other work)
**Why it's critical:** The first 30 seconds of audio determines whether a user stays or uninstalls. Thin sine waves = dead app. Beautiful layered audio = daily habit.

**Requirements:**
- [ ] Commission or source 40-60 high-quality audio loops:

| Mode | Ambient Beds | Melodic Loops | Total |
|------|-------------|---------------|-------|
| Focus | 4 (library rain, café hum, white noise, forest) | 6 (lo-fi pad, piano minimal, synth pulse, acoustic guitar, Rhodes, ambient drone) | 10 |
| Relaxation | 4 (ocean waves, gentle rain, wind through trees, stream) | 6 (warm pad, harp arpeggios, singing bowls, strings, celeste, nature + music blend) | 10 |
| Sleep | 4 (deep rain, brown noise, distant thunder, night crickets) | 6 (dark drone, soft piano, breath-synced pad, lullaby harp, bass wash, nothing/silence) | 10 |
| Energize | 4 (upbeat electronic texture, bright noise, morning birds, urban pulse) | 6 (driving synth, percussion loop, bright piano, guitar riff, brass pad, electronic build) | 10 |

- [ ] Technical specs per loop:
  - Format: 44.1 kHz, 16-bit, WAV (convert to AAC for bundle)
  - Duration: 60-120 seconds (seamless loop points)
  - Stereo (ambient) / Mono (melodic, to avoid interfering with binaural stereo field)
  - No lyrics, no vocal samples
  - Consistent loudness: -14 LUFS (ambient), -18 LUFS (melodic)
- [ ] Update `sounds.json` with tags per loop: mode affinity, energy (0-1), tempo, key, instrument, brightness, density
- [ ] Test each loop in context: binaural layer + ambient + melodic must sound cohesive
- [ ] Verify seamless looping (no clicks, no gaps)

**Sourcing options (ranked by quality/cost):**
1. **Commission from sound designer** — SoundBetter.com or Fiverr Pro ($500-1,500 for 40 loops)
2. **Royalty-free libraries** — Artlist ($200/yr, unlimited), Epidemic Sound, Splice
3. **Creative Commons** — Freesound.org (free, variable quality, verify licensing per file)
4. **Self-produced** — GarageBand / Logic Pro with stock instruments (free, time-intensive)

**Acceptance:** Launch app → select any mode → audio sounds beautiful within 3 seconds. Non-musician friend listens and says "that sounds really good" without prompting. Audio runs for 30+ minutes without fatigue or annoyance.

---

## PRIORITY 2: Category Definers (Ship Before or With v1.0)

### ~~2A. Study Track Creation Flow~~ → DONE as "Flow State"
**Phase alignment:** Phase 43B — COMPLETE
**Timeline:** Done (April 5, 2026)
**Repositioned:** "Study Track" → "Flow State." Same sonic anchoring science, broader audience. Students still use it for exams — but now a CEO uses it for "Board Meeting Prep" and an athlete uses it for "Race Day."

**How it works:**
1. User taps "Create Study Track" (from Compose tab or Morning Brief suggestion)
2. **Step 1:** Name your goal — free text ("Bar Exam — Constitutional Law")
3. **Step 2:** Pick your base sound — from SonicMemory favorites or browse sound library
4. **Step 3:** Set typical study duration — 30 / 60 / 90 min / custom
5. App creates a `ContextTrack` with locked sonic fingerprint:
   - Same ambient texture every session
   - Same melodic palette every session
   - Same carrier frequency range
   - Biometric adaptation still active (audio responds to body, but sonic *signature* stays constant)
6. Every subsequent study session with this track builds auditory recall anchors
7. On exam day: push notification → "Your Study Track is ready. Your brain knows this sound."

**Implementation:**
- [ ] Create `StudyTrackCreationView.swift` — 3-step sheet (name, sound, duration)
- [ ] Create `StudyTrackViewModel.swift` — manages creation state
- [ ] Extend `ContextTrack` model (already exists) with `isStudyTrack: Bool` and `lockedSoundProfile: SoundProfile`
- [ ] Modify `SoundSelector` to respect locked selections when `activeContextTrack?.isStudyTrack == true`
- [ ] Add "Study Track" quick-start card to ModeSelectionView when an active study track exists
- [ ] Schedule exam-day notification:
  - Read EventKit for events matching the goal name
  - Or let user set a "target date" during creation
  - Notification: "Your [Goal] Study Track is ready. Play it on the way there."
- [ ] Post-session: show consistency metric — "Session 8/12 with this track. Recall anchors strengthening."
- [ ] Study Track library in Compose tab — list of active and archived study tracks

**Acceptance:** Create study track → run 3 sessions with it → audio signature is identical each time (same ambient, melodic, carrier range). Biometric adaptation still works (beat frequency changes with HR). Exam-day notification fires. User can archive/delete completed study tracks.

---

### ~~2B. Morning Brief Notification~~ — DEFERRED

**Status:** Generator is built (`MorningBriefGenerator.swift`, 524 LOC). `MorningBriefView` is built (407 LOC). The notification wiring is ~2 days of work.

**Decision:** Deferred from v1.0 launch. The learning loop, Study Tracks, SoundDNA, and SonicMemory provide sufficient retention without daily push notifications. Early adopters are self-motivated — notification nudges matter more at scale (50K+ users).

**When to reconsider:** If Day 30 retention drops below 8% post-launch, wire the Morning Brief notification as a v1.0.1 update. The code is ready.

---

### 2C. Post-Session Share Card
**Phase alignment:** Expands Phase 45 (Monthly Neural Summary sharing)
**Timeline:** 2 days
**Why it's critical:** Zero-cost marketing. Every share is a product demo.

**Card design:**
```
┌─────────────────────────────────┐
│                                 │
│      [Adaptation Map Visual]    │
│      (hero — fills top half)    │
│                                 │
├─────────────────────────────────┤
│                                 │
│  Focus Session  •  32 min       │
│                                 │
│  HR  72 → 64 bpm    ▼ 8 bpm    │
│  HRV 42 → 58 ms     ▲ 38%     │
│                                 │
│  Beat range: 12-16 Hz (beta)    │
│  Adaptations: 14                │
│                                 │
│              bionaural.app      │
└─────────────────────────────────┘
```

**Implementation:**
- [ ] Create `ShareCardRenderer.swift` — generates UIImage from session data
- [ ] Layout: 1080x1920 (Instagram Stories / TikTok) and 1080x1080 (square / feed)
- [ ] Dark background using `Theme.Colors.canvas`
- [ ] Adaptation Map as hero visual (already rendered by `AdaptationMapView`)
- [ ] Session stats: mode, duration, HR delta, HRV delta, beat frequency range, adaptation count
- [ ] "bionaural.app" watermark bottom-right (subtle, not obtrusive)
- [ ] Add "Share" button to `PostSessionView` → native `UIActivityViewController` with rendered image
- [ ] Include session summary text for platforms that support it:
  - "32-min Focus session. My heart rate dropped 8 bpm while BioNaural adapted my binaural beats in real time."

**Acceptance:** Complete session → tap Share → see beautiful card with real data → share to Instagram/Messages/save to Photos. Card looks professional on dark and light backgrounds. Watermark is visible but not dominant.

---

### 2D. Visible Adaptation Moments
**Phase alignment:** Expands Phase 33 (session screen integration)
**Timeline:** 1 day
**Why it's critical:** Users won't know the audio is adapting unless you show them. One visible moment of intelligence is worth 30 minutes of invisible adaptation.

**Implementation:**
- [ ] Add `AdaptationToast` component to `SessionView`:
  - Triggered when `BiometricProcessor` publishes a state transition (e.g., Elevated → Calm)
  - Shows for 4 seconds, then fades
  - Examples:
    - "Heart rate dropped 6 bpm. Shifting to deeper alpha."
    - "Stress spike detected. Holding at calming frequency."
    - "You've reached your calm zone. Sustaining 10 Hz."
    - "HRV improving. Your body is responding."
  - Maximum 1 toast per 5 minutes (don't spam during active sessions)
  - Respect Reduce Motion: use opacity fade only, no slide animation
- [ ] Add subtle haptic on toast appearance (UIImpactFeedbackGenerator, `.light`)
- [ ] User can disable in Settings → "Show adaptation insights during sessions"
- [ ] Log which toasts users see → correlate with thumbs rating (do visible insights improve satisfaction?)

**Acceptance:** Start Focus session with Watch → HR drops after 5 min → toast appears with HR delta and frequency shift → fades after 4 seconds → no more toasts for at least 5 minutes. Settings toggle works.

---

## PRIORITY 3: Competitive Edge (Ship With v1.0 or v1.0.1)

### 3A. Energize Safety as a Feature
**Phase alignment:** NEW — insert as Phase 43C
**Timeline:** 1 day

The Energize mode has 7 independent safety guardrails (HR hard stop, ceiling, HRV floor/crash, rate-of-change, session time cap, mandatory cool-down, pre-screening). No binaural beat app has ever communicated safety to users.

**Implementation:**
- [ ] Add a brief safety animation to `EnergizeScreeningView`:
  - 3-panel swipeable education:
    1. "BioNaural monitors your heart rate in real time during Energize sessions."
    2. "If anything looks off, we automatically shift to calming frequencies."
    3. "Every Energize session ends with a mandatory cool-down."
  - Show once (first Energize attempt), then accessible from Energize mode info button
- [ ] During Energize session, show a subtle safety indicator:
  - Small shield icon in nav bar that pulses green when HR is in safe range
  - Turns amber with brief vibration if approaching ceiling
  - Turns red with strong haptic if safety override activates
- [ ] Post-session: if any safety event fired, show what happened and why:
  - "Safety activated at 12:34 — your HR hit 142 bpm. We shifted to 8 Hz alpha for recovery."

**Acceptance:** First Energize attempt → see safety education → start session → shield icon visible → if HR spikes → safety activates visibly with explanation. Users feel protected, not restricted.

---

### 3B. Localization: Japanese & Korean
**Phase alignment:** Pulls forward Phase 68 from v2.0 to v1.0
**Timeline:** 3-5 days (including translator turnaround)
**Why now:** Japan and Korea are #2 and #3 markets for meditation/focus apps. Brain.fm and Endel are English-first. Being early in these App Stores with a polished native app is a land grab.

**Implementation:**
- [ ] Extract all user-facing strings to String Catalogs (Xcode 15+)
  - Audit every view for hardcoded strings
  - Use `String(localized:)` or `LocalizedStringKey` throughout
  - Include: UI labels, onboarding text, science cards, settings, error messages, notification text, paywall copy
- [ ] Create `Localizable.xcstrings` with:
  - English (en) — base
  - Japanese (ja)
  - Korean (ko)
- [ ] Hire translators:
  - Option 1: Professional (Gengo, OneSky) — $0.08-0.12/word, ~5,000 words = $400-600 per language
  - Option 2: Native speaker review on Fiverr — $100-200 per language
  - Total budget: $600-1,600
- [ ] Localize App Store listing (title, subtitle, description, keywords) for ja and ko
- [ ] Test RTL-safe layouts (not needed for ja/ko but good practice)
- [ ] Test Dynamic Type with Japanese characters (wider glyphs, verify no truncation)
- [ ] Localize screenshot text overlays for App Store

**Acceptance:** Switch device language to Japanese → entire app renders in Japanese with no English fallthrough. Same for Korean. App Store listing appears correctly in both stores. No layout breaks with longer/shorter translated strings.

---

### 3C. Apple Featuring Nomination
**Phase alignment:** Same day as Phase 48 (App Store submission)
**Timeline:** 1 hour

**Nomination content:**
- [ ] Submit via https://developer.apple.com/contact/app-store/promote/
- [ ] Key points to include:
  1. **First binaural beats app with real-time biometric adaptation** — Apple Watch HR/HRV drives audio frequency selection in a closed feedback loop. No other app does this.
  2. **Apple Watch standalone** — full sessions on wrist with AirPods, no iPhone required
  3. **HealthKit depth** — reads HR, HRV, sleep, activity; writes mindful minutes and session summaries
  4. **On-device processing** — all biometric data processed locally, never leaves the device
  5. **Accessibility** — VoiceOver labels on all interactive elements, Dynamic Type, Reduce Motion support, high contrast
  6. **Live Activities** — session timer and biometric data in Dynamic Island and Lock Screen
  7. **App Intents + Shortcuts** — "Start a Focus session" via Siri
  8. **Focus Filters** — integrates with iOS Focus modes
  9. **Zero third-party analytics SDKs** — privacy-first architecture
  10. **Localized in Japanese and Korean** at launch
- [ ] Include 3-4 screenshots highlighting Watch app + adaptation visualization
- [ ] Target editorial calendar:
  - **May (Mental Health Awareness Month)** — ideal launch window
  - **September (back to school)** — Study Track feature angle
  - **January (New Year's resolutions)** — wellness/focus angle
  - **Post-WWDC** — if adopting new iOS APIs

---

## PRIORITY 4: Growth Accelerators (v1.0.1 — First Update)

### 4A. Live Activities & Dynamic Island
**Phase alignment:** Phase 37 (already in plan)
**Timeline:** 2-3 days

- [ ] `ActivityKit` Live Activity showing:
  - Session mode icon + timer countdown
  - Current HR (updated every 5s via push token or timer)
  - Current beat frequency
  - Play/pause controls on expanded view
- [ ] Dynamic Island compact: mode icon + timer
- [ ] Dynamic Island expanded: mode + timer + HR + frequency
- [ ] Lock Screen: full Live Activity with biometric card
- [ ] End Live Activity when session completes or user stops

### 4B. App Clip for Instant Trial
**Phase alignment:** NEW — post-launch growth
**Timeline:** 3-5 days

- [ ] Create App Clip target (10 MB limit)
- [ ] Single-screen experience: pick a mode → 5-minute session with time-based arc (no Watch required)
- [ ] Post-session: "Want your sessions to adapt to your heartbeat? Download BioNaural."
- [ ] App Clip Code / NFC tag for conference booths, co-working spaces, wellness events
- [ ] Safari Smart Banner on bionaural.app landing page

### 4C. Referral via SharePlay Co-Focus
**Phase alignment:** Phase 49 (already in plan as v1.1)
**Timeline:** 1 week

- [ ] SharePlay integration for Focus and Relaxation modes
- [ ] Shared session: both users hear the same adaptive audio, synchronized
- [ ] Each user's biometrics drive their own adaptation (personalized within shared session)
- [ ] Invitation IS the referral: non-users receive an App Clip link when invited
- [ ] Post-session: both users see shared summary ("You and Alex focused for 45 minutes together")
- [ ] Share to Messages with custom preview card

---

## Launch Checklist Summary

### MUST SHIP (v1.0 — before App Store submission)

| # | Item | Timeline | Status |
|---|------|----------|--------|
| 1 | StoreKit 2 subscriptions wired | 2-3 days | Not started |
| 2 | Apple Watch companion app | 1-2 weeks | Not started |
| 3 | Professional sound assets (40-60 loops) | 1-2 weeks (parallel) | Not started |
| ~~4~~ | ~~Study Track creation flow~~ | ~~3-4 days~~ | **DONE** — Repositioned as "Flow State." `FlowStateSetupView.swift`, all references renamed. Broader audience (not just students). 3x audits passed. |
| ~~5~~ | ~~Morning Brief notification~~ | ~~2 days~~ | **DEFERRED** — generator built (524 LOC), wire later if retention data demands it |
| ~~6~~ | ~~Post-session share card~~ | ~~2 days~~ | **DONE** — `ShareCardRenderer.swift` (Stories + Square formats, 2x2 metric grid, AdaptationMap hero, watermark) |
| ~~7~~ | ~~Visible adaptation toasts~~ | ~~1 day~~ | **DONE** — `AdaptationToast.swift` (4s auto-dismiss, per-mode messages, reduce motion, throttle-ready) |
| ~~8~~ | ~~Energize safety as feature~~ | ~~1 day~~ | **DONE** — `EnergizeSafetyEducationView.swift` (3-panel education) + `EnergizeSafetyIndicator.swift` (shield icon with safe/caution/critical states) |
| 9 | Japanese & Korean localization | 3-5 days | Not started |
| 10 | Apple Featuring nomination | 1 hour | Not started |

**Completed (April 5, 2026):**
- Post-session share card (ShareCardRenderer.swift) — Stories + Square formats
- Visible adaptation toasts (AdaptationToast.swift) — auto-dismiss, per-mode natural language
- Energize safety education (EnergizeSafetyEducationView.swift) — 3-panel swipeable
- Energize safety indicator (EnergizeSafetyIndicator.swift) — real-time shield icon
- All passed 3x pristine audits (token compliance, native UI/accessibility, code quality)
- Clean build + simulator verified on iPhone 17 Pro (iOS 26.2)

**Remaining estimated timeline: 2-3 weeks (with parallelization)**

### SHIP IN FIRST UPDATE (v1.0.1)

| # | Item | Timeline |
|---|------|----------|
| 11 | Live Activities & Dynamic Island | 2-3 days |
| 12 | App Clip | 3-5 days |
| 13 | SharePlay Co-Focus | 1 week |

---

## The Competitive Matrix After These Changes

| Capability | Brain.fm | Endel | Calm | Headspace | BioNaural |
|-----------|---------|-------|------|-----------|-----------|
| Real-time biometric adaptation | No | Shallow | No | No | **Deep (HR+HRV)** |
| Closed feedback loop | No | No | No | No | **Yes** |
| Apple Watch standalone | No | Yes | Basic | Basic | **Yes** |
| Study Tracks (state-dependent learning) | No | No | No | No | **Yes** |
| Calendar-aware recommendations | No | No | No | No | **Yes** |
| Morning Brief with biometric context | No | No | No | No | **Yes** |
| Visible adaptation during session | No | No | No | No | **Yes** |
| Post-session biometric share card | No | No | No | No | **Yes** |
| Frequency accuracy guaranteed | N/A | N/A | N/A | N/A | **Yes (real-time synthesis)** |
| Safety guardrails (Energize) | N/A | N/A | N/A | N/A | **Yes (7 independent)** |
| Honest science communication | Good | Minimal | Minimal | Good | **Yes (in-app Science section)** |
| Japanese/Korean localization | No | No | Yes | Yes | **Yes** |
| Production-quality audio | Yes | Yes | Yes | Yes | **Yes** |
| Isochronic tones | N/A | N/A | N/A | N/A | v1.1 |
| ML personalization | No | No | No | AI chat | v1.5 |
| Generative audio | Yes | Yes | No | No | v2.0 |

**BioNaural at launch occupies 10 capabilities that no competitor has. Not "does better" — literally doesn't exist in any competing product.**

---

## The One Sentence

> BioNaural is the first app that listens to your body, understands your life, and composes audio that adapts in real time — and after these 10 changes, no one can catch you.
