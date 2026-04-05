# BioNaural — Oura Ring & Smart Ring Integration

> What Oura can and can't do for BioNaural. API access, limitations, and the multi-wearable strategy.

---

## Key Finding: No Real-Time Data from Oura

The Oura API is **retrospective only**. Data flows: Ring → Oura app (BLE) → Oura cloud → REST API. Latency: **minutes to hours**. No streaming endpoint, no WebSocket, no push.

This rules out real-time biofeedback. Apple Watch remains the only consumer wearable with real-time HR streaming to third-party iOS apps.

---

## What Oura CAN Do: Pre-Session Context

Oura excels at **session personalization** — rich contextual data to set up the right experience before audio starts.

### Available via Oura API v2

| Endpoint | Data | Use for BioNaural |
|----------|------|-------------------|
| `/daily_readiness` | Readiness score, contributors | "Your readiness is 62 — recommending relaxation" |
| `/daily_sleep` | Sleep score, total sleep, deep sleep % | "You only got 5h last night — try sleep prep tonight" |
| `/heartrate` | Historical HR samples (5-min intervals) | Resting HR baseline calibration |
| `/sleep` (detailed) | Sleep stages, HR during sleep, HRV (5-min) | HRV baseline, sleep quality trends |
| `/daily_stress` | Daytime stress assessment | Session mode recommendation |
| `/daily_activity` | Steps, calories, movement | Activity context |
| `/daily_spo2` | Blood oxygen (nightly) | Recovery context |
| `/session` | Meditation/breathing sessions with HR+HRV | Baseline comparison |

### Authentication
OAuth 2.0 Authorization Code flow via `ASWebAuthenticationSession`. Free API access, 5000 requests per 5 min per user. No SDK — REST only.

---

## Oura's HRV Advantage

Finger PPG (Oura) is **more accurate than wrist PPG (Apple Watch)** for HRV. Palmar digital arteries have stronger pulsatile signals with less motion artifact.

- Oura reports **RMSSD** natively (preferred for parasympathetic assessment)
- Apple Watch reports **SDNN** via HealthKit (related but different metric)
- For a stationary/sleeping user, Oura HRV is among the best consumer-grade available

**BioNaural can use Oura's superior HRV baseline** to set session starting parameters, then use Apple Watch's real-time HR for live adaptation during the session.

---

## HealthKit as Universal Adapter

Oura writes to HealthKit when the user has sync enabled:

| HealthKit Type | Written by Oura |
|---------------|----------------|
| `heartRate` | Yes (batch, not real-time) |
| `heartRateVariabilitySDNN` | Yes (converted from RMSSD) |
| `restingHeartRate` | Yes |
| `sleepAnalysis` | Yes (with stages) |
| `stepCount` | Yes |
| `oxygenSaturation` | Yes |
| `respiratoryRate` | Yes |

**BioNaural can read Oura data through HealthKit without any Oura API integration.** This is the simplest path — works for any user who has HealthKit sync enabled in the Oura app. Requires no OAuth, no API keys, no backend.

---

## Other Smart Rings

| Ring | Public API | Real-Time? | Verdict |
|------|-----------|-----------|---------|
| **Oura Gen 3/4** | Yes (REST, mature) | No | Best ring integration. Context only. |
| **Ultrahuman Ring Air** | Yes (REST, emerging) | No | Worth supporting. Same limitations as Oura. |
| **Samsung Galaxy Ring** | No | No | Closed ecosystem, Android-first. Not viable. |
| **RingConn** | No | No | Not viable. |
| **Circular Ring** | Waitlist | No | Too immature. |

**No smart ring offers real-time data streaming to third-party apps.** All use BLE to companion app → cloud → API. This is a fundamental architectural limitation of the category.

---

## Integration Strategy

### Tier 1: Apple Watch (Real-Time Biofeedback)
- `HKWorkoutSession` → continuous ~1 Hz HR
- Only source for live audio adaptation
- The premium experience

### Tier 2: Oura / Smart Rings (Pre-Session Context)
- Read via HealthKit (simplest) or Oura API (richer data)
- Readiness score, HRV baseline, sleep quality → personalize session parameters
- Post-session: correlate BioNaural usage with longitudinal HRV/sleep trends
- "Users who did 3+ sessions/week showed 15% HRV improvement over 30 days"

### Tier 3: HealthKit Universal (Any Wearable)
- Read HR, HRV, sleep from HealthKit regardless of source device
- Automatically supports Oura, Garmin, Fitbit, WHOOP — whatever writes to HealthKit
- For real-time: only Apple Watch provides live streaming

---

## Implementation Approach

### Phase 1 (Launch): HealthKit Only
- Read from HealthKit for baseline data (works with Oura, Watch, Garmin, anything)
- Real-time adaptation via Apple Watch workout session
- No Oura-specific API integration needed

### Phase 2: Oura API Integration
- OAuth flow for richer data (readiness score, detailed sleep, stress)
- Pre-session recommendations: "Your Oura readiness is 62 and HRV is below baseline — we recommend relaxation mode at theta 6 Hz"
- Longitudinal dashboard: BioNaural sessions correlated with Oura recovery trends

### The Pitch
"We use your Oura sleep and readiness data to personalize your sessions, and your Apple Watch heart rate to adapt the audio in real time."

Two wearables, complementary roles, maximum personalization.
