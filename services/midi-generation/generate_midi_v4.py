"""
BioNaural MIDI Generator v4 — Pure Algorithmic Composition

Generates 400 MIDI sequences (10 genres × 4 modes × 10 variations)
using music theory rules encoded directly in Python.

NO API CALLS. Runs in seconds. $0 cost.

Music theory principles from FunctionalMusicTheory.md:
- Sleep: pentatonic minor/whole tone, descending, delta/theta Hz
- Relaxation: Lydian/pentatonic major, arch contour, alpha Hz
- Focus: pentatonic major/Dorian, flat/predictable, beta Hz
- Energize: Major/Mixolydian/Lydian, ascending, beta-gamma Hz
"""

import json
import math
import os
import random
from pathlib import Path

# ============================================================================
# SCALES (semitone intervals from root)
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

ROOTS = {"C": 0, "Db": 1, "D": 2, "Eb": 3, "E": 4, "F": 5, "Gb": 6, "G": 7, "Ab": 8, "A": 9, "Bb": 10, "B": 11}

# ============================================================================
# MODE DEFINITIONS
# ============================================================================
MODES = {
    "sleep": {
        "bpm": 48, "vel_range": (25, 45), "dur_range": (4.0, 16.0),
        "density": 0.15,  # notes per second
        "max_poly": 3, "has_drums": False,
        "contour": "descending", "octave_range": (2, 4),
        "scales": ["pentatonic_minor", "whole_tone", "aeolian", "dorian"],
        "keys": ["F", "Db", "Ab", "Eb"],
        "arc": [0.4, 0.35, 0.3, 0.25, 0.2, 0.2],
    },
    "relaxation": {
        "bpm": 62, "vel_range": (35, 60), "dur_range": (2.0, 8.0),
        "density": 0.3,
        "max_poly": 4, "has_drums": False,
        "contour": "arch", "octave_range": (3, 5),
        "scales": ["lydian", "pentatonic_major", "ionian", "mixolydian"],
        "keys": ["G", "D", "C", "A"],
        "arc": [0.3, 0.5, 0.6, 0.5, 0.4, 0.3],
    },
    "focus": {
        "bpm": 75, "vel_range": (45, 70), "dur_range": (1.0, 4.0),
        "density": 0.5,
        "max_poly": 5, "has_drums": True,
        "contour": "flat", "octave_range": (3, 5),
        "scales": ["pentatonic_major", "dorian", "ionian", "mixolydian"],
        "keys": ["C", "Bb", "D", "G"],
        "arc": [0.6, 0.65, 0.7, 0.7, 0.65, 0.6],
    },
    "energize": {
        "bpm": 115, "vel_range": (65, 100), "dur_range": (0.2, 1.5),
        "density": 1.2,
        "max_poly": 8, "has_drums": True,
        "contour": "ascending", "octave_range": (3, 6),
        "scales": ["ionian", "mixolydian", "lydian", "dorian"],
        "keys": ["D", "E", "A", "G"],
        "arc": [0.5, 0.7, 0.8, 0.9, 1.0, 0.7],
    },
}

# ============================================================================
# GENRE DEFINITIONS (instruments + chord styles)
# ============================================================================
GENRES = {
    "ambient":    {"melody": 88,  "bass": 89,  "chords": 91, "drums": 0,  "prog": "ambient"},
    "lofi":       {"melody": 4,   "bass": 33,  "chords": 89, "drums": 0,  "prog": "jazz"},
    "jazz":       {"melody": 0,   "bass": 32,  "chords": 89, "drums": 0,  "prog": "jazz"},
    "rock":       {"melody": 25,  "bass": 33,  "chords": 89, "drums": 0,  "prog": "rock"},
    "hiphop":     {"melody": 11,  "bass": 38,  "chords": 89, "drums": 0,  "prog": "minor"},
    "blues":      {"melody": 25,  "bass": 33,  "chords": 0,  "drums": 0,  "prog": "blues"},
    "reggae":     {"melody": 24,  "bass": 33,  "chords": 16, "drums": 0,  "prog": "major"},
    "classical":  {"melody": 0,   "bass": 42,  "chords": 49, "drums": 0,  "prog": "classical"},
    "latin":      {"melody": 73,  "bass": 33,  "chords": 0,  "drums": 0,  "prog": "minor"},
    "electronic": {"melody": 81,  "bass": 38,  "chords": 89, "drums": 0,  "prog": "minor"},
}

# Chord progressions as scale degree offsets (semitones from root)
PROGRESSIONS = {
    "ambient":   [[0,7], [0,7], [5,12], [0,7]],
    "jazz":      [[2,5,9], [7,11,14], [0,4,7,11], [0,4,7,11]],
    "rock":      [[0,7], [5,12], [7,14], [0,7]],
    "minor":     [[0,3,7], [5,8,12], [7,10,14], [0,3,7]],
    "blues":     [[0,4,7,10], [5,9,12,15], [0,4,7,10], [7,11,14,17], [5,9,12,15], [0,4,7,10]],
    "major":     [[0,4,7], [5,9,12], [7,11,14], [0,4,7]],
    "classical": [[0,4,7], [5,9,12], [7,11,14], [0,4,7], [9,12,16], [7,11,14]],
}

# Drum patterns (16-step, GM notes: kick=36, snare=38, chh=42, ohh=46, ride=51, rim=37, clave=75)
DRUM_PATTERNS = {
    "rock":       [(36,90),(0,0),(42,50),(0,0),(38,85),(0,0),(42,50),(0,0),(36,85),(0,0),(42,50),(36,70),(38,85),(0,0),(42,50),(0,0)],
    "jazz":       [(51,65),(0,0),(51,48),(0,0),(51,58),(42,30),(51,52),(0,0),(51,65),(0,0),(51,48),(37,42),(51,58),(0,0),(51,52),(0,0)],
    "hiphop":     [(36,100),(0,0),(0,0),(42,38),(38,78),(42,32),(0,0),(42,38),(0,0),(0,0),(36,82),(42,38),(38,78),(42,32),(42,38),(42,32)],
    "electronic": [(36,98),(42,38),(42,52),(42,38),(39,82),(42,38),(42,52),(42,38),(36,92),(42,38),(36,78),(42,42),(39,82),(42,38),(42,52),(46,48)],
    "blues":      [(36,78),(0,0),(42,42),(42,28),(38,68),(0,0),(42,42),(42,28),(36,72),(0,0),(42,42),(36,58),(38,68),(0,0),(42,42),(42,28)],
    "reggae":     [(0,0),(0,0),(0,0),(0,0),(37,68),(0,0),(42,42),(0,0),(36,88),(0,0),(42,42),(0,0),(37,68),(0,0),(42,42),(0,0)],
    "latin":      [(36,82),(0,0),(0,0),(75,68),(0,0),(0,0),(75,68),(0,0),(36,78),(0,0),(0,0),(75,68),(0,0),(0,0),(0,0),(0,0)],
    "lofi":       [(36,68),(0,0),(0,0),(0,0),(38,48),(0,0),(0,0),(0,0),(0,0),(0,0),(36,58),(0,0),(38,48),(0,0),(0,0),(0,0)],
    "classical":  [],  # No drums
    "ambient":    [],  # No drums
}

# ============================================================================
# VARIATIONS
# ============================================================================
VARIATIONS = [
    {"id": 0, "label": "foundation",      "harmony": "triads",   "register": 0,  "density_mult": 1.0, "arc_offset": 0.0,  "contour_var": 0, "swing": 0.0},
    {"id": 1, "label": "sparse_low",      "harmony": "triads",   "register": -2, "density_mult": 0.6, "arc_offset": -0.1, "contour_var": 1, "swing": 0.0},
    {"id": 2, "label": "dense_bright",    "harmony": "sevenths", "register": 2,  "density_mult": 1.4, "arc_offset": 0.1,  "contour_var": 2, "swing": 0.0},
    {"id": 3, "label": "warm_swing",      "harmony": "sevenths", "register": -1, "density_mult": 1.0, "arc_offset": 0.0,  "contour_var": 0, "swing": 0.08},
    {"id": 4, "label": "ethereal",        "harmony": "ninths",   "register": 3,  "density_mult": 0.6, "arc_offset": 0.05, "contour_var": 0, "swing": 0.0},
    {"id": 5, "label": "grounded",        "harmony": "triads",   "register": -2, "density_mult": 1.4, "arc_offset": -0.1, "contour_var": 1, "swing": 0.0},
    {"id": 6, "label": "complex_mid",     "harmony": "ninths",   "register": 0,  "density_mult": 1.0, "arc_offset": 0.1,  "contour_var": 2, "swing": 0.06},
    {"id": 7, "label": "minimal_rubato",  "harmony": "triads",   "register": 0,  "density_mult": 0.5, "arc_offset": 0.05, "contour_var": 1, "swing": 0.0},
    {"id": 8, "label": "lush_arc",        "harmony": "ninths",   "register": 1,  "density_mult": 1.3, "arc_offset": 0.0,  "contour_var": 0, "swing": 0.0},
    {"id": 9, "label": "tension_release", "harmony": "sevenths", "register": 2,  "density_mult": 1.0, "arc_offset": 0.1,  "contour_var": 2, "swing": 0.05},
]

DURATION = 60.0  # seconds per sequence

# ============================================================================
# DETERMINISTIC RANDOMNESS (seeded by genre+mode+variation)
# ============================================================================
def seed_rng(genre: str, mode: str, var_id: int):
    s = hash(f"{genre}_{mode}_{var_id}") % (2**31)
    random.seed(s)

def jitter(base: float, amount: float) -> float:
    return base + random.uniform(-amount, amount)

# ============================================================================
# SCALE HELPERS
# ============================================================================
def scale_notes(root_midi: int, scale: list, octave_low: int, octave_high: int) -> list:
    """Generate all MIDI notes in a scale within an octave range."""
    notes = []
    for octave in range(octave_low, octave_high + 1):
        for interval in scale:
            midi = root_midi + (octave - 5) * 12 + interval
            if 0 <= midi <= 127:
                notes.append(midi)
    return sorted(notes)

def nearest_scale_note(target: int, scale_notes: list) -> int:
    if not scale_notes:
        return max(0, min(127, target))
    return min(scale_notes, key=lambda n: abs(n - target))

def voice_lead(last_note: int, candidates: list, contour: str, progress: float) -> int:
    """Pick next note using voice-leading with contour bias."""
    if not candidates:
        return last_note

    # Contour bias
    if contour == "descending":
        below = [n for n in candidates if n <= last_note]
        pool = below if below and random.random() < 0.65 else candidates
    elif contour == "ascending":
        above = [n for n in candidates if n >= last_note]
        pool = above if above and random.random() < 0.55 else candidates
    elif contour == "arch":
        if progress < 0.5:
            above = [n for n in candidates if n >= last_note]
            pool = above if above and random.random() < 0.45 else candidates
        else:
            below = [n for n in candidates if n <= last_note]
            pool = below if below and random.random() < 0.50 else candidates
    else:  # flat
        pool = candidates

    # Prefer stepwise motion (70% near, 20% small leap, 10% large leap)
    sorted_pool = sorted(pool, key=lambda n: abs(n - last_note))
    r = random.random()
    if r < 0.70 and len(sorted_pool) >= 2:
        return sorted_pool[random.randint(0, min(2, len(sorted_pool)-1))]
    elif r < 0.90 and len(sorted_pool) >= 4:
        return sorted_pool[random.randint(1, min(4, len(sorted_pool)-1))]
    else:
        return random.choice(pool)

# ============================================================================
# GENERATORS
# ============================================================================

def generate_melody(mode_cfg, scale_list, root_midi, variation, duration):
    """Generate a melodic line following mode constraints and contour."""
    notes = []
    bpm = mode_cfg["bpm"]
    beat_dur = 60.0 / bpm
    vel_lo, vel_hi = mode_cfg["vel_range"]
    dur_lo, dur_hi = mode_cfg["dur_range"]
    density = mode_cfg["density"] * variation["density_mult"]
    contour = mode_cfg["contour"]
    oct_lo, oct_hi = mode_cfg["octave_range"]
    reg_shift = variation["register"]
    arc = mode_cfg["arc"]

    # Adjust octave range by register variation
    oct_lo = max(1, oct_lo + reg_shift // 2)
    oct_hi = min(7, oct_hi + (reg_shift + 1) // 2)

    available = scale_notes(root_midi, scale_list, oct_lo, oct_hi)
    if not available:
        return notes

    # Start in the middle-ish of range
    last_note = available[len(available) // 2]
    t = 0.0

    while t < duration:
        progress = t / duration
        segment = min(int(progress * len(arc)), len(arc) - 1)
        energy = arc[segment] + variation["arc_offset"]

        # Note interval based on density
        interval = max(0.3, (1.0 / max(0.05, density)) * (1.0 + (1.0 - energy) * 0.5))
        interval = jitter(interval, interval * 0.15)

        # Swing
        if variation["swing"] > 0 and int(t / beat_dur) % 2 == 1:
            t += variation["swing"] * beat_dur

        # Velocity scaled by arc energy
        vel = int(vel_lo + (vel_hi - vel_lo) * energy)
        vel = max(vel_lo, min(vel_hi, vel + random.randint(-3, 3)))

        # Duration
        dur = dur_lo + (dur_hi - dur_lo) * (1.0 - energy * 0.3)
        dur = jitter(dur, dur * 0.1)
        dur = max(dur_lo, min(dur_hi, dur))

        # Pick note with voice leading
        note = voice_lead(last_note, available, contour, progress)
        last_note = note

        # Humanize timing
        start = max(0, t + random.uniform(-0.015, 0.015))

        notes.append({"note": note, "velocity": vel, "startTime": round(start, 3), "duration": round(dur, 3)})
        t += interval

    return notes

def generate_bass(mode_cfg, root_midi, progression, scale_list, variation, duration):
    """Generate bass line following chord roots."""
    notes = []
    bpm = mode_cfg["bpm"]
    beat_dur = 60.0 / bpm
    bar_dur = beat_dur * 4
    vel_lo, vel_hi = mode_cfg["vel_range"]
    oct = max(1, mode_cfg["octave_range"][0] - 1)

    t = 0.0
    chord_idx = 0
    while t < duration:
        chord = progression[chord_idx % len(progression)]
        chord_root = root_midi + (oct - 5) * 12 + chord[0]
        chord_root = max(24, min(60, chord_root))

        # Bass plays chord root
        vel = int((vel_lo + vel_hi) / 2 + random.randint(-3, 3))
        dur = min(bar_dur * 0.9, mode_cfg["dur_range"][1])

        notes.append({"note": chord_root, "velocity": vel, "startTime": round(t + random.uniform(-0.01, 0.01), 3), "duration": round(dur, 3)})

        # Occasional passing tone on beat 3
        if mode_cfg["density"] > 0.3 and random.random() < 0.4:
            bass_notes = scale_notes(root_midi, scale_list, oct, oct + 1)
            fifth = nearest_scale_note(chord_root + 7, bass_notes)
            pt = t + beat_dur * 2
            if pt < duration:
                notes.append({"note": fifth, "velocity": vel - 5, "startTime": round(pt + random.uniform(-0.01, 0.01), 3), "duration": round(beat_dur * 1.5, 3)})

        t += bar_dur
        chord_idx += 1

    return notes

def generate_chords(mode_cfg, root_midi, progression, variation, duration):
    """Generate sustained chord pads."""
    notes = []
    bpm = mode_cfg["bpm"]
    bar_dur = 60.0 / bpm * 4
    vel_lo, vel_hi = mode_cfg["vel_range"]
    oct = mode_cfg["octave_range"][0]
    arc = mode_cfg["arc"]

    # Chord change interval (bars)
    chord_bars = 2 if mode_cfg["density"] > 0.4 else 4

    t = 0.0
    chord_idx = 0
    while t < duration:
        progress = t / duration
        segment = min(int(progress * len(arc)), len(arc) - 1)
        energy = arc[segment]

        chord = progression[chord_idx % len(progression)]
        chord_dur = bar_dur * chord_bars * 0.95

        vel = int(vel_lo + (vel_hi - vel_lo) * energy * 0.7)

        for interval in chord:
            midi = root_midi + (oct - 5) * 12 + interval
            if 0 <= midi <= 127:
                notes.append({
                    "note": midi,
                    "velocity": max(vel_lo, min(vel_hi, vel + random.randint(-2, 2))),
                    "startTime": round(t + random.uniform(0, 0.012), 3),
                    "duration": round(chord_dur, 3),
                })

        t += bar_dur * chord_bars
        chord_idx += 1

    return notes

def generate_drums(mode_cfg, genre, variation, duration):
    """Generate drum pattern from templates."""
    if not mode_cfg["has_drums"]:
        return []

    pattern = DRUM_PATTERNS.get(genre, [])
    if not pattern:
        return []

    notes = []
    bpm = mode_cfg["bpm"]
    step_dur = 60.0 / bpm / 4  # 16th note
    vel_lo, vel_hi = mode_cfg["vel_range"]

    t = 0.0
    step = 0
    while t < duration:
        hit = pattern[step % len(pattern)]
        note_num, base_vel = hit

        if note_num > 0 and base_vel > 0:
            # Scale velocity to mode range
            vel = int(base_vel * (vel_hi / 100.0))
            vel = max(vel_lo, min(vel_hi, vel + random.randint(-3, 3)))

            notes.append({
                "note": note_num,
                "velocity": vel,
                "startTime": round(t + random.uniform(-0.008, 0.008), 3),
                "duration": round(step_dur * 0.8, 3),
            })

        t += step_dur
        step += 1

    return notes

# ============================================================================
# MAIN GENERATOR
# ============================================================================

def generate_sequence(genre: str, mode: str, var_id: int) -> dict:
    seed_rng(genre, mode, var_id)
    variation = VARIATIONS[var_id]
    mode_cfg = MODES[mode]
    genre_cfg = GENRES[genre]

    # Select key and scale based on variation
    key = mode_cfg["keys"][var_id % len(mode_cfg["keys"])]
    scale_name = mode_cfg["scales"][var_id % len(mode_cfg["scales"])]
    scale_intervals = SCALES[scale_name]
    root_midi = ROOTS[key] + 60  # C4 = 60

    # Get chord progression
    prog_key = genre_cfg["prog"]
    progression = PROGRESSIONS.get(prog_key, PROGRESSIONS["major"])

    # Generate tracks
    melody_notes = generate_melody(mode_cfg, scale_intervals, root_midi, variation, DURATION)
    bass_notes = generate_bass(mode_cfg, root_midi, progression, scale_intervals, variation, DURATION)
    chord_notes = generate_chords(mode_cfg, root_midi, progression, variation, DURATION)
    drum_notes = generate_drums(mode_cfg, genre, variation, DURATION)

    tracks = [
        {"name": f"{genre.capitalize()} Melody", "program": genre_cfg["melody"], "role": "melody",
         "frequencyRole": "high-mid", "suggestedVolume": 0.65,
         "notes": melody_notes, "totalDuration": DURATION},
        {"name": f"{genre.capitalize()} Bass", "program": genre_cfg["bass"], "role": "bass",
         "frequencyRole": "sub-bass", "suggestedVolume": 0.55,
         "notes": bass_notes, "totalDuration": DURATION},
        {"name": f"{genre.capitalize()} Chords", "program": genre_cfg["chords"], "role": "chords",
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


def main():
    output_dir = Path(__file__).parent / "output_v4"
    output_dir.mkdir(exist_ok=True)

    genres = list(GENRES.keys())
    modes = list(MODES.keys())

    total = len(genres) * len(modes) * len(VARIATIONS)
    print(f"Generating {total} sequences ({len(genres)} genres × {len(modes)} modes × {len(VARIATIONS)} variations)")

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
                    json.dump(seq, f, separators=(",", ":"))  # minified

                note_count = sum(len(t["notes"]) for t in seq["tracks"])
                if var_id == 0:  # Only print first variation per combo
                    print(f"  {genre:12s} × {mode:12s} — {note_count:4d} notes, {seq['bpm']} BPM, key={seq['key']}, scale={seq['scale']}")

    # Save combined minified catalog
    catalog = {"sequences": all_sequences, "version": "4.0"}
    catalog_path = output_dir / "midi_sequences_v4.json"
    with open(catalog_path, "w") as f:
        json.dump(catalog, f, separators=(",", ":"))

    # Copy to app bundle
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
