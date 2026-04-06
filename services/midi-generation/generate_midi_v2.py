"""
BioNaural MIDI Batch Generator v2 — Orchestrator Approach

Critical difference from v1: ALL tracks generated in ONE Claude call
with rich compositional context that forces Claude to think as an
orchestrator, not individual track generators.

Based on the exact approach from the reference app (possibility-audio):
1. Pre-assign frequency roles for each track
2. Include mixing intelligence (fill sparse bands, avoid heavy ones)
3. Require mixStrategy explanation (forces holistic thinking)
4. Include counterpoint guidance (chord tones per function)
5. Generate segment volumes for shared energy arc
"""

import anthropic
import json
import sys
from pathlib import Path

client = anthropic.Anthropic()

# ============================================================================
# GENRE DEFINITIONS — Orchestrator-level detail
# ============================================================================

GENRES = {
    "ambient": {
        "desc": "Ambient/Atmospheric",
        "scales": "Lydian, whole tone, pentatonic, suspended",
        "chords": "Isus2 → IVmaj7 → Imaj7 → vi. Non-functional, atmospheric. Slow modal shifts.",
        "instruments": {
            "melody": ("New Age Pad", 88, "High shimmer pad. Sparse notes, 4-8 second sustains. Range: C4-C6."),
            "bass": ("Warm Pad", 89, "Sub-bass drone pad. Root notes only, 8-16 second sustains. Range: C2-C3."),
            "chords": ("Choir Pad", 91, "Mid-range sustained chords. Open voicings (root-5th-9th). Range: C3-C5."),
            "texture": ("Sweep Pad", 95, "Evolving texture layer. Very sparse, long notes. Range: C3-G5."),
        },
        "keys": {"sleep": "F", "relaxation": "D", "focus": "C", "energize": "C"},
        "feel": "No rhythmic pulse. Notes drift in freely. Long sustains with gentle overlaps.",
    },
    "lofi": {
        "desc": "Lo-Fi Hip Hop",
        "scales": "Minor 7th, dorian, major pentatonic. Jazzy warm harmony.",
        "chords": "ii7 → V7 → Imaj7, then Imaj7 → vi7 → ii7 → V7. Mellow 7th voicings throughout.",
        "instruments": {
            "melody": ("Electric Piano", 4, "Rhodes. Gentle jazz phrases, 7th chord arpeggios. Range: C4-C6. Velocity 45-65."),
            "bass": ("Electric Bass", 33, "Finger bass. Simple root patterns with chromatic walks. Range: E1-E3. Velocity 55-70."),
            "chords": ("Warm Pad", 89, "Sustained 7th chords beneath Rhodes. Open voicings. Range: C3-C5. Velocity 40-55."),
            "drums": ("Drums", 0, "Boom-bap: kick on 1 and 2.5, snare on 2 and 4. Soft closed hi-hat on 8ths. Ghost notes. Velocity 40-65."),
        },
        "keys": {"sleep": "Eb", "relaxation": "F", "focus": "C", "energize": "D"},
        "feel": "Relaxed swing. Notes slightly behind the beat. Everything soft and intimate.",
    },
    "jazz": {
        "desc": "Jazz",
        "scales": "Dorian, mixolydian, lydian, bebop dominant. Chromatic passing tones.",
        "chords": "ii7 → V7 → Imaj7 turnaround. Then iii7 → vi7 → ii7 → V7. Tritone subs optional.",
        "instruments": {
            "melody": ("Acoustic Piano", 0, "Jazz piano. Arpeggiate chord tones with chromatic passing tones. Range: C3-C6. Velocity 50-90."),
            "bass": ("Acoustic Bass", 32, "Walking quarter notes. Root → 3rd → 5th → chromatic approach. Range: E1-E3. Velocity 55-75."),
            "chords": ("Warm Pad", 89, "Sustained chord pads underneath. 7th/9th voicings. Range: C3-C5. Velocity 35-50."),
            "drums": ("Drums", 0, "Ride cymbal pattern with brush snare. Kick accents on 1. Ghost notes on snare. Swing feel. Velocity 45-80."),
        },
        "keys": {"sleep": "F", "relaxation": "C", "focus": "Bb", "energize": "F"},
        "feel": "Swing eighth notes. Comping: irregular rhythmic hits. Leave space — rests are musical.",
    },
    "rock": {
        "desc": "Rock",
        "scales": "Minor pentatonic, natural minor, blues scale.",
        "chords": "I → IV → V, or I → bVII → IV. Power chords (root + 5th). Driving energy.",
        "instruments": {
            "melody": ("Overdriven Guitar", 29, "Pentatonic riffs and power chord stabs. Range: E3-E5. Velocity 75-110."),
            "bass": ("Electric Bass", 33, "Driving eighth notes. Locks with kick drum. Range: E1-E3. Velocity 80-100."),
            "chords": ("Warm Pad", 89, "Sustained power chords underneath. Root+5th voicings. Range: E2-B4. Velocity 55-70."),
            "drums": ("Drums", 0, "Kick on 1&3, snare on 2&4, hi-hat 8ths. Crash on downbeats of sections. Velocity 80-110."),
        },
        "keys": {"sleep": "Em", "relaxation": "Am", "focus": "Em", "energize": "Em"},
        "feel": "Driving straight feel. Heavy downbeats. Accent beats 2 & 4 on snare.",
    },
    "hiphop": {
        "desc": "Hip Hop",
        "scales": "Minor pentatonic, natural minor, dorian. Dark and moody.",
        "chords": "i → bVI → bVII, or just i → iv vamp. Minor keys dominate.",
        "instruments": {
            "melody": ("Vibraphone", 11, "Bell-like melody. Short looping motifs. Range: C4-C6. Velocity 55-75."),
            "bass": ("Synth Bass", 38, "808-style sub bass. Long sustained notes on roots. Range: C1-C3. Velocity 85-110."),
            "chords": ("Warm Pad", 89, "Dark minor pads. Sparse. Range: C3-C5. Velocity 35-50."),
            "drums": ("Drums", 0, "Boom-bap: kick on 1&3, snare/clap on 2&4. Hi-hat 16ths with rolls. Velocity: kick 90-100, snare 75-85, hat 35-65."),
        },
        "keys": {"sleep": "Cm", "relaxation": "Dm", "focus": "Am", "energize": "Dm"},
        "feel": "Straight feel. Melodies sit behind the beat. Bass: long sustained sub notes.",
    },
    "blues": {
        "desc": "Blues",
        "scales": "Blues pentatonic (1-b3-4-b5-5-b7). Blue notes essential.",
        "chords": "12-bar: I7(4 bars) → IV7(2) → I7(2) → V7(1) → IV7(1) → I7(2). All dominant 7ths.",
        "instruments": {
            "melody": ("Steel Guitar", 25, "Blues licks. Call-and-response. Bend-like grace notes (chromatic approach from below). Range: C3-C5. Velocity 50-90."),
            "bass": ("Electric Bass", 33, "Walking bass. Root-3rd-5th-chromatic approach to next chord. Range: E1-E3. Velocity 60-80."),
            "chords": ("Piano", 0, "Comping on 2&4. 7th chord voicings. Range: C3-C5. Velocity 45-65."),
            "drums": ("Drums", 0, "Shuffle feel. Kick on 1&3, snare on 2&4. Triplet-based hi-hat. Velocity 55-80."),
        },
        "keys": {"sleep": "E", "relaxation": "A", "focus": "E", "energize": "A"},
        "feel": "Shuffle/swing. Triplet phrasing. Expressive dynamics — gentle verses, powerful climaxes.",
    },
    "reggae": {
        "desc": "Reggae",
        "scales": "Major, mixolydian, pentatonic major.",
        "chords": "I → IV, or I → V → vi → IV. Simple, repetitive.",
        "instruments": {
            "melody": ("Nylon Guitar", 24, "Simple vocal-style hooks. Repetitive. Range: C3-C5. Velocity 55-70."),
            "bass": ("Electric Bass", 33, "HEAVY. Dotted quarter-note feel. Root-5th patterns. Range: E1-E3. Velocity 80-95."),
            "chords": ("Organ", 16, "OFFBEAT SKANK. Silent on downbeats, hit on every upbeat ('and'). Range: C4-C6. Velocity 55-70."),
            "drums": ("Drums", 0, "ONE-DROP: kick ONLY on beat 3. Rim click on 2&4. Hi-hat on 8ths. Velocity: kick 85, rim 65, hat 40."),
        },
        "keys": {"sleep": "G", "relaxation": "C", "focus": "G", "energize": "D"},
        "feel": "OFFBEAT emphasis critical. Keys/guitar silent on downbeats, play on upbeats.",
    },
    "classical": {
        "desc": "Classical",
        "scales": "Major, natural/harmonic minor. Full chromatic vocabulary.",
        "chords": "I → IV → V → I, then I → vi → IV → V. Proper voice leading — common tones held.",
        "instruments": {
            "melody": ("Acoustic Piano", 0, "Lyrical, singable theme. Balanced antecedent-consequent phrases. Range: C4-C6. Velocity 45-85."),
            "bass": ("Cello", 42, "Legato bass line. Alberti patterns or sustained roots. Range: C2-C4. Velocity 45-70."),
            "chords": ("String Ensemble", 49, "Sustained legato strings. Close voicings. Range: C3-C5. Velocity 40-65."),
            "texture": ("Flute", 73, "Counter-melody in high register. Sparse, ornamental. Range: C5-C7. Velocity 40-60."),
        },
        "keys": {"sleep": "C", "relaxation": "G", "focus": "D", "energize": "D"},
        "feel": "Precise articulation. Crescendos and diminuendos. Proper cadences (V→I authentic, IV→I plagal).",
    },
    "latin": {
        "desc": "Latin/Salsa",
        "scales": "Harmonic minor, phrygian dominant. Syncopated.",
        "chords": "i → bVII → bVI → V (Andalusian cadence), or ii → V → I with Latin voicings.",
        "instruments": {
            "melody": ("Flute", 73, "Syncopated dance-oriented phrases. Call-and-response. Range: C4-C6. Velocity 65-90."),
            "bass": ("Electric Bass", 33, "TUMBAO pattern: syncopated, anticipated beats. Range: E1-E3. Velocity 75-95."),
            "chords": ("Piano", 0, "MONTUNO: repetitive arpeggiated figures locked to clave. Range: C3-C5. Velocity 60-80."),
            "drums": ("Drums", 0, "Son CLAVE 3-2 pattern. Conga accents. Kick on 1&3. Timbale rolls. Velocity 65-90."),
        },
        "keys": {"sleep": "Am", "relaxation": "Dm", "focus": "Am", "energize": "Am"},
        "feel": "CLAVE is fundamental. Everything locks to the clave grid. Syncopated anticipations.",
    },
    "electronic": {
        "desc": "Electronic/House",
        "scales": "Minor, dorian, minor pentatonic.",
        "chords": "i → iv, or i → bVI → bVII → i. Simple repetitive loops.",
        "instruments": {
            "melody": ("Sawtooth Lead", 81, "Arpeggiated synth patterns. 16th-note sequences. Range: C4-C6. Velocity 70-90."),
            "bass": ("Synth Bass", 38, "Pumping root-octave pattern. Eighth notes. Range: A1-A3. Velocity 85-100."),
            "chords": ("Warm Pad", 89, "Sustained minor chords. Slow filter sweep feel. Range: C3-C5. Velocity 50-70."),
            "drums": ("Drums", 0, "FOUR-ON-FLOOR: kick every beat. Clap on 2&4. Closed hi-hat 8ths. Open hi-hat on upbeats. Velocity: kick 95, clap 80, hat 45-60."),
        },
        "keys": {"sleep": "Am", "relaxation": "Cm", "focus": "Am", "energize": "Am"},
        "feel": "Steady driving pulse. Bass octave-bounces. Build/drop structure.",
    },
}

MODE_CONFIG = {
    "sleep": {
        "tempo_range": (42, 55),
        "energy": "Extremely gentle. Long sustains (4-16s). Very few notes. Low velocity (25-50). NO drums. Dark, warm, enveloping.",
        "has_drums": False,
        "segment_arc": [0.3, 0.4, 0.5, 0.5, 0.4, 0.3],  # gentle fade in/out
    },
    "relaxation": {
        "tempo_range": (55, 68),
        "energy": "Gentle, spacious. Medium sustains (2-6s). Moderate note density. Velocity 35-65. No drums or very subtle. Floating quality.",
        "has_drums": False,
        "segment_arc": [0.3, 0.5, 0.6, 0.7, 0.6, 0.4],
    },
    "focus": {
        "tempo_range": (68, 82),
        "energy": "Steady, predictable. Medium notes (1-4s). Consistent density. Velocity 45-75. Subtle drums OK. Should habituate within 2 minutes.",
        "has_drums": True,
        "segment_arc": [0.4, 0.6, 0.7, 0.7, 0.7, 0.5],
    },
    "energize": {
        "tempo_range": (100, 130),
        "energy": "Driving, rhythmic. Short punchy notes (0.2-2s). Dense. Velocity 65-110. Full drums. Builds energy.",
        "has_drums": True,
        "segment_arc": [0.4, 0.6, 0.8, 0.9, 1.0, 0.7],
    },
}

# ============================================================================
# TOOL SCHEMA — Forces orchestrated output
# ============================================================================

COMPOSE_TOOL = {
    "name": "compose_score",
    "description": "Compose a complete multi-track MIDI score where all tracks work together as a cohesive arrangement.",
    "input_schema": {
        "type": "object",
        "properties": {
            "mixStrategy": {
                "type": "string",
                "description": "Explain HOW these tracks work together: what frequency range each occupies, how they complement each other rhythmically, and how the energy builds over time.",
            },
            "key": {"type": "string"},
            "bpm": {"type": "integer"},
            "scale": {"type": "string"},
            "tracks": {
                "type": "array",
                "minItems": 3,
                "maxItems": 5,
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string", "description": "Track name, max 25 chars"},
                        "program": {"type": "integer", "description": "GM instrument 0-127"},
                        "role": {"type": "string", "enum": ["melody", "bass", "chords", "drums", "texture"]},
                        "frequencyRole": {"type": "string", "description": "What frequency band this fills: sub-bass(20-100Hz), bass(100-300Hz), low-mid(300-1kHz), high-mid(1-5kHz), presence(5kHz+)"},
                        "suggestedVolume": {"type": "number", "description": "Mix volume 0.2-0.85"},
                        "notes": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "note": {"type": "integer", "description": "MIDI note 24-96"},
                                    "velocity": {"type": "integer", "description": "1-127"},
                                    "startTime": {"type": "number", "description": "Seconds from start"},
                                    "duration": {"type": "number", "description": "Seconds (min 0.1)"},
                                },
                                "required": ["note", "velocity", "startTime", "duration"],
                            },
                        },
                        "totalDuration": {"type": "number"},
                    },
                    "required": ["name", "program", "role", "frequencyRole", "suggestedVolume", "notes", "totalDuration"],
                },
            },
        },
        "required": ["mixStrategy", "key", "bpm", "scale", "tracks"],
    },
}


def generate_score(genre_id: str, mode: str) -> dict | None:
    genre = GENRES[genre_id]
    mc = MODE_CONFIG[mode]
    key = genre["keys"][mode]
    bpm = (mc["tempo_range"][0] + mc["tempo_range"][1]) // 2

    # Build the track roster
    track_roster = []
    for role, (inst_name, program, desc) in genre["instruments"].items():
        if role == "drums" and not mc["has_drums"]:
            continue
        track_roster.append(f"- {role.upper()} ({inst_name}, GM {program}): {desc}")

    roster_text = "\n".join(track_roster)

    # Frequency mixing guidance
    mixing_guide = """MIXING INTELLIGENCE — Frequency Band Assignment:
- BASS track: Fill 20-300Hz. Low register MIDI notes (C1-C3, MIDI 24-48). This is the foundation.
- CHORDS track: Fill 300Hz-2kHz. Mid register (C3-C5, MIDI 48-72). Harmonic body.
- MELODY track: Fill 1kHz-8kHz. High register (C4-C6, MIDI 60-84). Lead voice, most prominent.
- TEXTURE track: Fill 3kHz+. Very high register (C5-C7, MIDI 72-96). Shimmer and air.
- DRUMS: Full spectrum but primarily rhythmic. Use GM drum map notes (kick=36, snare=38, hihat=42, ride=51).

CRITICAL: Each track MUST stay in its assigned frequency range. DO NOT have bass playing in the melody range or melody playing low notes. This is what makes multi-track music sound professional."""

    # Counterpoint guidance
    counterpoint = f"""COUNTERPOINT GUIDANCE for key of {key}:
- All tracks use the SAME chord progression: {genre['chords']}
- Bass: Plays chord ROOTS (and 5ths as passing tones)
- Chords: Plays full chord voicings (root-3rd-5th-7th)
- Melody: Plays chord tones on strong beats, scale tones and passing tones on weak beats
- Every note in every track must belong to the scale: {genre['scales']}"""

    # Energy arc
    arc = mc["segment_arc"]
    arc_text = f"Energy arc over 6 segments: {' → '.join(str(a) for a in arc)} (0=silent, 1=full energy)"

    system_prompt = f"""You are an expert music orchestrator composing a COMPLETE, COHESIVE multi-track score.

GENRE: {genre['desc']}
Scales: {genre['scales']}
Chord Progression: {genre['chords']}
Feel: {genre['feel']}

MODE: {mode.upper()} — {mc['energy']}

{mixing_guide}

{counterpoint}

ARRANGEMENT — Track Roster:
{roster_text}

ENERGY: {arc_text}

DURATION: 45 seconds at {bpm} BPM (quarter note = {60/bpm:.3f}s)

CRITICAL RULES FOR COHESION:
1. ALL tracks follow the SAME chord progression simultaneously
2. Bass notes are ALWAYS chord roots (or approach notes one beat before chord change)
3. Melody notes on beat 1 and 3 are ALWAYS chord tones (root, 3rd, 5th, 7th)
4. When chords change, ALL tracks change together on the SAME beat
5. Energy builds and falls together across ALL tracks (use the energy arc)
6. Each track stays in its assigned frequency range — NO crossing
7. Rhythmic interlock: bass and drums lock together; melody breathes between drum hits
8. Think of this as a BAND playing together, not separate soloists"""

    user_prompt = f"""Use compose_score to write a {genre['desc']} score for {mode} mode.

Key: {key}, BPM: {bpm}, Duration: 45 seconds.

First, write your mixStrategy explaining how the tracks work together.
Then compose ALL tracks simultaneously, ensuring they form a unified arrangement.

EVERY track must have at least 15 notes with proper startTime values from 0.0 to 45.0 seconds.
The music must sound like a REAL {genre['desc']} {mode} track — not random notes."""

    try:
        resp = client.messages.create(
            model="claude-opus-4-6",
            max_tokens=16000,
            system=system_prompt,
            tools=[COMPOSE_TOOL],
            tool_choice={"type": "tool", "name": "compose_score"},
            messages=[{"role": "user", "content": user_prompt}],
        )

        for block in resp.content:
            if block.type == "tool_use" and block.name == "compose_score":
                r = block.input
                # Validate and sanitize
                for t in r.get("tracks", []):
                    for n in t.get("notes", []):
                        n["note"] = max(0, min(127, n.get("note", 60)))
                        n["velocity"] = max(1, min(127, n.get("velocity", 60)))
                        n["startTime"] = max(0, n.get("startTime", 0))
                        n["duration"] = max(0.05, n.get("duration", 1))

                return {
                    "genre": genre_id,
                    "mode": mode,
                    "mixStrategy": r.get("mixStrategy", ""),
                    "tracks": r.get("tracks", []),
                    "key": r.get("key", key),
                    "bpm": r.get("bpm", bpm),
                    "scale": r.get("scale", ""),
                }
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)

    return None


def main():
    output_dir = Path(__file__).parent / "output_v2"
    output_dir.mkdir(exist_ok=True)

    genres = list(GENRES.keys())
    modes = list(MODE_CONFIG.keys())

    print(f"Generating MIDI v2 (orchestrator): {len(genres)} genres × {len(modes)} modes = {len(genres) * len(modes)}")
    print()

    all_sequences = []

    for genre in genres:
        for mode in modes:
            print(f"  {genre:12s} × {mode:12s}...", end=" ", flush=True)
            result = generate_score(genre, mode)

            if result:
                notes = sum(len(t.get("notes", [])) for t in result.get("tracks", []))
                tracks = len(result.get("tracks", []))
                if notes > 0:
                    all_sequences.append(result)
                    print(f"OK — {tracks} tracks, {notes} notes, {result['bpm']} BPM, key={result['key']}")
                    print(f"             Strategy: {result.get('mixStrategy', '')[:80]}...")
                    with open(output_dir / f"{genre}_{mode}.json", "w") as f:
                        json.dump(result, f, indent=2)
                else:
                    print(f"EMPTY ({tracks} tracks but 0 notes)")
            else:
                print("FAILED")

    # Save combined catalog
    catalog = {"sequences": all_sequences, "version": "2.0"}
    combined = output_dir / "midi_sequences_v2.json"
    with open(combined, "w") as f:
        json.dump(catalog, f)

    # Also copy to app bundle
    app_path = Path(__file__).parent.parent.parent / "src" / "BioNaural" / "Resources" / "midi_sequences.json"
    with open(app_path, "w") as f:
        json.dump(catalog, f)

    print(f"\nGenerated {len(all_sequences)} of {len(genres) * len(modes)} sequences")
    print(f"Output: {combined}")
    print(f"App bundle: {app_path}")


if __name__ == "__main__":
    main()
