# Tech: Energize Adaptive Algorithm

> Specification for the Energize mode's biometric-responsive audio adaptation.
> Designed to slot into BioNaural's existing adaptive algorithm architecture.

---

## Core Principle: Positive Feedback With a Hard Safety Ceiling

Focus uses **negative feedback** (HR up → frequency down to calm). Relaxation uses **gentle downward bias**. Sleep uses a **time-based ramp**.

Energize uses **conditional positive feedback** — encouraging mild sympathetic activation toward a target zone, with asymmetric correction that's slow to increase and fast to pull back.

### The IZOF Framework

Borrowed from sports psychology (Hanin's Individual Zone of Optimal Functioning): the target is a **zone**, not a direction. Reward arrival within a band, then shift to maintenance. This prevents runaway positive feedback loops.

---

## Frequency Range

| Parameter | Value |
|---|---|
| Primary band | High beta: 18-25 Hz |
| Ramp start | 14 Hz (alpha-beta border) |
| Sustain range | 18-24 Hz |
| Gamma accents | 30 Hz touches (10-15 sec, not sustained) |
| Cool-down target | 12 Hz alpha |
| Carrier frequency | 400-600 Hz (ascending from Focus's 300-450 Hz) |

For gamma presets (30+ Hz), bias carrier toward 400-500 Hz to preserve beat perception.

### Full Mode Carrier Pattern

| Mode | Beat Range | Carrier Range |
|---|---|---|
| Sleep | 0.5-4 Hz | 100-200 Hz |
| Relaxation | 4-8 Hz | 150-250 Hz |
| Focus | 12-20 Hz | 300-450 Hz |
| **Energize** | **18-40 Hz** | **400-600 Hz** |

---

## Biometric Targets

### Heart Rate

- **Target:** Baseline + 5-8 BPM (personalized)
- **Ceiling:** Baseline + 15 BPM, OR 100 BPM absolute, whichever is lower
- **Hard stop:** 0.75 × (220 - age), or 130 BPM if age unknown

### HRV as Stress Discriminator

The critical distinction between healthy arousal and stress:

| Metric | Healthy Energized | Stress / Overstimulation |
|---|---|---|
| HR | Slightly elevated (+5-8) | Elevated (+10+) |
| RMSSD | Maintained or mildly reduced | Sharply reduced |
| LF/HF ratio | Moderate increase | Spike / sustained high |
| HRV trend | Stable or slowly declining | Rapid, sustained drop |

**Key insight:** In healthy arousal, HR rises but HRV remains relatively preserved. In stress, HRV collapses. Track RMSSD trend over rolling 2-3 minute window; a drop exceeding ~30% from session baseline signals stress crossover.

---

## Core Update Rule (Every 10 Seconds)

```
hr_delta = current_hr - target_hr

if hr_delta < -5:        # under-aroused
    freq_adjust = +0.3 Hz
elif -5 <= hr_delta <= 0: # approaching target
    freq_adjust = +0.1 Hz
elif 0 < hr_delta <= 5:   # at target (hold)
    freq_adjust = 0.0
else:                     # over-aroused
    freq_adjust = -0.5 Hz # faster pullback
```

**Asymmetric correction:** +0.3 Hz up / -0.5 Hz down. Overshoot is self-correcting.

**Slew rate limit:** Max 0.5 Hz per 10-second tick.

---

## Safety Layer (Three Independent Triggers)

Any single trigger forces a cool-down ramp:

1. **HR ceiling breach:** HR exceeds absolute max for 20+ seconds → immediate gentle ramp to 14 Hz over 60 seconds
2. **HRV crash:** RMSSD drops below 20 ms (or below 50% of session-start RMSSD) → reduce frequency by 3 Hz immediately, then hold
3. **Sustained sympathetic dominance:** LF/HF ratio exceeds 4.0 for 2+ minutes → begin cool-down arc early

---

## Session Arc (Default: 10-15 Minutes)

### Standard Arc (10 min)

| Phase | Time | Frequency | Biometric Response |
|---|---|---|---|
| Activation | 0:00-3:00 | 10 → 18 Hz | **Ignored** (early HR data is noisy) |
| Ramp | 3:00-6:00 | 18 → 22 Hz | Positive feedback active |
| Peak/Sustain | 6:00-8:00 | 18-24 Hz | Adaptive hold at target zone |
| Integration | 8:00-10:00 | Current → 12 Hz | **Time-based** (ignore HR) |

### Extended Arc (15 min)

| Phase | Time | Frequency | Biometric Response |
|---|---|---|---|
| Warm-up | 0:00-3:00 | 14 → 18 Hz | Ignored |
| Ramp | 3:00-6:00 | 18 → 22 Hz | Positive feedback active |
| Sustain | 6:00-12:00 | 18-24 Hz | Adaptive hold |
| Cool-down | 12:00-15:00 | Current → 12 Hz | Time-based |

### Key Design Decisions

- **Warm-up ignores biometrics** — early HR readings after session start are noisy
- **Cool-down is mandatory and non-skippable** — prevents leaving users in an elevated state
- **Session time cap:** 20-30 minutes maximum. Sustained sympathetic drive beyond that increases cortisol without additional cognitive benefit
- **Start at alpha (10 Hz), not theta** — users choosing Energize are awake, not asleep. Starting at theta risks inducing drowsiness

### Arc Shape Comparison

| Mode | Shape | Ending State |
|---|---|---|
| **Energize** | Ramp up → plateau → gentle descent | Alert baseline (14-16 Hz) |
| Focus | Brief ramp → long sustained plateau | Sustained (no taper) |
| Relaxation | Gradual continuous descent | Relaxed alpha (8-10 Hz) |
| Sleep | Continuous descent, no return | Deep delta (1-3 Hz) |

Energize is the **only mode that ascends then intentionally returns partway down**.

---

## Duration Tiers

| Tier | Duration | Use Case |
|---|---|---|
| Quick Boost | 5-8 min | Mid-meeting reset, micro-break |
| Standard | 10-15 min | Post-lunch slump, afternoon dip |
| Deep Energize | 18-20 min | Morning ramp-up, pre-workout |

Default: 10 minutes. "Energize is a sprint, Focus is a marathon."

---

## AirPods Three-Axis Arousal Model

When AirPods are connected, add head movement as a third signal:

- **Head movement energy** (RMS of gyroscope magnitude) via `CMHeadphoneMotionManager`
- Rising movement + rising HR = confirmed activation
- Rising HR + no movement = possible anxiety (back off)
- This flips the existing Relaxation stillness metric into an activation metric with zero new API work

---

## Isochronic Tone Consideration

For beta/gamma frequencies (18+ Hz), isochronic tones may produce stronger cortical entrainment than binaural beats. Consider:

- Isochronic as primary entrainment for Energize (vs binaural for Focus/Relaxation/Sleep)
- Hybrid (both) as opt-in intensity tier
- Isochronic enables speaker-based sessions (no headphones)

---

## Fatigue Detection for Proactive Suggestions

The Watch can detect energy troughs with ~82-87% accuracy using personalized baselines:

- **HRV-to-HR ratio rising** in early afternoon = slump indicator
- **RMSSD below personal baseline** = reduced vagal tone
- **Reduced movement frequency/amplitude** = sedentary fatigue
- **Flattened circadian HR curve** = poor recovery

After 7-14 days of baseline data, proactive notifications: "Your energy usually drops around 2:30 PM — start a 5-minute Energize session?"

### Chronotype Detection

Sleep midpoint (from HealthKit sleep data) is the single best chronotype proxy:
- Larks: midpoint 2:00-3:00 AM
- Owls: midpoint 5:00-6:00 AM

Adjust Energize suggestion timing based on detected chronotype.
