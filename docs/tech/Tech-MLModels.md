# BioNaural — ML Model Architecture

> Four learning tasks. Specific models for each. All on-device. Total: < 100 KB, < 12ms inference.

---

## Summary

| Task | Model | Core ML? | Size | Inference | Training |
|------|-------|----------|------|-----------|----------|
| **Sound Selection** | Linear Thompson Sampling (contextual bandit) | No (Accelerate) | 50 KB | < 0.1 ms | On-device, incremental |
| **Frequency Tuning** | Gaussian Process Bayesian Optimization | No (Accelerate) | 15 KB | < 10 ms | On-device, incremental |
| **Sleep Onset** | Logistic Regression → Tiny GRU (8 units) | Optional Core ML | 1-5 KB | < 1 ms | On-device, SGD/BPTT |
| **User Model** | Rule-based statistical pattern detection | No | 20 KB | < 1 ms | On-device, batch |
| **Total** | | | **< 100 KB** | **< 12 ms** | |

**None of these need Core ML for inference.** All run as pure Swift with Apple's Accelerate framework (LAPACK, vDSP). This is faster, simpler, and works identically on iPhone and Apple Watch. Core ML is optional for the GRU sleep model only.

---

## Task 1: Sound Selection — Linear Thompson Sampling

### Why This Model

The sound selection problem is a textbook **contextual multi-armed bandit**. You have K arms (30-50 sounds), a context vector (user state), and a reward signal (biometric outcome + thumbs). You must balance exploration (try new sounds) vs. exploitation (use what works). This is NOT supervised learning (no "correct" labels) and NOT full RL (sessions are independent, no state transitions).

### Two Phases

**Phase 1 (Sessions 0-10): Non-Contextual Thompson Sampling**

Each sound maintains a Beta distribution: `Beta(α, β)`, initialized at `Beta(1, 1)`.

```
For each session:
1. For each candidate sound: sample θ ~ Beta(α, β)
2. Select top 2-3 sounds with highest θ
3. Observe reward r (biometric success ≥ 0.6 = success)
4. If success: α += 1. Else: β += 1.
```

Pure exploration/exploitation with no context. Learning which sounds work generally for this user.

**Phase 2 (Sessions 10+): Contextual Linear Thompson Sampling**

Model expected reward as a linear function of context:

```
E[reward | context, sound] = context^T × θ_sound
```

Maintain per-arm:
- `B_a = I + X^T × X` (precision matrix, 15×15)
- `μ_a = B_a⁻¹ × X^T × r` (posterior mean)

At decision time: sample `θ ~ N(μ_a, v² × B_a⁻¹)`, select arm with highest `context^T × θ`.

### Context Vector (~15 features)

| Feature | Encoding |
|---------|----------|
| Mode | One-hot (4: focus/relax/sleep/energize) |
| Entrainment method | Binary: binaural (0) or isochronic (1) — v1.1+ |
| HR normalized | (current - resting) / (max - resting) |
| HRV normalized | current / baseline |
| Biometric state | Binary: calm (0) or elevated (1) |
| Mood self-report | 0.0-1.0 |
| Time of day | sin/cos encoded (2 features) |
| Day of week | sin/cos encoded (2 features) |
| Sleep quality last night | 0.0-1.0 |
| Activity level today | 0.0-1.0 |
| Top instrument weights | 3 features from sound profile |

### Size & Performance

- Storage: 50 arms × (15×15 matrix + 15 vector) × 4 bytes = **48 KB**
- Inference: one matrix inverse (15×15) + sample + dot product = **< 0.1 ms**
- Update: rank-1 matrix update = one outer product + addition
- **No Core ML needed.** Pure Swift + Accelerate (vDSP, LAPACK).

### Cold Start

1. **Session 0:** Rule-based selection from sound tags (mode → energy/brightness/scale filters)
2. **Sessions 1-5:** Phase 1 Thompson Sampling (high exploration)
3. **Sessions 5-10:** Introduce context features gradually (start with mode + time of day)
4. **Sessions 10+:** Full contextual model
5. **Ship a global prior** — aggregate matrices from beta testers initialize each user's model. Encodes "most people prefer ocean sounds for sleep" without requiring user data.

---

## Task 2: Frequency Personalization — Gaussian Process Bayesian Optimization

### Why This Model

The sigmoid curve that maps HR → beat frequency has 4-6 continuous parameters. Finding the optimal parameters for this user is a black-box optimization problem with expensive evaluation (one evaluation = one full session). GP-BO is designed for exactly this: find the optimum in the fewest evaluations of a noisy, expensive function.

### Parameters to Optimize (Per Mode)

| Parameter | Range | What It Controls |
|-----------|-------|-----------------|
| midpoint | 60-100 BPM | HR at sigmoid center |
| steepness | 0.05-0.5 | Curve sharpness |
| min_freq | 1-8 Hz | Beat frequency at low HR |
| max_freq | 8-40 Hz | Beat frequency at high HR |
| transition_speed | 0.1-1.0 | Smoothing rate |
| entrainment_method | 0 or 1 | Binaural (0) vs isochronic (1) — v1.1+, categorical parameter |

**v1.1+ note:** Adding entrainment method as an optimizable parameter gives the GP-BO a powerful new lever. The system can discover that user A's Focus sessions produce better biometric outcomes with isochronic at 40 Hz gamma while user B responds better to binaural at 15 Hz beta. This is recorded in `SessionOutcome.entrainmentMethod` (see Tech-FeedbackLoop.md).

### How It Works

1. Model the objective (biometric success score) as a **Gaussian Process**: `f(θ) ~ GP(m(θ), k(θ,θ'))`
2. Kernel: **Matérn 5/2** (better than RBF for non-smooth objectives)
3. Acquisition function: **Expected Improvement** — balances exploring uncertain regions with exploiting known good regions
4. After each session: append observation, refit GP hyperparameters, optimize EI to find next parameters
5. GP naturally becomes more confident over time → exploitation increases

### Size & Performance

- Observation history: 50 sessions × 6 values = **1.2 KB**
- GP kernel matrix: 50×50 × 4 bytes = **10 KB**
- Inference (optimize EI): Cholesky decomposition + L-BFGS = **< 10 ms**
- **No Core ML needed.** Accelerate (LAPACK) for matrix ops.

### Cold Start

- **Session 0:** Literature defaults (Focus: midpoint 75, min 14 Hz, max 30 Hz. Sleep: midpoint 65, min 1 Hz, max 6 Hz.)
- **Sessions 1-5:** GP has high uncertainty → explores diverse parameter settings naturally
- **Sessions 10+:** Converging on this user's optimum

---

## Task 3: Sleep Onset Prediction — Logistic Regression → Tiny GRU

### Why This Model

Need sub-5ms inference, 5-20 training examples, temporal pattern recognition (HR *trend*, not just HR value). Start with logistic regression (robust with tiny data), graduate to a tiny GRU when data supports it.

### Phase 1: Logistic Regression (Sessions 0-15)

**Engineered temporal features** from the last 5-minute window:

| Feature | What It Captures |
|---------|-----------------|
| HR_mean_5min | Current heart rate level |
| HR_slope_5min | Is HR descending? (sleep onset signal) |
| HR_std_5min | HR variability (lower = settling) |
| HRV_approx | Parasympathetic tone |
| HRV_trend | Is HRV improving? |
| Motion_level | Is the user still? |
| Motion_trend | Is motion decreasing? |
| Session_duration | How long have they been listening? |
| Time_of_day | sin/cos encoded |
| Minutes_past_avg_onset | Relative to their typical sleep onset time |

12 features, 13 parameters. Inference: one dot product = **< 0.01 ms**.

### Phase 2: Tiny GRU (Sessions 15+)

```
Input (5 features/timestep) → GRU(8 hidden) → Dense(1, sigmoid)
```

- Sequence: 10 timesteps at 30-second intervals (5 minutes of data)
- **345 total parameters** (~1.4 KB)
- Trained on 300-900 samples (windowed from 15+ sessions)
- Inference: **< 1 ms** on Watch

### Cold Start

- **Session 0:** Heuristic: probability ramps linearly from 0.1 to 0.8 over minutes 20-60 of a sleep session
- **Sessions 1-3:** Logistic regression with strong prior weights (HR dropping + low motion + long session = onset)
- **Sessions 15+:** Optionally switch to GRU if logistic regression plateaus

---

## Task 4: User Model — Statistical Pattern Detection (Not ML)

### Why Not ML

Discovering cross-signal correlations like "after workout days, ocean sounds help this user sleep" from 10-50 sessions is a **statistical hypothesis testing** problem. ML would overfit catastrophically. The feature space is too large and the data is too sparse for any model to generalize.

### Architecture: Multiple Small Detectors

**Layer 1: Rolling Statistics (always running)**
- Track mean, variance, trend for: sleep quality, session scores, mood, activity, HR baselines, HRV baselines

**Layer 2: Conditional Comparisons (10+ sessions)**
- For each conditioning variable (activity level, sleep quality, time of day, mood, HR state):
  - Split sessions into two groups
  - Welch's t-test on biometric scores
  - Bonferroni correction for multiple comparisons
  - Require min 3 sessions per group, p < 0.05
- Output: validated rules like `IF activity > 0.7 AND mode == sleep THEN prefer(ocean_sounds)`

**Layer 3: Temporal Patterns (20+ sessions)**
- Day-of-week effects (ANOVA)
- Time-of-day effects (binned comparison)
- Sequence effects (autocorrelation of daily scores)

**Layer 4: Trend Detection (always running)**
- Linear regression of each metric against time
- Flags significant slopes (HRV improving, sleep quality declining, etc.)

### How Patterns Feed Other Models

Discovered patterns inject as **prior adjustments** to the Thompson Sampling model:
```
IF pattern says "ocean sounds work after workouts" AND user worked out today:
    Boost ocean sound arm's prior α by pattern_confidence * 2
```

This is more robust than expecting the bandit to discover these interactions from its own data alone.

### Size: **< 20 KB** for all patterns and statistics.

---

## Implementation Order

| Priority | Task | When | Why First |
|----------|------|------|-----------|
| 1 | Sound Selection (Phase 1: Beta Thompson) | v1 launch | Highest user-facing impact. Simplest to implement. |
| 2 | Sleep Onset (heuristic → logistic regression) | v1 launch | Start with heuristic, collect labels, add LR at v1.1 |
| 3 | Sound Selection (Phase 2: Contextual) | v1.1 (10+ sessions) | Needs session data. Upgrade from Phase 1. |
| 4 | Frequency Tuning (GP-BO) | v1.5 | Needs 10+ sessions. Iterative improvement. |
| 5 | User Model (pattern detection) | v1.5 (20+ sessions) | Needs substantial history. Additive, not critical path. |
| 6 | Sleep Onset (GRU upgrade) | v1.5 | Only if logistic regression plateaus. |

---

## Apple Frameworks Used

| Framework | For What |
|-----------|---------|
| **Accelerate** (vDSP) | Vector operations, means, variances, dot products |
| **Accelerate** (LAPACK) | Cholesky decomposition, matrix inverse, linear solves (GP-BO, Thompson Sampling) |
| **simd** | Small vector/matrix operations |
| **GameplayKit** (GKRandomSource) | Reproducible random sampling for Thompson Sampling |
| **Core ML** (optional) | GRU sleep model only, if using `.mlmodel` instead of pure Swift |
| **Create ML** (optional) | Initial model training from beta test data |

---

## Key Design Principle

**All models are implemented in pure Swift + Accelerate, not Core ML.** This means:
- Identical code on iPhone and Apple Watch (no model file format differences)
- Full control over training and inference (no Core ML abstraction overhead)
- Incremental on-device updates after every session (no batch retraining)
- Total model state serializes to < 100 KB of JSON/binary (trivially persisted in SwiftData)
- The entire ML system adds < 12 ms of compute per session — imperceptible
