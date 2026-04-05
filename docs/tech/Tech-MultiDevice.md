# BioNaural — Multi-Device Biometric Strategy

> Use whatever the user has: Watch, AirPods, iPhone, Oura Ring — or nothing at all.

---

## The Hierarchy

| Tier | Devices | Capability | % of Full Experience |
|------|---------|-----------|---------------------|
| **1 (Full)** | iPhone + Watch + AirPods | Real-time HR/HRV + activity + head tracking | 100% |
| **2** | iPhone + Watch | Real-time HR/HRV + activity | ~85% |
| **3** | iPhone + AirPods | Activity + head stillness (no HR) | ~50% |
| **4** | iPhone only | Activity + manual calibration | ~25% |

**Oura Ring** is a cross-tier enhancer — adds pre-session context (readiness, HRV baseline, sleep quality) to any tier, but never provides real-time data.

---

## What Each Device Provides

### Apple Watch (The Critical Wearable)

| Signal | API | Rate | Notes |
|--------|-----|------|-------|
| **Heart rate** | `HKQuantityType(.heartRate)` via `HKWorkoutSession` | ~1 Hz | Requires active workout session. The primary adaptation signal. |
| **HRV (SDNN)** | `HKQuantityType(.heartRateVariabilitySDNN)` | Every 3-7 min | Periodic, not real-time. Use as session-level modifier. |
| **Resting HR** | `HKQuantityType(.restingHeartRate)` | Daily | Baseline calibration. |
| **Activity** | `CMMotionActivityManager` | Event-driven (~3-8s) | stationary/walking/running/cycling/automotive |
| **Wrist motion** | `CMDeviceMotion` on watchOS | Up to 100 Hz | Stillness detection, fidgeting, typing |
| **SpO2** | `HKQuantityType(.oxygenSaturation)` | Every 1-2 hours | Too infrequent for real-time. Background context. |
| **Skin temperature** | `HKQuantityType(.appleSleepingWristTemperature)` | Periodic | Context signal. Rises with stress/exercise. |
| **ECG** | `HKElectrocardiogramType` | Manual only (30s) | Can't initiate from third-party app. Accurate HRV from stored recordings. |

### AirPods (The Underutilized Signal)

`CMHeadphoneMotionManager` (iOS 14+). Works with AirPods Pro, AirPods Max, AirPods 4 (ANC).

| Signal | Data | Rate | Inference |
|--------|------|------|-----------|
| **Head orientation** | `CMDeviceMotion.attitude` (roll/pitch/yaw, quaternion) | ~10-20 Hz | Head tilt, looking down, lying down |
| **Head stillness** | Derived from `userAcceleration` variance | Computed | **Excellent proxy for relaxation depth.** Still head = deep state. |
| **Walking/running** | Periodic vertical acceleration in `userAcceleration.y` | ~10-20 Hz | 1.5-2.5 Hz = walking, >2.5 Hz = running |
| **Nodding/shaking** | Pitch/yaw oscillation | ~10-20 Hz | Potential UI-free interaction |
| **Drowsiness** | Sustained pitch/roll drift | Slow | Head drooping = falling asleep |

**No health sensors currently** (no HR, no temperature). Apple has patents for in-ear PPG but nothing shipped as of early 2026.

**Key insight:** Head stillness during a focus/meditation session is a surprisingly strong signal. If the user's head is perfectly still for 10+ minutes, they're deeply engaged. If head motion increases, they're restless — the audio should respond.

### iPhone (Always Available)

| Signal | API | Rate | Inference |
|--------|-----|------|-----------|
| **Activity type** | `CMMotionActivityManager` | Event-driven | stationary/walking/running/cycling/automotive |
| **Steps + cadence** | `CMPedometer` | ~1 Hz during walking | Step rate, walking pace |
| **Device motion** | `CMDeviceMotion` via `CMMotionManager` | Up to 100 Hz | Phone pickup frequency, fidgeting (phone in pocket) |
| **Camera PPG** | Custom via `AVCaptureSession` | One-time measurement | Finger-on-camera HR: ±2-5 BPM accuracy. 30-sec measurement. |
| **Barometer** | `CMAltimeter` | Continuous | Altitude changes, airplane detection |
| **Ambient sound** | `SNClassifySoundRequest` (SoundAnalysis) | Continuous | Breathing detection category exists but unreliable |

**Background access:** CoreMotion continues during `audio` background mode on iOS 16+ as long as audio session is active.

---

## Sensor Fusion: The UserState Object

All device signals fuse into a single state object updated every 1-2 seconds:

```swift
struct UserState {
    let heartRate: Double?           // Watch HR (primary adaptation signal)
    let hrv: Double?                 // Watch SDNN (session-level modifier)
    let activityType: ActivityType   // .stationary, .walking, .running, .driving
    let headStillness: Double        // 0.0 (active) to 1.0 (perfectly still) — AirPods
    let cadence: Double?             // Steps/sec — pedometer
    let stressEstimate: Double?      // 0.0-1.0 composite from HR+HRV+motion
    let confidence: Double           // 0.0-1.0 overall confidence
    let sensorTier: SensorTier       // .full, .watchAndPhone, .airPodsAndPhone, .phoneOnly
    let timestamp: Date
}
```

### Stress Estimation (When Watch HR + HRV Available)

| HR | HRV | Motion | Head | Inference | Stress |
|----|-----|--------|------|-----------|--------|
| Low (<70) | High (>50ms) | Stationary | Still | **Relaxed** | 0.1-0.3 |
| Moderate (70-90) | Moderate (20-50ms) | Some motion | Some motion | **Neutral** | 0.4-0.6 |
| High (>90 at rest) | Low (<20ms) | Fidgeting | Restless | **Stressed** | 0.7-0.9 |
| Very high + stationary | Very low | Minimal | Still | **Acute anxiety** | 0.9+ |
| High + running | Any | Running detected | Moving | **Exercise, not stress** | Override |

Activity type overrides stress inference — elevated HR during running is normal, not stress.

---

## Tier Behaviors

### Tier 1: Full Suite (Watch + AirPods + iPhone)

```
Primary biometric:  Watch HR (1 Hz) + Watch HRV (periodic)
Primary activity:   Watch CMMotionActivity
Head tracking:      AirPods CMHeadphoneMotionManager
Ambient context:    iPhone time-of-day, barometer
```

Full biometric adaptation. Head stillness adds a second dimension — the audio responds to both physiology (HR/HRV) and behavior (motion/stillness).

### Tier 2: Watch + iPhone (No AirPods)

Same as Tier 1 minus head tracking. No spatial audio anchoring. ~85% capability — HR/HRV carry most of the signal.

### Tier 3: AirPods + iPhone (No Watch)

**No continuous HR.** The system operates in "activity-adaptive" mode:
- Activity type (walking → energizing, stationary → relaxation/focus)
- Head stillness as primary relaxation depth proxy
- Time of day as a prior (evening → sleep, morning → focus)
- Session duration heuristic (still for 20 min → deep state, don't disrupt)
- Offer camera PPG at session start for one-time HR baseline

~50% of full suite. Useful but less personalized.

### Tier 4: iPhone Only (No Wearables)

**Minimal biometric input.** BioNaural operates as an enhanced traditional binaural beats app:
1. Optional camera PPG at session start (30 sec, finger on camera) for baseline HR
2. `CMMotionActivity` for state changes (stationary vs. walking)
3. Phone-pickup detection via accelerometer spikes → infer restlessness
4. Manual self-report option ("I'm feeling anxious" → stress-relief protocol)
5. Time-based session arc (higher frequency → gradually lower over session duration)

~25% of full suite. Still functional, still valuable — just not adaptive.

---

## Runtime Tier Detection

```swift
class SensorAvailabilityManager {
    var watchHRAvailable: Bool {
        WCSession.default.isReachable && watchCompanionIsStreaming
    }
    var airPodsMotionAvailable: Bool {
        CMHeadphoneMotionManager.isDeviceMotionAvailable()
    }
    var phoneMotionAvailable: Bool {
        CMMotionActivityManager.isActivityAvailable()
    }
    var currentTier: SensorTier {
        if watchHRAvailable && airPodsMotionAvailable { return .full }
        if watchHRAvailable { return .watchAndPhone }
        if airPodsMotionAvailable { return .airPodsAndPhone }
        return .phoneOnly
    }
}
```

**Tier can change mid-session** (AirPods removed, Watch loses connection). When a sensor drops out: hold last known state for 30 seconds, then gracefully degrade to the lower tier's behavior. Never interrupt audio.

---

## AirPods Connection/Disconnection

```swift
class HeadMotionHandler: NSObject, CMHeadphoneMotionManagerDelegate {
    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        // AirPods connected — upgrade tier, start head tracking
    }
    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        // AirPods removed — downgrade tier, stop head tracking
    }
}
```

---

## Camera PPG (No-Watch HR Measurement)

For Tier 3 and 4 users who want a heart rate baseline:

1. User places fingertip over rear camera with flashlight on
2. Camera captures pulsatile blood volume changes (red channel oscillates with each heartbeat)
3. 30 seconds of capture → bandpass filter (0.7-4 Hz) → peak detection or FFT → BPM
4. Accuracy: ±2-5 BPM in controlled conditions

**APIs:** `AVCaptureSession` + `AVCaptureVideoDataOutput` + `vDSP` (Accelerate framework) for signal processing. No Apple-provided HR-from-camera API exists — custom implementation required.

**Use case:** "Check your heart rate" button at session start. One-time measurement, not continuous. Sets the session baseline for users without a Watch.

---

## Oura Ring Integration (Cross-Tier Enhancer)

Oura adds context to any tier but never provides real-time data:

| Data | How to Access | Use |
|------|-------------|-----|
| Readiness score | Oura API v2 or HealthKit | "Your readiness is 62 — recommending relaxation" |
| HRV baseline (RMSSD) | Oura API or HealthKit | More accurate than Watch SDNN. Session calibration. |
| Sleep quality | HealthKit `sleepAnalysis` | "You only got 5h — try sleep prep tonight" |
| Resting HR | HealthKit | Baseline normalization |

**Phase 1:** Read from HealthKit (works with any Oura user who has sync enabled, no Oura API needed).
**Phase 2:** Direct Oura API integration for readiness scores and richer data.

---

## Permissions Required

| Permission | Purpose | Required For |
|-----------|---------|-------------|
| HealthKit (read) | HR, HRV, resting HR, sleep, SpO2 | Watch biometrics, Oura data |
| HealthKit (write) | Mindful sessions, workout sessions | Session logging |
| Motion & Fitness | CMMotionActivity, CMPedometer | Activity detection (all tiers) |
| Microphone | Breathing detection (optional) | Experimental, not recommended |
| Camera | Camera PPG (optional) | No-Watch HR measurement |

**Design onboarding to explain why each permission matters.** Handle denials gracefully — app works at every tier, just with less personalization.

---

## What This Means for BioNaural

1. **Apple Watch is the primary biometric source.** Design the premium experience around it. Market it as the differentiator.
2. **AirPods head tracking is free bonus data.** Head stillness during sessions is a genuinely useful signal no competitor uses.
3. **iPhone-only mode must still be good.** Time-based arcs, activity detection, and optional camera PPG make it a better-than-average binaural beats app even without wearables.
4. **Oura/smart rings are context providers, not real-time sources.** "Your Oura says you're fatigued → we set up a recovery session" is a compelling feature.
5. **The tier system degrades gracefully.** Users get the best experience their hardware allows, with clear messaging about what each device adds.
6. **No sensor = no blocker.** BioNaural works at every tier. Biometric adaptation is premium, not required.
