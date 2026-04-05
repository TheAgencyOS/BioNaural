# Energize Mode: Build Estimate

> Engineering effort assessment for adding Energize as a 4th mode to BioNaural.

---

## Architecture Reuse: ~75-80%

BioNaural's architecture was designed around mode-specific parameterization. Energize slots into the same pipeline with mostly configuration-level changes.

---

## Fully Reusable (Zero Work)

| Component | Why It Reuses |
|---|---|
| **AVAudioEngine / binaural synthesis** | Same engine, different frequency parameters |
| **Watch HR/HRV pipeline** | Mode-agnostic data flow |
| **WCSession communication** | Same message format |
| **Three-layer audio mixer** | Same bus structure, different content |
| **SwiftData session models** | Add `.energize` case to FocusMode enum |
| **Feedback loop infrastructure** | Same SessionOutcome struct |
| **HealthKit integration** | Same queries, same write patterns |
| **Background audio / interruption handling** | Mode-agnostic |
| **Now Playing / Live Activities** | Parameterized by mode already |

## Mostly Reusable (Minor Additions)

| Component | Change Needed | Effort |
|---|---|---|
| **Adaptive algorithm core** | New sigmoid mapping + frequency range | 1-2 days |
| **ML model pipeline** | Retrain/fine-tune for Energize patterns | 2-3 days |
| **Theme system** | Add amber-gold color tokens | < 1 day |
| **Mode selection UI** | Vertical list → 2x2 grid | 1 day |
| **Onboarding flow** | No new screens; add Energize to mode picker | < 1 day |
| **Session timer** | Add Energize phase to Pomodoro cycle | 1 day |

## Must Be Built New

| Component | Description | Effort |
|---|---|---|
| **Positive feedback logic** | Core behavioral inversion — reward rising arousal toward a target zone. Asymmetric correction (+0.3/-0.5 Hz). IZOF zone targeting. | 3-5 days |
| **Safety guardrails** | HR ceiling detection, HRV crash detection, session time limits, cool-down enforcement, contraindication warnings. No existing analog. | 4-6 days |
| **Onboarding screening** | First-use health questionnaire (epilepsy, anxiety, cardiac). Warning display logic. | 1-2 days |
| **Fatigue detection model** | HRV + HR + movement fusion for proactive suggestions. Personal baseline learning (7-14 day window). | 3-5 days |
| **Orb amber-gold animation** | New color palette + rising particles + faster pulse + warm corona. | 1-2 days |
| **Head movement activation signal** | Flip CMHeadphoneMotionManager from stillness→activation metric | 1 day |
| **Energize-specific science cards** | In-app science content for the mode | 1 day |

## Content (Parallel Track)

| Asset | Count | Source | Timeline |
|---|---|---|---|
| Ambient sound beds | 3 + silence | Freesound CC0, Pixabay, commission | 1-2 weeks |
| Melodic loops | 10-15 | Commission (120-130 BPM, major/Lydian) | 2-3 weeks |
| Isochronic tone synthesis | Built into engine | Engineering | 2-3 days |
| Sound metadata tagging | All new assets | Manual | 1-2 days |
| **Total additional bundle** | ~30-40 MB | AAC 256kbps | — |

---

## Timeline Summary

| Track | Duration | Dependencies |
|---|---|---|
| **Engineering** | 2-3 weeks | Can start after v1 audio engine is stable |
| **Content** | 2-3 weeks | Runs in parallel with engineering |
| **Safety/Legal review** | 1-2 weeks | FTO search, FDA consult, FTC copy review |
| **Testing** | 1 week | After engineering + content merge |
| **Total** | ~4-5 weeks | Content and legal run parallel to engineering |

### Critical Path
```
Positive feedback logic (5d) → Safety guardrails (6d) → Fatigue detection (5d) → Integration testing (5d)
```

Content commissioning and legal review happen in parallel and are not on the critical path.

---

## Testing Priorities

### Unit Tests (Adaptive Algorithm)
- Positive feedback direction verified
- Asymmetric correction (+0.3/-0.5) deterministic
- Safety triggers fire at correct thresholds
- Session arc phases transition at correct times
- Warm-up phase ignores biometrics
- Cool-down is non-skippable

### Audio Tests
- Beat frequencies accurate via FFT (18-40 Hz range)
- Carrier frequencies in 400-600 Hz range
- Isochronic pulse timing accuracy
- Phase accumulator stability over 20 min (shorter than Focus's 2-hour test)
- Click-free transitions during frequency ramps

### Safety Tests
- HR ceiling triggers at exact threshold
- HRV crash detection fires within 1 control loop (100ms)
- Sympathetic dominance timer accurate
- Cool-down cannot be bypassed
- Emergency calm engages correctly

### Performance Targets
- < 5% CPU (same as other modes)
- Zero memory growth over 20-min session
- < 8% Watch battery per 15-min session

---

## Risk Items

| Risk | Impact | Mitigation |
|---|---|---|
| Positive feedback tuning | Could feel jittery or ineffective | Extended internal testing before TestFlight |
| Sound content delays | No ambient/melodic content at launch | Ship with beta beats + noise beds only; add content in v1.1.1 |
| Safety false positives | Guardrails trigger too easily, ruining sessions | Adjustable sensitivity; data logging for tuning |
| Isochronic tone quality | Pulsing can feel harsh | Embed in ambient texture; soft attack/release envelopes |

---

## Legal Budget (Energize-Specific)

| Item | Cost |
|---|---|
| FTO patent search (energy audio) | $2-4K |
| FDA regulatory consult | $1-2K |
| FTC advertising copy review | $1K |
| **Total** | **$4-7K** (additive to existing $6-16K) |

---

## v1 Prep (Do During v1 Development)

Even before Energize ships, these actions de-risk v1.1:

1. **Commission sound content early** — longest lead time item
2. **Add `.energize` case to FocusMode enum** — even if unused, prevents migration issues
3. **Log fatigue-relevant data** — HR/HRV baselines, circadian patterns, movement. 7-14 days of pre-Energize data means day-one personalization at v1.1 launch
4. **Design 2x2 mode grid** — even if only 3 cells are active at v1
5. **Begin FTO search** — patent landscape review takes 4-6 weeks
