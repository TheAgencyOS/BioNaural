# Functional Music Theory for BioNaural

## Purpose
This document defines the musical characteristics (scales, keys, rhythmic patterns, melodic contour, harmonic progression, timbre) that the GenerativeMIDIEngine and ACE-STEP prompts must produce for each mode. Every parameter is grounded in music therapy research, psychoacoustics, and functional music practice.

---

## 1. SLEEP MODE

**Goal:** Guide the listener from wakefulness to sleep onset. Music must become progressively simpler, slower, darker, and more formless.

### Scales & Keys
| Parameter | Value | Rationale |
|-----------|-------|-----------|
| **Primary scale** | Pentatonic minor (1, b3, 4, 5, b7) | Only 5 notes, no semitone tension. Impossible to create dissonance. Used in lullabies across cultures. |
| **Secondary scale** | Whole tone (C, D, E, F#, G#, Bb) | Dreamlike, no tonal center. Creates floating, directionless quality. Debussy used this for aquatic/dream imagery. |
| **Avoid** | Major 7th intervals, tritones, chromatic motion | These create tension/expectation that activates the prefrontal cortex. |
| **Key center** | F major / D minor (warm, low register) | F is traditionally the "pastoral" key. Low register promotes parasympathetic activation. |
| **Key changes** | None. Single tonal center throughout. | Key changes create arousal — the opposite of sleep. |

### Rhythmic Characteristics
- **Tempo:** Start 60 BPM, decelerate to 40 BPM over session (mirror natural HR decline)
- **Meter:** Free/arrhythmic preferred. If metered, use 3/4 or 6/8 (waltz/lullaby feel)
- **Note onset density:** 1-3 notes per 8 seconds (extremely sparse)
- **NO percussion** of any kind — no clicks, no pulses, no rhythmic grid
- **Timing:** Rubato (flexible timing). Notes should drift slightly off-grid for organic feel
- **Rests:** Long silences (4-8 seconds) between phrases. Silence is an active compositional element.

### Melodic Characteristics
- **Contour:** Predominantly descending. Falling lines signal "settling" to the nervous system.
- **Range:** C2-C4 (low register). High notes activate alertness.
- **Intervals:** Steps (2nds) and minor 3rds only. No leaps larger than a 4th.
- **Phrase length:** 2-3 notes, then rest. No long melodic lines.
- **Repetition:** High repetition with micro-variation. Same 3-note motif, slightly different each time.
- **Resolution:** Always resolve to the root or 5th. Never leave tension hanging.

### Harmonic Characteristics
- **Progression:** Static or drone-based. I → I → I or I → IV → I (no dominant function)
- **Voicing:** Close voicing, low register. Root-5th open voicing in bass.
- **Dissonance:** Zero. No suspensions, no 7th chords, no altered chords.
- **Texture:** 1-2 voices maximum. Polyphony increases cognitive load.

### Timbre & Texture
- **Instruments:** Warm analog pads, deep sine-wave synths, soft strings (cello, not violin)
- **Attack:** Very slow (200-500ms). No transients.
- **Filter:** Heavy low-pass (cutoff below 2kHz). Dark, muffled.
- **Reverb:** Large hall, high wet mix (60-80%). Sounds should feel distant.
- **Evolution:** Extremely slow timbral drift (filter sweep over 30-60 seconds)

---

## 2. RELAXATION MODE

**Goal:** Bring the listener from an activated state to calm alertness. Music should be pleasant, spacious, and gently moving — not static, but never urgent.

### Scales & Keys
| Parameter | Value | Rationale |
|-----------|-------|-----------|
| **Primary scale** | Lydian (1, 2, 3, #4, 5, 6, 7) | The raised 4th creates a "floating" quality without tension. Used by Sigur Ros, Brian Eno, ambient film scores. |
| **Secondary scale** | Major pentatonic (1, 2, 3, 5, 6) | Simple, warm, universally pleasant. No avoid notes. |
| **Tertiary** | Mixolydian (1, 2, 3, 4, 5, 6, b7) | Relaxed major sound. The flat 7th removes dominant tension. |
| **Key center** | G major / C major | Bright but not aggressive. "Neutral" keys that don't impose strong character. |
| **Key changes** | Rare. Modal interchange (Lydian ↔ Ionian) for subtle color. | Gentle, not jarring. |

### Rhythmic Characteristics
- **Tempo:** 55-70 BPM (resting heart rate zone). Steady, not decelerating.
- **Meter:** 4/4 or 3/4. Gentle pulse, not rigid grid.
- **Note onset density:** 3-6 notes per 8 seconds (moderate sparseness)
- **No percussion.** Optional very soft shaker or brush at 30% volume.
- **Timing:** Slight rubato. Notes breathe. Not quantized to grid.
- **Rests:** 2-4 second pauses between phrases.

### Melodic Characteristics
- **Contour:** Arch shape (rise then fall). Gently ascending lines that resolve downward.
- **Range:** C3-C5 (mid register). Warm, not too high or low.
- **Intervals:** Steps, 3rds, 4ths. Occasional 5th leap (resolved by step). No 7ths or larger.
- **Phrase length:** 3-5 notes. Lyrical but concise.
- **Repetition:** Moderate. Motifs recur with variation (transposition, rhythmic shift).
- **Resolution:** Resolve to root, 3rd, or 5th. Avoid ending on the raised 4th in Lydian.

### Harmonic Characteristics
- **Progression:** I → IV → I, I → vi → IV → I, I → IVmaj7 → I (Lydian color)
- **Voicing:** Open voicing, spread across registers. Octave doublings for warmth.
- **Dissonance:** Minimal. Suspended chords (sus2, sus4) that resolve gently.
- **Texture:** 2-3 voices. Enough for harmonic interest, not enough for complexity.

### Timbre & Texture
- **Instruments:** Warm pads (Juno-106 style), gentle piano (felt piano), soft strings (chamber ensemble)
- **Attack:** Moderate (50-200ms). Soft onset, never percussive.
- **Filter:** Low-pass at 4-6kHz. Present but not bright.
- **Reverb:** Medium hall, 40-60% wet. Spacious but not distant.
- **Evolution:** Slow filter sweeps (15-30 seconds), gentle LFO on cutoff.

---

## 3. FOCUS MODE

**Goal:** Maintain steady, non-distracting cognitive support. Music must be present enough to mask environmental noise but never demand attention. The brain should habituate to it within 2-3 minutes.

### Scales & Keys
| Parameter | Value | Rationale |
|-----------|-------|-----------|
| **Primary scale** | Pentatonic major (1, 2, 3, 5, 6) | No semitones = no tension = no distraction. The brain processes it with minimal cognitive load. |
| **Secondary scale** | Dorian (1, 2, b3, 4, 5, 6, b7) | Minor character without darkness. The raised 6th degree adds subtle brightness. Used in lo-fi hip hop. |
| **Tertiary** | Aeolian (natural minor) for variety | Standard minor, familiar, non-distracting. |
| **Key center** | C major / A minor | The most "neutral" keys. No strong emotional association. |
| **Key changes** | None during deep focus. Optional modal shift every 10+ minutes. | Stability is paramount. |

### Rhythmic Characteristics
- **Tempo:** 60-90 BPM. Matches resting-to-light-activity heart rate.
- **Meter:** 4/4 exclusively. Predictable, steady.
- **Note onset density:** 4-8 notes per 8 seconds (moderate, steady)
- **Optional subtle rhythm:** Very soft hi-hat or click at 15-20% volume. Provides gentle temporal grid.
- **Timing:** Tight to grid with slight humanization (±10ms). Predictability aids habituation.
- **Rests:** 1-2 second micro-pauses. Phrases overlap slightly for continuity.

### Melodic Characteristics
- **Contour:** Flat/undulating. Small oscillations around a center. No dramatic arcs.
- **Range:** C3-G4 (narrow mid-range). Avoid extremes.
- **Intervals:** Primarily steps and 3rds. Pentatonic intervals (2, 3, 5) preferred.
- **Phrase length:** 4-6 notes. Medium-length phrases that establish pattern then rest.
- **Repetition:** HIGH. Same motifs with minimal variation. Predictability = habituation = less distraction.
- **Resolution:** Always to stable tones (1, 3, 5). Never leave unresolved.

### Harmonic Characteristics
- **Progression:** I → IV → I, I → vi → I, I → V → vi → IV (ambient pop loop). Extremely familiar.
- **Voicing:** Mid-range, not too spread. Clean, clear intervals.
- **Dissonance:** None or nearly none. Occasional sus4 → major resolution.
- **Texture:** 2-4 voices. Rich enough to mask noise, sparse enough to not demand attention.

### Timbre & Texture
- **Instruments:** Clean piano (Rhodes/Wurlitzer), warm pad, soft mallet (vibraphone, marimba)
- **Attack:** Moderate (20-100ms). Present but soft.
- **Filter:** Low-pass at 6-8kHz. Clear but not bright. No sizzle.
- **Reverb:** Medium room, 30-40% wet. Present but not washy.
- **Evolution:** Very slow. Changes every 5-10 minutes. Stability is key.

---

## 4. ENERGIZE MODE

**Goal:** Increase arousal, motivation, and physical energy. Music should drive forward motion, create anticipation, and reward with resolution. This is the only mode where real rhythm, bass, and melodic hooks are appropriate.

### Scales & Keys
| Parameter | Value | Rationale |
|-----------|-------|-----------|
| **Primary scale** | Major (Ionian: 1, 2, 3, 4, 5, 6, 7) | Bright, forward, optimistic. Activates reward centers. |
| **Secondary scale** | Mixolydian (1, 2, 3, 4, 5, 6, b7) | Major but with a "cool" b7. Rock, funk, world music. |
| **Tertiary** | Lydian (1, 2, 3, #4, 5, 6, 7) | Ultra-bright. The raised 4th creates uplift and wonder. Film trailer music. |
| **Key center** | D major / A major | Bright, resonant keys. Guitar-friendly (open strings). |
| **Key changes** | Every 3-5 minutes. Up a half step or whole step for energy boost. | Classic pop/dance music technique (modulation = energy injection). |

### Rhythmic Characteristics
- **Tempo:** 100-140 BPM. Matches active heart rate / running cadence.
- **Meter:** 4/4 with strong downbeats. Syncopation on beats 2 and 4.
- **Note onset density:** 8-16 notes per 8 seconds (dense, driving)
- **Percussion:** YES. Tabla, djembe, electronic kicks, hi-hats, claps.
- **Bass:** YES. Synth bass or bass guitar. Root-5th patterns, octave jumps.
- **Timing:** Tight to grid. Quantized for groove. Optional swing (60-70%).
- **Rests:** Brief (0.5-1s). Music maintains forward momentum.

### Melodic Characteristics
- **Contour:** Ascending, then dramatic descent to resolve. Rising lines = energy building.
- **Range:** C3-C6 (wide range). Use high register for excitement, low for power.
- **Intervals:** 4ths, 5ths, octaves (power intervals). Larger leaps for drama.
- **Phrase length:** 4-8 notes. Hooks and riffs that repeat.
- **Repetition:** Moderate with development. Establish a hook, then build on it.
- **Resolution:** Can delay resolution (suspensions, passing tones) to create forward drive.

### Harmonic Characteristics
- **Progression:** I → V → vi → IV (pop anthem), I → IV → V → I (classic drive), vi → IV → I → V
- **Voicing:** Open, spread, big. Octave doublings for power.
- **Dissonance:** Controlled. 7th chords, sus4 → major resolutions, passing chromatic notes.
- **Texture:** 3-5 voices. Full, layered, building over time.

### Timbre & Texture
- **Instruments:** Bright synth pads, electric piano, tabla/percussion, bass synth, guitar (acoustic or clean electric)
- **Attack:** Fast (5-50ms). Crisp transients for rhythmic precision.
- **Filter:** Open (8-12kHz). Bright, present, alive.
- **Reverb:** Short room, 15-25% wet. Tight, punchy. Not washy.
- **Evolution:** Builds over 3-5 min cycles. Add layers, increase density, then strip back.

---

## 5. UNIVERSAL PRINCIPLES (All Modes)

### Micro-Variation
- Never let ANY parameter stay perfectly static for more than 30 seconds
- Apply slow LFOs to filter cutoff, volume, pan, reverb send
- Use prime-number loop lengths to prevent pattern recognition

### Voice Leading
- Prefer stepwise motion (scale steps) between successive notes
- If a leap occurs, resolve by step in the opposite direction
- Common tones between chords should be sustained, not re-attacked

### Harmonic Rhythm
- Sleep: Chord changes every 8-16 bars (32-64 seconds)
- Relaxation: Every 4-8 bars (8-16 seconds)
- Focus: Every 2-4 bars (4-8 seconds)
- Energize: Every 1-2 bars (2-4 seconds)

### Dynamic Range
- Sleep: 4-6 dB (nearly flat)
- Relaxation: 6-8 dB (gentle swells)
- Focus: 4-6 dB (steady, predictable)
- Energize: 8-14 dB (dramatic builds and drops)

### Frequency Spectrum
- Sleep: Below 2kHz dominant. Almost no high-frequency content.
- Relaxation: Below 4kHz dominant. Gentle presence.
- Focus: 200Hz-6kHz balanced. Clear mid-range.
- Energize: Full spectrum 60Hz-12kHz. Strong bass, bright highs.
