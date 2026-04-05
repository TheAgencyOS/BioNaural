# Apple Featuring Deep Dive — BioNaural

> What exists, what's missing, and the exact integrations that will get this app featured.

---

## Current State: 65% Complete, 8/10 Featuring Potential

The app has exceptional Apple ecosystem bones — Watch app, Live Activities, Dynamic Island, Widgets, Shortcuts, Focus Filters, HealthKit, Now Playing, Background Audio. Nobody else has all of these in a binaural beats app. That's the moat.

But "bones" isn't enough. Apple features apps that are **polished end-to-end**, adopt the **latest platform APIs on day one**, and demonstrate **deep respect for accessibility**. Here are the specific gaps and opportunities.

---

## TIER 1: Non-Negotiable Before Submission

These will get the app **rejected or ignored** if missing.

### 1. Dynamic Type Support (CRITICAL)

**Current:** All text uses fixed sizes from Theme.Typography.Size. Apple's accessibility team checks this.

**What to do:** Every `Font` in Theme.Typography must use `.relativeTo:` with proper text style mapping so iOS can scale them. The fonts already pass `.relativeTo` but the actual rendering must be tested at every Dynamic Type size — layouts need to stack vertically at XXL sizes.

**Effort:** 2-3 hours of testing and layout fixes.

### 2. Fix 3 Force Unwrap Crash Vectors

**Files:**
- `OnboardingScreens.swift:894-899` — HKObjectType force unwrap
- `ACEStepService.swift:154` — FileManager.urls() force unwrap
- `AdaptationMapView.swift:168-169` — Array first!/last! force unwrap

**Impact:** Crash on edge cases = instant App Store rejection.

### 3. Timer Leaks

**Files:** AmbienceLayer, MelodicLayer, SessionViewModel, OrbView, WavelengthView

Timers that don't invalidate before dealloc. On a 90-minute sleep session, this means battery drain and potential OOM crashes. Apple tests long sessions.

### 4. Full VoiceOver Audit

The app has good labels in most places but needs a complete screen-by-screen VoiceOver walkthrough. Every interactive element needs a label, hint, and proper trait. The Orb and Wavelength need `.accessibilityHidden(true)` since they're decorative (the audio is the product). Compose step navigation needs `.accessibilityAction` for swipe-to-advance.

---

## TIER 2: High-Impact Featuring Opportunities

These separate "good app" from "featured app."

### 5. HealthKit State of Mind (iOS 18+)

**What:** After each session, prompt a quick emotional check-in using `HKStateOfMind`. Log valence (-1 to +1), labels (`.calm`, `.focused`, `.stressed`, `.peaceful`), and association context.

**Why this matters:** Apple introduced this API specifically for wellbeing apps. Using it signals that BioNaural is a serious health tool, not just a sound machine. Over time, users can see their emotional trajectory correlated with session frequency in Apple Health.

**API:**
```
HKStateOfMind(
    date: Date(),
    kind: .momentaryEmotion,
    valence: 0.7,
    labels: [.calm, .peaceful],
    associations: [.mindfulnessSession]
)
```

Write via `healthStore.save(stateOfMind)`.

**Effort:** Small. The post-session thumbs UI already exists — extend it to capture valence and map thumbs-up to positive valence, thumbs-down to negative. Save to HealthKit alongside the existing mindfulness minutes write.

### 6. Foundation Models Framework (iOS 26 — On-Device AI)

**What:** Use Apple's on-device ~3B parameter language model for personalized session recommendations and natural language coaching. Zero API cost, zero data leaving device.

**Why this matters:** This is Apple's marquee iOS 26 framework. Apps that adopt it early will be featured prominently at WWDC and in the fall App Store refresh. BioNaural's data model is perfect for this — session history, biometric trends, time-of-day patterns, mood correlations.

**Concrete use cases:**
- "Based on your last 10 sessions, your HRV improves most with Calm mode in the evening. Your body responds 34% better to pad instruments than piano." (Generated from session data, on-device)
- Pre-session recommendation: "You had poor sleep last night (5.2 hrs from HealthKit). A 20-minute Calm session with ocean sounds typically helps your recovery on low-sleep days."
- Post-session insight: "Your heart rate dropped 12 BPM faster than your average — this combination is working well for you."

**API:**
```swift
let session = LanguageModelSession()
let prompt = "Given this user's session history: [data]. What session would you recommend and why? Respond as JSON with mode, duration, soundscape, and reasoning."
let response = try await session.respond(to: prompt, generating: SessionRecommendation.self)
```

**Guard:** Check `SystemLanguageModel.default.availability` — gracefully degrade on unsupported devices. This is a premium feature layer, not a dependency.

**Effort:** Medium. The data model is already there (FocusSession history, SoundProfile preferences, HealthKit reads). The AI coaching service (`AICoachService.swift`) already exists but uses Claude API — this would add an on-device alternative.

### 7. Liquid Glass Polish Pass

**Current:** The app uses `.glassEffect()` in some places (View+Modifiers.swift has `GlassCardModifier`, `AdaptiveGlassModifier`, `AdaptiveInteractiveGlassModifier`, `AdaptiveBarGlassModifier`).

**What's missing:**
- `GlassEffectContainer(spacing:)` wrapping nearby glass elements so they morph and blend
- `.glassEffectID("id", in: namespace)` for morphing transitions between screens
- `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)` on navigation buttons
- The Compose tab creation sheet should use glass prominently — each step's controls should feel like glass instruments

**Effort:** Small-Medium. The modifiers exist — apply them consistently.

### 8. Shortcuts Automation Triggers

**Current:** Start/Stop session intents exist with Siri phrases.

**What's missing:**
- **Intent donations** — every time a user manually starts a session, donate the intent so Siri learns patterns and proactively suggests
- **Automation triggers** — time-of-day, location-based, arriving at work/home
- **Parameterized shortcuts** — "Start a 25-minute focus session with rain and piano" as a single voice command that pre-fills the composition

**API:** `INInteraction(intent:).donate()`

**Effort:** Small. One line after session start.

### 9. SharePlay Co-Focus Rooms (v1.1)

**What:** Start a binaural session that syncs with friends via FaceTime or Messages. Everyone hears the same adaptive audio. The invitation IS the referral.

**Why:** Apple heavily features SharePlay-adopting apps. It's a natural viral loop. Focus apps are inherently social — study groups, co-working, couples winding down.

**API:** `GroupActivity` protocol, `GroupSession`, `GroupSessionMessenger`

**Effort:** Large but high-impact. Defer to v1.1 but design the architecture now.

---

## TIER 3: Differentiation (Nobody Else Has This)

### 10. AirPods Head Motion Tracking

**What:** During sessions, measure head stillness via AirPods motion sensors. Stillness = deeper focus/relaxation. Movement = user is distracted. Feed this into the adaptive algorithm.

**Why:** Nobody in the binaural beats space uses this. It's a second biometric signal beyond heart rate, available without Apple Watch. AirPods users (who are BioNaural's exact audience) get a richer experience.

**API:** `CMHeadphoneMotionManager` — provides gyroscope + accelerometer data from AirPods Pro/Max at 10-20 Hz. Compute stillness as magnitude of rotational velocity; low magnitude = still = focused.

**Current:** CLAUDE.md mentions this in the wearable hierarchy. Not implemented.

**Effort:** Medium. The BiometricProcessor already has the pipeline; add a second input source.

### 11. Adaptive Haptic Breathing Cues (Apple Watch)

**What:** During relaxation/sleep sessions, the Apple Watch delivers subtle haptic taps in a breathing rhythm — inhale for 4 seconds, exhale for 6 seconds. The rhythm gradually slows as the user's HRV improves.

**Why:** Combines Watch haptics with the adaptive algorithm. The user feels the session through their wrist without looking at any screen. This is the kind of multi-sensory integration Apple loves.

**API:** `WKInterfaceDevice.current().play(.click)` timed with a breathing curve. Or `CoreHaptics` on Watch for more nuanced patterns.

**Effort:** Small-Medium. Timer-based haptic delivery synced to session state.

### 12. Sleep Detection Auto-Stop

**What:** In Sleep mode, detect when the user actually falls asleep (sustained low HR + high HRV + minimal motion from Watch) and gracefully fade the audio out. No alarm, no sudden stop. The session knows you're asleep before you do.

**Why:** This is what makes BioNaural a genuine sleep tool, not just a sound machine. Competitors play sounds on a fixed timer. BioNaural reads your body and stops when you're actually asleep.

**Current:** CLAUDE.md references `timeToSleep` in SessionOutcome. The biometric classification system has all the signals. Just needs the auto-fade trigger.

**Effort:** Small. The classification states (Calm with sustained low HR = likely sleeping) and audio fade (`AudioEngine.stop()` with ramp) already exist. Wire the trigger.

---

## TIER 4: App Store Optimization & Timing

### 13. Launch Timing

**Target: May (Mental Health Awareness Month)**

Apple features wellness apps heavily in May. Pitch to Apple editorial 2-3 months before. Use the **App Store Connect Featuring Nomination** form.

### 14. App Store Screenshots

Lead with Apple Watch. Show the Orb on iPhone. Show the Dynamic Island during a session. Show the Compose tab (unique to BioNaural). Show the Health integration. Every screenshot must feature an Apple device front and center.

### 15. Localization

Even partial localization (App Store listing in 5-10 languages) multiplies featuring opportunities across regions. Apple features localized apps preferentially.

### 16. Privacy Nutrition Label

BioNaural processes everything on-device. The privacy label should be nearly empty. This is a massive trust signal that Apple values.

---

## Priority Execution Order

| # | Item | Effort | Impact | When |
|---|------|--------|--------|------|
| 1 | Fix force unwraps + timer leaks | 1 hr | Blocks submission | Now |
| 2 | Dynamic Type support | 3 hrs | Required for featuring | Now |
| 3 | VoiceOver audit | 2 hrs | Required for featuring | Now |
| 4 | HealthKit State of Mind | 2 hrs | High featuring signal | This week |
| 5 | Intent donations (Siri learning) | 30 min | Easy win | This week |
| 6 | Sleep detection auto-stop | 1 hr | Product differentiator | This week |
| 7 | Liquid Glass polish pass | 2 hrs | iOS 26 signal | This week |
| 8 | Foundation Models coaching | 1 week | Wow factor, WWDC feature | Next sprint |
| 9 | AirPods head motion | 3 days | Nobody else has this | Next sprint |
| 10 | Watch haptic breathing | 2 days | Multi-sensory experience | Next sprint |
| 11 | SharePlay architecture | 1 week | Viral loop, Apple loves it | v1.1 |
| 12 | Localization (5 languages) | 3 days | Multiplies featuring | Pre-launch |

---

## The Pitch (One Paragraph)

BioNaural is the first iOS app that generates adaptive binaural beats driven by real-time Apple Watch biometrics. It reads your heart rate and HRV, maps them to audio parameters through a deterministic control system, and delivers sound through three layered audio engines — all on-device, with zero cloud dependency. Users compose their own soundscapes in a guided flow, save them, and replay sessions that evolve based on their biology. With full Apple Watch standalone support, Live Activities, Dynamic Island, HealthKit State of Mind integration, Focus Filters, Siri Shortcuts, and the deepest AirPods integration in the category, BioNaural represents what's possible when an app is built exclusively for Apple's ecosystem.
