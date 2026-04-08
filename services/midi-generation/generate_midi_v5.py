"""
BioNaural MIDI Generator v5 — Advanced Procedural Composition

Generates 400 MIDI sequences (10 genres x 4 modes x 10 variations) using
a layered composition pipeline:

  1. Form Planner     — section structure (intro/A/B/climax/outro) + tension curve
  2. Harmony Engine   — tension-driven functional chord progressions
  3. Motif Generator  — seed motifs with development (transpose/invert/retrograde/fragment)
  4. Melody Weaver    — Markov + motif + phrase contour + constraint scoring
  5. Bass Generator   — genre-specific patterns (walking/root-5th/tumbao/synth-pump/drone)
  6. Chord Voicer     — genre-specific voicings with rhythmic comping
  7. Drum Programmer  — fills + ghost notes + groove templates + dynamic arc
  8. Humanizer        — genre-specific timing/velocity/accent profiles

NO API CALLS. Pure Python. Runs in seconds. $0 cost.
"""

import json
import math
import os
import random
from collections import defaultdict
from pathlib import Path

# ============================================================================
# SCALES
# ============================================================================
SCALES = {
    "pentatonic_minor": [0, 3, 5, 7, 10],
    "pentatonic_major": [0, 2, 4, 7, 9],
    "whole_tone":       [0, 2, 4, 6, 8, 10],
    "aeolian":          [0, 2, 3, 5, 7, 8, 10],
    "dorian":           [0, 2, 3, 5, 7, 9, 10],
    "lydian":           [0, 2, 4, 6, 7, 9, 11],
    "ionian":           [0, 2, 4, 5, 7, 9, 11],
    "mixolydian":       [0, 2, 4, 5, 7, 9, 10],
    "blues":            [0, 3, 5, 6, 7, 10],
    "phrygian":         [0, 1, 3, 5, 7, 8, 10],
    "harmonic_minor":   [0, 2, 3, 5, 7, 8, 11],
}

ROOTS = {"C": 0, "Db": 1, "D": 2, "Eb": 3, "E": 4, "F": 5,
         "Gb": 6, "G": 7, "Ab": 8, "A": 9, "Bb": 10, "B": 11}

# ============================================================================
# MODE DEFINITIONS
# ============================================================================
MODES = {
    "sleep": {
        "bpm": 48, "vel_range": (25, 45), "dur_range": (4.0, 16.0),
        "density": 0.15, "max_poly": 3, "has_drums": False,
        "contour": "descending", "octave_range": (2, 4),
        "scales": ["pentatonic_minor", "whole_tone", "aeolian", "dorian"],
        "keys": ["F", "Db", "Ab", "Eb"],
        "phrase_bars": 8, "motif_len": 3,
    },
    "relaxation": {
        "bpm": 62, "vel_range": (35, 60), "dur_range": (2.0, 8.0),
        "density": 0.3, "max_poly": 4, "has_drums": False,
        "contour": "arch", "octave_range": (3, 5),
        "scales": ["lydian", "pentatonic_major", "ionian", "mixolydian"],
        "keys": ["G", "D", "C", "A"],
        "phrase_bars": 4, "motif_len": 5,
    },
    "focus": {
        "bpm": 75, "vel_range": (40, 65), "dur_range": (0.3, 1.2),
        "density": 2.0, "max_poly": 5, "has_drums": True,
        "contour": "flat", "octave_range": (4, 5),
        "scales": ["pentatonic_major", "dorian", "ionian", "mixolydian"],
        "keys": ["C", "Bb", "D", "G"],
        "phrase_bars": 4, "motif_len": 8,
        "cell_beats": 16,  # 4-bar melodic cell
        "chord_progressions": [
            [(2, "min7"), (7, "dom7"), (0, "maj7"), (9, "min7")],   # ii7-V7-Imaj7-vi7
            [(0, "maj7"), (5, "maj7"), (0, "maj7"), (5, "maj7")],   # Imaj7-IVmaj7 loop
            [(9, "min7"), (2, "min7"), (7, "dom7"), (0, "maj7")],   # vi7-ii7-V7-Imaj7
            [(0, "maj7"), (9, "min7"), (2, "min7"), (7, "dom7")],   # Imaj7-vi7-ii7-V7
        ],
    },
    "energize": {
        "bpm": 130, "vel_range": (70, 110), "dur_range": (0.1, 0.8),
        "density": 3.0, "max_poly": 8, "has_drums": True,
        "contour": "ascending", "octave_range": (4, 6),
        "scales": ["ionian", "mixolydian", "lydian", "dorian"],
        "keys": ["D", "E", "A", "G"],
        "phrase_bars": 4, "motif_len": 4,
        "riff_steps": 16,
        "chord_progressions": [
            [(0, "maj"), (7, "maj"), (9, "min"), (5, "maj")],    # I-V-vi-IV anthem
            [(0, "maj"), (5, "maj"), (7, "dom7"), (0, "maj")],   # I-IV-V-I drive
            [(9, "min"), (5, "maj"), (0, "maj"), (7, "maj")],    # vi-IV-I-V buildup
            [(0, "maj"), (9, "min"), (5, "maj"), (7, "dom7")],   # I-vi-IV-V pop
        ],
    },
}

# ============================================================================
# GENRE DEFINITIONS
# ============================================================================
GENRES = {
    "ambient":    {"melody": 88, "bass": 89,  "chords": 91, "drums": 0, "bass_style": "drone",     "drum_style": "ambient",    "feel": "free",     "voicing": "open"},
    "lofi":       {"melody": 4,  "bass": 33,  "chords": 89, "drums": 0, "bass_style": "root_fifth","drum_style": "lofi",       "feel": "lazy",     "voicing": "spread"},
    "jazz":       {"melody": 0,  "bass": 32,  "chords": 89, "drums": 0, "bass_style": "walking",   "drum_style": "jazz",       "feel": "swing",    "voicing": "shell"},
    "rock":       {"melody": 25, "bass": 33,  "chords": 89, "drums": 0, "bass_style": "root_fifth","drum_style": "rock",       "feel": "straight", "voicing": "power"},
    "hiphop":     {"melody": 11, "bass": 38,  "chords": 89, "drums": 0, "bass_style": "synth",     "drum_style": "hiphop",     "feel": "lazy",     "voicing": "spread"},
    "blues":      {"melody": 25, "bass": 33,  "chords": 0,  "drums": 0, "bass_style": "walking",   "drum_style": "blues",      "feel": "shuffle",  "voicing": "shell"},
    "reggae":     {"melody": 24, "bass": 33,  "chords": 16, "drums": 0, "bass_style": "one_drop",  "drum_style": "reggae",     "feel": "laid_back","voicing": "triad"},
    "classical":  {"melody": 0,  "bass": 42,  "chords": 49, "drums": 0, "bass_style": "alberti",   "drum_style": "classical",  "feel": "rubato",   "voicing": "chorale"},
    "latin":      {"melody": 73, "bass": 33,  "chords": 0,  "drums": 0, "bass_style": "tumbao",    "drum_style": "latin",      "feel": "clave",    "voicing": "triad"},
    "electronic": {"melody": 81, "bass": 38,  "chords": 89, "drums": 0, "bass_style": "synth",     "drum_style": "electronic", "feel": "tight",    "voicing": "stacked"},
}

# Per-mode instrument overrides: (mode, genre) -> {role: GM program}
# Focus gets warmer timbres (Rhodes, vibraphone); energize gets brighter leads
MODE_INSTRUMENT_OVERRIDES = {
    ("focus", "hiphop"):     {"melody": 4},     # Rhodes instead of Music Box
    ("focus", "electronic"): {"melody": 5},     # Wurlitzer
    ("focus", "rock"):       {"melody": 4},     # Rhodes
    ("focus", "ambient"):    {"melody": 11},    # Vibraphone
    ("focus", "blues"):      {"melody": 4},     # Rhodes
    ("energize", "hiphop"):     {"melody": 80}, # Square Lead
    ("energize", "electronic"): {"melody": 81, "chords": 92},  # Saw Lead + Bowed Pad
    ("energize", "lofi"):       {"melody": 80}, # Square Lead
    ("energize", "ambient"):    {"melody": 81}, # Saw Lead
}

# ============================================================================
# VARIATIONS (enhanced from v4)
# ============================================================================
VARIATIONS = [
    {"id": 0, "label": "foundation",      "register": 0,  "density_mult": 1.0, "tension_shift": 0.0,  "motif_dev": "repeat",     "swing": 0.0},
    {"id": 1, "label": "sparse_low",      "register": -2, "density_mult": 0.6, "tension_shift": -0.1, "motif_dev": "transpose",  "swing": 0.0},
    {"id": 2, "label": "dense_bright",    "register": 2,  "density_mult": 1.4, "tension_shift": 0.1,  "motif_dev": "invert",     "swing": 0.0},
    {"id": 3, "label": "warm_swing",      "register": -1, "density_mult": 1.0, "tension_shift": 0.0,  "motif_dev": "retrograde", "swing": 0.08},
    {"id": 4, "label": "ethereal",        "register": 3,  "density_mult": 0.6, "tension_shift": 0.05, "motif_dev": "fragment",   "swing": 0.0},
    {"id": 5, "label": "grounded",        "register": -2, "density_mult": 1.4, "tension_shift": -0.1, "motif_dev": "sequence",   "swing": 0.0},
    {"id": 6, "label": "complex_mid",     "register": 0,  "density_mult": 1.0, "tension_shift": 0.1,  "motif_dev": "augment",    "swing": 0.06},
    {"id": 7, "label": "minimal_rubato",  "register": 0,  "density_mult": 0.5, "tension_shift": 0.05, "motif_dev": "fragment",   "swing": 0.0},
    {"id": 8, "label": "lush_arc",        "register": 1,  "density_mult": 1.3, "tension_shift": 0.0,  "motif_dev": "invert",     "swing": 0.0},
    {"id": 9, "label": "tension_release", "register": 2,  "density_mult": 1.0, "tension_shift": 0.1,  "motif_dev": "retrograde", "swing": 0.05},
]

DURATION = 60.0  # seconds per sequence

# ============================================================================
# UTILITIES
# ============================================================================
def seed_rng(genre: str, mode: str, var_id: int):
    s = hash(f"{genre}_{mode}_{var_id}_v5") % (2**31)
    random.seed(s)

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

def scale_notes(root_midi: int, scale: list, octave_low: int, octave_high: int) -> list:
    notes = []
    for octave in range(octave_low, octave_high + 1):
        for interval in scale:
            midi = root_midi + (octave - 5) * 12 + interval
            if 0 <= midi <= 127:
                notes.append(midi)
    return sorted(set(notes))

def nearest_scale(target: int, pool: list) -> int:
    if not pool:
        return clamp(target, 0, 127)
    return min(pool, key=lambda n: abs(n - target))

def weighted_choice(items, weights):
    total = sum(weights)
    r = random.random() * total
    cumulative = 0
    for item, w in zip(items, weights):
        cumulative += w
        if r <= cumulative:
            return item
    return items[-1]


# ============================================================================
# 1. TENSION CURVES
# ============================================================================
def tension_curve(mode: str, progress: float, shift: float = 0.0) -> float:
    """Returns tension 0.0-1.0 for a given progress through the piece."""
    if mode == "sleep":
        t = max(0, 0.4 * math.exp(-3.0 * progress))
    elif mode == "relaxation":
        t = 0.3 + 0.2 * math.sin(progress * 4 * math.pi)
    elif mode == "focus":
        bar_p = (progress * 16) % 1.0
        t = 0.4 + 0.1 * math.sin(bar_p * 2 * math.pi)
    elif mode == "energize":
        base = progress * 0.6
        cycle = math.sin(progress * 6 * math.pi)
        drop = max(0, cycle) * 0.3
        t = min(1.0, 0.2 + base + drop)
    else:
        t = 0.5
    return clamp(t + shift, 0.0, 1.0)


# ============================================================================
# 2. FORM PLANNER
# ============================================================================
def plan_form(mode: str, bpm: float, duration: float) -> list:
    """Returns list of sections: [{"name", "start_bar", "end_bar", "tension_base"}]"""
    bar_dur = 240.0 / bpm  # 4 beats per bar
    total_bars = max(4, int(duration / bar_dur))

    if mode == "sleep":
        # Gentle intro -> settling -> deep -> fade
        sections = [
            ("intro",   0.0,  0.20, 0.40),
            ("settle",  0.20, 0.45, 0.30),
            ("deep",    0.45, 0.80, 0.15),
            ("fade",    0.80, 1.00, 0.05),
        ]
    elif mode == "relaxation":
        # Intro -> breathe_A -> breathe_B -> breathe_A' -> outro
        sections = [
            ("intro",      0.0,  0.12, 0.30),
            ("breathe_a",  0.12, 0.37, 0.45),
            ("breathe_b",  0.37, 0.62, 0.50),
            ("breathe_a2", 0.62, 0.87, 0.40),
            ("outro",      0.87, 1.00, 0.25),
        ]
    elif mode == "focus":
        # Intro -> A -> B -> A -> B -> outro (loop-friendly)
        sections = [
            ("intro",  0.0,  0.10, 0.35),
            ("A",      0.10, 0.35, 0.45),
            ("B",      0.35, 0.55, 0.50),
            ("A2",     0.55, 0.75, 0.45),
            ("B2",     0.75, 0.90, 0.50),
            ("outro",  0.90, 1.00, 0.35),
        ]
    elif mode == "energize":
        # Intro -> build -> drop -> build2 -> drop2 -> cooldown
        sections = [
            ("intro",    0.0,  0.10, 0.30),
            ("build",    0.10, 0.30, 0.65),
            ("drop",     0.30, 0.50, 0.85),
            ("build2",   0.50, 0.65, 0.75),
            ("drop2",    0.65, 0.85, 0.95),
            ("cooldown", 0.85, 1.00, 0.40),
        ]
    else:
        sections = [("full", 0.0, 1.0, 0.5)]

    result = []
    for name, start_frac, end_frac, t_base in sections:
        result.append({
            "name": name,
            "start_bar": int(start_frac * total_bars),
            "end_bar": int(end_frac * total_bars),
            "start_time": start_frac * duration,
            "end_time": end_frac * duration,
            "tension_base": t_base,
        })
    # Fix gaps
    for i in range(1, len(result)):
        result[i]["start_bar"] = result[i - 1]["end_bar"]
        result[i]["start_time"] = result[i - 1]["end_time"]
    result[-1]["end_time"] = duration
    return result


def get_section_at(sections: list, t: float) -> dict:
    for s in reversed(sections):
        if t >= s["start_time"]:
            return s
    return sections[0]


# ============================================================================
# 3. FUNCTIONAL HARMONY ENGINE
# ============================================================================
# Chord intervals relative to root (semitones)
CHORD_TYPES = {
    "maj":   [0, 4, 7],
    "min":   [0, 3, 7],
    "dom7":  [0, 4, 7, 10],
    "min7":  [0, 3, 7, 10],
    "maj7":  [0, 4, 7, 11],
    "dim":   [0, 3, 6],
    "sus4":  [0, 5, 7],
    "sus2":  [0, 2, 7],
    "aug":   [0, 4, 8],
    "add9":  [0, 4, 7, 14],
    "dom9":  [0, 4, 7, 10, 14],
    "min9":  [0, 3, 7, 10, 14],
    "maj9":  [0, 4, 7, 11, 14],
    "power": [0, 7, 12],
    "fifth": [0, 7],
}

# Scale degrees -> chord qualities for major scale
DIATONIC_CHORDS = {
    0:  "maj",   # I
    2:  "min",   # ii
    4:  "min",   # iii
    5:  "maj",   # IV
    7:  "dom7",  # V7
    9:  "min",   # vi
    11: "dim",   # vii°
}

# Functional groups: which scale degrees serve which function
FUNCTION_DEGREES = {
    "tonic":       [0, 4, 9],      # I, iii, vi
    "subdominant": [2, 5],          # ii, IV
    "dominant":    [7, 11],         # V, vii°
}

# What can follow what
HARMONIC_SYNTAX = {
    "tonic":       ["tonic", "subdominant", "dominant"],
    "subdominant": ["subdominant", "dominant", "tonic"],
    "dominant":    ["tonic"],
}


def tension_to_function(tension: float) -> str:
    if tension < 0.3:
        return "tonic"
    elif tension < 0.65:
        return "subdominant"
    else:
        return "dominant"


def _generate_curated_harmony(mode: str, root_midi: int, bpm: float,
                              duration: float, variation: dict) -> list:
    """Use curated chord progressions for focus/energize. All tracks share
    the same key, scale, and progression — guaranteed cohesion."""
    mode_cfg = MODES[mode]
    progressions = mode_cfg["chord_progressions"]
    bar_dur = 240.0 / bpm
    bars_per_chord = 2 if mode == "focus" else 1

    # Pick progression based on variation for diversity across the 10 variations
    prog = progressions[variation["id"] % len(progressions)]

    chords = []
    t = 0.0
    chord_dur = bars_per_chord * bar_dur
    prog_idx = 0

    while t < duration:
        degree, chord_type = prog[prog_idx % len(prog)]
        chord_root = root_midi + degree - 12  # bass register
        chord_root = clamp(chord_root, 36, 72)

        tension = tension_curve(mode, t / duration, variation["tension_shift"])

        chords.append({
            "root": chord_root,
            "degree": degree,
            "type": chord_type,
            "start_time": t,
            "duration": chord_dur,
            "tension": tension,
        })

        t += chord_dur
        prog_idx += 1

    # Harmonic circularity: last chord resolves to first
    if len(chords) >= 2:
        first_root = chords[0]["root"]
        last = chords[-1]
        dominant_root = first_root + 7
        if dominant_root > 72:
            dominant_root -= 12
        last["root"] = clamp(dominant_root, 36, 72)
        last["type"] = "dom7"
        last["degree"] = 7
        last["tension"] = 0.6

    return chords


def generate_harmony(mode: str, root_midi: int, scale: list, bpm: float,
                     sections: list, duration: float, variation: dict) -> list:
    """Generate chord progression driven by tension curve.
    Returns list of {"root", "type", "start_time", "duration", "tension"}
    """
    # Use curated progressions for focus/energize (guaranteed cohesion)
    if "chord_progressions" in MODES.get(mode, {}):
        return _generate_curated_harmony(mode, root_midi, bpm, duration, variation)

    bar_dur = 240.0 / bpm
    total_bars = max(4, int(duration / bar_dur))

    # Chord change rate: slower for sleep/relax, faster for energize
    bars_per_chord = {"sleep": 4, "relaxation": 2, "focus": 2, "energize": 1}
    chord_bars = bars_per_chord.get(mode, 2)

    chords = []
    current_func = "tonic"

    for bar in range(0, total_bars, chord_bars):
        t = bar / total_bars
        section = get_section_at(sections, t * duration)
        tension = tension_curve(mode, t, variation["tension_shift"])

        target_func = tension_to_function(tension)

        # Follow harmonic syntax
        valid = HARMONIC_SYNTAX.get(current_func, ["tonic"])
        if target_func in valid:
            current_func = target_func
        else:
            current_func = valid[0]

        # Pick a degree from this function group
        degrees = FUNCTION_DEGREES[current_func]
        degree = random.choice(degrees)

        # Map scale degree to actual MIDI root
        # Find the nearest scale tone to root + degree
        chord_root = root_midi + degree - 12  # bass register
        chord_root = clamp(chord_root, 36, 72)

        chord_type = DIATONIC_CHORDS.get(degree, "maj")

        # At high tension, upgrade to 7th chords
        if tension > 0.6 and chord_type == "maj":
            chord_type = random.choice(["maj7", "dom7", "add9"])
        elif tension > 0.6 and chord_type == "min":
            chord_type = "min7"

        # Occasional sus chords for color
        if random.random() < 0.1 and tension < 0.5:
            chord_type = random.choice(["sus2", "sus4"])

        chords.append({
            "root": chord_root,
            "degree": degree,
            "type": chord_type,
            "start_time": bar * bar_dur,
            "duration": chord_bars * bar_dur,
            "tension": tension,
        })

    # === HARMONIC CIRCULARITY ===
    # Ensure the last chord resolves naturally to the first chord so the
    # loop boundary sounds seamless. Force the final chord to dominant (V)
    # which resolves to the tonic that starts the next loop iteration.
    if len(chords) >= 2:
        first_root = chords[0]["root"]
        last = chords[-1]
        # Set last chord to V (dominant) of the key → resolves to I at loop start
        dominant_root = first_root + 7  # perfect 5th above tonic
        if dominant_root > 72:
            dominant_root -= 12
        last["root"] = clamp(dominant_root, 36, 72)
        last["type"] = "dom7"
        last["degree"] = 7
        last["tension"] = 0.6

        # Second-to-last chord: subdominant (IV) for ii-V-I cadence feel
        if len(chords) >= 3:
            penult = chords[-2]
            subdominant_root = first_root + 5
            if subdominant_root > 72:
                subdominant_root -= 12
            penult["root"] = clamp(subdominant_root, 36, 72)
            penult["type"] = "maj"
            penult["degree"] = 5

    return chords


# ============================================================================
# 4. MOTIF GENERATOR & DEVELOPER
# ============================================================================
def generate_motif(scale_pool: list, mode: str, length: int) -> list:
    """Generate a seed motif as list of intervals from first note."""
    center = scale_pool[len(scale_pool) // 2]

    # Start from center of range
    motif = [center]
    for i in range(length - 1):
        if mode == "sleep":
            # Prefer descending steps
            candidates = [n for n in scale_pool if n <= motif[-1] and abs(n - motif[-1]) <= 5]
            if not candidates:
                candidates = [n for n in scale_pool if abs(n - motif[-1]) <= 5]
        elif mode == "energize":
            # Prefer ascending leaps
            candidates = [n for n in scale_pool if n >= motif[-1] and abs(n - motif[-1]) <= 7]
            if not candidates:
                candidates = [n for n in scale_pool if abs(n - motif[-1]) <= 7]
        elif mode == "focus":
            # Stepwise, narrow
            candidates = [n for n in scale_pool if abs(n - motif[-1]) <= 4]
        else:  # relaxation
            # Arch-like
            if i < length // 2:
                candidates = [n for n in scale_pool if n >= motif[-1] and abs(n - motif[-1]) <= 5]
            else:
                candidates = [n for n in scale_pool if n <= motif[-1] and abs(n - motif[-1]) <= 5]
            if not candidates:
                candidates = [n for n in scale_pool if abs(n - motif[-1]) <= 5]

        if not candidates:
            candidates = scale_pool
        motif.append(random.choice(candidates))
    return motif


def develop_motif(motif: list, technique: str, scale_pool: list, transposition: int = 0) -> list:
    """Apply a development technique to a motif."""
    if technique == "repeat":
        return list(motif)
    elif technique == "transpose":
        shifted = [n + transposition for n in motif]
        return [nearest_scale(n, scale_pool) for n in shifted]
    elif technique == "invert":
        pivot = motif[0]
        inverted = [pivot - (n - pivot) for n in motif]
        return [nearest_scale(n, scale_pool) for n in inverted]
    elif technique == "retrograde":
        return list(reversed(motif))
    elif technique == "fragment":
        half = max(2, len(motif) // 2)
        return motif[:half]
    elif technique == "augment":
        # Double the intervals
        result = [motif[0]]
        for i in range(1, len(motif)):
            interval = motif[i] - motif[i - 1]
            result.append(nearest_scale(result[-1] + interval * 2, scale_pool))
        return result
    elif technique == "sequence":
        # Repeat at +2 scale degrees
        idx_base = scale_pool.index(nearest_scale(motif[0], scale_pool))
        shift = min(2, len(scale_pool) - 1)
        shifted_root = scale_pool[min(idx_base + shift, len(scale_pool) - 1)]
        delta = shifted_root - motif[0]
        return [nearest_scale(n + delta, scale_pool) for n in motif]
    else:
        return list(motif)


# Development plan per variation
DEV_TECHNIQUES = ["repeat", "transpose", "invert", "retrograde", "fragment", "augment", "sequence"]


# ============================================================================
# 5. MARKOV INTERVAL CHAIN (for melody continuation between motifs)
# ============================================================================
# Hand-crafted interval transition matrices per mode
# Keys: current interval, Values: {next_interval: weight}
def build_interval_markov(mode: str) -> dict:
    """Build mode-specific interval transition weights."""
    if mode == "sleep":
        return {
            0:  {0: 4, -1: 3, -2: 5, -3: 2, 1: 1, 2: 1},
            -1: {0: 3, -1: 3, -2: 4, -3: 2, 1: 2},
            -2: {0: 4, -1: 3, -2: 2, 1: 2, -3: 1},
            -3: {0: 5, -1: 3, -2: 2, 1: 1},
            1:  {0: 4, -1: 5, -2: 3, 1: 1},
            2:  {0: 3, -1: 4, -2: 3, 1: 1},
            3:  {0: 4, -1: 4, -2: 2},
        }
    elif mode == "relaxation":
        return {
            0:  {0: 2, 1: 3, -1: 3, 2: 2, -2: 2, 3: 1, -3: 1},
            1:  {0: 2, 1: 2, 2: 2, -1: 3, -2: 1},
            -1: {0: 2, -1: 2, -2: 2, 1: 3, 2: 1},
            2:  {0: 3, -1: 3, 1: 2, -2: 2},
            -2: {0: 3, 1: 3, -1: 2, 2: 2},
            3:  {0: 3, -1: 4, -2: 2, 1: 1},
            -3: {0: 3, 1: 4, 2: 2, -1: 1},
        }
    elif mode == "focus":
        return {
            0:  {0: 1, 1: 4, -1: 4, 2: 2, -2: 2},
            1:  {0: 2, 1: 3, 2: 2, -1: 3, -2: 1},
            -1: {0: 2, -1: 3, -2: 2, 1: 3, 2: 1},
            2:  {0: 2, -1: 4, 1: 2, -2: 2},
            -2: {0: 2, 1: 4, -1: 2, 2: 2},
            3:  {0: 2, -1: 4, -2: 3},
            -3: {0: 2, 1: 4, 2: 3},
        }
    else:  # energize
        return {
            0:  {1: 3, 2: 3, 3: 2, -1: 2, -2: 1, 4: 1, 5: 1},
            1:  {0: 1, 1: 2, 2: 3, 3: 2, -1: 2, -2: 1},
            2:  {0: 2, 1: 2, 2: 2, 3: 2, -1: 3, -2: 2},
            3:  {0: 3, -1: 3, -2: 2, 1: 2, 2: 1},
            -1: {0: 2, 1: 3, 2: 3, -1: 1, 3: 1},
            -2: {0: 2, 1: 4, 2: 2, -1: 1},
            4:  {0: 3, -1: 3, -2: 2, -3: 1},
            5:  {0: 3, -1: 3, -2: 3},
            -3: {0: 2, 1: 4, 2: 3},
        }


def markov_next_interval(current_interval: int, chain: dict) -> int:
    """Pick next interval from Markov chain."""
    # Clamp to nearest known state
    known = list(chain.keys())
    state = min(known, key=lambda k: abs(k - current_interval))
    transitions = chain[state]
    intervals = list(transitions.keys())
    weights = list(transitions.values())
    return weighted_choice(intervals, weights)


# ============================================================================
# 6. MELODY WEAVER
# ============================================================================
def phrase_contour_target(mode: str, phrase_progress: float, octave_range: tuple,
                          root_midi: int) -> int:
    """Target pitch at this point in the phrase."""
    lo = root_midi + (octave_range[0] - 5) * 12
    hi = root_midi + (octave_range[1] - 5) * 12

    if mode == "sleep":
        t = 1.0 - phrase_progress  # descend
    elif mode == "relaxation":
        t = math.sin(phrase_progress * math.pi)  # arch
    elif mode == "focus":
        t = 0.5 + 0.1 * math.sin(phrase_progress * 2 * math.pi)  # plateau
    elif mode == "energize":
        t = phrase_progress  # ascend
    else:
        t = 0.5

    return int(lo + t * (hi - lo))


def score_note(candidate: int, last_note: int, contour_target: int,
               tension: float, mode: str) -> float:
    """Score a candidate note. Higher = better."""
    score = 0.0
    interval = abs(candidate - last_note)

    # Stepwise preference (stronger in sleep/focus)
    step_weight = {"sleep": 1.5, "relaxation": 1.0, "focus": 1.2, "energize": 0.5}.get(mode, 1.0)
    if interval <= 2:
        score += step_weight * 2.0
    elif interval <= 4:
        score += step_weight * 1.0
    elif interval <= 7:
        score += step_weight * 0.3
    else:
        score -= step_weight * 0.5

    # Contour adherence
    dist_to_target = abs(candidate - contour_target)
    score += max(0, 2.0 - dist_to_target / 6.0)

    # Leap resolution: if last interval was large, prefer opposite direction
    if interval > 4:
        score -= 0.5  # penalize consecutive leaps

    # Tension mapping: at high tension, favor wider intervals
    if tension > 0.6 and interval >= 3:
        score += tension * 0.5
    if tension < 0.3 and interval <= 2:
        score += (1.0 - tension) * 0.5

    return score


def generate_melody(mode: str, mode_cfg: dict, scale_pool: list, root_midi: int,
                    sections: list, chords: list, variation: dict, duration: float) -> list:
    """Dispatch to mode-specific melody generator."""
    if mode == "focus":
        return _generate_focus_melody(mode_cfg, scale_pool, root_midi, chords, variation, duration)
    elif mode == "energize":
        return _generate_energize_melody(mode_cfg, scale_pool, root_midi, sections, chords, variation, duration)
    return _generate_ambient_melody(mode, mode_cfg, scale_pool, root_midi, sections, chords, variation, duration)


# ============================================================================
# 6a. FOCUS MELODY — Chord-tone melody with 4-bar phrases (lo-fi study music)
# ============================================================================
def _generate_focus_melody(mode_cfg: dict, scale_pool: list, root_midi: int,
                           chords: list, variation: dict, duration: float) -> list:
    """Focus melody: chord-aware 4-bar phrases that repeat with subtle variation.
    Designed for habituation — predictable enough to fade into background,
    musical enough to mask environmental noise. Based on lo-fi study music
    research: pentatonic melody, jazz harmony, steady rhythm, flat dynamics."""
    notes = []
    bpm = mode_cfg["bpm"]
    beat_dur = 60.0 / bpm
    eighth = beat_dur / 2
    vel_lo, vel_hi = mode_cfg["vel_range"]

    # Constrain to warm mid-register (C4-G5, MIDI 60-79)
    pool = scale_notes(root_midi, SCALES[mode_cfg["scales"][0]], 4, 5)
    pool = [n for n in pool if 60 <= n <= 79]
    if not pool:
        pool = scale_notes(root_midi, SCALES[mode_cfg["scales"][0]], 3, 6)
    if not pool:
        return notes

    cell_beats = mode_cfg.get("cell_beats", 16)  # 4 bars
    total_slots = cell_beats * 2  # 8th-note grid

    # 5 rhythm templates (32 slots = 4 bars of 8th notes, ~50% fill rate)
    rhythm_templates = [
        # Steady 8ths with breathing room — classic lo-fi piano
        [1,0,1,1, 0,1,0,1, 1,0,1,0, 1,1,0,0, 1,0,0,1, 0,1,1,0, 1,0,1,0, 0,1,0,0],
        # Syncopated — jazzy Rhodes feel
        [1,0,0,1, 0,1,1,0, 0,0,1,0, 1,0,0,1, 0,1,0,1, 1,0,0,0, 1,0,0,1, 0,0,1,0],
        # Dotted — gentle bounce
        [1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,0, 1,0,0,1, 0,0,1,0, 1,0,0,0, 0,1,0,0],
        # Walking — regular pulse with pickup notes
        [0,1,1,0, 1,0,1,1, 0,1,0,0, 1,0,0,1, 0,1,1,0, 1,0,0,1, 0,1,0,1, 1,0,0,0],
        # Sparse — minimal, meditative
        [1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0, 0,0,1,0, 0,0,0,1, 0,0,0,0, 1,0,0,0],
    ]
    rhythm = rhythm_templates[variation["id"] % len(rhythm_templates)]

    def get_chord_tones_at(t_pos):
        """Get chord tones for the chord active at time t_pos."""
        ch = chords[0]
        for c in reversed(chords):
            if c["start_time"] <= t_pos:
                ch = c
                break
        intervals = CHORD_TYPES.get(ch["type"], CHORD_TYPES["maj"])
        tones = []
        for intv in intervals:
            for octave_shift in [-12, 0, 12]:
                candidate = ch["root"] + intv + octave_shift
                snapped = nearest_scale(candidate, pool)
                if snapped not in tones:
                    tones.append(snapped)
        return sorted(tones)

    # === BUILD INITIAL 4-BAR CELL (chord-aware) ===
    cell_pitches = []  # list of (pitch_or_None, is_chord_tone)
    last = pool[len(pool) // 2]  # start from center of range

    for slot in range(total_slots):
        if not rhythm[slot % len(rhythm)]:
            cell_pitches.append(None)
            continue

        slot_time = slot * eighth
        chord_tones = get_chord_tones_at(slot_time)
        is_strong = slot % 4 == 0  # beats 1, 2, 3, 4

        if is_strong:
            # Strong beats: chord tone, prefer closest to last note
            candidates = [ct for ct in chord_tones if 60 <= ct <= 79]
            if not candidates:
                candidates = chord_tones
            chosen = min(candidates, key=lambda n: abs(n - last)) if candidates else last
        else:
            # Weak beats: stepwise passing tone
            step_candidates = [n for n in pool if abs(n - last) <= 4 and 60 <= n <= 79]
            if not step_candidates:
                step_candidates = [n for n in pool if abs(n - last) <= 7]
            if step_candidates:
                # Prefer motion toward next strong beat's chord tone
                sorted_c = sorted(step_candidates, key=lambda n: abs(n - last))
                chosen = sorted_c[random.randint(0, min(2, len(sorted_c) - 1))]
            else:
                chosen = last

        cell_pitches.append(chosen)
        last = chosen

    # === REPEAT CELL with variation across the duration ===
    cell_dur = cell_beats * beat_dur
    t = 0.0
    cycle = 0

    while t < duration:
        # Variation strategy per cycle
        pitch_shift = 0
        vary_mask = []  # which slots get pitch re-selection

        if cycle == 0:
            vary_mask = [False] * total_slots
        elif cycle % 4 == 0:
            # Every 4th cycle: transpose entire cell ±1-2 scale degrees
            pitch_shift = random.choice([-3, -2, 2, 3])
            vary_mask = [False] * total_slots
        elif cycle % 2 == 0:
            # Every other cycle: re-select ~30% of pitches via Markov
            vary_mask = [random.random() < 0.3 for _ in range(total_slots)]
        else:
            # Odd cycles: rhythmic displacement (shift by 1 8th note)
            vary_mask = [False] * total_slots

        rhythmic_offset = eighth if (cycle % 2 == 1 and cycle > 0) else 0
        vel_shift = random.randint(-3, 3) if cycle > 0 else 0

        prev_note = pool[len(pool) // 2]
        for slot in range(total_slots):
            note_time = t + slot * eighth + rhythmic_offset
            if note_time >= duration:
                break

            pitch = cell_pitches[slot % len(cell_pitches)]
            if pitch is None:
                continue

            # Apply variation
            if vary_mask[slot % len(vary_mask)]:
                # Re-select this note: stepwise from previous
                chord_tones = get_chord_tones_at(note_time)
                step_cands = [n for n in pool if abs(n - prev_note) <= 4 and 60 <= n <= 79]
                if step_cands:
                    actual_pitch = random.choice(step_cands)
                else:
                    actual_pitch = nearest_scale(pitch + pitch_shift, pool)
            else:
                actual_pitch = nearest_scale(pitch + pitch_shift, pool)

            actual_pitch = clamp(actual_pitch, 60, 79)
            prev_note = actual_pitch

            # Velocity: very flat dynamics (science: 4-6 dB range for focus)
            cell_progress = slot / total_slots
            hairpin = 0.88 + 0.12 * math.sin(cell_progress * math.pi)
            vel = int(vel_lo + (vel_hi - vel_lo) * 0.65 * hairpin)
            vel = clamp(vel + vel_shift + random.randint(-2, 2), vel_lo, vel_hi)

            # Duration: 8th notes, occasional longer on strong beats
            if slot % 4 == 0 and random.random() < 0.3:
                dur = beat_dur * random.uniform(0.9, 1.6)
            else:
                dur = eighth * random.uniform(0.75, 0.95)

            notes.append({
                "note": actual_pitch,
                "velocity": vel,
                "startTime": round(max(0, note_time + random.gauss(0, 0.006)), 3),
                "duration": round(dur, 3),
            })

        t += cell_dur
        cycle += 1

    return notes


# ============================================================================
# 6b. ENERGIZE MELODY — Call-and-response riffs with build-drop dynamics
# ============================================================================
def _generate_energize_melody(mode_cfg: dict, scale_pool: list, root_midi: int,
                              sections: list, chords: list, variation: dict,
                              duration: float) -> list:
    """Energize melody: 2-bar call-and-response riffs that repeat 4x then
    evolve. Section-driven dynamics (intro→build→drop→cooldown). Power
    intervals on strong beats, steps on weak beats. Based on exercise music
    science: 128-140 BPM, strong motor entrainment, emotional escalation."""
    notes = []
    bpm = mode_cfg["bpm"]
    beat_dur = 60.0 / bpm
    sixteenth = beat_dur / 4
    eighth = beat_dur / 2
    bar_dur = beat_dur * 4
    vel_lo, vel_hi = mode_cfg["vel_range"]

    # Wide range for energy (C4-C6, MIDI 60-96)
    pool = scale_notes(root_midi, SCALES[mode_cfg["scales"][0]], 4, 6)
    pool = [n for n in pool if 60 <= n <= 96]
    if not pool:
        pool = scale_notes(root_midi, SCALES[mode_cfg["scales"][0]], 3, 6)
    if not pool:
        return notes

    # Call rhythm patterns (16 steps = 1 bar of 16th notes)
    call_rhythms = [
        [1,0,1,0, 1,0,1,1, 0,1,0,1, 1,0,1,0],  # driving syncopation
        [1,0,0,1, 0,1,0,1, 1,0,0,1, 0,1,1,0],  # off-beat hook
        [1,1,0,1, 1,0,0,0, 1,1,0,1, 0,0,1,0],  # punchy call
        [1,0,1,0, 0,1,1,0, 1,0,1,0, 1,1,0,0],  # straight drive
        [1,0,0,1, 1,0,1,0, 0,1,0,0, 1,0,1,1],  # hook with pickup
    ]

    def get_chord_at(t_pos):
        ch = chords[0] if chords else {"root": root_midi, "type": "maj"}
        for c in reversed(chords):
            if c["start_time"] <= t_pos:
                ch = c
                break
        return ch

    def build_riff_pitches(chord, bar_offset=0):
        """Build a 16-note pitch sequence from chord + power intervals."""
        cr = chord["root"] + 12  # melody register
        cr = clamp(cr, 60, 84)
        intervals = CHORD_TYPES.get(chord["type"], CHORD_TYPES["maj"])

        pitches = []
        for step in range(16):
            is_strong = step % 4 == 0
            if is_strong:
                # Power intervals: root, 5th, octave, 5th-of-octave
                power = [cr, cr + 7, cr + 12, cr + 7 + 12]
                power = [nearest_scale(p, pool) for p in power]
                pitch = power[(step // 4 + bar_offset) % len(power)]
            else:
                # Steps from previous pitch or chord tone
                if pitches:
                    prev = pitches[-1]
                    step_cands = [n for n in pool if 1 <= abs(n - prev) <= 4]
                    pitch = random.choice(step_cands) if step_cands else prev
                else:
                    pitch = nearest_scale(cr + random.choice(intervals), pool)
            pitches.append(clamp(pitch, 60, 96))
        return pitches

    def make_response(call_pitches):
        """Create response by inverting interval direction and transposing up."""
        if len(call_pitches) < 2:
            return call_pitches[:]
        response = [call_pitches[0] + 5]  # start a 4th higher
        for i in range(1, len(call_pitches)):
            interval = call_pitches[i] - call_pitches[i - 1]
            response.append(response[-1] - interval)  # invert direction
        return [nearest_scale(clamp(p, 60, 96), pool) for p in response]

    t = 0.0
    riff_idx = variation["id"] % len(call_rhythms)
    riff_rep = 0
    current_call_pitches = None
    current_response_pitches = None
    is_call_bar = True

    while t < duration:
        progress = t / duration
        section = get_section_at(sections, t)
        section_name = section["name"]
        tension = tension_curve("energize", progress, variation["tension_shift"])

        chord = get_chord_at(t)

        # Generate new riff every 4 repetitions (8 bars)
        if riff_rep % 4 == 0 or current_call_pitches is None:
            current_call_pitches = build_riff_pitches(chord, bar_offset=riff_idx)
            current_response_pitches = make_response(current_call_pitches)
            if riff_rep > 0:
                riff_idx = (riff_idx + 1) % len(call_rhythms)

        # Section-driven rhythm and density
        if section_name in ("intro", "cooldown"):
            rhythm = [1,0,0,0, 1,0,0,0, 0,0,1,0, 0,0,0,0]  # sparse
            vel_scale = 0.6
        elif section_name in ("build", "build2"):
            rhythm = call_rhythms[riff_idx % len(call_rhythms)]
            vel_scale = 0.75 + progress * 0.25
        elif section_name in ("drop", "drop2"):
            # Drop: densest pattern
            rhythm = [1,1,0,1, 1,0,1,1, 0,1,1,0, 1,0,1,1]
            vel_scale = 1.0
        else:
            rhythm = call_rhythms[riff_idx % len(call_rhythms)]
            vel_scale = 0.8

        # Select pitches: call or response bar
        pitches = current_call_pitches if is_call_bar else current_response_pitches

        for step in range(16):
            step_time = t + step * sixteenth
            if step_time >= duration:
                break
            if not rhythm[step % len(rhythm)]:
                continue

            pitch = pitches[step % len(pitches)]

            # Velocity with strong accents (exercise music: strong motor entrainment)
            is_downbeat = step == 0
            is_backbeat = step == 8
            if is_downbeat:
                accent = 1.30
            elif is_backbeat:
                accent = 1.10
            elif step % 4 == 0:
                accent = 1.05
            elif step % 2 == 0:
                accent = 0.95
            else:
                accent = 0.85

            base_vel = vel_lo + (vel_hi - vel_lo) * tension * vel_scale
            vel = int(base_vel * accent)
            vel = clamp(vel + random.randint(-3, 3), vel_lo, vel_hi)

            # Duration: punchy on 16ths, longer on strong beats
            if is_downbeat:
                dur = sixteenth * random.uniform(3.0, 4.0)
            elif step % 4 == 0:
                dur = sixteenth * random.uniform(2.0, 3.0)
            else:
                dur = sixteenth * random.uniform(1.2, 2.0)

            notes.append({
                "note": pitch,
                "velocity": vel,
                "startTime": round(max(0, step_time + random.uniform(-0.003, 0.003)), 3),
                "duration": round(dur, 3),
            })

        t += bar_dur
        is_call_bar = not is_call_bar  # alternate call/response
        if is_call_bar:
            riff_rep += 1

    return notes


# ============================================================================
# 6c. AMBIENT/RELAXATION/SLEEP MELODY — Motif + Markov (original algorithm)
# ============================================================================
def _generate_ambient_melody(mode: str, mode_cfg: dict, scale_pool: list, root_midi: int,
                             sections: list, chords: list, variation: dict, duration: float) -> list:
    """Generate melody using motif development + Markov + constraint scoring.
    Used for sleep and relaxation modes where sparse, organic phrasing works."""
    notes = []
    bpm = mode_cfg["bpm"]
    beat_dur = 60.0 / bpm
    vel_lo, vel_hi = mode_cfg["vel_range"]
    dur_lo, dur_hi = mode_cfg["dur_range"]
    density = mode_cfg["density"] * variation["density_mult"]
    oct_lo, oct_hi = mode_cfg["octave_range"]
    reg = variation["register"]
    oct_lo = clamp(oct_lo + reg // 2, 1, 7)
    oct_hi = clamp(oct_hi + (reg + 1) // 2, oct_lo + 1, 8)

    pool = scale_notes(root_midi, SCALES[mode_cfg["scales"][0]], oct_lo, oct_hi)
    if not pool:
        return notes

    # Generate seed motif
    motif = generate_motif(pool, mode, mode_cfg["motif_len"])
    motif2 = generate_motif(pool, mode, max(3, mode_cfg["motif_len"] - 1))

    # Build Markov chain
    markov = build_interval_markov(mode)

    # Phrase structure
    phrase_bars = mode_cfg["phrase_bars"]
    phrase_dur = phrase_bars * beat_dur * 4
    bar_dur = beat_dur * 4

    t = 0.0
    last_note = pool[len(pool) // 2]
    last_interval = 0
    phrase_idx = 0
    motif_cooldown = 0  # bars until next motif insertion

    while t < duration:
        progress = t / duration
        section = get_section_at(sections, t)
        tension = tension_curve(mode, progress, variation["tension_shift"])

        # Current phrase position
        phrase_pos = (t % phrase_dur) / phrase_dur if phrase_dur > 0 else 0
        is_phrase_start = phrase_pos < 0.05

        # === MOTIF INSERTION at phrase boundaries ===
        if is_phrase_start and motif_cooldown <= 0:
            # Pick development technique based on section and variation
            dev_primary = variation["motif_dev"]
            section_devs = {
                "intro": "repeat", "settle": "fragment", "deep": "fragment",
                "fade": "fragment",
                "breathe_a": "repeat", "breathe_b": "invert", "breathe_a2": "transpose",
                "A": "repeat", "B": "transpose", "A2": "invert", "B2": "retrograde",
                "build": "transpose", "drop": "augment", "build2": "sequence",
                "drop2": "augment", "cooldown": "fragment",
                "outro": "retrograde",
            }
            technique = section_devs.get(section["name"], dev_primary)

            # Alternate between two motifs
            src = motif if phrase_idx % 3 != 2 else motif2
            transposition = random.choice([-5, -3, -2, 0, 2, 3, 5])
            developed = develop_motif(src, technique, pool, transposition)

            # Place motif notes
            motif_t = t
            for m_note in developed:
                if motif_t >= duration:
                    break
                m_note = nearest_scale(m_note, pool)
                vel = int(vel_lo + (vel_hi - vel_lo) * clamp(tension + 0.1, 0, 1))
                vel = clamp(vel + random.randint(-3, 3), vel_lo, vel_hi)

                note_dur = dur_lo + (dur_hi - dur_lo) * (0.5 + 0.2 * (1.0 - tension))
                note_dur = clamp(note_dur + random.uniform(-note_dur * 0.1, note_dur * 0.1),
                                 dur_lo, dur_hi)

                notes.append({
                    "note": m_note,
                    "velocity": vel,
                    "startTime": round(max(0, motif_t + random.uniform(-0.012, 0.012)), 3),
                    "duration": round(note_dur, 3),
                })
                last_note = m_note
                interval = max(0.3, (1.0 / max(0.05, density)) * 0.7)
                motif_t += interval

            t = motif_t
            motif_cooldown = phrase_bars
            phrase_idx += 1
            continue

        motif_cooldown -= (beat_dur * 4) / max(0.1, beat_dur * 4) * 0.1

        # === MARKOV + CONSTRAINT continuation ===
        # Get next interval from Markov chain
        next_int = markov_next_interval(last_interval, markov)
        candidate_base = last_note + next_int

        # Score multiple candidates
        candidates = [nearest_scale(candidate_base + offset, pool) for offset in range(-3, 4)]
        candidates = list(set(candidates))

        ct = phrase_contour_target(mode, phrase_pos, (oct_lo, oct_hi), root_midi)
        scored = [(c, score_note(c, last_note, ct, tension, mode)) for c in candidates]
        scored.sort(key=lambda x: -x[1])

        # Weighted selection from top 3
        top = scored[:min(3, len(scored))]
        if top:
            chosen = weighted_choice([s[0] for s in top], [max(0.1, s[1] + 1) for s in top])
        else:
            chosen = last_note

        # Velocity follows tension curve + phrase dynamics (hairpin)
        phrase_dynamic = 0.85 + 0.15 * math.sin(phrase_pos * math.pi)  # peak at center
        vel = int(vel_lo + (vel_hi - vel_lo) * tension * phrase_dynamic)
        vel = clamp(vel + random.randint(-3, 3), vel_lo, vel_hi)

        # Duration inversely related to tension (high tension = shorter notes)
        dur_t = dur_lo + (dur_hi - dur_lo) * (1.0 - tension * 0.5)
        dur_t = clamp(dur_t + random.uniform(-dur_t * 0.1, dur_t * 0.1), dur_lo, dur_hi)

        # Swing
        if variation["swing"] > 0:
            beat_pos = int(t / beat_dur)
            if beat_pos % 2 == 1:
                t += variation["swing"] * beat_dur

        notes.append({
            "note": chosen,
            "velocity": vel,
            "startTime": round(max(0, t + random.uniform(-0.012, 0.012)), 3),
            "duration": round(dur_t, 3),
        })

        last_interval = chosen - last_note
        last_note = chosen

        # Next note interval based on density + tension
        gap = max(0.25, (1.0 / max(0.05, density)) * (1.0 + (1.0 - tension) * 0.3))
        t += gap + random.uniform(-gap * 0.12, gap * 0.12)

    return notes


# ============================================================================
# 7. BASS GENERATOR — Genre-Specific
# ============================================================================
def generate_bass(mode: str, mode_cfg: dict, genre_cfg: dict, root_midi: int,
                  scale: list, chords: list, sections: list,
                  variation: dict, duration: float) -> list:
    style = genre_cfg["bass_style"]
    bpm = mode_cfg["bpm"]
    beat_dur = 60.0 / bpm
    bar_dur = beat_dur * 4
    vel_lo, vel_hi = mode_cfg["vel_range"]
    bass_oct = max(1, mode_cfg["octave_range"][0] - 1)
    bass_pool = scale_notes(root_midi, scale, bass_oct, bass_oct + 1)

    notes = []

    # Mode-specific bass overrides (cohesive with curated harmony)
    if mode == "focus":
        return _bass_focus_walking(chords, bass_pool, bpm, vel_lo, vel_hi, duration)
    elif mode == "energize":
        return _bass_energize_locked(chords, bass_pool, bpm, vel_lo, vel_hi, duration, sections)

    if style == "drone":
        return _bass_drone(chords, vel_lo, vel_hi, duration)
    elif style == "walking":
        return _bass_walking(chords, bass_pool, bpm, vel_lo, vel_hi, duration)
    elif style == "root_fifth":
        return _bass_root_fifth(chords, bpm, vel_lo, vel_hi, duration)
    elif style == "synth":
        return _bass_synth_pump(chords, bpm, vel_lo, vel_hi, duration, mode)
    elif style == "tumbao":
        return _bass_tumbao(chords, bass_pool, bpm, vel_lo, vel_hi, duration)
    elif style == "one_drop":
        return _bass_one_drop(chords, bass_pool, bpm, vel_lo, vel_hi, duration)
    elif style == "alberti":
        return _bass_alberti(chords, bass_pool, bpm, vel_lo, vel_hi, duration)
    else:
        return _bass_root_fifth(chords, bpm, vel_lo, vel_hi, duration)


def _bass_focus_walking(chords, pool, bpm, vel_lo, vel_hi, duration):
    """Focus bass: half-time walking feel. Root on beat 1, 5th on beat 3,
    chromatic approach to next chord on beat 4. Warm, recessed, supportive."""
    notes = []
    beat_dur = 60.0 / bpm
    # Velocity: warm and low (50-60% of range)
    bass_vel_lo = vel_lo
    bass_vel_hi = int(vel_lo + (vel_hi - vel_lo) * 0.55)

    for ci, chord in enumerate(chords):
        root = clamp(chord["root"], 36, 55)
        fifth = nearest_scale(root + 7, pool)
        fifth = clamp(fifth, 36, 55)
        next_root = chords[(ci + 1) % len(chords)]["root"]
        next_root = clamp(next_root, 36, 55)
        t = chord["start_time"]

        beats = max(1, int(chord["duration"] / beat_dur))

        for beat in range(beats):
            bt = t + beat * beat_dur
            if bt >= duration:
                break

            if beat == 0:
                note = root
                vel = bass_vel_hi  # accent beat 1
                dur = beat_dur * 1.8  # half note (sustained)
            elif beat == 2:
                note = fifth
                vel = int(bass_vel_hi * 0.9)
                dur = beat_dur * 1.5
            elif beat == beats - 1 and next_root != root:
                # Chromatic approach to next chord
                if next_root > root:
                    note = clamp(next_root - 1, 36, 55)
                else:
                    note = clamp(next_root + 1, 36, 55)
                vel = int(bass_vel_hi * 0.75)
                dur = beat_dur * 0.9
            else:
                continue  # skip beats 1, 3 if no approach needed

            notes.append({
                "note": note,
                "velocity": clamp(vel + random.randint(-2, 2), bass_vel_lo, bass_vel_hi),
                "startTime": round(bt + random.uniform(0.003, 0.010), 3),  # slightly behind beat
                "duration": round(min(dur, duration - bt), 3),
            })

    return notes


def _bass_energize_locked(chords, pool, bpm, vel_lo, vel_hi, duration, sections):
    """Energize bass: locked to four-on-the-floor kick. Root on every beat,
    octave jump on beat 3, 8th-note subdivision with sidechain velocity dip.
    Driving, prominent, tight with drums."""
    notes = []
    beat_dur = 60.0 / bpm
    eighth = beat_dur / 2
    bass_vel_lo = int(vel_lo * 0.9)
    bass_vel_hi = int(vel_hi * 0.85)

    for ci, chord in enumerate(chords):
        root = clamp(chord["root"], 36, 50)
        octave_root = clamp(root + 12, 48, 62)
        t = chord["start_time"]
        beats = max(1, int(chord["duration"] / beat_dur))

        section = get_section_at(sections, t)
        section_name = section["name"]

        for beat in range(beats):
            bt = t + beat * beat_dur
            if bt >= duration:
                break

            if section_name in ("intro", "cooldown"):
                # Sparse: half notes only on beats 1 and 3
                if beat % 2 == 0:
                    notes.append({
                        "note": root,
                        "velocity": clamp(int(bass_vel_hi * 0.7) + random.randint(-2, 2), bass_vel_lo, bass_vel_hi),
                        "startTime": round(bt, 3),
                        "duration": round(beat_dur * 1.8, 3),
                    })
            else:
                # Full drive: 8th note subdivision with sidechain dip
                # On-beat: full velocity root (or octave on beat 3)
                note = octave_root if beat == 2 else root
                vel_on = bass_vel_hi if beat in (0, 2) else int(bass_vel_hi * 0.9)
                notes.append({
                    "note": note,
                    "velocity": clamp(vel_on + random.randint(-2, 2), bass_vel_lo, bass_vel_hi),
                    "startTime": round(bt, 3),
                    "duration": round(eighth * 0.85, 3),
                })

                # Off-beat 8th: sidechain ducked (40% velocity)
                off_t = bt + eighth
                if off_t < duration:
                    vel_off = int(vel_on * 0.4)
                    notes.append({
                        "note": root,
                        "velocity": clamp(vel_off + random.randint(-2, 2), bass_vel_lo, bass_vel_hi),
                        "startTime": round(off_t, 3),
                        "duration": round(eighth * 0.6, 3),
                    })

                # 16th note fill before chord change (last beat)
                if section_name in ("drop", "drop2") and beat == beats - 1:
                    next_root = chords[(ci + 1) % len(chords)]["root"]
                    next_root = clamp(next_root, 36, 50)
                    sixteenth = beat_dur / 4
                    fill_notes = [root, nearest_scale(root + 2, pool),
                                  nearest_scale(root + 4, pool), next_root]
                    for fi, fn in enumerate(fill_notes):
                        ft = bt + fi * sixteenth
                        if ft < duration:
                            notes.append({
                                "note": clamp(fn, 36, 55),
                                "velocity": clamp(int(bass_vel_hi * 0.8) + fi * 3, bass_vel_lo, bass_vel_hi),
                                "startTime": round(ft + random.uniform(-0.002, 0.002), 3),
                                "duration": round(sixteenth * 0.8, 3),
                            })

    return notes


def _bass_drone(chords, vel_lo, vel_hi, duration):
    """Long sustained tones — ambient/sleep."""
    notes = []
    for chord in chords:
        root = clamp(chord["root"] - 12, 28, 55)
        vel = int((vel_lo + vel_hi) * 0.4)
        notes.append({
            "note": root,
            "velocity": clamp(vel + random.randint(-2, 2), vel_lo, vel_hi),
            "startTime": round(chord["start_time"] + random.uniform(0, 0.02), 3),
            "duration": round(chord["duration"] * 0.95, 3),
        })
    return notes


def _bass_walking(chords, pool, bpm, vel_lo, vel_hi, duration):
    """Walking bass — quarter notes with chromatic approaches. Jazz/Blues."""
    notes = []
    beat_dur = 60.0 / bpm

    for ci, chord in enumerate(chords):
        root = chord["root"]
        next_root = chords[(ci + 1) % len(chords)]["root"]

        beats_in_chord = max(1, int(chord["duration"] / beat_dur))
        t = chord["start_time"]

        for beat in range(beats_in_chord):
            if t >= duration:
                break

            if beat == 0:
                note = root  # always start on root
            elif beat == beats_in_chord - 1 and beats_in_chord >= 3:
                # Chromatic approach to next chord root
                if next_root > root:
                    note = next_root - 1
                else:
                    note = next_root + 1
                note = clamp(note, 28, 60)
            elif beat == 1:
                # 3rd or 5th
                note = nearest_scale(root + random.choice([3, 4, 7]), pool)
            elif beat == 2:
                note = nearest_scale(root + 7, pool)  # 5th
            else:
                note = nearest_scale(root + random.choice([2, 4, 5, 7]), pool)

            note = clamp(note, 28, 60)
            vel = 75 if beat == 0 else 65
            vel = clamp(vel + random.randint(-3, 3), vel_lo, vel_hi)

            notes.append({
                "note": note,
                "velocity": vel,
                "startTime": round(t + random.uniform(-0.008, 0.008), 3),
                "duration": round(beat_dur * 0.85, 3),
            })
            t += beat_dur

    return notes


def _bass_root_fifth(chords, bpm, vel_lo, vel_hi, duration):
    """Root-fifth pattern — rock/pop/lofi."""
    notes = []
    beat_dur = 60.0 / bpm

    for chord in chords:
        root = chord["root"]
        fifth = root + 7
        t = chord["start_time"]

        beats = max(1, int(chord["duration"] / beat_dur))
        pattern = [root, fifth, root, fifth, root, fifth, root, fifth]

        for beat in range(min(beats, len(pattern))):
            if t >= duration:
                break
            note = clamp(pattern[beat], 28, 60)
            vel = 78 if beat % 2 == 0 else 62
            vel = clamp(vel + random.randint(-3, 3), vel_lo, vel_hi)

            notes.append({
                "note": note,
                "velocity": vel,
                "startTime": round(t + random.uniform(-0.005, 0.005), 3),
                "duration": round(beat_dur * 0.85, 3),
            })
            t += beat_dur

    return notes


def _bass_synth_pump(chords, bpm, vel_lo, vel_hi, duration, mode):
    """Pumping synth bass with sidechain-style velocity. Electronic/HipHop."""
    notes = []
    step_dur = 60.0 / bpm / 4  # 16th notes

    # Sidechain pump pattern (velocity multiplier)
    pump = [1.0, 0.3, 0.5, 0.7, 0.95, 0.3, 0.5, 0.7,
            1.0, 0.3, 0.5, 0.7, 0.95, 0.3, 0.5, 0.7]

    for chord in chords:
        root = clamp(chord["root"], 28, 55)
        t = chord["start_time"]
        steps = max(1, int(chord["duration"] / step_dur))

        for step in range(steps):
            if t >= duration:
                break
            # Skip some steps for variation
            if mode == "focus" and random.random() < 0.3:
                t += step_dur
                continue

            vel = int(vel_hi * pump[step % len(pump)])
            vel = clamp(vel + random.randint(-2, 2), vel_lo, vel_hi)

            notes.append({
                "note": root,
                "velocity": vel,
                "startTime": round(t, 3),
                "duration": round(step_dur * 0.7, 3),
            })
            t += step_dur

    return notes


def _bass_tumbao(chords, pool, bpm, vel_lo, vel_hi, duration):
    """Afro-Cuban tumbao bass — anticipated root on 4-and. Latin."""
    notes = []
    beat_dur = 60.0 / bpm

    for ci, chord in enumerate(chords):
        root = clamp(chord["root"], 28, 55)
        fifth = nearest_scale(root + 7, pool)
        fifth = clamp(fifth, 28, 55)
        t = chord["start_time"]

        # Tumbao: silence-silence-5th-silence | root(anticipated)-silence-root-silence
        tumbao = [
            (None, 0), (None, 0), (fifth, 65), (None, 0),
            (root, 80), (None, 0), (root, 70), (None, 0),
        ]

        for step, (note, vel) in enumerate(tumbao):
            nt = t + step * (beat_dur / 2)
            if nt >= duration:
                break
            if note is not None:
                vel = clamp(vel + random.randint(-3, 3), vel_lo, vel_hi)
                notes.append({
                    "note": note,
                    "velocity": vel,
                    "startTime": round(nt + random.uniform(-0.005, 0.005), 3),
                    "duration": round(beat_dur * 0.8, 3),
                })

    return notes


def _bass_one_drop(chords, pool, bpm, vel_lo, vel_hi, duration):
    """Reggae one-drop bass — heavy on beat 3 with melodic fills."""
    notes = []
    beat_dur = 60.0 / bpm

    for chord in chords:
        root = clamp(chord["root"], 28, 55)
        t = chord["start_time"]
        beats = max(1, int(chord["duration"] / beat_dur))

        for beat in range(beats):
            nt = t + beat * beat_dur
            if nt >= duration:
                break

            if beat == 2:  # Beat 3 — the one-drop hit
                vel = clamp(85 + random.randint(-3, 3), vel_lo, vel_hi)
                notes.append({
                    "note": root,
                    "velocity": vel,
                    "startTime": round(nt + random.uniform(0, 0.015), 3),
                    "duration": round(beat_dur * 1.5, 3),
                })
            elif beat == 0 and random.random() < 0.5:
                # Occasional root on beat 1
                vel = clamp(65 + random.randint(-3, 3), vel_lo, vel_hi)
                fifth = nearest_scale(root + 7, pool)
                notes.append({
                    "note": clamp(fifth, 28, 55),
                    "velocity": vel,
                    "startTime": round(nt + random.uniform(0, 0.01), 3),
                    "duration": round(beat_dur * 0.8, 3),
                })

    return notes


def _bass_alberti(chords, pool, bpm, vel_lo, vel_hi, duration):
    """Alberti bass — broken chord arpeggiation. Classical."""
    notes = []
    beat_dur = 60.0 / bpm
    # Pattern: root-5th-3rd-5th (as 8th notes)
    eighth = beat_dur / 2

    for chord in chords:
        root = clamp(chord["root"], 36, 60)
        third = nearest_scale(root + random.choice([3, 4]), pool)
        fifth = nearest_scale(root + 7, pool)
        third = clamp(third, 36, 60)
        fifth = clamp(fifth, 36, 60)

        pattern = [root, fifth, third, fifth]
        t = chord["start_time"]
        beats = max(1, int(chord["duration"] / eighth))

        for i in range(beats):
            if t >= duration:
                break
            note = pattern[i % len(pattern)]
            vel = 60 if i % 4 == 0 else 48
            vel = clamp(vel + random.randint(-2, 2), vel_lo, vel_hi)

            notes.append({
                "note": note,
                "velocity": vel,
                "startTime": round(t + random.uniform(-0.005, 0.005), 3),
                "duration": round(eighth * 0.9, 3),
            })
            t += eighth

    return notes


# ============================================================================
# 8. CHORD VOICER — Genre-Specific
# ============================================================================
def generate_chord_track(mode: str, mode_cfg: dict, genre_cfg: dict, root_midi: int,
                         chords: list, sections: list, variation: dict, duration: float) -> list:
    """Generate chord/pad track with genre-specific voicing and rhythm."""
    voicing_style = genre_cfg["voicing"]
    bpm = mode_cfg["bpm"]
    beat_dur = 60.0 / bpm
    vel_lo, vel_hi = mode_cfg["vel_range"]

    notes = []

    for chord in chords:
        cr = chord["root"]
        ct = chord["type"]
        intervals = CHORD_TYPES.get(ct, CHORD_TYPES["maj"])
        tension = chord["tension"]

        # === MODE-SPECIFIC VOICING OVERRIDES ===
        if mode == "focus":
            # Jazz voicing: root drop, 3rd, 7th, 9th (if available)
            voiced = _voice_jazz(cr, ct, intervals)
            chord_vel_lo = int(vel_lo * 0.9)
            chord_vel_hi = int(vel_hi * 0.50)  # background texture
            # Always sustained pads for focus (never stabs)
            notes.extend(_rhythm_sustained(voiced, chord, chord_vel_lo, chord_vel_hi, tension, duration))
            continue
        elif mode == "energize":
            # Open power: root + 5th + octave + high 5th
            voiced = _voice_open_power(cr, intervals)
            chord_vel_lo = vel_lo
            chord_vel_hi = int(vel_hi * 0.70)  # supportive, not dominating
            # All-beats stabs for driving energy
            notes.extend(_rhythm_strummed(voiced, chord, bpm, chord_vel_lo, chord_vel_hi, tension, duration, mode))
            continue

        # Build voicing based on genre style (sleep/relaxation path — untouched)
        if voicing_style == "open":
            voiced = _voice_open(cr, intervals)
        elif voicing_style == "shell":
            voiced = _voice_shell(cr, intervals)
        elif voicing_style == "power":
            voiced = _voice_power(cr)
        elif voicing_style == "spread":
            voiced = _voice_spread(cr, intervals)
        elif voicing_style == "stacked":
            voiced = _voice_stacked(cr, intervals)
        elif voicing_style == "chorale":
            voiced = _voice_chorale(cr, intervals)
        else:  # "triad"
            voiced = [cr + i for i in intervals]

        chord_vel_lo = vel_lo
        chord_vel_hi = vel_hi

        # Rhythmic placement (sleep/relaxation path — untouched)
        if voicing_style in ("power", "stacked"):
            notes.extend(_rhythm_strummed(voiced, chord, bpm, chord_vel_lo, chord_vel_hi, tension, duration, mode))
        elif genre_cfg["feel"] in ("clave", "laid_back"):
            notes.extend(_rhythm_upbeat_stabs(voiced, chord, bpm, chord_vel_lo, chord_vel_hi, duration))
        else:
            notes.extend(_rhythm_sustained(voiced, chord, chord_vel_lo, chord_vel_hi, tension, duration))

    return notes


def _voice_jazz(root, chord_type, intervals):
    """Jazz voicing: root dropped an octave, 3rd, 7th, optional 9th.
    Creates the warm, open sound of lo-fi and jazz piano."""
    root_drop = clamp(root - 12, 36, 55)  # root in bass register
    voiced = [root_drop]

    if len(intervals) >= 2:
        voiced.append(clamp(root + intervals[1], 55, 75))   # 3rd in mid-range
    if len(intervals) >= 4:
        voiced.append(clamp(root + intervals[3], 58, 78))   # 7th
    elif len(intervals) >= 3:
        voiced.append(clamp(root + intervals[2], 55, 75))   # 5th if no 7th
    # Add 9th for richness (2 semitones above octave = 14 semitones above root)
    if chord_type in ("min7", "maj7", "dom7", "dom9", "min9", "maj9"):
        voiced.append(clamp(root + 14, 62, 82))             # 9th

    return voiced


def _voice_open_power(root, intervals):
    """Open power voicing: root + 5th + octave + 5th-of-octave.
    Wider and more powerful than basic power chords. Used for energize."""
    return [
        clamp(root, 36, 55),
        clamp(root + 7, 43, 62),
        clamp(root + 12, 48, 67),
        clamp(root + 19, 55, 74),  # 5th of octave
    ]


def _voice_open(root, intervals):
    """Open voicing — intervals spread across octaves."""
    voiced = []
    for i, intv in enumerate(intervals[:3]):
        octave_shift = (i - 1) * 12  # spread: below, at, above
        voiced.append(clamp(root + intv + octave_shift, 36, 96))
    return voiced

def _voice_shell(root, intervals):
    """Shell voicing — root + 3rd + 7th."""
    shell = [root]
    if len(intervals) >= 2:
        shell.append(root + intervals[1])  # 3rd
    if len(intervals) >= 4:
        shell.append(root + intervals[3])  # 7th
    elif len(intervals) >= 3:
        shell.append(root + intervals[2])  # 5th if no 7th
    return [clamp(n, 48, 84) for n in shell]

def _voice_power(root):
    """Power chord — root + 5th + octave."""
    return [clamp(root, 36, 60), clamp(root + 7, 43, 67), clamp(root + 12, 48, 72)]

def _voice_spread(root, intervals):
    """Spread voicing — root low, add 9th."""
    voiced = [clamp(root - 12, 36, 48)]  # root low
    for intv in intervals[1:3]:
        voiced.append(clamp(root + intv + 12, 60, 84))  # upper octave
    voiced.append(clamp(root + 14, 62, 86))  # add 9th
    return voiced

def _voice_stacked(root, intervals):
    """Stacked voicing — dense upper harmonics."""
    voiced = [clamp(root, 48, 72)]
    for intv in intervals:
        voiced.append(clamp(root + intv + 12, 60, 96))
    return voiced

def _voice_chorale(root, intervals):
    """SATB chorale voicing."""
    bass = clamp(root - 12, 36, 55)
    tenor = clamp(root + (intervals[1] if len(intervals) > 1 else 4), 48, 67)
    alto = clamp(root + (intervals[2] if len(intervals) > 2 else 7), 55, 77)
    soprano = clamp(root + 12, 60, 84)
    return [bass, tenor, alto, soprano]


def _rhythm_sustained(voiced, chord, vel_lo, vel_hi, tension, duration):
    """Sustained chord pad."""
    notes = []
    vel = int(vel_lo + (vel_hi - vel_lo) * tension * 0.6)
    for note in voiced:
        if chord["start_time"] >= duration:
            break
        notes.append({
            "note": note,
            "velocity": clamp(vel + random.randint(-2, 2), vel_lo, vel_hi),
            "startTime": round(chord["start_time"] + random.uniform(0, 0.01), 3),
            "duration": round(chord["duration"] * 0.95, 3),
        })
    return notes

def _rhythm_strummed(voiced, chord, bpm, vel_lo, vel_hi, tension, duration, mode=""):
    """Rhythmic strumming — adapts density to mode."""
    notes = []
    beat_dur = 60.0 / bpm

    # Energize: all-beat stabs (driving support)
    # Focus: never reaches here (uses _rhythm_sustained via continue)
    if mode == "energize":
        step_dur = beat_dur  # quarter notes
        patterns = [
            [1, 1, 1, 1],  # all four beats
            [1, 1, 1, 0],  # beats 1-2-3
            [1, 0, 1, 1],  # beats 1, 3, 4
        ]
    elif mode == "focus":
        step_dur = beat_dur
        patterns = [[1, 0, 1, 0]]
    else:
        step_dur = beat_dur / 2  # 8th notes
        patterns = [
            [1, 0, 1, 0, 1, 0, 1, 0],
            [1, 1, 0, 1, 1, 0, 1, 0],
            [1, 0, 0, 1, 0, 0, 1, 0],
        ]

    t = chord["start_time"]
    steps = max(1, int(chord["duration"] / step_dur))
    pattern = patterns[int(tension * 2.9) % len(patterns)]

    for step in range(steps):
        if t >= duration:
            break
        if pattern[step % len(pattern)]:
            vel = int(vel_lo + (vel_hi - vel_lo) * (0.6 + tension * 0.3))
            if step % len(pattern) == 0:
                vel = int(vel * 1.1)  # accent downbeat
            for note in voiced:
                notes.append({
                    "note": note,
                    "velocity": clamp(vel + random.randint(-3, 3), vel_lo, vel_hi),
                    "startTime": round(t + random.uniform(-0.003, 0.003), 3),
                    "duration": round(step_dur * 0.7, 3),
                })
        t += step_dur
    return notes

def _rhythm_upbeat_stabs(voiced, chord, bpm, vel_lo, vel_hi, duration):
    """Upbeat chord stabs — reggae skank / latin montuno."""
    notes = []
    beat_dur = 60.0 / bpm
    t = chord["start_time"]
    beats = max(1, int(chord["duration"] / beat_dur))

    for beat in range(beats):
        nt = t + beat * beat_dur
        if nt >= duration:
            break
        # Play on upbeats (and of each beat)
        upbeat_t = nt + beat_dur * 0.5
        if upbeat_t >= duration:
            break

        vel = clamp(int((vel_lo + vel_hi) * 0.45) + random.randint(-3, 3), vel_lo, vel_hi)
        for note in voiced:
            notes.append({
                "note": note,
                "velocity": vel,
                "startTime": round(upbeat_t + random.uniform(-0.005, 0.005), 3),
                "duration": round(beat_dur * 0.3, 3),  # short staccato stab
            })
    return notes


# ============================================================================
# 9. DRUM PROGRAMMER
# ============================================================================
# Drum note map (GM)
KICK = 36; SNARE = 38; CLAP = 39; CHH = 42; OHH = 46
RIDE = 51; CRASH = 49; LOTOM = 45; HITOM = 43; RIM = 37; CLAVE = 75

# Core patterns (16-step, (note, velocity) pairs — 0 = silence)
DRUM_CORES = {
    "rock": [
        (KICK,90),(0,0),(CHH,50),(0,0),(SNARE,85),(0,0),(CHH,50),(0,0),
        (KICK,85),(0,0),(CHH,50),(KICK,70),(SNARE,85),(0,0),(CHH,50),(0,0),
    ],
    "jazz": [
        (RIDE,65),(0,0),(RIDE,48),(0,0),(RIDE,58),(CHH,30),(RIDE,52),(0,0),
        (RIDE,65),(0,0),(RIDE,48),(RIM,42),(RIDE,58),(0,0),(RIDE,52),(0,0),
    ],
    "hiphop": [
        (KICK,100),(0,0),(0,0),(CHH,38),(SNARE,78),(CHH,32),(0,0),(CHH,38),
        (0,0),(0,0),(KICK,82),(CHH,38),(SNARE,78),(CHH,32),(CHH,38),(CHH,32),
    ],
    "electronic": [
        (KICK,98),(CHH,38),(CHH,52),(CHH,38),(CLAP,82),(CHH,38),(CHH,52),(CHH,38),
        (KICK,92),(CHH,38),(KICK,78),(CHH,42),(CLAP,82),(CHH,38),(CHH,52),(OHH,48),
    ],
    "blues": [
        (KICK,78),(0,0),(CHH,42),(CHH,28),(SNARE,68),(0,0),(CHH,42),(CHH,28),
        (KICK,72),(0,0),(CHH,42),(KICK,58),(SNARE,68),(0,0),(CHH,42),(CHH,28),
    ],
    "reggae": [
        (0,0),(0,0),(0,0),(0,0),(RIM,68),(0,0),(CHH,42),(0,0),
        (KICK,88),(0,0),(CHH,42),(0,0),(RIM,68),(0,0),(CHH,42),(0,0),
    ],
    "latin": [
        (KICK,82),(0,0),(0,0),(CLAVE,68),(0,0),(0,0),(CLAVE,68),(0,0),
        (KICK,78),(0,0),(0,0),(CLAVE,68),(0,0),(0,0),(0,0),(0,0),
    ],
    "lofi": [
        (KICK,68),(0,0),(0,0),(0,0),(SNARE,48),(0,0),(0,0),(0,0),
        (0,0),(0,0),(KICK,58),(0,0),(SNARE,48),(0,0),(0,0),(0,0),
    ],
    "classical": [],
    "ambient": [],
}

# Fill patterns (8-step, replaces last 2 beats of a 4-bar phrase)
FILL_PATTERNS = {
    "rock":       [(SNARE,70),(HITOM,65),(LOTOM,70),(SNARE,75),(HITOM,78),(LOTOM,80),(SNARE,85),(CRASH,95)],
    "jazz":       [(SNARE,45),(0,0),(SNARE,50),(SNARE,52),(SNARE,55),(SNARE,58),(SNARE,62),(CRASH,55)],
    "hiphop":     [(0,0),(SNARE,65),(0,0),(SNARE,70),(KICK,80),(SNARE,75),(KICK,85),(SNARE,90)],
    "electronic": [(SNARE,55),(SNARE,60),(SNARE,65),(SNARE,70),(SNARE,75),(SNARE,80),(SNARE,90),(CRASH,98)],
    "blues":      [(SNARE,55),(0,0),(SNARE,60),(0,0),(SNARE,65),(SNARE,68),(SNARE,72),(CRASH,60)],
    "reggae":     [(RIM,55),(0,0),(RIM,60),(0,0),(KICK,75),(0,0),(KICK,80),(CRASH,65)],
    "latin":      [(CLAVE,65),(CLAVE,68),(CLAVE,70),(0,0),(KICK,78),(0,0),(KICK,82),(CRASH,72)],
    "lofi":       [(SNARE,38),(0,0),(SNARE,42),(0,0),(KICK,52),(SNARE,48),(KICK,55),(SNARE,52)],
}

# Groove templates (timing offset in ms per 16th note position within a beat)
GROOVE_TEMPLATES = {
    "straight": [0, 0, 0, 0],
    "swing":    [0, 0, 18, 0],
    "shuffle":  [0, 0, 22, 0],
    "lazy":     [0, 6, 10, 4],
    "tight":    [0, 0, 0, 0],
    "clave":    [0, -4, 3, -3],
    "laid_back":[0, 8, 5, 8],
    "rubato":   [0, 3, -2, 5],
    "free":     [0, 0, 0, 0],
}


# Four-on-the-floor patterns for focus/energize (kick every beat)
# Multiple variations for rotation — not cheesy synths, just solid grooves
FOUR_ON_FLOOR = {
    # Minimal deep house: kick + offbeat hats + snare on 2&4
    "minimal": [
        (KICK,92),(0,0),(CHH,35),(0,0),(KICK,88),(0,0),(CHH,40),(0,0),
        (KICK,90),(0,0),(CHH,35),(0,0),(KICK,88),(0,0),(CHH,40),(OHH,30),
    ],
    # Driving: kick + closed hats on every 8th + clap on 2&4
    "driving": [
        (KICK,95),(CHH,32),(CHH,42),(CHH,32),(KICK,90),(CHH,32),(CHH,42),(CHH,32),
        (KICK,92),(CHH,32),(CHH,42),(CHH,32),(KICK,90),(CHH,32),(CHH,42),(CHH,32),
    ],
    # Groove: kick on beats + syncopated hat + rimshot accents
    "groove": [
        (KICK,90),(0,0),(CHH,38),(CHH,25),(KICK,85),(0,0),(CHH,38),(0,0),
        (KICK,88),(CHH,25),(CHH,38),(0,0),(KICK,85),(0,0),(CHH,38),(CHH,25),
    ],
    # Punchy: kick + snare on 2&4 + 16th hats for energy
    "punchy": [
        (KICK,95),(CHH,28),(CHH,38),(CHH,28),(KICK,92),(CHH,28),(CHH,38),(CHH,28),
        (KICK,93),(CHH,28),(CHH,38),(CHH,28),(KICK,90),(CHH,28),(CHH,38),(OHH,35),
    ],
}

# Snare/clap overlay for four-on-the-floor (plays on beats 2 and 4)
FOUR_ON_FLOOR_BACKBEAT = [
    (0,0),(0,0),(0,0),(0,0),(SNARE,75),(0,0),(0,0),(0,0),
    (0,0),(0,0),(0,0),(0,0),(SNARE,78),(0,0),(0,0),(0,0),
]

FOUR_ON_FLOOR_FILLS = [
    # Snare roll into crash
    (SNARE,60),(SNARE,65),(SNARE,68),(SNARE,72),(SNARE,76),(SNARE,80),(SNARE,88),(CRASH,92),
]


def generate_drums(mode: str, mode_cfg: dict, genre: str, genre_cfg: dict,
                   sections: list, variation: dict, duration: float) -> list:
    """Generate drum track with fills, ghost notes, groove, and dynamic arc."""
    if not mode_cfg["has_drums"]:
        return []

    drum_style = genre_cfg["drum_style"]

    # === FOUR-ON-THE-FLOOR for focus and energize ===
    if mode in ("focus", "energize"):
        # Remove drums for focus ambient/classical (per FunctionalMusicTheory.md)
        if mode == "focus" and genre in ("ambient", "classical"):
            return []

        floor_styles = list(FOUR_ON_FLOOR.keys())
        floor_key = floor_styles[variation["id"] % len(floor_styles)]
        core = FOUR_ON_FLOOR[floor_key]
        backbeat = FOUR_ON_FLOOR_BACKBEAT

        if mode == "focus":
            # Softer drums: scale all velocities down to 60%
            core = [(n, int(v * 0.6)) if n > 0 else (n, v) for n, v in core]
            backbeat = [(n, int(v * 0.55)) if n > 0 else (n, v) for n, v in backbeat]
            fill_pattern = FOUR_ON_FLOOR_FILLS
            # Half-time for odd variations: kick on 1&3 only, hat on 2&4
            if variation["id"] % 2 == 1:
                core = [
                    (KICK,55),(0,0),(0,0),(0,0),(0,0),(0,0),(CHH,20),(0,0),
                    (KICK,50),(0,0),(0,0),(0,0),(0,0),(0,0),(CHH,20),(0,0),
                ]
                backbeat = [(0,0)] * 16  # no snare in half-time
        else:
            # Energize: multiple fill patterns rotated per variation
            energize_fills = [
                [(SNARE,60),(SNARE,65),(SNARE,68),(SNARE,72),(SNARE,76),(SNARE,80),(SNARE,88),(CRASH,92)],
                [(HITOM,70),(HITOM,75),(LOTOM,72),(LOTOM,78),(SNARE,80),(SNARE,85),(KICK,90),(CRASH,95)],
                [(KICK,70),(SNARE,65),(KICK,75),(SNARE,70),(KICK,80),(SNARE,80),(KICK,90),(CRASH,95)],
                [(SNARE,50),(SNARE,55),(SNARE,58),(SNARE,62),(SNARE,68),(SNARE,72),(SNARE,82),(CRASH,90)],
            ]
            fill_pattern = energize_fills[variation["id"] % len(energize_fills)]
    else:
        core = DRUM_CORES.get(drum_style, [])
        fill_pattern = FILL_PATTERNS.get(drum_style, [])
        backbeat = None

    if not core:
        return []

    bpm = mode_cfg["bpm"]
    step_dur = 60.0 / bpm / 4  # 16th note
    vel_lo, vel_hi = mode_cfg["vel_range"]
    feel = genre_cfg["feel"]
    groove = GROOVE_TEMPLATES.get(feel, GROOVE_TEMPLATES["straight"])

    notes = []
    t = 0.0
    step = 0
    bar_steps = 16
    total_steps = int(duration / step_dur)

    # Use the fill pattern set earlier (four-on-the-floor or genre-specific)
    if mode not in ("focus", "energize"):
        fill_pattern = FILL_PATTERNS.get(drum_style, [])

    # For focus/energize, use straight groove (tight, not genre-dependent)
    if mode in ("focus", "energize"):
        groove = GROOVE_TEMPLATES["straight"]

    # Phrase length for fill placement (every N bars)
    fill_interval_bars = 4
    fill_interval_steps = fill_interval_bars * bar_steps

    for step_idx in range(total_steps):
        t = step_idx * step_dur
        if t >= duration:
            break

        progress = t / duration
        tension = tension_curve(mode, progress, variation["tension_shift"])

        # Dynamic arc: scale velocity by tension
        dyn_scale = 0.7 + tension * 0.3

        # Determine if we're in a fill zone (last 2 beats before phrase boundary)
        steps_into_phrase = step_idx % fill_interval_steps
        is_fill_zone = (steps_into_phrase >= fill_interval_steps - 8 and
                        fill_pattern and
                        step_idx > fill_interval_steps)  # no fill on first phrase

        if is_fill_zone:
            fill_step = steps_into_phrase - (fill_interval_steps - 8)
            if fill_step < len(fill_pattern):
                note_num, base_vel = fill_pattern[fill_step]
            else:
                note_num, base_vel = 0, 0
        else:
            hit = core[step_idx % len(core)]
            note_num, base_vel = hit

        if note_num > 0 and base_vel > 0:
            vel = int(base_vel * dyn_scale * (vel_hi / 100.0))
            vel = clamp(vel + random.randint(-3, 3), vel_lo, vel_hi)

            # Apply groove template
            beat_pos = step_idx % 4
            timing_offset_ms = groove[beat_pos]
            timing_offset = timing_offset_ms / 1000.0

            notes.append({
                "note": note_num,
                "velocity": vel,
                "startTime": round(t + timing_offset + random.uniform(-0.004, 0.004), 3),
                "duration": round(step_dur * 0.8, 3),
            })

    # === BACKBEAT OVERLAY for four-on-the-floor (snare on 2 & 4) ===
    if backbeat:
        for step_idx in range(total_steps):
            t = step_idx * step_dur
            if t >= duration:
                break
            bb_hit = backbeat[step_idx % len(backbeat)]
            note_num, base_vel = bb_hit
            if note_num > 0 and base_vel > 0:
                progress = t / duration
                tension = tension_curve(mode, progress, variation["tension_shift"])
                dyn_scale = 0.7 + tension * 0.3
                vel = int(base_vel * dyn_scale * (vel_hi / 100.0))
                vel = clamp(vel + random.randint(-2, 2), vel_lo, vel_hi)
                notes.append({
                    "note": note_num,
                    "velocity": vel,
                    "startTime": round(t + random.uniform(-0.003, 0.003), 3),
                    "duration": round(step_dur * 0.8, 3),
                })

    # === GHOST NOTES (quiet snare hits between main beats) ===
    ghost_prob = {"jazz": 0.35, "hiphop": 0.25, "lofi": 0.18, "rock": 0.12,
                  "blues": 0.20, "electronic": 0.05, "reggae": 0.08,
                  "latin": 0.10, "ambient": 0, "classical": 0}.get(drum_style, 0.1)

    if ghost_prob > 0:
        main_times = {round(n["startTime"], 2) for n in notes}
        for step_idx in range(total_steps):
            t = step_idx * step_dur
            if t >= duration:
                break
            t_rounded = round(t, 2)
            # Don't add ghost where main hit exists
            if t_rounded not in main_times and random.random() < ghost_prob:
                notes.append({
                    "note": SNARE,
                    "velocity": random.randint(12, 28),
                    "startTime": round(t + random.uniform(-0.004, 0.004), 3),
                    "duration": round(step_dur * 0.5, 3),
                })

    # === ENERGIZE: open hi-hat on upbeats during drops ===
    if mode == "energize":
        for step_idx in range(total_steps):
            t = step_idx * step_dur
            if t >= duration:
                break
            bar_step = step_idx % 16
            if bar_step in (2, 6, 10, 14):  # 8th-note upbeats
                section = get_section_at(sections, t)
                if section["name"] in ("drop", "drop2"):
                    notes.append({
                        "note": OHH,
                        "velocity": clamp(38 + random.randint(-3, 3), vel_lo, vel_hi),
                        "startTime": round(t + random.uniform(-0.003, 0.003), 3),
                        "duration": round(step_dur * 0.6, 3),
                    })

    # === CRASH CYMBALS at section boundaries ===
    for section in sections:
        if section["start_time"] > 0 and section["start_time"] < duration:
            crash_vel = 85 if mode != "focus" else 50
            notes.append({
                "note": CRASH,
                "velocity": clamp(int(crash_vel * (vel_hi / 100.0)), vel_lo, vel_hi),
                "startTime": round(section["start_time"], 3),
                "duration": round(60.0 / bpm * 2, 3),
            })
            # Extra crash emphasis on energize drops
            if mode == "energize" and section["name"] in ("drop", "drop2"):
                notes.append({
                    "note": KICK,
                    "velocity": clamp(int(100 * (vel_hi / 100.0)), vel_lo, vel_hi),
                    "startTime": round(section["start_time"], 3),
                    "duration": round(step_dur * 2, 3),
                })

    return notes


# ============================================================================
# 10. HUMANIZER
# ============================================================================
HUMANIZE_PROFILES = {
    "tight":   {"timing_ms": 2,  "vel_var": 2,  "dur_var": 0.02},
    "relaxed": {"timing_ms": 8,  "vel_var": 5,  "dur_var": 0.04},
    "sloppy":  {"timing_ms": 18, "vel_var": 8,  "dur_var": 0.08},
    "robotic": {"timing_ms": 0,  "vel_var": 0,  "dur_var": 0.00},
}

GENRE_FEEL_MAP = {
    "electronic": "tight", "classical": "relaxed", "jazz": "relaxed",
    "lofi": "sloppy", "rock": "relaxed", "hiphop": "sloppy",
    "blues": "relaxed", "reggae": "relaxed", "latin": "tight",
    "ambient": "sloppy",
}

# Metric accent pattern for 4/4 (quarter note positions)
ACCENT_4_4 = [1.15, 0.85, 1.05, 0.90]


def humanize_track(events: list, genre: str, bpm: float, is_drums: bool = False) -> list:
    """Apply humanization: timing jitter, velocity variation, phrase dynamics."""
    feel = GENRE_FEEL_MAP.get(genre, "relaxed")
    profile = HUMANIZE_PROFILES[feel]
    beat_dur = 60.0 / bpm

    # Drums get tighter humanization
    intensity = 0.6 if is_drums else 1.0

    for event in events:
        # Gaussian timing jitter (clusters near the beat, more natural than uniform)
        jitter = random.gauss(0, profile["timing_ms"] / 1000.0) * intensity
        event["startTime"] = round(max(0, event["startTime"] + jitter), 3)

        # Velocity variation
        vel_jitter = int(random.gauss(0, profile["vel_var"]) * intensity)
        event["velocity"] = clamp(event["velocity"] + vel_jitter, 1, 127)

        # Duration variation
        dur_jitter = event["duration"] * profile["dur_var"] * intensity
        event["duration"] = round(max(0.01, event["duration"] + random.gauss(0, dur_jitter)), 3)

        # Metric accent (not for drums — they have their own accent pattern)
        if not is_drums and beat_dur > 0:
            beat_idx = int(event["startTime"] / beat_dur) % 4
            event["velocity"] = clamp(int(event["velocity"] * ACCENT_4_4[beat_idx]), 1, 127)

    return events


def apply_phrase_dynamics(events: list, bpm: float, phrase_bars: int = 4) -> list:
    """Apply crescendo-diminuendo hairpin within each phrase."""
    beat_dur = 60.0 / bpm
    phrase_dur = phrase_bars * beat_dur * 4

    if phrase_dur <= 0:
        return events

    for event in events:
        phrase_progress = (event["startTime"] % phrase_dur) / phrase_dur
        # Hairpin: crescendo to ~60%, diminuendo after
        if phrase_progress < 0.6:
            scale = 0.88 + 0.12 * (phrase_progress / 0.6)
        else:
            scale = 1.0 - 0.15 * ((phrase_progress - 0.6) / 0.4)
        event["velocity"] = clamp(int(event["velocity"] * scale), 1, 127)

    return events


# ============================================================================
# MAIN GENERATOR
# ============================================================================
def generate_sequence(genre: str, mode: str, var_id: int) -> dict:
    seed_rng(genre, mode, var_id)
    variation = VARIATIONS[var_id]
    mode_cfg = MODES[mode]
    genre_cfg = GENRES[genre]

    # Key and scale selection
    key = mode_cfg["keys"][var_id % len(mode_cfg["keys"])]
    scale_name = mode_cfg["scales"][var_id % len(mode_cfg["scales"])]
    scale_intervals = SCALES[scale_name]
    root_midi = ROOTS[key] + 60  # C4 = 60

    bpm = mode_cfg["bpm"]

    # === PIPELINE ===

    # 1. Plan form
    sections = plan_form(mode, bpm, DURATION)

    # 2. Generate harmony
    chords = generate_harmony(mode, root_midi, scale_intervals, bpm,
                              sections, DURATION, variation)

    # 3-6. Generate tracks
    melody_notes = generate_melody(mode, mode_cfg, scale_intervals, root_midi,
                                   sections, chords, variation, DURATION)

    bass_notes = generate_bass(mode, mode_cfg, genre_cfg, root_midi,
                               scale_intervals, chords, sections, variation, DURATION)

    chord_notes = generate_chord_track(mode, mode_cfg, genre_cfg, root_midi,
                                       chords, sections, variation, DURATION)

    drum_notes = generate_drums(mode, mode_cfg, genre, genre_cfg,
                                sections, variation, DURATION)

    # 7. Humanize all tracks
    melody_notes = humanize_track(melody_notes, genre, bpm)
    melody_notes = apply_phrase_dynamics(melody_notes, bpm, mode_cfg["phrase_bars"])

    bass_notes = humanize_track(bass_notes, genre, bpm)

    chord_notes = humanize_track(chord_notes, genre, bpm)

    if drum_notes:
        drum_notes = humanize_track(drum_notes, genre, bpm, is_drums=True)

    # === LOOP BOUNDARY SMOOTHING ===
    # Fade velocity near the end and start of the sequence so the loop
    # boundary is imperceptible. 5-second fade zone on each side.
    fade_zone = 5.0
    for track in [melody_notes, bass_notes, chord_notes]:
        for note in track:
            t = note["startTime"]
            if t > DURATION - fade_zone:
                # Fade out at end
                fade = (DURATION - t) / fade_zone  # 1.0 → 0.0
                note["velocity"] = max(1, int(note["velocity"] * fade))
            elif t < fade_zone:
                # Fade in at start (gentle — don't make the opening silent)
                fade = 0.5 + 0.5 * (t / fade_zone)  # 0.5 → 1.0
                note["velocity"] = max(1, int(note["velocity"] * fade))

    # Trim notes that extend past the sequence boundary
    for track in [melody_notes, bass_notes, chord_notes]:
        for note in track:
            end = note["startTime"] + note["duration"]
            if end > DURATION:
                note["duration"] = round(max(0.05, DURATION - note["startTime"]), 3)

    # Sort all tracks by start time
    melody_notes.sort(key=lambda n: n["startTime"])
    bass_notes.sort(key=lambda n: n["startTime"])
    chord_notes.sort(key=lambda n: n["startTime"])
    if drum_notes:
        drum_notes.sort(key=lambda n: n["startTime"])

    # Apply per-mode instrument overrides for cohesive timbre
    overrides = MODE_INSTRUMENT_OVERRIDES.get((mode, genre), {})
    melody_prog = overrides.get("melody", genre_cfg["melody"])
    bass_prog = overrides.get("bass", genre_cfg["bass"])
    chords_prog = overrides.get("chords", genre_cfg["chords"])

    # Build output (same format as v4 for app compatibility)
    tracks = [
        {"name": f"{genre.capitalize()} Melody", "program": melody_prog, "role": "melody",
         "frequencyRole": "high-mid", "suggestedVolume": 0.65,
         "notes": melody_notes, "totalDuration": DURATION},
        {"name": f"{genre.capitalize()} Bass", "program": bass_prog, "role": "bass",
         "frequencyRole": "sub-bass", "suggestedVolume": 0.55,
         "notes": bass_notes, "totalDuration": DURATION},
        {"name": f"{genre.capitalize()} Chords", "program": chords_prog, "role": "chords",
         "frequencyRole": "low-mid", "suggestedVolume": 0.50,
         "notes": chord_notes, "totalDuration": DURATION},
    ]

    if drum_notes:
        tracks.append({
            "name": f"{genre.capitalize()} Drums", "program": 0, "role": "drums",
            "frequencyRole": "percussion", "suggestedVolume": 0.45,
            "notes": drum_notes, "totalDuration": DURATION,
        })

    return {
        "genre": genre,
        "mode": mode,
        "variation": var_id,
        "key": key,
        "bpm": mode_cfg["bpm"],
        "scale": scale_name,
        "tracks": tracks,
    }


# ============================================================================
# MAIN
# ============================================================================
def main():
    output_dir = Path(__file__).parent / "output_v5"
    output_dir.mkdir(exist_ok=True)

    genres = list(GENRES.keys())
    modes = list(MODES.keys())

    total = len(genres) * len(modes) * len(VARIATIONS)
    print(f"Generating {total} sequences ({len(genres)} genres x {len(modes)} modes x {len(VARIATIONS)} variations)")
    print("Pipeline: Form -> Harmony -> Motif -> Melody(Markov+Constraint) -> Bass -> Chords -> Drums -> Humanize")
    print()

    all_sequences = []
    count = 0

    for genre in genres:
        for mode in modes:
            for var in VARIATIONS:
                var_id = var["id"]
                seq = generate_sequence(genre, mode, var_id)

                all_sequences.append(seq)
                count += 1

                # Save individual file
                fname = f"{genre}_{mode}_v{var_id}.json"
                with open(output_dir / fname, "w") as f:
                    json.dump(seq, f, separators=(",", ":"))

                note_count = sum(len(t["notes"]) for t in seq["tracks"])
                if var_id == 0:
                    print(f"  {genre:12s} x {mode:12s} -- {note_count:4d} notes, {seq['bpm']} BPM, key={seq['key']}, scale={seq['scale']}")

    # Save combined catalog
    catalog = {"sequences": all_sequences, "version": "5.0"}
    catalog_path = output_dir / "midi_sequences_v5.json"
    with open(catalog_path, "w") as f:
        json.dump(catalog, f, separators=(",", ":"))

    # Copy to app bundle (replaces v4)
    app_path = Path(__file__).parent.parent.parent / "src" / "BioNaural" / "Resources" / "midi_sequences.json"
    with open(app_path, "w") as f:
        json.dump(catalog, f, separators=(",", ":"))

    catalog_size = os.path.getsize(catalog_path) / 1024 / 1024
    app_size = os.path.getsize(app_path) / 1024 / 1024

    print(f"\nGenerated {count} sequences")
    print(f"Catalog: {catalog_path} ({catalog_size:.1f} MB)")
    print(f"App bundle: {app_path} ({app_size:.1f} MB)")


if __name__ == "__main__":
    main()
