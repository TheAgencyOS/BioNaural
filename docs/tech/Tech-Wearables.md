# BioNaural — Wearable Integration Strategy

> Apple Watch is primary. HealthKit is the silent universal adapter. Polar BLE is the real-time wildcard.

---

## The Landscape

| Wearable | Public API | Real-Time HR to iOS | HealthKit Sync | Priority |
|----------|-----------|-------------------|---------------|----------|
| **Apple Watch** | HealthKit + WatchKit | Yes (1 Hz via HKWorkoutSession) | Native | **Critical** |
| **Oura Ring** | REST API v2 (cloud) | No (minutes-hours delay) | Yes (HR, HRV, sleep, SpO2) | High (context) |
| **WHOOP** | REST API (dev platform) | No (batch/historical) | Yes (HR, HRV, sleep, workouts) | Medium |
| **Polar** | AccessLink API + **BLE SDK** | **Yes (real-time HR + RR intervals)** | Yes (HR, sleep, workouts) | **High (real-time)** |
| **Garmin** | Health API (B2B partnership required) | No (BLE broadcast on some models) | Yes (HR, sleep, workouts — no HRV) | Medium |
| **Fitbit** | Web API (REST, mature) | No | **No (does NOT write to HealthKit)** | Low-Medium |
| **Amazfit/Zepp** | No public API | No | Yes (basic: HR, steps, sleep) | Low |
| **Coros** | No API | No | Yes (HR, workouts, sleep) | Low |
| **Samsung Galaxy Watch** | Android-only SDK | No on iOS | Effectively none on iOS | Skip |
| **Biostrap** | Enterprise/research only | No | Inconsistent | Skip |

---

## HealthKit as Universal Adapter

**The politically safe, technically simple approach.** Read from HealthKit and automatically support any wearable that syncs to it.

| HealthKit Data Type | Written By |
|-------------------|-----------|
| Heart Rate | Apple Watch, Oura, WHOOP, Garmin, Polar, Amazfit, Coros |
| HRV (SDNN) | Apple Watch, Oura, WHOOP (recent) |
| Sleep (with stages) | Apple Watch, Oura, WHOOP, Garmin, Polar |
| SpO2 | Apple Watch, Oura |
| Resting HR | Apple Watch, Oura, Garmin |
| Workouts | All except Oura |

**Covers ~80% of wearable users for free with zero per-device code.** The notable gap: Fitbit does NOT write to HealthKit.

**Limitation:** HealthKit data is not real-time. It arrives after the source app syncs — minutes to hours delay. No proprietary scores (recovery, strain, stress, body battery).

---

## Real-Time Sources (For Live Biofeedback)

Only three paths give real-time HR to an iOS app:

### 1. Apple Watch (Primary)
- `HKWorkoutSession` → ~1 Hz HR via `HKAnchoredObjectQuery`
- `WCSession.sendMessage` → 50-200ms to iPhone
- End-to-end: ~1.2-1.5 seconds
- **The premium BioNaural experience**

### 2. Polar BLE SDK (Secondary)
- **Open-source iOS SDK** (`polarofficial/polar-ble-sdk` on GitHub)
- Streams real-time HR AND raw RR intervals (beat-to-beat for true HRV calculation)
- Supported devices: H10 chest strap (medical-grade ECG), H9, Verity Sense (optical armband), OH1
- Direct BLE connection — no companion app required
- **H10 is gold-standard HR for $50-90**
- MIT license, free to use

```swift
// Polar SDK example
let api = PolarBleApiDefaultImpl.polarImplementation(DispatchQueue.main, features: [.hr, .deviceInfo])
api.startHrStreaming(deviceId).subscribe(onNext: { hrData in
    // hrData.hr — heart rate in BPM
    // hrData.rrsMs — array of RR intervals in milliseconds (for HRV)
})
```

### 3. Standard BLE Heart Rate Service (0x180D)
- Many chest straps and some watches broadcast standard BLE HR
- Read via `CoreBluetooth` on iOS
- Covers: Polar (also), Garmin (some models), Wahoo, Scosche, generic HR monitors
- No SDK needed — standard BLE GATT profile

---

## Integration Strategy (Phased)

### Phase 1: Launch
- **Apple HealthKit** — read HR, HRV, sleep, SpO2 from any source
- **Apple Watch real-time** — `HKWorkoutSession` for live biofeedback
- Covers: Apple Watch, Oura, WHOOP, Garmin, Polar, Amazfit, Coros (via HealthKit)

### Phase 2: Expand Real-Time
- **Standard BLE HR (0x180D)** via CoreBluetooth — supports any broadcasting HR monitor
- **Polar BLE SDK** — richer data (RR intervals for real-time HRV). Polar H10/Verity Sense become recommended accessories.
- Now: real-time biofeedback works with Apple Watch OR any BLE HR monitor

### Phase 3: Rich Context
- **Oura Cloud API** — readiness scores, detailed sleep, superior HRV baseline
- **WHOOP API** — strain, recovery scores
- Pre-session intelligence: "Your Oura readiness is 62 and WHOOP recovery is yellow — recommending relaxation"

### Phase 4: Garmin (Only If Demand Warrants)
- **Garmin Health API** — requires B2B partnership. Only if Garmin users are a significant segment.

**Fitbit: Skipped entirely.** Doesn't write to HealthKit, requires separate API or paid aggregator, user base shrinking under Google ownership. Not worth the effort for any version.

**Third-party aggregators (Terra, Vital): Not needed.** HealthKit covers the wearables that matter. No aggregator dependency, no ongoing cost, no privacy hop.

---

## What This Means for BioNaural

1. **Apple Watch is the primary real-time source.** Design and market around it.
2. **HealthKit is the silent universal adapter.** One integration, automatic support for 7+ wearables.
3. **Polar BLE SDK is the real-time wildcard.** For users without Apple Watch, a Polar H10 ($50) gives medical-grade real-time HR + HRV. Worth integrating in Phase 2.
4. **Standard BLE HR (0x180D)** opens the door to dozens of chest straps and monitors. Low effort, broad compatibility.
5. **Oura and WHOOP APIs add rich context** but never real-time. Phase 3 — pre-session personalization.
6. **Fitbit is the gap.** No HealthKit sync. Direct API or aggregator needed if Fitbit users are a priority.
7. **Skip Samsung and Biostrap** on iOS. Not worth the effort.
