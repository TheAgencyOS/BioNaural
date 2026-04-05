# BioNaural: Killer Feature Brainstorm

> The foundation is built — biometric feedback loop, three-layer audio, four modes, learning system. These features are what tie it all together and make the app unforgettable.

---

## Feature 1: "Body Music" — Your Physiology Composes the Track

**Priority: HIGH — Primary differentiator and viral mechanic**

Every session, your heartbeat, HRV, and biometric state don't just modulate the audio — they compose a unique, one-of-a-kind ambient track. Your calm has a sound. Your focus has a melody. Tuesday's deep work session sounds different from Thursday's.

### How It Works

- HR rhythm seeds melodic timing (BPM mapping — resting HR of 62 creates a different rhythmic feel than 74)
- HRV variance drives harmonic complexity (high HRV = richer chord voicings, low HRV = simpler intervals)
- Biometric state transitions become musical movements (calm → focused = key modulation, elevated → calm = resolution)
- Beat frequency range during session influences tonal palette (beta range = brighter timbres, theta = warmer/darker)
- The three audio layers already exist — this makes the melodic layer generative from biometrics instead of rule-selected from a library

### What the User Experiences

- During session: the audio feels alive, responsive, personal (this already happens with adaptation)
- After session: "Save this track" option on the post-session summary screen
- Saved tracks appear in a personal "Body Music Library" — each one labeled with date, mode, duration, and the Adaptation Map as album art
- Replay any saved track as a static (non-adaptive) session — "I loved how Tuesday's focus felt"
- Export a 15–60 second preview clip for sharing

### Why It's a Killer Feature

- Each session produces a collectible artifact — not a score, not a badge, a piece of music your body wrote
- Inherently shareable: "Listen to what my focus session sounded like"
- Creates a library that grows with the user — people don't delete apps that hold their creations
- Ties directly into the existing melodic layer + sound library architecture
- The Adaptation Map visual becomes an album cover
- No competitor can replicate this without the entire biometric pipeline

### Viral Mechanic

Share a 15-second audio clip to Instagram/TikTok with the Adaptation Map as the visual. Beautiful, personal, completely unique. People ask "what is that?" — that's the distribution.

### Technical Alignment

- Builds on existing MelodicLayer architecture
- Generative MIDI through sampled instruments is already on the v2 roadmap — this pulls it forward with biometric seeding
- SessionOutcome already logs all biometric data needed for post-session track reconstruction
- Adaptation Map visual export is already planned

---

## Feature 2: "The Morning Brief" — AI-Powered Daily Prescription

**Priority: HIGH — Daily engagement hook without gamification**

Every morning, the app synthesizes overnight data into a single personalized card with a specific session recommendation.

### What the User Sees

```
Good morning, Eric.

Rough night — 5.8 hrs, restless after 2 AM.
Resting HR is +3 bpm over your 7-day average.
It's Monday — historically your hardest focus day.

Your prescription:
12-min Relaxation before your first deep work block.
Ocean ambient + 180 Hz carrier.
Your body needs a runway today.

[Start Session]
```

### Data Sources

- HealthKit: sleep duration, sleep stages, resting HR, HRV overnight trend
- Session history: which modes work best on which days, time-of-day patterns
- Check-in history: mood patterns by day of week (always stressed Monday? calm Friday?)
- Biometric response curves: how fast user's HR drops in Relaxation, how long Focus takes to settle
- Calendar integration (see Feature 6): upcoming stressors, meeting density
- Weather API (optional): barometric pressure changes correlate with mood/migraine

### How It Works

- Overnight job (on-device) runs at user's typical wake time (learned from HealthKit)
- Aggregates all available data sources
- Rule-based recommendation engine (v1) / ML model (v1.5+)
- Delivers as a local push notification: "Your morning brief is ready"
- Opens to the brief card — one tap to start the recommended session

### Why It's a Killer Feature

- Transforms BioNaural from "a tool you use when you remember" to "a daily advisor that knows you"
- Makes the invisible learning loop VISIBLE — users see that the app knows them
- Creates a daily open habit without streaks or guilt (genuine utility, not manipulation)
- The prescription gets better every week — compounding stickiness
- Ties together ALL background data sources into a single moment of value

### The Retention Moment

After 2 weeks, the brief says something so accurate the user thinks "how does it know that?" That's the moment they never uninstall.

---

## Feature 3: "Neural Replay" — Your 30-Day Biometric Evolution

**Priority: MEDIUM — Retention + validation + shareable content**

After 30 days of sessions, unlock a cinematic playback of your physiological journey. Not a dashboard. A movie.

### What the User Sees

A 60-second animation:
- The Orb and Wavelength animate through 30 days of session data
- Early sessions: Orb is jittery, Wavelength is chaotic, HR takes 8 minutes to settle
- Week 2: Orb calms faster, Wavelength smooths, time-to-calm drops to 5 minutes
- Week 4: Orb finds its rhythm quickly, Wavelength is serene, time-to-calm is 3 minutes
- Overlay: key milestones ("Day 12: fastest calm ever — 2:41"), mode distribution, total hours
- Final frame: side-by-side comparison of Day 1 vs Day 30 biometric response curves

### Data Required

- All SessionOutcome records (already logged)
- HR time series per session (store compressed — downsample to 0.1 Hz for replay)
- Adaptation event timestamps
- State classification history

### Why It's a Killer Feature

- Makes progress tangible without scores or gamification
- Deeply personal — it's the user's actual biometric data, animated beautifully
- Shareable as a video (30-day transformation content performs extremely well on social media)
- Creates "I want to see next month's" anticipation — monthly retention loop
- Validates the time investment — "this is actually working, I can see it"
- Aligns with the Monthly Neural Summary ("Wrapped") already on the roadmap

### Viral Mechanic

Export as a 15-second video optimized for Instagram Stories / TikTok. The visual is striking (Orb evolution over time), the data is personal, and the narrative ("watch my stress response change in 30 days") is compelling health/wellness content.

---

## Feature 4: "Life-Aware Audio" — Calendar + Context Integration

**Priority: HIGH — The feature that makes BioNaural feel omniscient**

The app reads the user's calendar, learns their life patterns, and proactively creates personalized audio experiences tied to upcoming events, memories, and goals. See dedicated section below for full exploration.

### Core Concept

BioNaural doesn't just respond to your body — it understands your life. It sees the exam on Friday, the presentation on Monday, the vacation next week. It knows that certain sounds help you study, that your stress spikes before client calls, that rain sounds remind you of your favorite coffee shop where you do your best work.

### Three Pillars

1. **Calendar Intelligence:** Reads calendar events, identifies stressors and patterns, proactively prepares sessions
2. **Sonic Memory:** Learns that specific sounds are tied to specific memories, moods, or states for this user
3. **Context Tracks:** Creates purpose-built audio experiences tied to life events (study track for exams, calm track for presentations, energy track for race day)

### Full Exploration

See the dedicated "Life-Aware Audio" section at the end of this document for the complete deep dive into calendar integration, sonic memory, study tracks, and the notification/delivery system.

---

## Feature Interaction Map

These features aren't isolated — they compound:

```
Calendar Intelligence detects: "Big presentation tomorrow"
    ↓
Morning Brief says: "We've prepared your Confidence Track."
    ↓
User runs the session — Body Music captures their pre-presentation physiology
    ↓
Sonic Memory pulls in sounds tied to user's "calm + confident" state
    ↓
Post-session: track saved to Body Music library as "Pre-Presentation Calm"
    ↓
Next presentation: Morning Brief suggests replaying that track (sonic memory callback)
    ↓
Neural Replay at month-end shows: "Your pre-presentation HR has dropped 12 bpm over 3 months"
    ↓
User shares the replay on Instagram. Friend downloads BioNaural.
    ↓
Both users are now in the retention loop
```

---

## Final Verdict: What Ships and When

### TIER 1 — MUST IMPLEMENT (Non-negotiable, these define what BioNaural IS)

These aren't features. They're the product identity. Without them, BioNaural is just another binaural beats app.

| Rank | Feature | Why It's Non-Negotiable | When |
|------|---------|------------------------|------|
| 1 | **Life-Aware Audio: Calendar Intelligence** | This is the single biggest unlock. It transforms BioNaural from "open when you remember" to "the app that sees your life coming and prepares you." Calendar + biometrics + proactive delivery = no competitor can touch this. The "we made something for you" notification is the most powerful retention mechanic in the entire app. | v1 (simplified) → v1.1 (full) |
| 2 | **Life-Aware Audio: Study Tracks** | State-dependent learning is real science with real data (15–20% recall improvement). This makes BioNaural a **cognitive performance tool**, not a wellness app. Students will build their entire exam prep around this. It's the feature that gets mentioned in "how I passed the bar exam" TikToks. | v1.1 |
| 3 | **Life-Aware Audio: Sonic Memory** | The emotional anchor layer. When the app uses sounds tied to YOUR memories, the biometric response is faster and deeper. This is what makes every user's BioNaural completely unique — and impossible to replicate by switching to a competitor. It's the personalization moat on top of the biometric moat. | v1.1 (basic input) → v1.5 (full learning) |
| 4 | **The Morning Brief** | The daily engagement hook. Without this, users have to decide to open the app. With this, the app comes to them with a reason. Calendar-aware Morning Brief + Life-Aware Audio = the app feels omniscient. | v1 (rule-based, HealthKit only) → v1.1 (calendar-aware) → v1.5 (ML-powered) |

**Why Life-Aware Audio is #1:** It's three features in a trench coat (Calendar + Study Tracks + Sonic Memory) but they share infrastructure and compound on each other. Together they answer the question no other audio app answers: "What does my LIFE need right now?" Not what does my body need (that's the core adaptive engine). What does my *life* need.

---

### TIER 2 — CHOPPING BLOCK (Ships only if Tier 1 is solid)

These make the app stickier and more shareable, but the app works without them. They ship IF there's bandwidth and IF Tier 1 is clean.

| Rank | Feature | Case FOR Keeping | Case FOR Cutting | Verdict |
|------|---------|-----------------|-----------------|---------|
| 5 | **Body Music** | Viral sharing mechanic. Each session produces a collectible. Creates a personal library users won't delete. | Generative audio is a massive engineering lift. The melodic layer already works with rule-based selection — making it fully generative from biometrics is a v2-level audio engine rewrite. The sharing angle is strong but the build cost is high. | **KEEP — but descoped.** v1: save session parameters for replay + basic export (a recording of what played, not generative composition). v1.5+: true biometric-generative melodic layer. Don't let this block launch. |
| 6 | **Neural Replay** | Retention + validation. Users SEE their progress. Shareable video content. | Requires 30+ days of data to be meaningful — can't deliver value early. The Monthly Neural Summary ("Wrapped") already covers similar ground with less engineering. Could be a fancy visualization over existing summary data rather than a separate feature. | **KEEP — but defer to v1.5.** By then there's enough user data. Build it as a premium upgrade to the existing Monthly Summary, not a separate system. |

---

### Summary Table

| Feature | Tier | Status | Ships In |
|---------|------|--------|----------|
| Calendar Intelligence | 1 — MUST SHIP | **Build it** | v1 (basic) → v1.1 (full) |
| Study Tracks | 1 — MUST SHIP | **Build it** | v1.1 |
| Sonic Memory | 1 — MUST SHIP | **Build it** | v1.1 (input) → v1.5 (learning) |
| Morning Brief | 1 — MUST SHIP | **Build it** | v1 (simple) → v1.1 (calendar) |
| Body Music | 2 — CHOPPING BLOCK | **Descoped** — save/replay only at v1, generative at v1.5+ | v1 (basic) → v1.5 (full) |
| Neural Replay | 2 — CHOPPING BLOCK | **Deferred** — premium Monthly Summary upgrade | v1.5 |

---

---

# Deep Dive: "Life-Aware Audio" — Calendar + Context + Sonic Memory

> The feature that makes BioNaural feel like it understands your life, not just your heart rate.

---

## The Big Idea

Most audio/focus apps are reactive — you open them when you need them. BioNaural should be **proactive and contextual**. It should understand what's coming in your life and prepare you for it, using the most powerful sensory trigger humans have: **sound tied to memory and emotion.**

Three interconnected systems:

1. **Calendar Intelligence** — sees your life, anticipates your needs
2. **Sonic Memory** — learns which sounds are emotionally meaningful to YOU
3. **Context Tracks** — creates purpose-built audio tied to specific life events

---

## Pillar 1: Calendar Intelligence

### How It Works

**Data source:** EventKit (on-device calendar access, same permission model as Reminders)

**Event analysis (all on-device):**
- Read upcoming events (rolling 7-day window)
- Classify events by likely stress/energy impact:
  - **High stress indicators:** keywords like "exam," "final," "presentation," "review," "deadline," "interview," "pitch," "defense"
  - **Moderate stress:** "meeting," "call," "sync," "standup," "1:1"
  - **Recovery opportunities:** gaps > 90 min between events, "lunch," "break"
  - **Energy events:** "workout," "gym," "run," "game," "practice"
- Learn from user patterns over time:
  - "Eric's HR spikes 15 bpm before events with 'client' in the title"
  - "Mondays with 5+ meetings correlate with poor Sleep session outcomes that night"
  - "The 48 hours before events tagged 'deadline' show elevated resting HR"

**Proactive actions:**
- Morning Brief incorporates calendar: "3 meetings before noon, then a 2-hour gap. Save your Focus session for 1 PM."
- Pre-event preparation: "Presentation in 90 minutes. A 15-min Relaxation session now would bring your HR down to your optimal pre-performance zone."
- Post-event recovery: "That was a 2-hour client call. Your HR is still elevated. 10-min Relaxation?"
- Exam prep: "Finals week starts Monday. Starting Thursday, we'll shift your evening sessions to Sleep mode with extended theta ramps."

### The Notification

This is where it gets sticky:

```
[Push notification, 90 minutes before a tagged high-stress event]

"Exam in 90 minutes. We made something for you."

[Opens to a pre-built session card]

Your Exam Prep Session
15 min | Focus → Relaxation bridge
Carrier: 380 Hz (your optimal alert-but-calm frequency)
Ambient: Library Rain (your highest-performing focus sound)
Built from your last 12 study sessions.

[Start Now]        [Save for Later]
```

The notification doesn't say "time to meditate." It says "we made something for you." That's a gift, not a nag. The session is already configured — zero decisions required.

### Calendar Pattern Learning (Over Time)

After 30+ days with calendar access:

| Pattern Detected | App Response |
|---|---|
| HR always elevated morning of events with "interview" | Pre-suggest a Relaxation session the night before AND morning of |
| Focus sessions before "deadline" events have 40% higher completion rate | "Deadline Friday. Your best prep window is Wednesday 2-4 PM based on your patterns." |
| Sleep quality drops 2 days before travel events | "Trip to NYC on Thursday. Starting tonight, we'll extend your Sleep sessions by 5 min." |
| Recovery sessions after "all-hands" meetings show fastest HR normalization | Auto-suggest 8-min Relaxation immediately after recurring all-hands |

### Privacy Model

- All calendar processing happens on-device (EventKit is local)
- No event titles or details ever leave the device
- Only derived patterns are stored (not raw calendar data)
- User can see exactly what the app has learned: "Settings > Calendar Insights > What BioNaural Knows"
- Full opt-out at any time, with pattern data deletion

---

## Pillar 2: Sonic Memory — Sound as Emotional Anchor

### The Science of Sound + Memory

Sound is the most powerful memory trigger after smell:
- **Auditory-evoked autobiographical memories** are faster and more emotionally vivid than visual cues (Belfi et al., 2016)
- **Music-evoked nostalgia** activates the reward system (nucleus accumbens) and reduces cortisol
- **State-dependent learning:** information encoded in a specific auditory environment is better recalled in that same environment (Smith & Vela, 2001)
- **The "Proust effect" for sound:** a specific ambient texture can instantly transport someone to a mental state they associate with it

### How It Works

**Onboarding (optional, earned after 5+ sessions):**

```
"Want to make BioNaural even more personal?"

Tell us about a sound that means something to you:
- A place where you feel calm (beach house, grandma's kitchen, library)
- A song that helps you focus
- A sound from a memory you love
- A type of music that puts you in the zone

[Text input or voice memo]
```

The app doesn't try to recreate the exact sound. It extracts the **sonic qualities** — warmth, rhythm, texture, frequency range — and incorporates them into the melodic and ambient layers.

**Examples:**

| User Input | What BioNaural Does |
|---|---|
| "Rain on a tin roof at my cabin" | Selects rain ambient with metallic resonance, adds subtle low-frequency warmth. Tags this profile as "Cabin." |
| "Lo-fi hip hop beats" | Adjusts melodic layer: slightly swung rhythm, vinyl crackle texture, muted piano voicings, slower tempo |
| "The library at my university was always quiet with a low hum" | Reduces ambient to near-silence, adds subtle HVAC-style brown noise, keeps melodic layer minimal |
| "My mom used to play Debussy when I was studying" | Shifts melodic palette toward impressionistic piano — whole-tone intervals, sustained pedal, gentle dynamics |
| "Ocean waves at our honeymoon spot" | Prioritizes ocean ambient, adds warmth to carrier frequency, stores as emotionally significant for Relaxation |

**Over time, the app builds a "Sonic Profile":**
- Which ambient textures correlate with the user's best biometric outcomes
- Which melodic qualities (tempo, key, instrument, complexity) produce the deepest focus or fastest relaxation
- Which user-described sounds map to which audio parameters
- Emotional associations: "Cabin Rain" = safety/calm, "Lo-fi" = productive flow

### Why This Matters

When the app uses a sound the user has an emotional connection to, the biometric response is faster and deeper. The user isn't just hearing pleasant audio — they're hearing a **trigger for a specific emotional state they've already experienced.** This is the difference between a generic meditation app and an app that feels like it *knows you.*

---

## Pillar 3: Context Tracks — Purpose-Built Audio for Life Events

### The Concept

Combine Calendar Intelligence + Sonic Memory + Biometric Learning to create tracks that are built for a specific purpose in the user's life.

### Track Types

**Study Track (State-Dependent Learning)**

The most scientifically grounded context track:

- User tells the app: "I'm studying for the bar exam" (or the app infers from calendar: "Bar Exam" event in 3 weeks)
- The app creates a consistent auditory environment for all study sessions:
  - Same ambient texture every session (state-dependent learning requires consistency)
  - Same carrier frequency range
  - Same melodic palette
  - Biometric adaptation still active (the audio responds to their body), but the sonic signature stays constant
- **On exam day:** The app suggests playing the Study Track during the exam (or right before)
- The consistent auditory cue triggers state-dependent recall — the brain re-enters the mental state it was in during encoding

**The science:**
- Godden & Baddeley (1975): Divers who learned words underwater recalled them better underwater
- Smith & Vela (2001): Meta-analysis confirms context-dependent memory across modalities
- Grant et al. (1998): Matching auditory study/test conditions improved recall by 15–20%
- **The implication:** If every study session has the same sonic fingerprint, hearing that fingerprint during the exam primes recall

**How the user experiences it:**

```
[3 weeks before exam]
Morning Brief: "Bar Exam in 21 days. Want to create a Study Track?
Same sonic environment every session — builds auditory recall anchors."

[Start Study Track Setup]

Step 1: What subject? (free text: "Bar Exam — Constitutional Law")
Step 2: Pick your base sound (from Sonic Memory favorites or new selection)
Step 3: How long are your study sessions? (30 min / 60 min / 90 min / custom)

Your Study Track is ready. Use it every session for maximum recall anchoring.
```

```
[Exam morning]
Push notification: "Bar Exam today. Your Study Track is ready.
Play it on the way there or during the exam.
Your brain knows this sound — let it work for you."
```

**Pre-Performance Track**

For presentations, interviews, competitions:
- Builds a track from the user's most successful Energize + Focus sessions
- Calibrated to the user's optimal "alert but calm" biometric zone
- Morning Brief: "Pitch meeting at 2 PM. Your Confidence Track is ready — 12 min, tuned to your pre-performance sweet spot."

**Recovery Track**

For post-stress events:
- Detects elevated biometrics after a calendar event
- Suggests a short Relaxation session using the user's most effective calming sounds
- "That 90-minute board meeting just ended. Your Recovery Track is queued — 8 minutes to baseline."

**Sleep Prep Track**

For travel, time zone changes, or pre-event anxiety:
- Extended theta ramp + user's most effective sleep sounds
- Adjusts timing based on calendar (early morning flight = earlier sleep session suggestion)
- "Flight to London at 6 AM. Starting your Sleep Prep Track 30 min earlier tonight."

---

## The Notification & Delivery System

### Push Notification Philosophy

**Never nag. Always gift.**

Every notification should feel like the app did work FOR you, not that it's asking something OF you:

| Bad (Nag) | Good (Gift) |
|---|---|
| "Time for your daily session!" | "We noticed your HR is elevated. Made you something." |
| "Don't forget to meditate!" | "Exam in 90 min. Your Study Track is ready." |
| "You haven't used BioNaural in 3 days" | "Rough sleep last night. A 10-min Relaxation would help — here's one built from your best sessions." |
| "Complete your streak!" | (No streaks. Ever.) |

### Notification Types (User-Controlled)

| Type | Trigger | Default | Content |
|---|---|---|---|
| Morning Brief | Daily at learned wake time | ON | Overnight synthesis + daily prescription |
| Pre-Event Prep | 60–90 min before high-stress calendar event | ON | Pre-built session recommendation |
| Post-Event Recovery | Elevated biometrics after calendar event | OFF | Quick recovery session suggestion |
| Study Track Reminder | During active study period (user-defined) | ON | "Study session? Your [Subject] Track is ready." |
| Weekly Insight | Sunday evening | ON | One surprising pattern from the week |
| Monthly Replay | 1st of month | ON | Neural Replay is ready to view |

### Email Option (Weekly Digest)

For users who prefer email over push:
- Weekly summary email with key biometric trends
- Upcoming calendar-aware recommendations for the week
- One insight, one recommendation, one encouragement
- Beautiful, minimal design — consistent with app aesthetic
- Links deep into the app for each recommendation

---

## How All Three Pillars Connect

```
Calendar Intelligence detects: "Final Exam — Organic Chemistry" in 2 weeks
    ↓
App creates Study Track using Sonic Memory:
  "Library Rain" ambient (user's described calm-focus sound)
  + Melodic palette from user's highest-performing Focus sessions
  + Consistent carrier at 340 Hz (user's optimal focus frequency, learned over 30 sessions)
    ↓
Every study session uses this track — biometric adaptation still active,
but the sonic signature stays constant (state-dependent learning)
    ↓
Morning Brief each day: "Exam in [X] days. Study Track session?"
Pre-session: "2-hour study block? Your Organic Chem Track is ready."
    ↓
Exam morning notification: "Today's the day. Play your Study Track
on the way there. Your brain knows this sound."
    ↓
Post-exam: "How'd it go? Here's a Recovery Track. You earned it."
    ↓
Body Music saves the exam-morning session as a unique track
Neural Replay at month-end shows the entire exam prep journey
```

---

## Privacy & Permissions

### Calendar
- EventKit access (on-device only)
- No event data leaves the device
- Only derived patterns stored (not raw event titles)
- Transparent: "Settings > What BioNaural Knows > Calendar Patterns"
- Full opt-out with data deletion

### Sonic Memory
- User-provided descriptions stored on-device
- Never transmitted to any server
- User can view, edit, or delete any sonic memory
- No audio recordings stored (only extracted parameters)

### Notifications
- All notification types independently toggleable
- "Quiet Mode" disables all proactive notifications
- Notification frequency cap: max 3 per day (Morning Brief + 2 contextual)
- Never notify during an active session or Focus Mode (iOS)

---

## Technical Requirements

### New Frameworks
- **EventKit** — calendar read access (similar permission model to HealthKit)
- **UserNotifications** — scheduled + contextual push notifications
- **BackgroundTasks** — overnight processing for Morning Brief generation
- **NaturalLanguage** — on-device text classification for calendar event analysis

### Data Models

```swift
// Calendar Intelligence
struct CalendarInsight {
    let eventTitle: String  // stored on-device only, never transmitted
    let eventDate: Date
    let stressClassification: StressLevel  // .low, .moderate, .high, .critical
    let suggestedMode: FocusMode
    let suggestedTiming: DateInterval  // when to run the prep session
    let confidence: Double  // 0-1, based on pattern history
}

// Sonic Memory
struct SonicMemory: Identifiable {
    let id: UUID
    let userDescription: String  // "Rain on a tin roof at my cabin"
    let extractedParameters: SonicParameters  // warmth, rhythm, texture mappings
    let emotionalAssociation: EmotionalTag  // .calm, .focused, .energized, .nostalgic
    let associatedMode: FocusMode?
    let biometricCorrelation: Double?  // how well this sound predicts good outcomes
    let dateCreated: Date
}

// Context Track
struct ContextTrack: Identifiable {
    let id: UUID
    let name: String  // "Organic Chemistry Study Track"
    let purpose: TrackPurpose  // .study, .prePerformance, .recovery, .sleepPrep
    let linkedCalendarEvent: String?  // event keyword association
    let sonicProfile: SonicParameters  // locked audio parameters for consistency
    let sessionHistory: [UUID]  // sessions that used this track
    let createdDate: Date
    let activeUntil: Date?  // nil = permanent, date = auto-archive after event
}
```

### Integration Points

- **Morning Brief** reads CalendarInsight + overnight HealthKit + session history
- **Context Track creation** pulls from SonicMemory + learned biometric preferences
- **Notification scheduler** reads calendar events + creates pre/post event notifications
- **SessionOutcome** records which Context Track was used (for learning loop)
- **Study Track consistency** overrides normal sound selection — locks ambient + melodic palette

---

## Competitive Moat

No competitor has this combination:

| Capability | Brain.fm | Endel | Calm | BioNaural |
|---|---|---|---|---|
| Calendar-aware recommendations | No | No | No | **Yes** |
| Sound-memory personalization | No | No | No | **Yes** |
| State-dependent study tracks | No | No | No | **Yes** |
| Biometric + calendar + sound fusion | No | No | No | **Yes** |
| Proactive "gift" notifications | No | Shallow | Generic | **Deep + contextual** |

This isn't just a feature — it's a new category: **Life-Aware Audio.**
