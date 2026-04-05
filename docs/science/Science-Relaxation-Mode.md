# BioNaural — Relaxation Mode Science & Design

> Distinct from meditation (structured practice) and sleep (unconsciousness). Relaxation = awake, passive, de-stress.

---

## The Relaxation Frequency: Alpha (8-11 Hz)

| Range | State | Use Case |
|-------|-------|----------|
| 10-12 Hz (upper alpha) | Relaxed but alert | "Just finished work, chilling on the couch" |
| 8-10 Hz (lower alpha) | Deeper relaxation, "floaty" | "Warm bath" feeling |
| 7-8 Hz (alpha-theta border) | Deep calm, anxiety reduction strongest here | Acute stress recovery |

**Sweet spot: 10 Hz** — the brain's natural resting frequency. Peak alpha for most adults.

**For acute panic/stress:** Start at 12-14 Hz (meeting the user's activated state), ramp down to 8-9 Hz over 10 minutes. "Pace and lead."

### How Relaxation Differs from Other Modes

| Dimension | Relaxation | Focus | Meditation | Sleep |
|-----------|-----------|-------|-----------|-------|
| Frequency | 8-11 Hz (alpha) | 12-15+ Hz (beta) | 4-8 Hz (theta) | 1-4 Hz (delta) |
| Goal | Parasympathetic activation | Sustained attention | Altered states, insight | Unconsciousness |
| User effort | Zero (passive) | Medium (working) | High (practicing) | Zero (letting go) |
| Sleep risk | Low | Low | Moderate | Goal |
| Duration | 5-30 min | 15-120 min | 15-45 min | 15-45 min (prep) |

---

## Scientific Evidence

### Anxiety Reduction (Strongest Evidence in Entire Field)

| Study | Year | Finding |
|-------|------|---------|
| **Garcia-Argibay et al.** (meta-analysis) | 2019 | **Hedges' g = -0.45** for anxiety. Alpha/theta frequencies strongest. 10+ min exposure required. |
| Padmanabhan et al. | 2005 | Alpha-theta range (7-13 Hz): moderate anxiety reduction (d ~ 0.4-0.6) |
| Le Scouarnec et al. | 2001 | Delta/theta beats daily × 30 days: 26% anxiety reduction vs. 7% control |
| Wahbeh et al. | 2007 | 8-week daily delta beats: significant trait anxiety decrease |
| Isik et al. | 2017 | 10 Hz beats for 30 min pre-surgery: lower anxiety scores AND lower blood pressure |
| Chaieb et al. (review) | 2015 | Alpha-range (8-13 Hz) most consistent for subjective relaxation |

### HRV Improvement

| Study | Finding |
|-------|---------|
| McConnell et al. (2014) | Theta beats (7 Hz) increased HF-HRV (parasympathetic marker) |
| Palaniappan et al. (2015) | Alpha beats (10 Hz) shifted autonomic balance toward parasympathetic. Comparable to guided breathing. |
| Goodin et al. (2012) | Alpha beats improved vagal tone during stress recovery. Faster return to baseline HRV. |

### Cortisol
Weak evidence. Trend toward reduction but not significant in studies (small samples). The overall relaxation experience (soundscape + beats + downtime) likely reduces cortisol even if the binaural component's specific contribution is hard to isolate.

---

## Biometric Targets

| Metric | Starting (Stressed) | Target (Relaxed) | How to Measure |
|--------|-------------------|------------------|---------------|
| Heart rate | User's current | 5-15 BPM below starting | Apple Watch HR |
| HRV (RMSSD) | User's baseline | 20-40% increase above baseline | Watch-derived or Oura baseline |
| Respiratory rate | 12-20 breaths/min | 6-10 breaths/min | Watch (limited API) |
| HR stability | Oscillating | Plateau for 2+ min | Trend detection |

**Key:** Use personal baselines, never population norms. HRV is highly individual.

---

## Adaptive Algorithm: Relaxation Mode

| Parameter | Relaxation | vs Focus | vs Sleep |
|-----------|-----------|----------|---------|
| Input sensitivity | Medium | High | Low |
| Frequency range | 8-12 Hz | 6-18 Hz | 1-8 Hz |
| Adjustment speed | Slow (0.5-1 Hz/min) | Moderate | Continuous downward ramp |
| Direction bias | Downward | Bidirectional | Downward only |
| Floor | 8 Hz (prevent sleep drift) | 6 Hz | None (deeper = better) |
| Ceiling | 12 Hz (catch stress spikes) | 18 Hz | 8 Hz |
| Response to HR spike | Gently increase to 11-12 Hz to "catch," then ramp back down | Decrease to calm | Ignore (normal during sleep onset) |
| Completion signal | HR + HRV stable in relaxed range for 3+ min | User decides | Sleep onset detected |

**Philosophy:** The user should feel like they naturally relaxed, not like the app pushed them there. Invisible adaptation.

---

## Sound Design

### Carrier Frequencies

| Mode | Carrier Range | Character |
|------|-------------|-----------|
| **Relaxation** | **150-250 Hz** | **Warm, chest-resonant, grounding** |
| Focus | 250-450 Hz | Brighter, "heady," alert |
| Sleep | 100-200 Hz | Deep hum, very warm |

### Soundscape Layers

| Layer | Relaxation | Sleep |
|-------|-----------|-------|
| Nature | Active water, breeze, birdsong | Rain, distant thunder, deep ocean |
| Brightness | Warm but present (some mids) | Very dark (heavily filtered) |
| Dynamics | Subtle, slow wave-like modulation | Nearly static |
| Density | Medium (2-3 layers) | Sparse (1-2 layers, lots of silence) |
| Beat audibility | Subtle but perceptible | Nearly inaudible (deeply embedded) |
| Volume arc | Steady throughout | Gradual fade over 20-45 min |
| End | Gentle brightening, slight volume increase | Fade to silence |

**Aesthetic:** Relaxation = "a beautiful afternoon by a river." Sleep = "a dark, warm cocoon."

### Best Nature Sounds for Relaxation
- **Flowing water** (streams, rain, ocean) — #1 for parasympathetic activation (Gould van Praag et al., 2017, *Scientific Reports*)
- Wind through trees
- Distant birdsong (not sharp or rhythmic)
- Warm ambient pads with slow modulation

---

## Use Cases & Session Designs

### Post-Work Decompression (Primary)
- Start at 11-12 Hz, ramp to 9-10 Hz over 5-7 min, sustain at 10 Hz
- Duration: 15-20 min
- Soundscape: Water + distant birds + warm pads

### Acute Anxiety Management
- Start at 12-14 Hz (meeting high beta), ramp to 8-9 Hz over 10 min
- Duration: 10-15 min
- Soundscape: Steady, predictable. Continuous rain. No surprises.
- **Recommend enabling breathing guide** (6 breaths/min haptic/visual)

### Recovery Between Focus Sessions
- Quick ramp: 13 Hz → 10 Hz over 3 min, sustain 5-7 min, return to 12-13 Hz
- Duration: 5-10 min ("power relax")
- Soundscape: Lighter, brighter. Gentle nature. Not too immersive.

### Evening Wind-Down (Not Sleep)
- Steady 9-10 Hz alpha. No dramatic ramps.
- Duration: 20-30 min
- Soundscape: Warmer, slightly darker. Evening nature (crickets, gentle wind).
- Does NOT transition to sleep frequencies. If user wants sleep, switch modes.

### Pain Management
- Alpha-theta border (7-9 Hz). Pain research shows this reduces central sensitization.
- Duration: 15-30 min (longer is better for pain)
- Soundscape: Very warm, enveloping. Low carriers (150-180 Hz). "Wrapped in sound."
- **Underserved niche — differentiator.**

---

## Session Arc: Standard 15-Minute Relaxation

| Phase | Time | Frequency | Soundscape | Purpose |
|-------|------|-----------|-----------|---------|
| Meet | 0:00-1:00 | 12-13 Hz | Fade in from silence | Match user's current state |
| Ramp Down | 1:00-5:00 | 13→10 Hz | Build layers gradually | Guide toward alpha |
| Sustain | 5:00-12:00 | 10 Hz (±0.5 Hz gentle drift) | Full, stable | Maintain relaxed state |
| Return | 12:00-14:00 | 10→11 Hz | Subtle brightening | Gently restore alertness |
| Close | 14:00-15:00 | 11-12 Hz | Fade out | Session end |

**Options:**
- "Gentle end" (with return phase) — default
- "Soft fade" (no return, fade at same frequency) — for evening/pain use

**Duration presets:** 5 min (Quick), 15 min (Standard), 30 min (Deep), Open-ended

---

## Competitive Differentiation

| Feature | Calm | Headspace | Brain.fm | **BioNaural** |
|---------|------|-----------|---------|--------------|
| Dedicated relax mode | No (playlists) | Partial (guided) | Yes | **Yes** |
| Binaural beats | No | No | Yes (AM-based) | **Yes** |
| Adapts to biometrics | No | No | No | **Yes** |
| Relax vs meditation distinct | Blurred | Blurred | Clear | **Clear** |
| Breathing guide option | Separate feature | Within guided | No | **Optional overlay** |
| Pain management positioning | No | No | No | **Opportunity** |

**BioNaural's unique value:** First relaxation experience that (a) uses binaural beats optimized for alpha, (b) adapts in real-time to biometrics, and (c) clearly separates relaxation from meditation and sleep. The biometric feedback loop is the killer feature — the user can feel that they're actually relaxing, creating a positive feedback loop no competitor can match.
