# BioNaural — Feedback & Learning Loop

> Thumbs up/down + biometric outcomes = the training signal. The app gets smarter every session.

---

## The Two Feedback Signals

### 1. Explicit: Thumbs Up / Down

Simple, binary, low-friction. The user tells you what they liked.

**When to show:** Post-session summary screen. One prompt:

> "How was the sound?"
> [👍] [👎]

Optional: tap the thumb to expand to a quick tag — "Too busy," "Too quiet," "Loved it," "Not my style." But the binary alone is valuable.

**Never show mid-session.** Don't interrupt a focus/relaxation/sleep state for feedback. Post-session only.

**What it captures:**
- Liked/disliked the overall sound combination
- Indirectly: preference for the melodic layer selection, ambient bed, and volume balance
- Does NOT capture whether it "worked" — a user might enjoy music that doesn't actually calm them

### 2. Implicit: Biometric Outcomes

This is the killer signal. Objective, automatic, no user effort.

| Metric | How to Measure | What It Means |
|--------|---------------|---------------|
| **HR delta** | `session_end_HR - session_start_HR` | Did heart rate drop? By how much? |
| **HRV delta** | `session_end_HRV - session_start_HRV` | Did HRV improve (increase)? |
| **Time to calm** | Minutes until HR stabilized below user's resting + 5 BPM | How quickly did the session take effect? |
| **Time to sleep onset** | Minutes from session start to detected sleep (Watch motion + HR) | Sleep mode: did they fall asleep? How fast? |
| **Adaptation count** | Number of biometric state transitions during session | Fewer = more stable session = better |
| **Session completion** | Did user complete the intended duration? Or stop early? | Stopping early = something was wrong |
| **Sustained deep state** | Minutes in the lowest biometric zone (Calm) | Longer = better session quality |

### Combining the Two

| Scenario | Interpretation | Weight |
|----------|---------------|--------|
| 👍 + biometrics improved | Strong positive — sound worked AND user liked it | Highest |
| 👍 + biometrics neutral | User liked it but it didn't measurably help | Medium positive (preference, not efficacy) |
| 👍 + biometrics worsened | Rare. User enjoyed but it activated them. | Low — note preference but don't optimize for this |
| 👎 + biometrics improved | Sound worked objectively but user didn't like it | Medium — effective but unsustainable (user won't come back) |
| 👎 + biometrics neutral | Failed on both counts | Strong negative |
| 👎 + biometrics worsened | Total failure | Strongest negative — avoid this combination |
| No feedback + biometrics improved | User didn't rate but body says it worked | Medium positive (most sessions will be this) |
| No feedback + biometrics neutral | No signal | Ignore — maintain current weights |

**The biometric signal is more reliable than thumbs.** Someone might thumbs-up a sound they enjoy that doesn't calm them. The biometrics don't lie. But thumbs captures preference — and preference drives retention. Both matter.

---

## What Gets Recorded Per Session

```swift
struct SessionOutcome {
    // Session metadata
    let sessionID: UUID
    let mode: FocusMode
    let duration: TimeInterval
    let timestamp: Date
    let timeOfDay: Int  // hour (0-23)
    let dayOfWeek: Int
    
    // Entrainment parameters
    let entrainmentMethod: EntrainmentMethod  // .binaural or .isochronic (v1.1+)
    let entrainmentFrequencyRange: ClosedRange<Double>  // actual beat/pulse frequency used
    let carrierFrequency: Double
    
    // Sound selections
    let ambientBedID: SoundID
    let melodicLayerIDs: [SoundID]  // may have multiple due to crossfades
    
    // Biometric outcomes
    let hrStart: Double
    let hrEnd: Double
    let hrDelta: Double  // negative = calming (good for relax/sleep)
    let hrvStart: Double?
    let hrvEnd: Double?
    let hrvDelta: Double?  // positive = improving (good)
    let timeToCalm: TimeInterval?  // seconds until Calm state reached
    let timeToSleep: TimeInterval?  // seconds until sleep detected (sleep mode only)
    let adaptationCount: Int
    let sustainedDeepStateMinutes: Double
    let wasCompleted: Bool
    
    // Pre-session check-in (self-report)
    let checkInMood: Double?         // 0.0 (wired/anxious) to 1.0 (calm/tired)
    let checkInGoal: FocusMode?      // what they said they wanted to do
    let checkInSkipped: Bool         // did they skip the check-in?
    
    // User feedback (post-session)
    let thumbsRating: ThumbsRating?  // .up, .down, nil (no rating)
    let feedbackTags: [String]?  // optional: "too busy", "loved it", etc.
    
    // Computed
    var biometricSuccessScore: Double {
        // 0.0 = no improvement, 1.0 = strong improvement
        // Weighted combination of HR delta, HRV delta, time to target, sustained state
        // Normalized to the user's personal history
    }
    
    var checkInBiometricAlignment: Double? {
        // How well did the self-report match the biometric reality?
        // checkInMood 0.2 (wired) + HR 92 + HRV low = high alignment (they knew they were stressed)
        // checkInMood 0.8 (calm) + HR 92 + HRV low = low alignment (they thought they were calm but weren't)
        // This helps the system learn: does this user accurately perceive their own state?
        // Users with low self-awareness benefit MORE from biometric adaptation.
        // Users with high self-awareness can rely more on check-in data in Manual Mode.
    }
    
    var overallScore: Double {
        // Combines biometricSuccessScore + thumbsRating into single 0-1 value
        // Biometric weight: 0.7, Thumbs weight: 0.3
    }
}
```

Stored in SwiftData. Every session. This is the training data for the learning system.

**Note on `entrainmentMethod`:** v1 always records `.binaural`. When isochronic tones are added (v1.1+), the system records which method was used so the v1.5 ML contextual bandit can learn which entrainment method produces better biometric outcomes for each user/mode/context. Without this field, the learning loop cannot optimize entrainment method selection.

### The Three-Signal Learning Loop

The system learns from three signals, each reinforcing the others:

| Signal | What It Tells You | Available In |
|--------|------------------|-------------|
| **Pre-session check-in** | Subjective state + intent. "I'm wired and need to focus." | Both modes |
| **Biometric outcomes** | Objective physiology. Did HR drop? Did HRV improve? Did they sleep? | Adaptive mode |
| **Post-session thumbs** | Preference. Did they enjoy it? | Both modes |

**Why all three matter:**
- Check-in alone is subjective and unreliable (people misjudge their state 30-40% of the time)
- Biometrics alone miss subjective preference (something can "work" physiologically but feel unpleasant)
- Thumbs alone miss both objective efficacy and starting state

**Together:** The system learns a rich model per user:
- "When this user says they're wired AND their HR confirms it, these sounds calm them fastest"
- "When this user says they're calm but their HR says otherwise, trust the HR"
- "This user's Focus sessions produce better biometric outcomes with isochronic tones at 40 Hz gamma than binaural beats at 15 Hz beta"
- "This user has high self-awareness (check-in matches biometrics 85% of the time) — weight their check-in more heavily in Manual Mode"
- "This user has low self-awareness (30% alignment) — always use biometric adaptation when available, default to conservative sounds in Manual Mode"

This is the compounding personalization that no competitor has. After 50 sessions, the app knows both what the user SAYS they need and what their body ACTUALLY needs — and knows when those differ.

---

## The Learning System

### Phase 1 (v1): Rule-Based Selection + Outcome Logging

No ML yet. Just rules + data collection.

```
1. Mode + biometric state → filter sound library (rules from Tech-MelodicLayer.md)
2. User preference profile → rank within filtered set
3. Select top sounds
4. Play session
5. Record SessionOutcome (all biometric data + thumbs)
6. Update user preference weights:
   - Thumbs up → increase weight for those sound tags by 10%
   - Thumbs down → decrease weight by 20% (negatives are more informative)
   - Biometric success > 0.7 → increase weight for those sounds by 15%
   - Biometric success < 0.3 → decrease weight by 10%
```

This is simple exponential weight updating — not ML, just adaptive rules. But it makes the app noticeably smarter within 5-10 sessions.

### Phase 2 (v1.5): ML-Powered Sound Selection

After 20+ sessions with outcome data:

**Model type:** Contextual bandit (multi-armed bandit with context features)
- Arms = sound combinations in the library
- Context = user profile + current biometric state + time of day + mode
- Reward = `overallScore` from SessionOutcome
- Exploration/exploitation: Thompson sampling or UCB1

**Why contextual bandit, not deep learning:**
- Small action space (30-50 sounds, not millions)
- Small dataset per user (20-100 sessions, not millions)
- Need to balance exploration (try new sounds) with exploitation (use what works)
- Runs on-device with Core ML, kilobytes not gigabytes
- Interpretable — you can explain "we chose this because it worked 4 out of 5 times when your HR was elevated"

**Training:**
- On-device using Create ML or custom implementation
- User's own data only (privacy-preserving)
- Retrain after every 5 sessions (fast, lightweight)
- Fallback to rules if model confidence is low

### Phase 3 (v2+): Cross-User Learning

With opt-in anonymous data from thousands of users:
- Collaborative filtering: "Users like you tend to respond well to..."
- Population-level priors for cold-start (new users get better defaults)
- Requires cloud component and explicit consent
- Optional — the on-device learning is the core experience

---

## The User Model: Learning Everything

BioNaural doesn't just learn which sounds work during sessions. It builds a **full behavioral model** of the user — how their mood, metrics, and needs change across their entire day and week. The app watches patterns across all available data (with permission) and gets smarter about every recommendation.

### What the System Tracks (Beyond Sessions)

| Data Source | What We Learn | How It Feeds the Model |
|------------|---------------|----------------------|
| **HealthKit — sleep** | How they slept last night (hours, deep sleep %, stages) | Poor sleep → suggest Relaxation over Focus. Good sleep → user can handle higher-intensity Focus. |
| **HealthKit — resting HR** | Daily resting HR trend | Rising resting HR over days → suggest more Relaxation sessions. Falling → user is recovering well. |
| **HealthKit — HRV** | HRV trend over days/weeks | Declining HRV trend → system proactively suggests recovery sessions. |
| **HealthKit — activity** | Steps, active energy, workouts | Heavy workout day → evening session should be deeply calming. Sedentary day → different sound profile. |
| **CoreMotion — movement patterns** | When they move, when they're still | Learns their daily rhythm. Knows when they typically sit down to work vs. when they're active. |
| **AirPods — head stillness** | How still they are during sessions over time | Learns their baseline restlessness. Can detect improvement in focus/meditation practice over weeks. |
| **Session history** | When they use the app, which modes, how long | Time-of-day patterns, session frequency, preferred durations per mode. |
| **Check-in history** | Mood/stress self-reports over time | Mood patterns — are they always stressed on Monday mornings? Calm on weekends? This informs proactive suggestions. |
| **Biometric response curves** | How quickly their HR drops in Relaxation, how fast they fall asleep | Learns their personal response time. Adjusts session arcs to match their body's pace, not a generic default. |

### Cross-Signal Correlations the Model Discovers

Over 30-60 days of data, the system can discover patterns like:

- "After days with 8000+ steps, your Sleep sessions work 40% faster"
- "Your Focus is best between 9-11 AM when you slept 7+ hours"
- "When your resting HR is elevated 2+ days in a row, Relaxation with ocean sounds produces the biggest HRV improvement"
- "You check in as 'calm' on mornings after Sleep sessions, but 'wired' when you skip"
- "Your head stillness during Focus sessions has improved 35% over the last month — your focus practice is working"

These aren't displayed as raw data — they surface as **proactive suggestions** and **insights** on the home screen and in the Monthly Neural Summary.

### How Movement Changes Things

The app tracks movement context from HealthKit and CoreMotion:

| Movement Pattern | What It Means | How the App Responds |
|-----------------|---------------|---------------------|
| Sedentary all day | Likely desk work, possible tension | Evening session: suggest Relaxation, warmer sounds, lower frequencies |
| Heavy workout earlier | Elevated HR/cortisol, body in recovery | Session: start at lower frequency, calming melodic content, recovery-optimized |
| Walking right now (phone in pocket) | Active, alert, possibly commuting | If they start a session: don't suggest Sleep, suggest Focus or Relaxation. Adjust for movement noise. |
| Just finished moving | Transition from active to rest | Great moment for Relaxation. Suggest it proactively. |
| Woke up recently (time + first movement) | Morning state | Pull last night's sleep data, factor into session recommendation. |

### How Sleep Changes Things

Sleep quality from Apple Watch directly affects the next day's session parameters:

| Sleep Data | Impact on Next Day |
|-----------|-------------------|
| < 6 hours total | System notes fatigue risk. Suggest shorter Focus sessions. Relaxation frequency starts lower (deeper alpha). |
| Deep sleep < 45 min | Poor recovery. HRV likely low. Suggest Recovery Relaxation before attempting Focus. |
| 7+ hours, good deep sleep | Full capacity. Focus sessions can be longer and at higher beta frequencies. |
| Fragmented (many awakenings) | System adjusts expectation: this user's biometrics may be noisier today. Increase signal quality model sensitivity. |
| BioNaural Sleep session last night | Compare: did Sleep mode improve objective sleep metrics? This is the strongest training signal for the sound selection model. |

### Privacy Architecture for the Full Model

All of this runs **on-device**:
- HealthKit queries happen locally — data never leaves the device
- The user model is a SwiftData entity stored locally
- CoreMotion activity data is processed in-memory, not persisted raw
- AirPods head motion is computed into "stillness scores," raw data not stored
- The model only sends aggregated insights to the UI — never raw health data

If the user deletes their data (Settings → Privacy → Delete My Data), the entire model is wiped.

---

## Biometric Success Scoring

### Focus Mode Success

| Metric | Weight | Good Outcome |
|--------|--------|-------------|
| HR stability (low variance) | 0.3 | Steady HR = sustained focus |
| Adaptation count (low) | 0.2 | Fewer state transitions = stable |
| Session completed | 0.2 | Finished intended duration |
| Sustained Focused state | 0.3 | Time in Focused zone |

### Relaxation Mode Success

| Metric | Weight | Good Outcome |
|--------|--------|-------------|
| HR delta (negative) | 0.3 | Heart rate dropped |
| HRV delta (positive) | 0.3 | HRV improved |
| Time to calm | 0.2 | Reached Calm state quickly |
| Session completed | 0.2 | Finished intended duration |

### Sleep Mode Success

| Metric | Weight | Good Outcome |
|--------|--------|-------------|
| Time to sleep onset | 0.4 | Fell asleep quickly |
| HR delta (negative) | 0.2 | Heart rate descended |
| HRV delta (positive) | 0.2 | Parasympathetic activation |
| Session completed (or sleep detected) | 0.2 | Didn't abandon |

---

## The Flywheel

```
Session → Sound selection (rules + learned weights) → Audio plays
    → Biometrics measured throughout → Session ends
    → Outcome recorded (biometric deltas + thumbs)
    → Weights updated for this user's sound profile
    → Next session's selection is smarter
    → Better outcomes → user comes back → more data → smarter selections → ...
```

**This is the moat.** After 50 sessions, switching to a competitor means abandoning a system that knows:
- Which piano patches calm you fastest
- That you respond better to strings than pads for focus
- That your sleep sessions work best with very low-density, dark sounds at 0.1 energy
- That Thursday evenings require different sounds than Monday mornings
- That when your HRV is below baseline, forest ambient + sparse piano produces the best recovery
- That isochronic tones at 40 Hz work better for your morning Focus sessions but binaural beats work better for evening Relaxation

No competitor has this data. No competitor can replicate it. It's compounding personalization built on objective biometric outcomes.

---

## UX for Feedback

### Post-Session (Every Session)

The summary screen already exists. Add one element:

```
┌─────────────────────────────────┐
│                                 │
│          48:32                  │
│          Focus                  │
│                                 │
│    ♡ 64 avg     ◆ 48ms avg    │
│    ∿ 8 shifts   ⬒ 22:14 peak │
│                                 │
│   [compressed wavelength]      │
│                                 │
│     How was the sound?         │
│       [👍]     [👎]            │
│                                 │
│          Done                  │
│                                 │
└─────────────────────────────────┘
```

Tapping a thumb records the rating. Tapping nothing (just "Done") = no explicit feedback, biometric outcomes still recorded.

**No follow-up questions unless the user taps thumbs-down.** On thumbs-down only: "What didn't work?" → [Too busy] [Too quiet] [Not my style] [Other]. Optional, dismissible.

### In-Session (Never)

Do NOT show feedback UI during a session. The session is sacred.

### Settings

Settings → Sound Preferences → shows the user's current profile:
- Preferred instruments (learned from feedback)
- "Reset my sound preferences" option
- "I prefer [Nature-forward / Musical / Minimal / Mix]" toggle (can change anytime)
