"""
BioNaural MIDI Generator v3 — Mode-First, Genre-as-Flavor

CRITICAL CHANGE: The therapeutic mode (sleep/relax/focus/energize) is the
PRIMARY driver of ALL musical parameters. Genre only influences instrument
choice and harmonic vocabulary — it NEVER overrides mode constraints.

Example: "jazz × sleep" = sleep-appropriate music that happens to use
jazz instruments (soft piano, gentle bass). NOT jazz music forced into
sleep parameters.
"""

import anthropic
import json
import sys
from pathlib import Path

client = anthropic.Anthropic()

# ============================================================================
# MODE DEFINITIONS — These are the PRIMARY musical specifications
# ============================================================================

MODES = {
    "sleep": {
        "tempo": 48,
        "description": """SLEEP MODE — Music for falling asleep and deep rest.

ABSOLUTE RULES (genre CANNOT override these):
- Tempo: EXACTLY 48 BPM. No faster.
- NO drums, NO percussion of any kind
- NO rhythmic pulse — notes float freely
- ALL notes: velocity 25-45 (barely audible)
- ALL notes: duration 4-16 seconds (long, sustained)
- Maximum 3-4 notes sounding at any time
- Predominantly DESCENDING melodic motion (settling)
- Frequency range: LOW register only (C2-C4). Nothing above C5.
- Note density: 1-2 new notes every 4-8 seconds
- Chord changes: every 16-32 seconds (near-static harmony)
- Energy arc: starts at 0.4, gently descends to 0.2 over 45 seconds
- Think: warm blanket of sound, darkness, weightlessness""",
        "tracks": ["melody", "bass", "chords"],
    },
    "relaxation": {
        "tempo": 62,
        "description": """RELAXATION MODE — Music for unwinding, stress relief, gentle calm.

ABSOLUTE RULES (genre CANNOT override these):
- Tempo: EXACTLY 62 BPM.
- NO drums. Optional very subtle shaker/brush at velocity 20-30 ONLY.
- Gentle rhythmic sway is OK but never driving
- ALL notes: velocity 35-60
- Note durations: 2-8 seconds (flowing, connected)
- Maximum 4-5 notes sounding at any time
- Melodic contour: gentle ARCH shapes (rise then fall within phrases)
- Frequency range: C3-C5 primarily. Bass in C2-C3.
- Note density: 2-4 new notes every 4 seconds
- Chord changes: every 8-16 seconds
- Energy arc: 0.3 → 0.5 → 0.6 → 0.5 → 0.4 → 0.3
- Think: floating on calm water, gentle breeze, warm sunlight""",
        "tracks": ["melody", "bass", "chords"],
    },
    "focus": {
        "tempo": 75,
        "description": """FOCUS MODE — Music for concentration, study, deep work.

ABSOLUTE RULES (genre CANNOT override these):
- Tempo: EXACTLY 75 BPM.
- Subtle drums OK (side stick, soft hi-hat) at velocity 30-45
- STEADY, PREDICTABLE patterns that the brain habituates to within 2 minutes
- Melody: velocity 45-70, pentatonic preferred (no tension)
- Note durations: 1-4 seconds
- Repetitive motifs that repeat with MINIMAL variation
- Frequency range: C3-C5. Bass in C2-C3.
- Note density: 3-5 new notes every 2-4 seconds
- Chord changes: every 4-8 seconds (steady, familiar)
- Energy arc: flat at 0.6-0.7 throughout (consistency is key)
- Think: steady warm pulse, background wallpaper, NOT attention-grabbing""",
        "tracks": ["melody", "bass", "chords", "drums"],
    },
    "energize": {
        "tempo": 115,
        "description": """ENERGIZE MODE — Music for workouts, motivation, energy boost.

ABSOLUTE RULES (genre CANNOT override these):
- Tempo: EXACTLY 115 BPM.
- FULL drums: kick on 1&3, snare on 2&4, hi-hat pattern
- DRIVING rhythmic pulse throughout
- Melody: velocity 65-100, short punchy notes (0.2-1.5s)
- Bass: velocity 80-100, locked with kick drum
- Dense note patterns, forward momentum
- Frequency range: FULL spectrum. Bass C1-C3, melody C4-C6.
- Note density: 6-12 new notes every 2 seconds
- Chord changes: every 2-4 seconds (driving harmonic rhythm)
- Energy arc: 0.5 → 0.7 → 0.8 → 0.9 → 1.0 → 0.7
- Think: power, drive, heart pumping, unstoppable momentum""",
        "tracks": ["melody", "bass", "chords", "drums"],
    },
}

# ============================================================================
# GENRE FLAVORS — Only instruments and harmonic vocabulary
# ============================================================================

GENRE_FLAVORS = {
    "ambient":    {"melody": ("New Age Pad", 88), "bass": ("Warm Pad", 89), "chords": ("Choir Pad", 91), "drums": ("Drums", 0), "scales": "Lydian, whole tone, sus2/sus4", "chords_style": "Non-functional, modal shifts. Isus2→IVmaj7→I."},
    "lofi":       {"melody": ("Electric Piano", 4), "bass": ("Electric Bass", 33), "chords": ("Warm Pad", 89), "drums": ("Drums", 0), "scales": "Minor 7th, dorian, pentatonic", "chords_style": "ii7→V7→Imaj7. Jazz-influenced 7th voicings."},
    "jazz":       {"melody": ("Acoustic Piano", 0), "bass": ("Acoustic Bass", 32), "chords": ("Warm Pad", 89), "drums": ("Drums", 0), "scales": "Dorian, mixolydian, bebop", "chords_style": "ii7→V7→Imaj7 turnarounds. Extended voicings (9ths, 13ths)."},
    "rock":       {"melody": ("Clean Guitar", 25), "bass": ("Electric Bass", 33), "chords": ("Warm Pad", 89), "drums": ("Drums", 0), "scales": "Minor pentatonic, natural minor", "chords_style": "I→IV→V, I→bVII→IV. Simple root+5th voicings."},
    "hiphop":     {"melody": ("Vibraphone", 11), "bass": ("Synth Bass", 38), "chords": ("Warm Pad", 89), "drums": ("Drums", 0), "scales": "Minor pentatonic, dorian", "chords_style": "i→bVI→bVII, or i→iv vamp."},
    "blues":      {"melody": ("Steel Guitar", 25), "bass": ("Electric Bass", 33), "chords": ("Piano", 0), "drums": ("Drums", 0), "scales": "Blues scale (1-b3-4-b5-5-b7)", "chords_style": "12-bar: I7→IV7→V7. All dominant 7ths."},
    "reggae":     {"melody": ("Nylon Guitar", 24), "bass": ("Electric Bass", 33), "chords": ("Organ", 16), "drums": ("Drums", 0), "scales": "Major, mixolydian", "chords_style": "I→IV→V. Offbeat chord stabs on upbeats."},
    "classical":  {"melody": ("Acoustic Piano", 0), "bass": ("Cello", 42), "chords": ("String Ensemble", 49), "drums": ("Drums", 0), "scales": "Major, harmonic minor", "chords_style": "I→IV→V→I. Proper voice leading, authentic cadences."},
    "latin":      {"melody": ("Flute", 73), "bass": ("Electric Bass", 33), "chords": ("Piano", 0), "drums": ("Drums", 0), "scales": "Harmonic minor, phrygian dominant", "chords_style": "i→bVII→bVI→V (Andalusian). Syncopated montuno."},
    "electronic": {"melody": ("Sawtooth Lead", 81), "bass": ("Synth Bass", 38), "chords": ("Warm Pad", 89), "drums": ("Drums", 0), "scales": "Minor, dorian", "chords_style": "i→iv, i→bVI→bVII→i."},
}

KEYS = {
    "sleep": {"ambient": "F", "lofi": "Eb", "jazz": "F", "rock": "Am", "hiphop": "Cm", "blues": "E", "reggae": "G", "classical": "C", "latin": "Am", "electronic": "Am"},
    "relaxation": {"ambient": "D", "lofi": "F", "jazz": "C", "rock": "Am", "hiphop": "Dm", "blues": "A", "reggae": "C", "classical": "G", "latin": "Dm", "electronic": "Cm"},
    "focus": {"ambient": "C", "lofi": "C", "jazz": "Bb", "rock": "Em", "hiphop": "Am", "blues": "E", "reggae": "G", "classical": "D", "latin": "Am", "electronic": "Am"},
    "energize": {"ambient": "C", "lofi": "D", "jazz": "F", "rock": "Em", "hiphop": "Dm", "blues": "A", "reggae": "D", "classical": "D", "latin": "Am", "electronic": "Am"},
}

TOOL = {
    "name": "compose_score",
    "description": "Compose a cohesive multi-track therapeutic MIDI score.",
    "input_schema": {
        "type": "object",
        "properties": {
            "mixStrategy": {"type": "string", "description": "How tracks complement each other spectrally and rhythmically."},
            "key": {"type": "string"}, "bpm": {"type": "integer"}, "scale": {"type": "string"},
            "tracks": {
                "type": "array", "minItems": 3, "maxItems": 4,
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"}, "program": {"type": "integer"},
                        "role": {"type": "string", "enum": ["melody", "bass", "chords", "drums"]},
                        "frequencyRole": {"type": "string"},
                        "suggestedVolume": {"type": "number"},
                        "notes": {"type": "array", "items": {"type": "object", "properties": {
                            "note": {"type": "integer"}, "velocity": {"type": "integer"},
                            "startTime": {"type": "number"}, "duration": {"type": "number"},
                        }, "required": ["note", "velocity", "startTime", "duration"]}},
                        "totalDuration": {"type": "number"},
                    },
                    "required": ["name", "program", "role", "frequencyRole", "suggestedVolume", "notes", "totalDuration"],
                },
            },
        },
        "required": ["mixStrategy", "key", "bpm", "scale", "tracks"],
    },
}


def generate(genre_id: str, mode: str) -> dict | None:
    mc = MODES[mode]
    gf = GENRE_FLAVORS[genre_id]
    key = KEYS[mode][genre_id]

    # Build instrument list (mode controls which roles exist)
    instruments = []
    for role in mc["tracks"]:
        inst_name, prog = gf[role]
        instruments.append(f"- {role.upper()}: {inst_name} (GM {prog})")

    system = f"""You are composing THERAPEUTIC music. The therapeutic MODE is the absolute authority.

{mc['description']}

GENRE FLAVOR: {genre_id}
This only affects instrument timbre and harmonic vocabulary — it NEVER overrides mode rules.
Scales: {gf['scales']}
Chord style: {gf['chords_style']}

INSTRUMENTS (genre-flavored, mode-constrained):
{chr(10).join(instruments)}

KEY: {key}, BPM: {mc['tempo']}, DURATION: 45 seconds.

FREQUENCY SEPARATION:
- Bass: MIDI 24-48 (C1-C3). Foundation.
- Chords: MIDI 48-72 (C3-C5). Harmonic body.
- Melody: MIDI 60-84 (C4-C6). Lead voice.
{'- Drums: GM percussion map (kick=36, snare=38, hihat=42, ride=51, rim=37).' if 'drums' in mc['tracks'] else ''}

ALL tracks follow the SAME chord progression and change chords TOGETHER.
Bass ALWAYS plays chord roots. Melody hits chord tones on strong beats.
Every track must have at least 15 notes spanning 0 to 45 seconds."""

    prompt = f"""Use compose_score to write {mode} music using {genre_id} instruments.

Remember: This is {mode.upper()} music FIRST. The {genre_id} genre only colors the instrument sounds
and harmonic choices. Every musical decision (tempo, density, dynamics, rhythm) must serve
the {mode} therapeutic purpose.

Generate all tracks now."""

    try:
        resp = client.messages.create(
            model="claude-opus-4-6", max_tokens=16000,
            system=system, tools=[TOOL],
            tool_choice={"type": "tool", "name": "compose_score"},
            messages=[{"role": "user", "content": prompt}],
        )
        for block in resp.content:
            if block.type == "tool_use" and block.name == "compose_score":
                r = block.input
                for t in r.get("tracks", []):
                    for n in t.get("notes", []):
                        n["note"] = max(0, min(127, n.get("note", 60)))
                        n["velocity"] = max(1, min(127, n.get("velocity", 60)))
                        n["startTime"] = max(0, n.get("startTime", 0))
                        n["duration"] = max(0.05, n.get("duration", 1))
                return {"genre": genre_id, "mode": mode, "mixStrategy": r.get("mixStrategy", ""),
                        "tracks": r.get("tracks", []), "key": r.get("key", key),
                        "bpm": r.get("bpm", mc["tempo"]), "scale": r.get("scale", "")}
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
    return None


def main():
    output_dir = Path(__file__).parent / "output_v3"
    output_dir.mkdir(exist_ok=True)

    genres = list(GENRE_FLAVORS.keys())
    modes = list(MODES.keys())
    print(f"Generating v3 (mode-first): {len(genres)} genres × {len(modes)} modes = {len(genres) * len(modes)}\n")

    all_seqs = []
    for genre in genres:
        for mode in modes:
            print(f"  {genre:12s} × {mode:12s}...", end=" ", flush=True)
            result = generate(genre, mode)
            if result:
                notes = sum(len(t.get("notes", [])) for t in result.get("tracks", []))
                if notes > 0:
                    all_seqs.append(result)
                    print(f"OK — {len(result['tracks'])} tracks, {notes} notes, {result['bpm']} BPM")
                    with open(output_dir / f"{genre}_{mode}.json", "w") as f:
                        json.dump(result, f, indent=2)
                else:
                    print("EMPTY")
            else:
                print("FAILED")

    catalog = {"sequences": all_seqs, "version": "3.0"}
    with open(output_dir / "midi_sequences_v3.json", "w") as f:
        json.dump(catalog, f)
    app_path = Path(__file__).parent.parent.parent / "src" / "BioNaural" / "Resources" / "midi_sequences.json"
    with open(app_path, "w") as f:
        json.dump(catalog, f)
    print(f"\nGenerated {len(all_seqs)} of {len(genres) * len(modes)} sequences")


if __name__ == "__main__":
    main()
