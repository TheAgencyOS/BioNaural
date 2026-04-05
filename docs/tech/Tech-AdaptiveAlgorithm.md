# BioNaural — Adaptive Algorithm Specification

> How biometric data maps to audio parameters. The brain of the app.

---

## System Overview

```
Apple Watch (HR sensor)
    → Signal Processing (smoothing, trend detection, artifact rejection)
    → State Classification (calm / focused / elevated / peak)
    → Mapping Functions (state → audio parameters, mode-dependent)
    → Slew Rate Limiting (smooth transitions)
    → Audio Engine (AVAudioEngine)
```

Control loop runs at **10 Hz** (every 100ms). Total computation per tick: microseconds.

---

## 1. Input Signals

### Heart Rate (HR)

**Source:** `HKQuantityType(.heartRate)` during `HKWorkoutSession`. Updates every 1-5 seconds.

**Normalization — Heart Rate Reserve (HRR):**

```
HR_normalized = (HR_current - HR_rest) / (HR_max - HR_rest)
```

Yields 0.0-1.0 where 0 = resting, 1 = maximal effort. Superior to raw BPM because it accounts for individual fitness. A fit athlete at 60 BPM = same activation level as sedentary user at 80 BPM.

- **HR_rest:** From baseline calibration or HealthKit `restingHeartRate`. Range: 45-85 BPM.
- **HR_max:** Tanaka formula: `208 - (0.7 × age)`. Refined with observed data over sessions.

**State zones:**

| Zone | HR_normalized | Label |
|------|-------------|-------|
| 0 | 0.00 – 0.20 | Calm / Rest |
| 1 | 0.20 – 0.45 | Light / Focused |
| 2 | 0.45 – 0.70 | Elevated |
| 3 | 0.70 – 1.00 | Peak |

### HRV (RMSSD)

Apple Watch exposes SDNN via HealthKit, not RMSSD directly. For true RMSSD, derive from inter-beat intervals (IBI):

```
RMSSD = sqrt( (1/N) × Σ(IBI[i+1] - IBI[i])² )
```

Window: 30-60 seconds. Slides forward every 5 seconds.

**Normalization (log transform, population-normed):**

```
lnRMSSD = ln(RMSSD)
HRV_normalized = (lnRMSSD - 2.3) / (5.0 - 2.3)    // 0-1 scale
```

High HRV = parasympathetic (calm). Low HRV = sympathetic (stress). Inverse of HR activation — complementary signals.

---

## 2. Signal Processing

### Dual Exponential Moving Average (EMA)

```
HR_fast[t] = 0.4 × HR_raw[t] + 0.6 × HR_fast[t-1]     // responsive (~2.5s window)
HR_slow[t] = 0.1 × HR_raw[t] + 0.9 × HR_slow[t-1]     // stable (~10s window)
```

- **HR_slow** → drives audio parameter mapping (prevents jittery sound)
- **HR_fast - HR_slow** → trend detection (see below)

### Trend Detection (MACD-style)

```
HR_trend = HR_fast - HR_slow
```

| HR_trend | Interpretation |
|----------|---------------|
| > +2 BPM | Rising (sympathetic activation) |
| < -2 BPM | Falling (parasympathetic recovery) |
| -2 to +2 | Stable |

The ±2 BPM deadband prevents noise from triggering false signals.

**Acceleration (sudden spike detection):**
```
HR_accel = HR_trend[t] - HR_trend[t-1]
If |HR_accel| > 5 BPM/s → flag as potential artifact or sudden event
```

### Artifact Rejection

Applied before EMA smoothing:

```
REJECT sample IF: |HR_raw[t] - HR_smooth[t-1]| > 30 BPM
(30 BPM/s = fastest plausible physiological change during maximal sprint)
```

On rejection: substitute previous smoothed value (hold last known good). If >5 artifacts in 10 seconds → treat as sustained data quality issue → engage dropout protocol.

**HRV artifact rejection:** Reject any IBI where `|IBI[i] - median(last 5 IBIs)| > 300ms`. Recompute RMSSD only from clean IBIs. If >30% rejected → hold previous HRV value.

### State Classification with Hysteresis

Prevents rapid zone oscillation when HR sits near a boundary.

**Enter/exit thresholds with hysteresis band h=0.03:**

| Transition | Enter Condition | Exit Condition | Min Dwell |
|-----------|----------------|----------------|-----------|
| Calm → Focused | HR_norm > 0.23 | HR_norm < 0.17 | 5 sec |
| Focused → Elevated | HR_norm > 0.48 | HR_norm < 0.42 | 5 sec |
| Elevated → Peak | HR_norm > 0.73 | HR_norm < 0.67 | 5 sec |

No skip-transitions allowed (Calm cannot jump to Elevated). This smooths the experience.

---

## 3. Output Parameters

| Parameter | Min | Max | Unit | Controls |
|-----------|-----|-----|------|----------|
| Entrainment method | — | — | enum | `.binaural` or `.isochronic` (v1.1+) |
| Beat/pulse frequency | 1 | 40 | Hz | Entrainment target |
| Carrier frequency | 100 | 500 | Hz | Perceived pitch/warmth |
| Entrainment layer amplitude | 0.0 | 1.0 | norm | Beat prominence in mix |
| Ambient texture level | 0.0 | 1.0 | norm | Background soundscape |
| Waveform harmonic content | 0.0 | 1.0 | norm | 0=sine, 1=rich harmonics |

**Entrainment method selection (v1.1+):**
- Focus/Energize at beta/gamma (>13 Hz): prefer isochronic (stronger cortical response at high frequencies)
- Relaxation at alpha (8-13 Hz): default binaural, isochronic optional
- Sleep at theta/delta (<8 Hz): prefer binaural (isochronic less effective at low frequencies, pulsing counterproductive for sleep)
- User preference override: some users hate the isochronic pulsing — always respect explicit choice
- At v1.5, the ML contextual bandit learns the optimal method per user/mode/context from biometric outcomes

**Binaural stereo split:**
```
Left ear:  carrier_freq - (beat_freq / 2)
Right ear: carrier_freq + (beat_freq / 2)
```

**Isochronic generation (v1.1+):**
```
Single carrier tone amplitude-modulated at pulse_freq with smooth ramping
Duty cycle: ~50% (peak amplitude ~33% after ramp)
No stereo split needed — works through speakers or headphones
```

---

## 4. Mapping Functions (Mode-Dependent)

### Deep Work / Focus Mode (Negative Feedback)

**Goal:** Counteract elevated HR by guiding toward calm. As HR rises, beat frequency decreases toward theta.

```
beat_freq = beat_max - (beat_max - beat_min) × sigmoid(k × (HR_norm - midpoint))

beat_min = 6 Hz (theta)
beat_max = 18 Hz (low beta)
k = 6 (steepness)
midpoint = 0.4
```

| HR_normalized | beat_freq |
|--------------|-----------|
| 0.0 (calm) | ~17 Hz (alert beta — maintain focus) |
| 0.4 (mid) | ~12 Hz (alpha — balanced) |
| 0.8 (elevated) | ~7 Hz (theta — calming influence) |

**Why sigmoid over linear:** Concentrates change in the transition zone, saturates at extremes. The audio doesn't chase noise at the edges. Continuously differentiable = smooth transitions.

### Workout / Energy Mode (Positive Feedback)

**Goal:** Match elevated HR with energizing frequencies.

```
beat_freq = beat_min + (beat_max - beat_min) × sigmoid(k × (HR_norm - midpoint))

beat_min = 10 Hz (alpha baseline)
beat_max = 30 Hz (beta/gamma)
k = 5, midpoint = 0.5
```

### Relaxation Mode (Gentle Downward Bias)

**Goal:** Parasympathetic activation. Gentle, slow, downward-biased toward alpha.

```
beat_freq = 12 - 4 × sigmoid(k × (relaxation_depth - midpoint))

beat_min = 8 Hz (alpha floor — prevent sleep drift)
beat_max = 12 Hz (upper alpha — catch stress spikes)
k = 4, midpoint = 0.4
```

Uses HR as primary signal (HRV as modifier). Adjustment speed: slow (0.5-1 Hz/min). If HR spikes, gently increase to 11-12 Hz to "catch," then ramp back down.

### Sleep Mode (Continuous Downward Ramp)

**Goal:** Mirror natural sleep onset. Theta → delta over 25 minutes.

```
beat_freq = 6 - (4 × session_progress)    // 6 Hz at start → 2 Hz at 25 min
```

Time-based ramp is primary. Biometrics are secondary: if HR/motion indicate sleep onset, accelerate the ramp and begin audio fade. If HR stays elevated, hold at current frequency (don't force descent). No floor — deeper is better.

### Mode-Dependent Carrier Frequencies

The carrier must vary by mode to match the psychological character:

| Mode | Carrier Range | Character |
|------|-------------|-----------|
| Focus | 300-450 Hz | Brighter, alert, "heady" |
| Relaxation | 150-250 Hz | Warm, chest-resonant, grounding |
| Sleep | 100-200 Hz | Deep hum, very warm |

```
// Mode-specific carrier with trend modulation:
carrier_freq = mode_carrier_base + 50 × tanh(HR_trend / 5)
```

### Secondary Mappings

**Carrier frequency** (mode-dependent base + HR trend modulation):
```
// See Mode-Dependent Carrier Frequencies table above for base values
carrier_freq = mode_carrier_base + 50 × tanh(HR_trend / 5)
// Focus: 300-450 Hz, Relaxation: 150-250 Hz, Sleep: 100-200 Hz
```
Rising HR → slightly brighter tone. Falling → warmer.

**Binaural layer amplitude** (peaks in the responsive middle range):
```
binaural_amplitude = 0.3 + 0.5 × (1 - (2 × HR_norm - 1)²)
```
Inverted parabola: peaks at HR_norm=0.5, drops at extremes.

**Ambient texture level** (inverse to activation):
```
ambient_level = 0.8 - 0.5 × HR_normalized
```
Calm = rich ambient (0.8). Peak = ambient recedes (0.3).

**Harmonic content** (correlated with state):
```
harmonic_content = 0.1 + 0.6 × HR_normalized
```
Calm = near-pure sine. Elevated = richer harmonics.

---

## 5. Slew Rate Limiting (Critical for UX)

Audio changes must be imperceptible in the moment. A change of ~0.5 Hz/sec in beat frequency is below perception threshold.

| Parameter | Max Change Rate | Full Sweep Duration |
|-----------|----------------|-------------------|
| Beat frequency | 0.3 Hz/sec | 6→18 Hz in ~40 sec |
| Carrier frequency | 2 Hz/sec | 350→450 Hz in ~50 sec |
| Amplitude | 0.02/sec | 0→1 in ~50 sec |
| Ambient level | 0.03/sec | 0→1 in ~33 sec |

```
parameter[t] = parameter[t-1] + clamp(target - parameter[t-1], -max_delta × dt, +max_delta × dt)
```

At 10 Hz control loop (dt=0.1s), beat frequency changes at most 0.03 Hz per tick.

---

## 6. Proportional + Feedforward Control

Full PID is inappropriate — we can't truly "control" HR. The integral term would overcorrect. The plant (human nervous system) has 30-120 second latency.

```
// Proportional: how far is current from target?
adjustment = Kp × (target - current)

// Feedforward: anticipate based on HR trend
feedforward = Kff × (-HR_trend)    // For Focus mode: rising HR → preemptively lower beat

command = current + (adjustment + feedforward) × dt
command = clamp(command, min, max)
command = slew_rate_limit(command)
```

Gains:
- `Kp = 0.1` (10% of error corrected per second)
- `Kff = 0.5` (anticipation from trend)

Low Kp ensures audio doesn't chase noise. Feedforward gives anticipation — adjustment starts before the slow EMA fully catches up.

### Oscillation Prevention

Could the feedback loop create a cycle (audio calms user → HR drops → algorithm increases beat → user re-activates → repeat)? Unlikely because:
1. Plant latency (30-120s) >> controller time constant (~3s)
2. Slew rate limiter acts as low-pass filter
3. Hysteresis adds damping

**Monitor:** If HR_trend oscillates with 2-5 minute period, reduce Kp by 50% dynamically. Detection: >4 zero-crossings of HR_trend in 5 minutes.

---

## 7. Personalization

### Baseline Calibration (Every Session)

First 2-3 minutes: collect resting data.

```
HR_baseline = mean(HR_samples[0..180s])
HRV_baseline = RMSSD(IBI_samples[0..180s])
```

If session starts elevated (HR_baseline > historical_rest × 1.2), use historical 7-day median from HealthKit instead.

### First Session (No History)

Population defaults:
- HR_rest = 72 BPM
- HR_max = 208 - 0.7 × age (or 185 if age unknown)
- HRV baseline lnRMSSD = 3.5

Audio starts at neutral (10 Hz, 400 Hz carrier) during calibration. Wider hysteresis (h=0.05) and slower slew rates (0.15 Hz/s) until baseline is established.

### Profile Building Over Sessions

After each session, store observed baselines. Update rolling profile:

```
HR_rest_profile = 0.8 × HR_rest_profile + 0.2 × HR_rest_latest
```

**Entrainment method personalization (v1.5):** The GP-BO frequency tuning system (see Tech-MLModels.md) adds entrainment method as an optimizable parameter. After 20+ sessions with both methods recorded in `SessionOutcome.entrainmentMethod`, the system learns which method produces better biometric outcomes for each user in each mode/context.

After 10+ sessions, switch from absolute zone thresholds to **percentile-based:**
- Calm: below 25th percentile of user's HR_normalized distribution
- Focused: 25th-50th
- Elevated: 50th-80th
- Peak: above 80th

Automatically handles athletes vs. sedentary users without manual tuning.

---

## 8. Edge Cases

### Data Dropout (Watch Disconnect)

**Detection:** No HR sample for >10 seconds.

**Response:**
1. Freeze current audio parameters (no abrupt change)
2. Over 60 seconds, linearly interpolate toward neutral (10 Hz, 400 Hz, 0.5 amplitude)
3. If data returns within 60s, resume adaptive control from last known HR_slow
4. If no data after 60s, hold neutral and show reconnection prompt

**Never stop audio or make jarring changes.** The user is in a focus state — protect it.

### Artifacts

Sudden HR spike (75 → 180 → 78 in 2 samples) = motion artifact. The rejection filter catches this. Sustained quality issues (>5 artifacts in 10s) trigger the dropout protocol.

---

## 10 Hz Control Loop Summary

```
Every 100ms:
  1. Read latest HR_raw (may be same as last tick)
  2. Apply artifact rejection (deterministic filter)
  3. Score signal quality via Core ML model → confidence weight (0.0-1.0)
  4. Update HR_fast and HR_slow EMAs
  5. Compute HR_trend = HR_fast - HR_slow
  6. Compute HR_normalized
  7. Update state machine (hysteresis + dwell time)
  8. Compute target values for all output parameters via mode-specific mapping
  9. Scale adaptation strength by signal quality: adaptation = base × confidence
  10. Apply proportional + feedforward control
  11. Apply slew rate limiting
  12. Send parameters to audio engine
```

Step 3 is the v1 ML feature — a ~50KB logistic regression model on Core ML that scores sample reliability. When signal quality is low (wrist movement, sensor noise), the system holds current parameters rather than chasing noise. When quality is high, full adaptation responsiveness. Microseconds per tick. No performance concern.
