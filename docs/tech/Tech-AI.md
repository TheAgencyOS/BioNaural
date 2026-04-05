# BioNaural — AI/ML Strategy

> Add ML only where it measurably improves the experience. Don't AI-wash. The adaptive engine is the product — ML makes it smarter over time.

---

## The Honest Assessment

BioNaural's competitive advantage is **biometric-adaptive audio with real-time responsiveness.** That's an engineering achievement, not an AI achievement. The deterministic control system (EMA smoothing, sigmoid mapping, slew rate limiting) is the correct architecture for real-time audio. ML sits above it, tuning parameters — never replacing the core loop.

---

## What Needs ML vs. What Doesn't

| Feature | Needs ML? | Why / Why Not |
|---------|-----------|--------------|
| Binaural beat generation | No | Pure DSP. `sin(2π*f*t)` is not improvable by ML. |
| Real-time adaptive loop | No | Control systems engineering. Must be deterministic, low-latency, predictable. |
| **Melodic layer sound curation** | **Yes (v1.5)** | Rules select sounds at launch. ML learns which sounds → best biometric outcomes per user. Contextual bandit on Core ML. |
| **Per-user frequency personalization** | **Yes (v1.5)** | Users respond differently. ML learns individual optimal beat frequencies over 10-20 sessions. |
| **Sleep onset prediction** | **Yes (v1.5)** | Multi-signal gradual process. ML predicts 2-5 min earlier than threshold rules. |
| Signal quality scoring | Yes (v1) | ~50KB logistic regression. Scores biometric sample reliability. Established in launch pipeline. |
| Feedback-driven weight updating | No (v1) | Simple exponential weight updates (thumbs + biometric outcomes). Not ML — adaptive rules. Becomes ML in v1.5. |
| Session recommendations | No (at first) | 20-30 rules get 80% there. ML only valuable with aggregate user data. |
| Generative MIDI melodies | Not yet (v2+) | Rule-based MIDI through sampled instruments. Not AI generation. Infinite variety from small file size. |
| LLM coaching | Not yet (v2+) | Privacy risk, regulatory risk, scope creep. |

---

## Launch (v1): Signal Quality ML + Deterministic Engine

Ship the deterministic adaptive engine as the core, with one genuine ML feature on day one.

### v1 ML Feature: Signal Quality Scoring

A lightweight Core ML model (~50KB, logistic regression) that scores each incoming biometric sample for reliability.

**What it does:** When the user moves their wrist, the Watch sensor gets noisy, or Bluetooth drops a sample, the model tells the adaptive engine "trust this data less." The system leans more on presets when signal is poor, becomes more responsive when signal is clean.

**Why this is the right v1 ML:**
- Genuinely ML (not achievable with simple threshold rules — multi-feature classification)
- Genuinely useful (prevents erratic audio behavior from bad sensor data)
- Invisible to the user (best ML features are invisible)
- Establishes the Core ML pipeline for v1.5 features
- Days of work, not months (~50KB model, logistic regression)
- You can honestly say "on-device machine learning" in marketing

**Implementation:**
- Input features: HR delta from previous sample, HR variance over 10s window, motion level, time since last sample, sample source confidence
- Output: 0.0-1.0 reliability score
- Feeds into `BiometricProcessor` as a confidence weight: `adaptation_strength = base_strength × signal_quality`
- When quality is low, the engine holds current parameters (doesn't chase noise)
- When quality is high, the engine responds fully to biometric changes

**Training data strategy (solving the chicken-and-egg):**
- **Phase 1 (pre-launch):** Train initial model on synthetic data + published Apple Watch PPG noise profiles. Use known artifact patterns: sudden HR spikes >30 BPM/sec = motion artifact, HR dropout to 0 = sensor loss, HR variance >20 BPM in 5s window = unreliable. These heuristics become labeled training examples.
- **Phase 2 (internal testing):** Collect real sensor data during TestFlight beta. Developers wear Watch during various activities (typing, walking, wrist movement, stable sitting). Manually label samples as reliable/artifact. ~500-1000 labeled samples is sufficient for logistic regression.
- **Phase 3 (post-launch):** Optionally collect anonymized signal quality data (NOT raw health data) from users who opt in. Retrain model with real-world distribution. Push updated model via app update.

**What else ships at v1:**
- Excellent deterministic adaptive algorithms (the core)
- **Comprehensive session data logging** (biometrics, parameters, outcomes, user ratings) — this IS the training data for v1.5
- Clean architecture separating parameter-selection from audio engine (so personalization ML inserts later without refactoring)

**Why not personalization at v1:** It needs 10-20 sessions of per-user data. At launch, every user has zero. The model would output population defaults — identical to the sigmoid curves, but less predictable. Ship the data collection, add the intelligence when the data supports it.

---

## v1.5 (3-6 Months Post-Launch): Lightweight On-Device ML

### 1. Per-User Parameter Personalization

The strongest ML use case. The fixed sigmoid curves work for an average user. ML learns THIS user's optimal response.

**What it does:** After 10-20 sessions, observes: "This user's HRV increases most during 7.8 Hz, not the default 10 Hz." Tunes sigmoid midpoints, slopes, and output ranges per user.

**Approach:** Bayesian optimization or contextual bandit on Core ML. Not deep learning.
- Model size: kilobytes
- Training: on-device with user's own sessions only
- Privacy: fully on-device, no cloud
- Battery: negligible (inference every 5-10 seconds, not every audio frame)

### 2. Sleep Onset Prediction

**What it does:** Predicts when user is falling asleep, 2-5 minutes earlier than simple HR/motion rules. Triggers graceful audio fade.

**Approach:** Logistic regression over rolling features (HR trend, HRV trend, motion level, session duration, time of day).
- Input: 5-minute feature windows
- Output: probability of sleep onset
- Trained on user's past sleep sessions

Both features are: genuinely improved by ML, small model size, on-device/private, perceptible to users.

---

## v2+ (12+ Months): Expanded ML

| Feature | Approach | Risk |
|---------|---------|------|
| Pre-session prediction | Regression from context (time, sleep, HRV baseline, activity) | Low |
| LLM coaching | Send aggregated summaries (never raw data) to Claude. Opt-in. | Medium (privacy, regulatory) |
| Cross-user insights | Anonymized aggregate patterns. Requires scale + consent. | Medium |

### LLM Coach (If Pursued)

Like AIZEN's Ask tab. Analyzes session history and biometric trends:
- "Your focus sessions work best between 8-10 AM"
- "You fell asleep faster with ocean sounds — want to make that default?"

**Privacy architecture:**
- All raw health data stays on-device
- Only send aggregated summaries: "12 sessions this week, avg 18 min, HRV improved 15%"
- Never send raw HR/HRV time series
- System prompt prevents medical advice
- Opt-in with clear disclosure

**Verdict:** Genuine differentiator but v2+ only. On-device insights (trend charts, session summaries) deliver 80% of coaching value without LLM dependency.

---

## Generative Audio: Not Now

**Brain.fm:** Years of specialized R&D, significant funding, dedicated research team. Not replicable by a small team.

**AudioCraft/MusicGen:** 300M-3.3B parameters. Not feasible on-device. Server-side pre-generation adds cloud dependency for marginal benefit over bundled audio.

**Recommendation:** Hybrid of bundled ambient beds (3-5 per mode: rain, forest, ocean, minimal, silence) + real-time procedural synthesis (binaural beats, filtered noise, gentle pads via AVAudioEngine). Quality + adaptability + manageable app size.

AI-generated audio is a v3+ possibility if on-device models become practical (2-3 years out for mobile).

---

## What Competitors Actually Do

| App | Real AI | Marketing AI |
|-----|---------|-------------|
| **Brain.fm** | AI-composed music with neural phase-locking. Multi-year R&D. | "Scientifically proven" is overstated |
| **Endel** | Algorithmic/procedural composition. Rule-based engine. | Calls it "AI" — it's sophisticated rules |
| **Calm** | Content recommendation (collaborative filtering) | Doesn't over-claim AI |
| **Headspace** | Recently added AI-generated meditation guidance | Moderate |

**BioNaural's niche:** Neither Brain.fm (no biometrics) nor Endel (shallow biometric use) do deep real-time biometric adaptation. BioNaural wins on the control systems + biofeedback loop, not on AI.

---

## The "AI Washing" Trap — What to Avoid

**DO NOT:**
- Call the deterministic adaptive algorithm "AI" in marketing
- Add an ML model that makes imperceptible differences just to claim "AI-powered"
- Send health data to cloud APIs for features achievable on-device
- Try to replicate Brain.fm's generative music engine
- Add an LLM chatbot giving health advice without serious guardrails

**DO:**
- Market biometric adaptation as what it is: real-time adaptive audio driven by your physiology
- Add ML only where it produces perceptible, measurable improvement
- Keep health data on-device
- Log everything from day one (future training data)
- Let the adaptive experience be the story — ML quietly makes it better over time

---

## Architecture for ML (v1 and Beyond)

```
BiometricProcessor (actor)
    → SignalQualityModel (Core ML)     ← v1: scores sample reliability
    → ParameterSelector (protocol)     ← ML replaces this in v1.5
        → DeterministicSelector        ← v1 implementation (sigmoid curves)
        → MLPersonalizedSelector       ← v1.5 implementation (Core ML)
    → AudioParameters (atomic writes)
    → Audio Engine (render callback)
```

**v1:** `SignalQualityModel` feeds a confidence weight into `BiometricProcessor`. `DeterministicSelector` handles parameter mapping. Core ML pipeline is established.

**v1.5:** `MLPersonalizedSelector` replaces `DeterministicSelector` via the `ParameterSelector` protocol. The audio engine and control loop never change. `SignalQualityModel` continues running.
