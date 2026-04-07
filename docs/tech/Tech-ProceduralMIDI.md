# Procedural MIDI Generation — Research & Implementation Guide

> **Purpose:** Exhaustive reference for upgrading `generate_midi_v4.py` from basic weighted random walk to musically sophisticated procedural composition. Covers algorithms, genre-specific patterns, and concrete implementation strategies for BioNaural's four modes (Sleep, Relaxation, Focus, Energize).

---

## Table of Contents

1. [Current State & Gaps](#1-current-state--gaps)
2. [Markov Chains](#2-markov-chains)
3. [L-Systems for Music](#3-l-systems-for-music)
4. [Constraint-Based Generation](#4-constraint-based-generation)
5. [Tension-Resolution Curves](#5-tension-resolution-curves)
6. [Genre-Specific Rhythmic Patterns](#6-genre-specific-rhythmic-patterns)
7. [Authentic Bass Lines](#7-authentic-bass-lines)
8. [Authentic Drum Programming](#8-authentic-drum-programming)
9. [Melodic Contour Algorithms](#9-melodic-contour-algorithms)
10. [Harmonic Progression Generation](#10-harmonic-progression-generation)
11. [Humanization & Feel](#11-humanization--feel)
12. [Mode-Specific Composition Strategies](#12-mode-specific-composition-strategies)
13. [Implementation Plan for v5](#13-implementation-plan-for-v5)
14. [References](#14-references)

---

## 1. Current State & Gaps

### What v4 does well
- Deterministic seeding (reproducible outputs)
- Mode-aware arc envelopes (energy curves over time)
- Voice-leading with contour bias (stepwise preference)
- 10 variation templates with register/density/swing modifiers
- Genre-specific instrument programs and chord progressions
- 16-step drum patterns per genre

### What v4 lacks
| Gap | Impact |
|-----|--------|
| **Melody is weighted random walk** | Notes feel aimless — no phrases, no motifs, no call-and-response |
| **No Markov or probabilistic modeling** | Can't learn or encode stylistic tendencies |
| **Bass only plays chord roots** | Sounds mechanical — no walking, no syncopation, no genre idiom |
| **Drums are static 16-step loops** | No fills, no variation, no groove evolution over 60s |
| **No tension-resolution** | Harmonic progressions don't breathe — no buildup, no release |
| **No phrase structure** | No antecedent-consequent, no 4/8-bar phrasing |
| **No rhythmic variation** | All genres use the same note-placement logic |
| **Chords are block voicings** | No arpeggiation, no broken chords, no rhythmic comping |
| **No motif development** | A melody note sequence is never revisited or varied |

---

## 2. Markov Chains

### Concept
A Markov chain models music as a sequence of states (notes, intervals, or rhythm tokens) where the probability of the next state depends only on the current state (first-order) or the last N states (Nth-order). This captures stylistic patterns without explicit rules.

### First-Order (Pitch)
- **State:** MIDI note number (or scale degree)
- **Transition matrix:** `P[current_note][next_note]` = probability
- Build the matrix from a corpus of melodies in the target genre/mode, or hand-craft it from music theory rules

Example transition matrix for pentatonic minor (scale degrees 1,b3,4,5,b7):
```
From \ To    1     b3    4     5     b7
1          0.10  0.30  0.25  0.25  0.10
b3         0.25  0.05  0.35  0.20  0.15
4          0.20  0.20  0.05  0.40  0.15
5          0.30  0.15  0.25  0.05  0.25
b7         0.35  0.15  0.15  0.25  0.10
```

### Second-Order (Bigram Context)
- **State:** Tuple of (previous_note, current_note)
- Captures directional tendencies: "if I just went up a 3rd, I'm likely to step back down"
- Dramatically improves naturalness at the cost of a larger matrix

### Interval-Based Markov
Instead of absolute pitches, model intervals (semitone distances):
- **State:** interval from previous note (e.g., +2, -1, +5, 0)
- More generalizable across keys and octaves
- Combine with scale-degree constraints to stay in key

### Rhythm Markov
Model note durations as a separate chain:
- **States:** duration classes (16th, 8th, dotted-8th, quarter, half, whole)
- **Transitions:** encode rhythmic tendencies (e.g., after a long note, short notes are more likely)
- Can be coupled with pitch Markov for a joint (pitch, duration) model

### Implementation Strategy
```python
class MarkovMelody:
    def __init__(self, order=2, scale_degrees=None):
        self.order = order
        self.pitch_chain = defaultdict(Counter)  # {context: {next: count}}
        self.rhythm_chain = defaultdict(Counter)
        self.scale_degrees = scale_degrees

    def train(self, melodies: list[list[tuple[int, float]]]):
        """Train from a list of melodies, each a list of (pitch, duration) tuples."""
        for melody in melodies:
            intervals = [melody[i+1][0] - melody[i][0] for i in range(len(melody)-1)]
            durations = [m[1] for m in melody]
            for i in range(self.order, len(intervals)):
                context = tuple(intervals[i-self.order:i])
                self.pitch_chain[context][intervals[i]] += 1
            for i in range(self.order, len(durations)):
                context = tuple(durations[i-self.order:i])
                self.rhythm_chain[context][durations[i]] += 1

    def generate(self, length: int, start_pitch: int) -> list[tuple[int, float]]:
        """Generate a melody of `length` notes starting from `start_pitch`."""
        # ... weighted random selection from transition probabilities
```

### BioNaural Application
- **Sleep:** High self-transition probability (repeated notes), strong descending bias, long durations dominate the rhythm chain
- **Focus:** Narrow interval distribution (mostly steps), consistent rhythmic values (predictability = focus)
- **Energize:** Wide interval distribution (leaps OK), syncopated rhythm chain with short values
- **Relaxation:** Moderate intervals, mixture of short and long (breathing-like)

---

## 3. L-Systems for Music

### Concept
L-systems (Lindenmayer systems) are parallel rewriting systems originally designed for modeling plant growth. Applied to music, they generate self-similar, fractal-like structures that sound organic and structured simultaneously.

### How It Works
1. Define an **alphabet** of musical symbols (notes, rests, actions)
2. Define **production rules** that replace symbols with sequences
3. Start with an **axiom** (seed phrase) and iterate N times
4. **Interpret** the resulting string as musical events

### Musical Alphabet Example
```
A = play root note (scale degree 1)
B = play 3rd (scale degree 3)
C = play 5th (scale degree 5)
+ = move up one scale degree
- = move down one scale degree
[ = save state (push position/octave)
] = restore state (pop)
. = rest
> = increase velocity
< = decrease velocity
^ = octave up
v = octave down
```

### Production Rules for Sleep Mode
```
Axiom: A . . B
Rules:
  A → A . - A      (root note, rest, step down, root note)
  B → B . . v B    (3rd, long rest, octave down, 3rd)
  . → . .           (rests expand — music gets sparser)
```

After 3 iterations:
```
A . - A . . . - A . - A . . . . . . v B . . v B . . . . . . v v B . . v B
```
Result: a melody that naturally becomes sparser and descends — perfect for sleep.

### Production Rules for Energize Mode
```
Axiom: A B C
Rules:
  A → A + B A       (root, step up, 3rd, root — builds energy)
  B → B C + B       (3rd, 5th, step up, 3rd — ascending)
  C → C > A C       (5th, louder, root, 5th — accent pattern)
```
Result: increasingly dense, ascending, accented patterns.

### Stochastic L-Systems
Add probability to rules for variety:
```
A → A . - A   (60%)
A → A B A     (30%)
A → A . . A   (10%)
```
Different variations select different random paths through the rule space.

### Implementation
```python
class MusicalLSystem:
    def __init__(self, axiom: str, rules: dict, iterations: int):
        self.axiom = axiom
        self.rules = rules
        self.iterations = iterations

    def generate(self) -> str:
        current = self.axiom
        for _ in range(self.iterations):
            next_str = ""
            for char in current:
                if char in self.rules:
                    rule = self.rules[char]
                    if isinstance(rule, list):  # stochastic
                        next_str += random.choices(
                            [r[0] for r in rule],
                            weights=[r[1] for r in rule]
                        )[0]
                    else:
                        next_str += rule
                else:
                    next_str += char
            current = next_str
        return current

    def interpret(self, lstring: str, root_midi: int, scale: list) -> list:
        """Convert L-system string to MIDI note events."""
        notes = []
        pos = 0  # current scale degree index
        octave = 0
        velocity = 70
        time = 0.0
        stack = []

        for char in lstring:
            if char in "ABCDEFG":
                degree = ord(char) - ord('A')
                midi = root_midi + scale[degree % len(scale)] + octave * 12
                notes.append({"note": midi, "velocity": velocity, "time": time})
                time += 0.25
            elif char == '+': pos += 1
            elif char == '-': pos -= 1
            elif char == '^': octave += 1
            elif char == 'v': octave -= 1
            elif char == '>': velocity = min(127, velocity + 10)
            elif char == '<': velocity = max(1, velocity - 10)
            elif char == '.': time += 0.25  # rest
            elif char == '[': stack.append((pos, octave, velocity))
            elif char == ']': pos, octave, velocity = stack.pop()

        return notes
```

### Why L-Systems for BioNaural
- **Self-similarity** creates coherent, recognizable patterns without exact repetition
- **Parametric control** over density (iterations), direction (rule bias), and complexity
- **Deterministic** with seeded stochastic variants — perfect for reproducible generation
- **Naturally creates phrase structure** — the tree-like expansion maps to musical form

---

## 4. Constraint-Based Generation

### Concept
Instead of generating notes freely and hoping they sound good, define musical **constraints** that any valid output must satisfy. Then use constraint satisfaction (backtracking, heuristic search, or penalty-based scoring) to find sequences that meet all constraints simultaneously.

### Constraint Categories

#### Hard Constraints (must satisfy)
1. **Scale membership:** Every note must belong to the active scale
2. **Range bounds:** Notes must stay within the mode's octave range
3. **Maximum interval:** No leap larger than an octave (12 semitones) for melody
4. **Avoid parallel fifths/octaves:** Consecutive voices shouldn't move in parallel perfect intervals (classical constraint, optional for modern genres)
5. **Rhythmic alignment:** Notes should align to the grid (quantized to 16th or 8th notes)
6. **Duration minimum:** No note shorter than the mode's minimum duration

#### Soft Constraints (prefer, penalize violations)
1. **Stepwise motion preference:** Penalize leaps > 4 semitones (weight: 0.7)
2. **Contour adherence:** Penalize notes that move against the target contour (weight: 0.5)
3. **Resolution tendency:** After a leap, prefer stepwise motion back (weight: 0.6)
4. **Repetition avoidance:** Penalize more than 3 consecutive repeated pitches (weight: 0.3)
5. **Climax placement:** The highest note should fall near the golden ratio point (~62%) of the phrase (weight: 0.4)
6. **Cadential patterns:** Phrase endings should approach the tonic by step (weight: 0.8)
7. **Register balance:** Median pitch should stay near the center of the range (weight: 0.2)

### Scoring Function
```python
def score_melody(notes: list, constraints: dict, mode_cfg: dict) -> float:
    score = 0.0
    weights = constraints.get("weights", {})

    for i in range(1, len(notes)):
        interval = abs(notes[i]["note"] - notes[i-1]["note"])

        # Stepwise preference
        if interval <= 2:
            score += weights.get("stepwise", 0.7) * 1.0
        elif interval <= 4:
            score += weights.get("stepwise", 0.7) * 0.5
        elif interval > 7:
            score -= weights.get("stepwise", 0.7) * 0.5

        # Leap resolution
        if i >= 2:
            prev_interval = notes[i-1]["note"] - notes[i-2]["note"]
            curr_interval = notes[i]["note"] - notes[i-1]["note"]
            if abs(prev_interval) > 4 and curr_interval * prev_interval < 0:
                score += weights.get("resolution", 0.6) * 1.0  # resolved

        # Contour adherence
        progress = notes[i]["startTime"] / mode_cfg.get("duration", 60)
        expected_direction = get_contour_direction(mode_cfg["contour"], progress)
        actual_direction = 1 if notes[i]["note"] > notes[i-1]["note"] else -1
        if actual_direction == expected_direction:
            score += weights.get("contour", 0.5) * 0.5

    return score
```

### Generate-and-Test vs. Guided Search
1. **Generate-and-test:** Generate N candidates, score each, keep the best. Simple but wasteful.
2. **Guided search:** At each note choice, evaluate all candidates against constraints and pick the highest-scoring. More efficient.
3. **Beam search:** Maintain K best partial melodies, extend each, prune to K best. Good balance of quality and speed.

### BioNaural Application
For real-time generation (v5), use guided search with mode-specific constraint weights:

| Constraint | Sleep | Relax | Focus | Energize |
|-----------|-------|-------|-------|----------|
| Stepwise | 0.9 | 0.7 | 0.8 | 0.4 |
| Contour | 0.8 | 0.6 | 0.3 | 0.7 |
| Resolution | 0.5 | 0.6 | 0.7 | 0.3 |
| Repetition avoid | 0.2 | 0.4 | 0.6 | 0.5 |
| Cadence | 0.3 | 0.7 | 0.5 | 0.4 |
| Register balance | 0.3 | 0.5 | 0.7 | 0.4 |

---

## 5. Tension-Resolution Curves

### Concept
Musical tension is the listener's sense of instability or anticipation. Resolution is the return to stability. Without tension-resolution arcs, music feels static and emotionally flat — the primary complaint about v4's output.

### Sources of Musical Tension
1. **Harmonic tension:** Dissonant intervals (tritones, minor 2nds, major 7ths), non-tonic chords, suspended chords, dominant 7ths
2. **Melodic tension:** Large leaps, notes outside the expected range, chromatic passing tones, unresolved phrases
3. **Rhythmic tension:** Syncopation, accelerating note density, cross-rhythms, unexpected accents
4. **Dynamic tension:** Crescendo, sudden dynamic changes
5. **Registral tension:** Extreme high or low notes, expanding range

### Tension Curve Shapes

```
Sleep (gradual release):
  T: ████▓▓▓▓░░░░░░░░░░░░
     high → sustained low → zero

Relaxation (wave/breathe):
  T: ░░▓▓████▓▓░░▓▓███▓▓░░
     gentle rise → peak → release → rise → peak → release

Focus (plateau with micro-variation):
  T: ░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░
     steady moderate tension — not boring, not distracting

Energize (escalating with payoffs):
  T: ░░▓▓████░░▓▓█████░░▓▓██████
     build → release → bigger build → release → biggest build
```

### Implementation: Tension as a Control Parameter

```python
def tension_curve(mode: str, progress: float) -> float:
    """Returns tension level 0.0-1.0 for a given progress through the piece."""
    if mode == "sleep":
        # Exponential decay
        return max(0, 0.4 * math.exp(-3.0 * progress))

    elif mode == "relaxation":
        # Sinusoidal breathing pattern (2 cycles over the piece)
        return 0.3 + 0.2 * math.sin(progress * 4 * math.pi)

    elif mode == "focus":
        # Flat with subtle 8-bar micro-variation
        bar_progress = (progress * 16) % 1.0  # 16 phrases
        return 0.4 + 0.1 * math.sin(bar_progress * 2 * math.pi)

    elif mode == "energize":
        # Ramp with periodic drops (tension-release cycles)
        base_ramp = progress * 0.6  # overall escalation
        cycle = math.sin(progress * 6 * math.pi)  # 3 build-release cycles
        drop = max(0, cycle) * 0.3
        return min(1.0, 0.2 + base_ramp + drop)

    return 0.5
```

### Applying Tension to Musical Parameters

| Tension Level | Harmony | Melody | Rhythm | Dynamics |
|--------------|---------|--------|--------|----------|
| 0.0 (rest) | Root position tonic | Tonic/5th, long notes | Sparse, on-beat | pp-p |
| 0.3 (low) | I, IV, vi | Stepwise, mid-range | Regular, gentle swing | mp |
| 0.5 (moderate) | ii, V, secondary dom | Wider intervals, range expansion | Some syncopation | mf |
| 0.7 (high) | Diminished, augmented, sus | Large leaps, high register | Dense, cross-rhythm | f |
| 1.0 (peak) | Tritone sub, chromatic | Peak note, maximum range | Fills, polyrhythm | ff |

### Tension-Driven Chord Selection
```python
def select_chord(tension: float, key: str, scale: list, progression_bank: dict) -> list:
    """Select a chord appropriate for the current tension level."""
    if tension < 0.2:
        # Tonic stability — I, vi
        return random.choice([progression_bank["tonic"], progression_bank["submediant"]])
    elif tension < 0.5:
        # Subdominant area — IV, ii
        return random.choice([progression_bank["subdominant"], progression_bank["supertonic"]])
    elif tension < 0.8:
        # Dominant area — V, V7, iii
        return random.choice([progression_bank["dominant"], progression_bank["dominant7"]])
    else:
        # Maximum tension — diminished, augmented, tritone substitution
        return random.choice([progression_bank["diminished"], progression_bank["augmented"]])
```

---

## 6. Genre-Specific Rhythmic Patterns

### The Problem with v4
v4 uses a single note-placement algorithm for all genres — density and swing are the only differentiators. Real genres have fundamentally different rhythmic DNA.

### Lo-Fi Hip Hop
- **Feel:** Laid-back, slightly behind the beat
- **Swing:** 55-62% (subtle)
- **Key pattern:** Kick on 1, snare on 3, hi-hat 8ths with ghost notes
- **Melodic rhythm:** Lots of space, notes slightly after the beat (10-30ms late)
- **Bass:** Half-time feel, sustained notes on 1 and 3, occasional 16th-note fills
- **Signature:** Sample chops — notes that start and stop abruptly mid-sustain

```python
LOFI_RHYTHM = {
    "melody_grid": [1, 0, 0, 0, 0.3, 0, 0.7, 0, 1, 0, 0, 0.5, 0, 0, 0.3, 0],
    "timing_offset_ms": 15,  # behind the beat
    "velocity_groove": [100, 40, 60, 40, 80, 40, 60, 40, 90, 40, 55, 40, 75, 40, 60, 40],
    "note_probability": 0.35,  # sparse
}
```

### Jazz
- **Feel:** Swing 8ths (66-72% ratio), walking motion
- **Key pattern:** Ride cymbal swing pattern (ding-ding-a-ding), kick feathering
- **Melodic rhythm:** Bebop 8th note lines punctuated by rests, anticipations on beat 4+
- **Bass:** Walking quarter notes, chromatic approaches on beat 4
- **Chords:** Comp on upbeats (Freddie Green style), shell voicings

```python
JAZZ_RHYTHM = {
    "swing_ratio": 0.67,  # triplet swing
    "melody_density": 0.7,  # busy 8th note lines
    "approach_tones": True,  # chromatic lead-ins to target notes
    "anticipation_prob": 0.3,  # notes arriving an 8th early
    "walking_bass": True,
}
```

### Ambient / Sleep
- **Feel:** Free time, no strong pulse, events float
- **Key pattern:** No drums. Occasional deep sub hits.
- **Melodic rhythm:** Irregular intervals (2-16 seconds between notes), notes sustain until the next one
- **Bass:** Drones or very long pedal tones (8-16 bars)
- **Pads:** Evolving sustained chords with slow attack/release

```python
AMBIENT_RHYTHM = {
    "meter": None,  # no fixed meter
    "note_interval_range": (2.0, 16.0),  # seconds between events
    "sustain_to_next": True,  # each note rings until the next
    "quantize": False,  # free time
    "velocity_range": (20, 50),  # always quiet
}
```

### Electronic / EDM
- **Feel:** Strictly quantized, machine-precise, four-on-the-floor
- **Key pattern:** Kick every beat, offbeat hi-hats, snare on 2 and 4, build/drop structure
- **Melodic rhythm:** Arpeggiated patterns (16th note), gated synths
- **Bass:** Sidechain-pumping pattern (8th notes with velocity envelope), sub bass on 1
- **Signature:** Build-up (snare roll) → drop (everything hits) → breakdown (sparse)

```python
ELECTRONIC_RHYTHM = {
    "quantize": True,  # machine-tight
    "arp_patterns": [
        [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0],  # straight 8ths
        [1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,1],  # syncopated
        [1,1,0,1, 1,0,1,1, 0,1,1,0, 1,1,0,1],  # dense 16ths
    ],
    "sidechain_envelope": [1.0, 0.3, 0.5, 0.7, 1.0, 0.3, 0.5, 0.7],
    "build_drop_structure": True,
}
```

### Rock
- **Feel:** Straight 8ths, strong backbeat
- **Key pattern:** Kick/snare alternation, ride or crash cymbal on every 8th
- **Melodic rhythm:** Phrase-based (2-4 bars), rests between phrases
- **Bass:** Root-5th patterns, follows kick drum rhythm
- **Power chords:** 8th note strumming or sustained power chords

```python
ROCK_RHYTHM = {
    "swing_ratio": 0.50,  # straight (no swing)
    "backbeat_emphasis": 1.5,  # snare louder on 2 and 4
    "phrase_length_bars": 4,
    "rest_between_phrases": True,
    "bass_follows_kick": True,
}
```

### Reggae
- **Feel:** Half-time, emphasis on the "and" of beats 2 and 4 (skank)
- **Key pattern:** Rimshot on 3, kick on 1 after the 3, organ skank on upbeats
- **Melodic rhythm:** Sparse, behind the beat
- **Bass:** One-drop pattern — heavy on beat 3, often plays a melodic hook
- **Chords:** Upbeat stabs only (muted on downbeats)

```python
REGGAE_RHYTHM = {
    "skank_pattern": [0,1,0,1, 0,1,0,1, 0,1,0,1, 0,1,0,1],  # upbeats only
    "one_drop_bass": True,  # bass on beat 3
    "behind_beat_ms": 20,
    "chord_mute_downbeats": True,
}
```

### Latin (Bossa Nova / Samba influence)
- **Feel:** Syncopated, clave-based, 2-3 or 3-2 pattern
- **Key pattern:** Clave rhythm drives everything, shaker on 16ths, kick sparse
- **Melodic rhythm:** Anticipations (notes land on "and" before the target beat)
- **Bass:** Tumbao pattern — root on 1, anticipation of chord change on 4+

```python
LATIN_RHYTHM = {
    "clave_pattern": "3-2",  # or "2-3"
    "clave_32": [1,0,0,1, 0,0,1,0, 0,0,1,0, 0,1,0,0],  # 3-2 son clave
    "clave_23": [0,0,1,0, 0,1,0,0, 1,0,0,1, 0,0,1,0],  # 2-3 son clave
    "anticipation_prob": 0.5,  # very syncopated
    "tumbao_bass": True,
}
```

### Blues
- **Feel:** Shuffle (triplet swing ~67%), lazy behind-the-beat feel
- **Key pattern:** 12-bar form with turnaround, shuffle hi-hat
- **Melodic rhythm:** Call-and-response (play 2 bars, rest 2 bars), bends and slides
- **Bass:** Walking or boogie-woogie (8th note root-5th-6th-5th pattern)
- **Form:** 12-bar blues (I-I-I-I / IV-IV-I-I / V-IV-I-V)

```python
BLUES_RHYTHM = {
    "swing_ratio": 0.67,  # shuffle
    "twelve_bar_form": True,
    "call_response_bars": (2, 2),  # play 2, rest 2
    "turnaround": True,  # last 2 bars have characteristic lick
    "boogie_bass": [0, 0, 7, 7, 9, 9, 7, 7],  # root-5th-6th-5th in scale degrees
}
```

### Classical
- **Feel:** Flexible tempo (rubato), strong-weak beat hierarchy
- **Key pattern:** No drum kit — orchestral percussion only if any
- **Melodic rhythm:** Period phrasing (antecedent 4 bars + consequent 4 bars)
- **Bass:** Alberti bass (broken chord arpeggiation), or cello-like sustained lines
- **Form:** Binary (A-B), ternary (A-B-A), or theme-and-variations

```python
CLASSICAL_RHYTHM = {
    "rubato": True,
    "phrase_structure": "period",  # antecedent + consequent
    "alberti_bass": [0, 2, 1, 2],  # root-5th-3rd-5th (scale degree indices)
    "dynamic_phrasing": True,  # crescendo to phrase peak, diminuendo at end
    "form": "ternary",
}
```

---

## 7. Authentic Bass Lines

### v4 Problem
Bass only plays chord roots with an occasional passing 5th. This sounds like a beginner's MIDI arrangement.

### Walking Bass (Jazz / Blues)
```python
def generate_walking_bass(chord_roots: list, scale: list, bars: int, bpm: float) -> list:
    """Generate a walking bass line — quarter notes with chromatic approaches."""
    notes = []
    beat_dur = 60.0 / bpm
    t = 0.0

    for bar in range(bars):
        chord_root = chord_roots[bar % len(chord_roots)]
        next_root = chord_roots[(bar + 1) % len(chord_roots)]

        # Beats 1-3: chord tones + scale tones
        beat1 = chord_root  # always start on root
        beat2 = nearest_scale_note(chord_root + 4, scale)  # 3rd
        beat3 = nearest_scale_note(chord_root + 7, scale)  # 5th

        # Beat 4: chromatic approach to next bar's root
        # One semitone above or below the next root
        if next_root > chord_root:
            beat4 = next_root - 1  # approach from below
        else:
            beat4 = next_root + 1  # approach from above

        for i, note in enumerate([beat1, beat2, beat3, beat4]):
            vel = 75 if i == 0 else 65  # accent beat 1
            notes.append({
                "note": note,
                "velocity": vel + random.randint(-3, 3),
                "startTime": round(t, 3),
                "duration": round(beat_dur * 0.85, 3),
            })
            t += beat_dur

    return notes
```

### Root-Fifth Pattern (Rock / Pop)
```python
def generate_root_fifth_bass(chord_roots: list, beat_dur: float, bars: int) -> list:
    """Simple but effective rock bass — root on 1&3, fifth on 2&4."""
    notes = []
    t = 0.0
    for bar in range(bars):
        root = chord_roots[bar % len(chord_roots)]
        fifth = root + 7
        for beat, note in enumerate([root, fifth, root, fifth]):
            vel = 85 if beat % 2 == 0 else 70
            notes.append({"note": note, "velocity": vel, "startTime": round(t, 3),
                          "duration": round(beat_dur * 0.9, 3)})
            t += beat_dur
    return notes
```

### Tumbao (Latin)
```python
def generate_tumbao_bass(root: int, fifth: int, octave_root: int, beat_dur: float) -> list:
    """Classic Afro-Cuban tumbao bass pattern — anticipated root on 4-and."""
    # Pattern: rest-rest-5th-rest | root(ant.)-rest-root-rest
    pattern = [
        (None, 0), (None, 0), (fifth, 65), (None, 0),
        (root, 80), (None, 0), (octave_root, 75), (None, 0),
    ]
    # The root on beat 4-and of the previous bar anticipates the chord change
    ...
```

### Synth Bass (Electronic)
```python
def generate_synth_bass(root: int, bpm: float, bars: int) -> list:
    """Pumping synth bass with sidechain-style velocity envelope."""
    notes = []
    step_dur = 60.0 / bpm / 4  # 16th notes
    t = 0.0
    for bar in range(bars):
        for step in range(16):
            # Sidechain pump: full velocity on downbeats, dip in between
            pump = [100, 30, 50, 70,  100, 30, 50, 70,  100, 30, 50, 70,  100, 30, 50, 70]
            vel = pump[step]
            notes.append({"note": root, "velocity": vel, "startTime": round(t, 3),
                          "duration": round(step_dur * 0.7, 3)})
            t += step_dur
    return notes
```

---

## 8. Authentic Drum Programming

### Beyond 16-Step Loops
v4's drums are a single 16-step pattern that repeats identically for 60 seconds. Real drums need:

1. **Variation every 4-8 bars** — fills, ghost notes, open hi-hats
2. **Fills at phrase boundaries** — snare rolls, tom patterns, crash accents
3. **Ghost notes** — very quiet snare hits between main beats (velocity 15-30)
4. **Dynamic arc** — drums follow the overall energy curve
5. **Groove template** — slight timing offsets that create the genre's feel

### Drum Fill Generation
```python
def generate_fill(style: str, fill_length_steps: int = 8) -> list:
    """Generate a drum fill for the last 2 beats of a phrase."""
    fills = {
        "rock": {
            "notes": [38, 45, 43, 38, 45, 43, 45, 38],  # snare, lo-tom, hi-tom
            "velocity_ramp": True,  # crescendo
        },
        "jazz": {
            "notes": [38, 0, 38, 0, 38, 38, 38, 38],  # snare press roll
            "velocity_ramp": False,
        },
        "electronic": {
            "notes": [38, 38, 38, 38, 38, 38, 38, 38],  # snare roll → buildup
            "velocity_ramp": True,
        },
        "hiphop": {
            "notes": [0, 38, 0, 38, 36, 38, 36, 38],  # kick-snare pattern
            "velocity_ramp": False,
        },
    }
    fill_def = fills.get(style, fills["rock"])
    events = []
    for i, note in enumerate(fill_def["notes"][:fill_length_steps]):
        if note > 0:
            vel = 60 + int(i / fill_length_steps * 40) if fill_def["velocity_ramp"] else 75
            events.append({"note": note, "velocity": vel, "step": i})
    return events
```

### Ghost Note Layer
```python
def add_ghost_notes(drum_track: list, style: str, bpm: float) -> list:
    """Add ghost notes (very quiet snare hits) between main beats."""
    ghost_probability = {"jazz": 0.4, "hiphop": 0.3, "lofi": 0.2, "rock": 0.15}
    prob = ghost_probability.get(style, 0.1)
    step_dur = 60.0 / bpm / 4

    ghosts = []
    for i in range(64):  # 4 bars of 16th notes
        t = i * step_dur
        # Don't add ghosts where main hits exist
        has_main_hit = any(abs(n["startTime"] - t) < step_dur * 0.3 for n in drum_track)
        if not has_main_hit and random.random() < prob:
            ghosts.append({
                "note": 38,  # snare ghost
                "velocity": random.randint(12, 28),
                "startTime": round(t + random.uniform(-0.005, 0.005), 3),
                "duration": round(step_dur * 0.5, 3),
            })
    return drum_track + ghosts
```

### Groove Templates (Timing Offsets)
Real drummers don't play exactly on the grid. Each genre has characteristic timing deviations:

```python
GROOVE_TEMPLATES = {
    # Offset in ms for each 16th note position in one beat
    # Positive = late, negative = early
    "straight":  [0, 0, 0, 0],
    "swing":     [0, 0, 15, 0],      # triplet feel on 2nd 8th
    "lazy":      [0, 5, 8, 3],       # everything slightly behind (lo-fi)
    "pushing":   [0, -3, -2, -5],    # drummer leaning forward (energize)
    "shuffle":   [0, 0, 20, 0],      # heavy shuffle
    "bossa":     [0, -5, 3, -3],     # bossa nova micro-timing
}

def apply_groove(events: list, groove: list, bpm: float) -> list:
    step_dur = 60.0 / bpm / 4
    for event in events:
        step_in_beat = int(event["startTime"] / step_dur) % 4
        offset_ms = groove[step_in_beat]
        event["startTime"] += offset_ms / 1000.0
    return events
```

---

## 9. Melodic Contour Algorithms

### Beyond Random Walk
v4's `voice_lead()` biases toward step motion with a directional preference. This produces monotonous contours because there's no concept of phrases, peaks, or resting points.

### Phrase-Based Contour
Structure melody into 4-bar or 8-bar phrases with clear shapes:

```python
class PhraseContour:
    """Generates melodic contours using phrase-level planning."""

    SHAPES = {
        "arch":     lambda p: math.sin(p * math.pi),           # rise, peak at center, fall
        "valley":   lambda p: 1 - math.sin(p * math.pi),       # fall, bottom at center, rise
        "ramp_up":  lambda p: p,                                # steady ascent
        "ramp_down":lambda p: 1 - p,                            # steady descent
        "plateau":  lambda p: min(1, p * 3) if p < 0.33 else 1 if p < 0.66 else max(0, 3 - p * 3),
        "zigzag":   lambda p: abs(math.sin(p * 2 * math.pi)),  # oscillating
    }

    def __init__(self, shape: str, octave_range: tuple, scale_notes: list):
        self.shape_fn = self.SHAPES[shape]
        self.lo = min(n for n in scale_notes if n >= octave_range[0] * 12)
        self.hi = max(n for n in scale_notes if n <= octave_range[1] * 12)
        self.scale_notes = scale_notes

    def target_pitch_at(self, progress: float) -> int:
        """Get the target pitch for this point in the phrase."""
        t = self.shape_fn(progress)
        target_midi = self.lo + t * (self.hi - self.lo)
        return nearest_scale_note(int(target_midi), self.scale_notes)
```

### Motif Development
A motif is a short melodic fragment (3-7 notes) that recurs throughout a piece in varied forms:

```python
class MotifDeveloper:
    """Creates and develops melodic motifs through transformation."""

    def __init__(self, motif: list):
        """motif: list of intervals from first note, e.g. [0, 2, 4, 2, 0]"""
        self.original = motif

    def transpose(self, semitones: int) -> list:
        return [n + semitones for n in self.original]

    def invert(self) -> list:
        """Mirror intervals around the first note."""
        return [self.original[0] - (n - self.original[0]) for n in self.original]

    def retrograde(self) -> list:
        """Reverse the motif."""
        return list(reversed(self.original))

    def augment(self, factor: float = 2.0) -> list:
        """Stretch intervals by a factor."""
        return [int(self.original[0] + (n - self.original[0]) * factor) for n in self.original]

    def diminish(self, factor: float = 0.5) -> list:
        """Compress intervals."""
        return self.augment(factor)

    def fragment(self, start: int = 0, length: int = 3) -> list:
        """Extract a sub-motif."""
        return self.original[start:start + length]

    def sequence(self, transpositions: list) -> list:
        """Repeat the motif at different pitch levels (melodic sequence)."""
        result = []
        for t in transpositions:
            result.extend(self.transpose(t))
        return result

    def develop(self, technique: str) -> list:
        """Apply a development technique."""
        techniques = {
            "inversion": self.invert,
            "retrograde": self.retrograde,
            "augmentation": lambda: self.augment(2.0),
            "diminution": lambda: self.diminish(0.5),
            "retrograde_inversion": lambda: list(reversed(self.invert())),
            "fragment_head": lambda: self.fragment(0, 3),
            "fragment_tail": lambda: self.fragment(-3),
        }
        return techniques.get(technique, lambda: self.original)()
```

### Call and Response
Structure melody as alternating "call" (statement) and "response" (answer) phrases:

```python
def call_and_response(motif: list, scale: list, bars: int = 8) -> list:
    """Generate call-and-response melody from a seed motif."""
    dev = MotifDeveloper(motif)
    phrases = []

    for i in range(bars // 2):
        # Call: original or transposed motif
        call = dev.transpose(i * 2)  # sequence upward
        phrases.append(("call", call))

        # Response: varied form of the motif
        techniques = ["inversion", "retrograde", "fragment_head", "augmentation"]
        response = dev.develop(techniques[i % len(techniques)])
        phrases.append(("response", response))

    return phrases
```

---

## 10. Harmonic Progression Generation

### Beyond Static Progressions
v4 uses hardcoded 4-6 chord progressions per genre. Real music uses harmonic rhythm, secondary dominants, modal interchange, and phrase-level planning.

### Functional Harmony System
```python
FUNCTION_GROUPS = {
    "tonic":       ["I", "iii", "vi"],       # stability
    "subdominant": ["ii", "IV"],              # mild tension
    "dominant":    ["V", "vii°"],             # strong tension → resolves to tonic
    "chromatic":   ["bII", "bVII", "#IV°"],   # color/surprise
}

# Valid functional progressions (what can follow what)
HARMONIC_SYNTAX = {
    "tonic":       ["tonic", "subdominant", "dominant"],
    "subdominant": ["subdominant", "dominant", "tonic"],
    "dominant":    ["tonic"],  # dominant MUST resolve to tonic
    "chromatic":   ["dominant", "tonic"],
}
```

### Tension-Driven Progression Generator
```python
def generate_progression(tension_curve: callable, bars: int, mode: str) -> list:
    """Generate chord progression driven by the tension curve."""
    chords = []
    current_function = "tonic"

    for bar in range(bars):
        progress = bar / bars
        tension = tension_curve(mode, progress)

        # Select harmonic function based on tension level
        if tension < 0.3:
            target_function = "tonic"
        elif tension < 0.6:
            target_function = "subdominant"
        elif tension < 0.85:
            target_function = "dominant"
        else:
            target_function = "chromatic"

        # Ensure valid voice-leading (check harmonic syntax)
        valid_next = HARMONIC_SYNTAX[current_function]
        if target_function in valid_next:
            current_function = target_function
        else:
            # Pick closest valid function
            current_function = valid_next[0]

        # Select specific chord from function group
        chord_options = FUNCTION_GROUPS[current_function]
        chord = random.choice(chord_options)
        chords.append(chord)

    return chords
```

### Chord Voicing Strategies
Instead of block chords, use idiomatic voicing styles per genre:

| Genre | Voicing Style | Implementation |
|-------|--------------|----------------|
| Jazz | Shell voicings (root-7th-3rd), drop 2 | Omit 5th, add extensions |
| Lo-fi | Spread triads with added 9th | Root low, 3rd-5th-9th spread |
| Ambient | Open 5ths and 4ths, clusters | Perfect intervals, stack 4ths |
| Rock | Power chords (root-5th-octave) | No 3rd, doubled root |
| Classical | 4-part chorale (SATB) | Voice-leading rules |
| Electronic | Stacked 3rds, added 7ths/9ths | Dense upper structure |

---

## 11. Humanization & Feel

### Micro-Timing
Real musicians don't play on a perfectly quantized grid. Apply consistent, genre-appropriate timing deviations:

```python
def humanize(events: list, style: str, intensity: float = 1.0) -> list:
    """Apply humanization to MIDI events."""
    profiles = {
        "tight":    {"timing_ms": 3,  "velocity_var": 3,  "duration_var": 0.02},
        "relaxed":  {"timing_ms": 12, "velocity_var": 6,  "duration_var": 0.05},
        "sloppy":   {"timing_ms": 25, "velocity_var": 10, "duration_var": 0.10},
        "robotic":  {"timing_ms": 0,  "velocity_var": 0,  "duration_var": 0.00},
    }

    genre_profiles = {
        "electronic": "tight", "classical": "relaxed", "jazz": "relaxed",
        "lofi": "sloppy", "rock": "relaxed", "hiphop": "sloppy",
        "blues": "relaxed", "reggae": "relaxed", "latin": "tight",
        "ambient": "sloppy",
    }

    profile = profiles[genre_profiles.get(style, "relaxed")]

    for event in events:
        # Timing jitter (Gaussian, not uniform — clusters near the beat)
        event["startTime"] += random.gauss(0, profile["timing_ms"] / 1000.0) * intensity
        event["startTime"] = max(0, event["startTime"])

        # Velocity variation (subtle)
        event["velocity"] += int(random.gauss(0, profile["velocity_var"]) * intensity)
        event["velocity"] = max(1, min(127, event["velocity"]))

        # Duration variation
        dur_var = event["duration"] * profile["duration_var"] * intensity
        event["duration"] += random.gauss(0, dur_var)
        event["duration"] = max(0.01, event["duration"])

    return events
```

### Velocity Accents
Real performances have consistent accent patterns based on meter:

```python
ACCENT_PATTERNS = {
    "4/4": {
        # Beat: 1 (strong), 2 (weak), 3 (medium), 4 (weak)
        "quarter": [1.2, 0.85, 1.05, 0.90],
        "eighth":  [1.2, 0.70, 0.85, 0.65, 1.05, 0.70, 0.90, 0.65],
    },
    "3/4": {
        "quarter": [1.2, 0.80, 0.85],
    },
    "6/8": {
        "eighth": [1.2, 0.65, 0.75, 1.05, 0.65, 0.75],
    },
}

def apply_accents(events: list, meter: str, bpm: float) -> list:
    beat_dur = 60.0 / bpm
    pattern = ACCENT_PATTERNS.get(meter, ACCENT_PATTERNS["4/4"])["quarter"]
    for event in events:
        beat_index = int(event["startTime"] / beat_dur) % len(pattern)
        event["velocity"] = int(event["velocity"] * pattern[beat_index])
        event["velocity"] = max(1, min(127, event["velocity"]))
    return events
```

### Dynamic Phrasing (Hairpins)
Musical phrases naturally crescendo toward a peak and diminuendo toward the end:

```python
def apply_phrase_dynamics(events: list, phrase_length_beats: int, bpm: float) -> list:
    """Apply crescendo-diminuendo shape within each phrase."""
    beat_dur = 60.0 / bpm
    phrase_dur = phrase_length_beats * beat_dur

    for event in events:
        # Position within current phrase (0.0 to 1.0)
        phrase_progress = (event["startTime"] % phrase_dur) / phrase_dur
        # Hairpin shape: crescendo to ~60%, then diminuendo
        if phrase_progress < 0.6:
            dynamic_scale = 0.85 + 0.15 * (phrase_progress / 0.6)
        else:
            dynamic_scale = 1.0 - 0.2 * ((phrase_progress - 0.6) / 0.4)

        event["velocity"] = int(event["velocity"] * dynamic_scale)
        event["velocity"] = max(1, min(127, event["velocity"]))

    return events
```

---

## 12. Mode-Specific Composition Strategies

### Sleep Mode
**Goal:** Guide the listener from wakefulness to deep sleep. Music must become invisible.

| Parameter | Strategy |
|-----------|----------|
| **Melody** | Start with recognizable motif (3-5 notes), repeat with diminishing variation. By minute 3, only fragments remain. By minute 5, near-silence with occasional single tones. |
| **Harmony** | Start on IV or vi (warm, not assertive). Progressions slow to one chord per 8-16 bars. Final section: drone on I. |
| **Rhythm** | No beat. Note onsets are irregular (L-system timing). Spacing increases from 3s to 15s between notes. |
| **Dynamics** | Continuous decrescendo from mp to ppp. Last notes at velocity 15-25. |
| **Bass** | Drone/pedal tone. No movement. Sub-bass frequencies (MIDI notes 28-40). |
| **Texture** | Whole-tone or pentatonic scale only (no semitone tension). Reverb tail is the primary texture. |

### Relaxation Mode
**Goal:** Gentle stimulation that promotes calm alertness. Like a massage for the mind.

| Parameter | Strategy |
|-----------|----------|
| **Melody** | Breathing-like phrases: 4 bars up (inhale), 4 bars down (exhale). Arch contour. Motif repeats with gentle variation (transposition, rhythmic augmentation). |
| **Harmony** | Lydian or major. 2-chord oscillation (I-IV-I-IV) creates gentle rocking. Occasional vi or ii for color. Change every 4-8 bars. |
| **Rhythm** | Gentle pulse at 60-70 BPM (matches resting heart rate). Arpeggio patterns (broken chords) create motion without stress. |
| **Dynamics** | Wave-like: mp → mf → mp → mf. Follows the breathing metaphor. |
| **Bass** | Sustained roots with octave movement. Half notes or whole notes. Warm, round tone. |
| **Texture** | Lydian (raised 4th = openness without tension). Lots of reverb, slow attack. |

### Focus Mode
**Goal:** Maintain cognitive engagement without distraction. The music should be interesting enough to prevent mind-wandering but predictable enough to stay in the background.

| Parameter | Strategy |
|-----------|----------|
| **Melody** | Predictable intervallic patterns with subtle variation. Sequences (same shape, different pitch). No surprises. Moderate density (0.5 notes/sec). |
| **Harmony** | Modal (Dorian, Mixolydian) — not strongly directional. Avoid dominant → tonic cadences (too conclusive, breaks concentration). Loop-friendly progressions. |
| **Rhythm** | Steady pulse. Straight 8ths or gentle swing. Consistent note values (mostly quarters and 8ths). Lo-fi-inspired grooves work well. |
| **Dynamics** | Flat — mf throughout. Minimal dynamic variation (focus = consistency). |
| **Bass** | Quarter-note walking or steady root-5th. Provides grounding without demanding attention. |
| **Texture** | Mid-register (C3-C5). Avoid extreme highs (piercing) and extreme lows (rumbling). Piano, Rhodes, or warm synth patches. |

### Energize Mode
**Goal:** Build energy and motivation. Music should make the listener want to move.

| Parameter | Strategy |
|-----------|----------|
| **Melody** | Ascending riffs, hook-based. Call-and-response with drums. Rhythmically syncopated. Wide intervals (4ths, 5ths, octaves). High register. |
| **Harmony** | Major or Mixolydian. Strong I-IV-V motion. Power chords acceptable. Build-drop structure (electronic) or verse-chorus energy (rock). |
| **Rhythm** | Strong backbeat. Driving 8th or 16th notes. Kick on every beat (four-on-the-floor for electronic). Fills every 4-8 bars. |
| **Dynamics** | Escalating: start at mf, build to ff by 75%, then pull back for cool-down. |
| **Bass** | Driving, rhythmically active. 8th notes or syncopated 16ths. High velocity. Follows kick pattern. |
| **Drums** | Essential. Genre-appropriate pattern with ghost notes, fills, and dynamic arc. Open hi-hat accents for energy. Crash cymbals at section boundaries. |

---

## 13. Implementation Plan for v5

### Architecture: Layered Generation Pipeline

```
┌─────────────────────────────────────────────────────┐
│  1. FORM PLANNER                                     │
│     Input: mode, genre, duration, tension_curve      │
│     Output: section map (intro, A, B, bridge, outro) │
│             + tension value per bar                   │
├─────────────────────────────────────────────────────┤
│  2. HARMONY ENGINE                                   │
│     Input: section map, tension per bar              │
│     Output: chord progression with voicings          │
│     Method: tension-driven functional harmony        │
├─────────────────────────────────────────────────────┤
│  3. MOTIF GENERATOR                                  │
│     Input: mode, scale, seed                         │
│     Output: 2-3 seed motifs (3-7 notes each)        │
│     Method: constraint-based + Markov                │
├─────────────────────────────────────────────────────┤
│  4. MELODY WEAVER                                    │
│     Input: chord progression, motifs, contour        │
│     Output: melody track                             │
│     Method: motif development + phrase contour       │
│             + constraint scoring                     │
├─────────────────────────────────────────────────────┤
│  5. BASS GENERATOR                                   │
│     Input: chord roots, genre, tension               │
│     Output: bass track                               │
│     Method: genre-specific patterns (walking,        │
│             root-5th, tumbao, synth pump)            │
├─────────────────────────────────────────────────────┤
│  6. CHORD VOICER                                     │
│     Input: chord symbols, genre, register            │
│     Output: chord/pad track                          │
│     Method: genre-specific voicing rules +           │
│             rhythmic comping patterns                │
├─────────────────────────────────────────────────────┤
│  7. DRUM PROGRAMMER                                  │
│     Input: genre, tension, section boundaries        │
│     Output: drum track with fills + ghosts           │
│     Method: pattern library + fill generator +       │
│             ghost note layer + groove template       │
├─────────────────────────────────────────────────────┤
│  8. HUMANIZER                                        │
│     Input: all tracks                                │
│     Output: humanized tracks                         │
│     Method: genre-specific timing/velocity profiles  │
│             + phrase dynamics + accent patterns      │
└─────────────────────────────────────────────────────┘
```

### Priority Order (highest impact first)

1. **Tension-resolution curves** — The single biggest improvement. Makes music feel alive.
2. **Genre-specific drum patterns with fills** — Drums define the genre feel more than any other element.
3. **Bass line patterns per genre** — Walking, root-5th, tumbao, synth pump.
4. **Motif-based melody** — Introduce a seed motif and develop it (repeat, transpose, invert, fragment).
5. **Phrase structure** — 4-bar and 8-bar phrasing with antecedent-consequent relationships.
6. **Humanization** — Genre-appropriate timing and velocity profiles.
7. **Harmonic sophistication** — Tension-driven progression generation, secondary dominants.
8. **L-system experimentation** — Especially for Sleep and Ambient modes where organic structure helps.

### Migration Strategy
- Keep v4's `generate_sequence()` API signature unchanged
- Replace internal generators one at a time (bass first, then drums, then melody)
- Each improvement is testable in isolation via A/B comparison with v4 output
- Seed-based determinism must be preserved — same inputs = same outputs
- All new algorithms must be pure Python, no dependencies, runs in seconds

### Estimated Output Quality Improvement

| Component | v4 Quality | v5 Target | Key Technique |
|-----------|-----------|-----------|---------------|
| Melody | 3/10 | 7/10 | Markov + motif + phrase contour |
| Bass | 2/10 | 8/10 | Genre-specific patterns |
| Drums | 4/10 | 8/10 | Fills + ghosts + groove templates |
| Harmony | 5/10 | 7/10 | Tension-driven + voicing rules |
| Overall feel | 3/10 | 7/10 | Humanization + dynamic phrasing |

---

## 14. References

### Academic & Foundational
- Nierhaus, G. (2009). *Algorithmic Composition*. Springer. — Comprehensive survey of all techniques.
- Cope, D. (2000). *The Algorithmic Composer*. A-R Editions. — EMI system, Markov + pattern matching.
- Prusinkiewicz, P. & Lindenmayer, A. (1990). *The Algorithmic Beauty of Plants*. — L-systems foundation.
- Lerdahl, F. & Jackendoff, R. (1983). *A Generative Theory of Tonal Music*. MIT Press. — Formal tension model.

### Practical / Implementable
- Collins, N. (2009). "Musical Form and Algorithmic Composition." Contemporary Music Review. — Form-level generation.
- Pachet, F. (2003). "The Continuator: Musical Interaction with Style." Journal of New Music Research. — Markov models for style imitation.
- Quick, D. (2014). *Kulitta: A Framework for Automated Music Composition*. Yale PhD thesis. — Constraint-based generation with learned harmony.

### Genre-Specific Drum Programming
- GM drum map (General MIDI Level 1): Note 35 = Acoustic Bass Drum, 36 = Bass Drum 1, 38 = Acoustic Snare, 42 = Closed Hi-Hat, 46 = Open Hi-Hat, 49 = Crash 1, 51 = Ride Cymbal, 37 = Side Stick, 75 = Claves
- Groove templates from: BFD, Superior Drummer, EZDrummer MIDI libraries (patterns, not samples)

### Code References
- `generate_midi_v4.py` — Current generator (baseline)
- `services/midi-generation/output_v4/` — v4 output for comparison
- `docs/product/Feature-SoundSample.md` — Sound DNA feature (user preference input)
- `docs/science/Science-FunctionalMusicTheory.md` — BioNaural's music theory rules (if exists)

---

*Document created: 2026-04-07. Research for generate_midi_v5.py upgrade.*
