# BioNaural — Feature Considerations

> Ideas worth evaluating, sourced from competitive research and gap analysis.

---

## Circadian-Aware Defaults

Suggest the right mode and adjust starting frequencies based on time of day.

| Time Block | Suggested Mode | Starting Frequency Bias |
|-----------|---------------|------------------------|
| Early morning (5–8am) | Study | Light alpha (10–12 Hz), gentle ramp |
| Morning (8–12pm) | Deep Work | Mid alpha (9–11 Hz), steady |
| Afternoon (12–3pm) | Deep Work | Alpha with beta nudge (10–14 Hz), fights post-lunch dip |
| Late afternoon (3–6pm) | Study | Alpha (10–12 Hz), sustained |
| Evening (6–9pm) | Meditation | Theta-leaning (6–8 Hz), wind down |
| Night (9pm–5am) | Meditation | Deep theta/delta (4–6 Hz) |

**Why it matters:** Removes one decision from the user. They open the app and the right mode is already highlighted. One less tap to start.

**Complexity:** Low. Time-of-day switch with 6 brackets. Could ship in v1.

---

## Calibration Session (Personal Baselines)

A short onboarding session (3–5 min) where the user sits still while the app records their resting heart rate and HRV range. All adaptation thresholds are then derived from personal baselines rather than population averages.

| Threshold | Derivation |
|-----------|-----------|
| Elevated HR | `restingHR × 1.15` |
| High HR | `restingHR × 1.30` |
| Stress (low HRV) | Below personal 25th percentile |
| Recovery (high HRV) | Above personal 75th percentile |

**Why it matters:** An athlete with a resting HR of 50 and a desk worker at 75 need completely different adaptation triggers. Hardcoded thresholds would be wrong for most users.

**Complexity:** Low-medium. The calibration UI is simple. Storing and deriving thresholds is straightforward with SwiftData. Could ship in v1 or early v2.

---

## Harmonic Layering (Beyond Pure Tones)

Pure binaural sine waves are fatiguing after ~5 minutes. Layer additional audio elements that are musically related to the core binaural frequency:

| Layer | Relationship to Carrier | Purpose |
|-------|------------------------|---------|
| Sub-octave | Carrier ÷ 2 | Warmth, depth, fullness |
| Overtone fifth | Carrier × 1.5 | Brightness, presence |
| Mode-specific waveform | Triangle (calm), soft saw (energy) | Texture variation between modes |
| Ambient bed | Noise/texture, unrelated to carrier | Spatial depth, masks pure-tone fatigue |

**Why it matters:** This is the difference between "medical equipment" and "something I'd actually listen to for an hour." Audio quality is make-or-break per your own risk assessment.

**Complexity:** Medium. AVAudioEngine supports this natively with multiple audio nodes. The hard part is sound design taste, not engineering. Should be core to v1.

---

## Click-Safe Frequency Transitions

When the adaptive engine shifts frequencies, clamp the maximum change per audio frame (~50ms) and use eased interpolation. Prevents audible clicks, pops, and jarring shifts.

| Parameter | Constraint |
|-----------|-----------|
| Max frequency step | ±0.5 Hz per 50ms frame |
| Interpolation curve | Cosine ease-in-out |
| Minimum transition duration | 3 seconds |

**Why it matters:** Users should never consciously notice a frequency change. If they hear a click or sudden shift, the illusion breaks.

**Complexity:** Low. A few lines in the audio engine. Non-negotiable for v1.

---

## Generative Melodic Layer (v2+)

Algorithmically generated melodic elements (pads, arpeggios, single-note accents) that follow the session's harmonic context. Not pre-recorded — generated in real-time using scale-aware chord progressions.

| Element | Role |
|---------|------|
| Primary pad | Sustained chords, sets harmonic foundation |
| Secondary texture | Strings or choir, enters after 30s, arpeggiated |
| Melodic accent | Single notes placed sparsely, adds human feel |

**Why it matters:** Moves the app from "binaural beat tool" to "adaptive music experience." Significant differentiator. But hard to do well — bad generative music is worse than no music.

**Complexity:** High. Requires either a SoundFont synthesizer or custom AVAudioEngine instrument nodes. Needs serious sound design investment. v2 at earliest.

---

## Session Persistence & Trends

Save every session: duration, mode, average HR, HRV trend, adaptation events, and the Wavelength data. Surface trends over time.

**Why it matters:** Users need to see that the app is learning and that their focus is improving. Also feeds the personalization engine.

**Complexity:** Low for storage (SwiftData). Medium for meaningful trend visualization. Core session save in v1, trends in v2.
