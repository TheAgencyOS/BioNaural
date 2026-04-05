# BioNaural — HealthKit Research

> What exists in AIZEN, what's reusable, and what needs to be built new.

---

## AIZEN's HealthKit Architecture

AIZEN has a production-grade HealthKit integration across 20 files and ~5,000+ lines. The core pattern is a **singleton manager with protocol** (`HealthKitManager.shared`), all queries are read-only and on-demand, data stays on-device, and everything degrades gracefully when HealthKit is unavailable.

**Key file:** `BLOC/AIZEN/AIZEN/Services/HealthKitManager.swift` (696 lines)

---

## What AIZEN Reads from HealthKit

| Data Type | Identifier | Query Style | Notes |
|-----------|-----------|-------------|-------|
| Sleep hours | `sleepAnalysis` | On-demand, 24hr lookback | Sums asleep stages only (core, deep, REM, unspecified) |
| Sleep stages | `sleepAnalysis` | On-demand | Returns array of stage + duration |
| Weekly sleep avg | `sleepAnalysis` | On-demand, 7-day | Groups by night, averages |
| HRV (SDNN) | `heartRateVariabilitySDNN` | On-demand, 24hr lookback | Latest sample, milliseconds |
| Resting HR | `restingHeartRate` | On-demand, 48hr lookback | Latest sample, bpm |
| Steps | `stepCount` | On-demand, cumulative today | Uses HKStatisticsQueryDescriptor |
| Active days/week | `stepCount` | On-demand, 7-day | Counts days with 1000+ steps |
| Mindful minutes | `mindfulSession` | On-demand, today + weekly | Sums duration of sessions |
| Water intake | `dietaryWater` | On-demand, today + 7-day | Milliliters, cumulative |
| State of Mind | `stateOfMind` | Write only | Valence, label, association |

## What AIZEN Writes to HealthKit

| Data Type | When | Details |
|-----------|------|---------|
| Workouts | Move ritual completion | HKWorkoutBuilder with distance, calories, steps, GPS route |
| Mindful sessions | Breathe ritual completion | Category sample with start/end times |
| State of Mind | Any ritual completion | Mood valence mapped to ritual type (focus=focused, breathe=calm, etc.) |
| Water | Manual log | 250ml increments |

---

## Reusable for BioNaural

### Direct Copy (Pattern + Code)

| Component | Why It Fits | File |
|-----------|------------|------|
| HealthKitManager singleton pattern | Same authorization flow, same on-device architecture | `Services/HealthKitManager.swift` |
| HealthKitManaging protocol | Enables mock injection for testing | `Services/Protocols/HealthKitManaging.swift` |
| HRV (SDNN) query | Core biometric for stress/recovery detection in adaptive engine | `HealthKitManager.swift:380-387` |
| Resting HR query | Baseline calibration for the adaptive engine | `HealthKitManager.swift:390-397` |
| Generic latest-quantity helper | Reusable for any HKQuantityType query | `HealthKitManager.swift:645-669` |
| Workout save (HKWorkoutBuilder) | Workout mode sessions should save to Health | `HealthKitManager.swift:86-175` |
| Mindful session save | Meditation mode sessions should save to Health | `HealthKitManager.swift:241-261` |
| Calorie estimation (MET-based) | Workout mode calorie tracking | `HealthKitManager.swift:215-239` |
| State of Mind logging | Log focus state post-session | `HomeView+Actions.swift:73-80` |
| Health summary builder | Context for any future AI features | `HealthKitManager.swift:607-641` |
| MockHealthKitManager | Testing from day one | `AizenTests/Mocks/MockHealthKitManager.swift` |
| HealthKit onboarding prompt | Permission request UI pattern | `Components/HealthKitOnboardingPrompt.swift` |
| Graceful degradation pattern | Works without Watch, works without permissions | Throughout |

### Adapt (Pattern Reusable, Logic Changes)

| Component | What Changes | Why |
|-----------|-------------|-----|
| Health correlation engine | AIZEN correlates rituals to sleep/HRV. BioNaural would correlate session modes to focus outcomes. | Different data model, same engine pattern |
| State of Mind labels | AIZEN maps ritual types (breathe=calm). BioNaural maps focus modes (deep work=focused, workout=energized). | Different label mapping |
| WatchConnectivity manager | AIZEN sends task context. BioNaural sends biometric data. | Different payload, same communication pattern |

---

## What Needs to Be Built New

These are the critical gaps between AIZEN's on-demand approach and BioNaural's real-time requirements.

### 1. Real-Time Heart Rate Streaming

**Why:** The adaptive audio engine needs continuous HR data during sessions (every 1-5 seconds), not single on-demand queries.

**Approach:** `HKAnchoredObjectQuery` or `HKObserverQuery` on `heartRate` type, running for the duration of a session. Alternatively, run an `HKWorkoutSession` on the Watch to unlock high-frequency HR sampling.

**Key decision:** Running an HKWorkoutSession on the Watch provides the best HR frequency (1-5 sec updates) but shows workout indicators on the Watch face. For Deep Work/Study modes, this might feel wrong. Options:
- Use HKWorkoutSession for Workout mode (natural fit)
- Use observer queries for non-workout modes (less frequent but no workout UI on Watch)
- Or accept the workout indicator as a tradeoff for better data across all modes

### 2. Watch Companion App with Live HR Pipeline

**Why:** Real-time HR data originates on the Watch. It needs to reach the iPhone's audio engine with minimal latency.

**Architecture:**
```
Watch (HR sensor) → WatchOS App (HKWorkoutSession)
    → WatchConnectivity (sendMessage for real-time)
    → iPhone App (Biometric Processor)
    → Adaptive Audio Engine (AVAudioEngine)
```

**Latency target:** < 3 seconds from heartbeat to audio adaptation. WatchConnectivity's `sendMessage` (real-time) achieves sub-second delivery when both apps are active.

**AIZEN reference:** `WatchConnectivityManager.swift` handles the communication channel. The payload changes from task context to biometric data, but the infrastructure is the same.

### 3. HRV During Sessions

**Challenge:** Apple Watch doesn't provide continuous real-time HRV like it does HR. HRV (SDNN) is sampled periodically (roughly every few hours in background, more during sleep).

**Options:**
- Use the latest HRV sample as a session baseline (available at session start)
- Compute approximate HRV from raw RR intervals if available during a workout session
- Accept that HRV is a slower-moving signal — use it for session-level adaptation, not second-by-second changes

**Recommendation:** Use HR for real-time adaptation (fast signal, 1-5 sec updates). Use HRV as a session-level modifier (sets the baseline tone at session start, recalculated every few minutes if new samples arrive).

### 4. Background Audio + HealthKit Coexistence

**Challenge:** The iPhone app needs to run background audio (AVAudioEngine) while simultaneously receiving HealthKit data from the Watch.

**Requirements:**
- `UIBackgroundModes`: `audio` (for AVAudioEngine), `bluetooth-central` (for Watch communication)
- The audio session must be configured for `.playback` category with `.mixWithOthers` option if user wants to combine with other audio
- HealthKit queries can run while the app is in background audio mode

### 5. Session-to-HealthKit Mapping

What BioNaural sessions should write back to HealthKit:

| Mode | HealthKit Write | Type |
|------|----------------|------|
| Deep Work | Mindful session | `HKCategoryType.mindfulSession` |
| Study | Mindful session | `HKCategoryType.mindfulSession` |
| Meditation | Mindful session | `HKCategoryType.mindfulSession` |
| Workout | Workout | `HKWorkoutType` with activity type + metrics |
| All modes | State of Mind | Mode-specific valence + label |

---

## Data Types BioNaural Needs (Full List)

### Read (from HealthKit)

| Type | Priority | Real-Time? | Purpose |
|------|----------|-----------|---------|
| `heartRate` | Critical | Yes (during sessions) | Primary signal for adaptive engine |
| `heartRateVariabilitySDNN` | High | No (session baseline) | Stress/recovery state, sets tone |
| `restingHeartRate` | Medium | No (daily baseline) | Calibrate what "calm" means for this user |
| `activeEnergyBurned` | Medium | During workout mode | Workout intensity tracking |
| `stepCount` | Low | No | Session summary context |
| `oxygenSaturation` | Future | No | SpO2 trends (limited access, Series 6+) |
| `respiratoryRate` | Future | No | Sleep-only currently, may expand |

### Write (to HealthKit)

| Type | When | Purpose |
|------|------|---------|
| `mindfulSession` | Non-workout session end | Log focus/meditation time |
| `HKWorkout` | Workout session end | Full workout with metrics |
| `stateOfMind` | Any session end | Emotional state post-session |

---

## Technical Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Watch-iPhone latency spikes | Medium | Buffer 2-3 HR samples. Audio engine interpolates between samples. Graceful degradation to preset behavior if data gaps > 10 sec. |
| HKWorkoutSession showing workout UI on Watch during Deep Work | Low | Use observer queries for non-workout modes. Accept slightly lower HR frequency. |
| Battery drain from continuous HR + audio | Medium | Session-based (30-120 min cap). Warn user of expected battery impact. |
| HealthKit authorization denied | Low | App works without biometrics — falls back to smart presets. AIZEN's graceful degradation pattern handles this. |
| Background audio interruptions | Medium | Configure AVAudioSession correctly. Handle interruption notifications. Resume gracefully. |

---

## Summary

AIZEN provides ~70% of the HealthKit infrastructure BioNaural needs. The authorization flow, query patterns, workout saving, mindful session logging, mock testing, and graceful degradation are all production-ready and portable.

The 30% that's new is the real-time pipeline: live HR streaming from Watch → iPhone → audio engine. This is the engineering core of BioNaural and the piece that makes the adaptive engine possible. AIZEN's WatchConnectivity infrastructure provides the communication channel — the payload just changes from task data to biometric data.
