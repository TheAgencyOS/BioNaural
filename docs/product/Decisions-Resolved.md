# BioNaural — Resolved Design Decisions

> Every yes/no decision that affects development. All resolved.

---

## Confirmed YES

### 1. Apple Watch Standalone Sessions — YES
The Watch can run a complete session independently — binaural beat synthesis on-Watch, audio to AirPods/Bluetooth headphones, no iPhone required. This is a significant engineering lift (audio engine must run on watchOS) but a massive Apple featuring angle ("works independently on Apple Watch").

**Implications:**
- Audio engine needs a watchOS-compatible version (AVAudioEngine runs on watchOS 10+)
- Binaural synthesis via AVAudioSourceNode works on Watch
- Ambient/melodic layers: bundle a subset of sounds in the Watch app (smaller library, 3-5 beds)
- Session data syncs to iPhone via WCSession.transferUserInfo when they reconnect
- HR data stays on-Watch during standalone (no WCSession streaming needed — Watch reads its own HealthKit directly)
- Adaptive algorithm runs entirely on-Watch during standalone
- **Build plan impact:** New phase needed in Watch App section

### 2. Timer / Pomodoro Integration — YES
Focus mode supports optional Pomodoro timing: 25 min focus → 5 min relaxation break → repeat. The app auto-switches between Focus and Relaxation modes on the Pomodoro cycle.

**Design:**
- Optional toggle in Focus mode settings: "Pomodoro mode"
- Focus session (25 min, beta) → haptic tap → auto-switch to Relaxation (5 min, alpha) → haptic tap → back to Focus
- User sets cycle count (default: 4 cycles = 2 hours)
- The audio seamlessly crossfades between modes (binaural frequency shifts, melodic layer adapts, ambient holds)
- Timer shows both session time and cycle progress (e.g., "Cycle 2 of 4 — Focus — 12:30")
- Post-session summary shows all cycles with per-cycle biometric data
- **Build plan impact:** Add to Phase 17 (Session Arc) or as a new phase after it

### 3. SharePlay for Co-Focus Rooms — YES
When co-focus rooms ship (v1.1+), use Apple's SharePlay framework. This makes shared sessions native to FaceTime and Messages — users can start a co-focus room directly from a conversation.

**Benefits:**
- Strong Apple featuring signal (SharePlay adoption)
- No custom server infrastructure for real-time room management
- Works over iMessage: "Focus with me?" → tap → both users enter a shared session
- Each participant has their own biometric adaptation but shares the same session timer and ambient Orb visibility
- **Build plan impact:** Post-launch phase (alongside Co-Focus Rooms, Phase 49)

### 4. "It Doesn't Work For Me" Graceful UX — YES
Design an honest off-ramp for users who don't perceive binaural beat effects (the science says this is 20-30% of people).

**Design:**
- After session 5 with no thumbs-up and poor biometric outcomes: show a card:
  > "Everyone's brain responds differently to binaural beats. If you're not feeling the effect, here are some things to try:"
  > - Try a different mode
  > - Adjust the binaural beats volume (increase the "Beats" slider)
  > - Try a longer session (20+ minutes)
  > - Make sure Spatial Audio is off (re-run test tone)
- After session 10 with still no improvement:
  > "Binaural beats work for most people, but not everyone — and that's normal neuroscience, not a flaw in you or the app. The melodic and ambient layers are still valuable for creating a focused/calm environment, even without the entrainment effect."
- Never blame the user. Never oversell. The In-App Science "Individual Differences" card explains the neuroscience.
- The app remains useful even without binaural entrainment — the three-layer audio, adaptive engine, and feedback loop still create a personalized sound environment.

### 10. Energize as Fourth Mode — YES
Added Energize as the 4th mode alongside Focus, Relaxation, and Sleep. Energize targets high-beta/low-gamma frequencies (18-30 Hz) for uplifting arousal, pre-workout activation, and morning energy. Designed for shorter sessions (10-20 min).

**Implications:**
- Mode selection moves from vertical list to 2x2 grid
- Energize uses amber-gold (#F5A623) as its mode color
- Free tier remains 2 modes (Focus + Relaxation); premium unlocks all 4 (Focus, Relaxation, Sleep, Energize)
- Adaptive algorithm adds upward bias / arousal reinforcement logic for Energize
- Carrier frequency range: 350-500 Hz
- Session Orb behavior: faster pulse, warm corona, subtle upward particle effects
- New in-app science card explains high-beta/low-gamma research
- **Build plan impact:** Expand mode-related phases to include Energize parameters, audio curves, and UI

---

## Confirmed NO

### 5. CarPlay — NO (Explicit Block)
Binaural beats induce relaxation and altered states. Driving while drowsy is dangerous. BioNaural must explicitly block CarPlay playback.

**Implementation:**
- Check `AVAudioSession.currentRoute` for `.carPlay` output
- If CarPlay detected: show alert: "BioNaural is not available during CarPlay for safety. Binaural beats can cause drowsiness."
- Do not play audio through CarPlay under any circumstances
- **Build plan impact:** Add to Phase 18 (Headphone Detection) as a CarPlay check

---

## Confirmed Features (New)

### 6. Offline Mode
The app must work fully offline (airplane mode, no WiFi, no cellular).

**What works offline:**
- All audio synthesis (binaural + ambient + melodic — all local)
- Apple Watch HR streaming (Bluetooth, not network-dependent)
- Session history (SwiftData, local)
- Adaptive algorithm (all on-device)
- Feedback loop (local weight updates)

**What doesn't work offline:**
- CloudKit sync (deferred to v1.1 anyway)
- Oura/WHOOP API calls (v2 features)
- StoreKit subscription validation (iOS caches entitlements locally for days)
- App Store review prompt

**Implementation:** No special offline mode needed — the architecture is already on-device-first. Just ensure no hard network dependencies in the session flow. Add a check: if network is unavailable during subscription check, trust the cached entitlement.

### 7. Battery Warning
Before starting a session, check Watch battery level.

**Implementation:**
- If Watch battery < 20% and session duration > 15 min: show warning:
  > "Your Apple Watch battery is at [X]%. A [duration] session uses approximately [estimate]% battery. Continue anyway?"
  > [Continue] [Shorten Session]
- Estimate: ~5% per 15 min (conservative)
- Don't block — just inform. The user decides.

### 8. Data Export (GDPR Compliance)
Users can export all their data.

**Implementation:**
- Settings → Privacy → Export My Data
- Generates a JSON file containing: session history, user profile, sound preferences, biometric baselines
- Does NOT include raw HealthKit data (that's Apple's responsibility)
- Share via native share sheet (AirDrop, Files, email)
- Also: Settings → Privacy → Delete My Data (removes all SwiftData + resets preferences)

### 9. Archive Stale Research Docs
Move research docs that no longer match the shipped product to an archive subfolder so developers aren't confused.

**Move to `_Research-Archive/`:**
- `Science-Exercise.md` — Workout isn't a mode, doc concludes "evidence is weak"
- `BioNaural-Features.md` — loose ideas file, doesn't match finalized feature set

**Add prominent note to:**
- `Focus-Categories.md` — "RESEARCH ARCHIVE: This doc explored 13 focus categories. The shipped product has 4 modes: Focus, Relaxation, Sleep, Energize. This doc is retained for research context only."

---

## Summary of Build Plan Impacts

| Decision | Phase Impact |
|----------|-------------|
| Watch standalone | New phase after Phase 36 (Watch app section) |
| Pomodoro timer | Expand Phase 17 (Session Arc) |
| SharePlay | Add to post-launch Phase 49 (Co-Focus Rooms) |
| CarPlay block | Add to Phase 18 (Headphone Detection) |
| "Doesn't work" UX | Add to Phase 34 (Contextual Science Cards) or new retention phase |
| Offline mode | No new phase — verify no network dependencies in session flow |
| Battery warning | Add to Phase 33 (Onboarding) or Phase 31 (Session Integration) |
| Data export | Add to Phase 8 (Settings) |
| Archive stale docs | Folder reorganization (non-code) |

---

## 2026-04-05: Calendar Insights Sparkles Button → Settings

### Decision
Removed the sparkles (✨) toolbar button from the Insights tab that linked to CalendarInsightsView. CalendarInsightsView now lives exclusively in Settings → Life-Aware Audio → Calendar Insights.

### Why
The Insights tab now surfaces correlations directly through 7 integrated views:
- Event-Health Timeline (HR + calendar events on shared chart)
- Post-Event Impact Cards (per-event biometric cost)
- Predictive Health Forecast (forward-looking predictions)
- Weekly Correlation Digest (ranked event costs)
- Life Event Halo (multi-day stress arcs)
- Weather Health Card (barometric pressure + conditions)
- Journal Correlation Card (real-life activity context)

The raw pattern list in CalendarInsightsView became redundant as a user-facing feature. It's now a transparency/debugging screen — similar to how Apple puts Siri learning data in Settings, not in the main UI.

### Also changed
- Focus Filter Settings added to Settings → Life-Aware Audio → Focus Filters
- Settings gear added to Home tab top-right toolbar (was only on Insights)

---

## v1.1 Planned: "What I Know About You" — Unified Intelligence Page

### Concept
Replace CalendarInsightsView (raw pattern text + strength dots) with a comprehensive "What BioNaural Has Learned" page consolidating ALL learned intelligence.

### Sections

**1. Calendar Patterns** (existing CalendarInsightsView data)
- "HR spikes before meetings with 'client'" (strength: ●●○)
- "Heavy Monday mornings degrade afternoon Focus"
- "Poor sleep 1-2 days before deadlines"

**2. Weather Correlations** (from WeatherKit over time)
- "Rainy days: Relaxation scores +12%"
- "Falling pressure: your HRV drops ~6ms"
- "Best Focus weather: clear, 18-22°C"

**3. Journal Patterns** (from JournalingSuggestions over time)
- "Post-workout sessions: best biometric response"
- "Sessions after coffee shop visits: highest Focus scores"
- "Music listening days correlate with better sleep sessions"

**4. Biometric Baselines** (from HealthKit trends)
- "Your resting HR has dropped 3 BPM over 30 days"
- "HRV trending up since you started evening Relaxation"
- "Average time-to-calm: 4.2 min (was 7.1 min at start)"

**5. Circadian Patterns** (from session history)
- "Your best Focus window: 9-11 AM"
- "Thursday is historically your hardest day"
- "Weekend sessions score 15% higher than weekday"

**6. Sound Preferences** (from session outcomes)
- "Rain ambient: highest completion rate (92%)"
- "380 Hz carrier: your optimal Focus frequency"
- "Piano melodic layer: best HRV response"

### Design
- Glass card pattern matching Health view
- Each section: collapsible card with 3-5 learned facts
- Confidence/strength indicator per fact (dots or bar)
- "BioNaural has learned N facts about you" summary at top
- Privacy footer: "All learning happens on-device. Nothing leaves your iPhone."
- "Clear All" destructive action at bottom
- Accessible from Settings → Life-Aware Audio → What I've Learned

### When to build
After v1 ships and users have 30+ sessions. Needs real data to be meaningful.

### Data sources
All already being collected:
- `CalendarPatternLearner.analyzePatterns()` → calendar patterns
- `WeatherServiceProtocol` + session outcomes → weather correlations
- `JournalSuggestionServiceProtocol` + session outcomes → journal patterns
- `HealthKitServiceProtocol` trend queries → biometric baselines
- `FocusSession` @Query by time/day → circadian patterns
- `SessionOutcome.activeSoundTags` + scores → sound preferences
