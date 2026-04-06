"""
BioNaural MIDI Batch Generator

Uses Claude API with tool use to generate high-quality, genre-authentic
MIDI sequences for all 10 genres × 4 modes. Each generation produces
3-5 tracks (melody, bass, drums, chords, texture) that are cohesive
in key, scale, tempo, and style.

Output: JSON files bundled into the iOS app. Zero per-session API cost.

Estimated total cost: ~$3-8 (one-time batch generation)
"""

import anthropic
import json
import os
import sys
from pathlib import Path

client = anthropic.Anthropic()

# ============================================================================
# GENRE INSTRUCTIONS (from reference app analysis)
# ============================================================================

GENRE_INSTRUCTIONS = {
    "ambient": """GENRE: Ambient
Scales: Major, lydian, whole tone, pentatonic, suspended. Avoid strong functional harmony.
Chord progressions: Static drones, slow modal shifts. Isus2-IVmaj7. Non-functional, atmospheric.
Rhythm: No strong pulse. Free-floating, evolving textures.
Instruments: Warm Pad (89), New Age Pad (88), Choir Pad (91), Sweep Pad (95).
Melodies: Sparse, widely spaced notes. Long sustains (4-16 seconds). Gentle intervals: 2nds, 5ths, octaves. Range: C3-C5.
Velocity: 30-60. Very gentle, ethereal. Slow swells.
Keys: C, D, F, Ab. Open, resonant keys. Use sus2 and sus4 voicings.
Subtle: Extremely slow note changes (every 4-8 seconds). Layer multiple pads at different registers. No rhythmic pulse.""",

    "lofi": """GENRE: Lo-Fi
Scales: Major 7th, dorian, minor 7th, pentatonic. Jazzy, warm harmony.
Chord progressions: ii7-V7-Imaj7, Imaj7-vi7-ii7-V7. Jazz-influenced with mellow voicings.
Rhythm: 4/4, relaxed swing. Slightly behind the beat. Boom-bap influenced drums. 72-85 BPM.
Instruments: Piano (0), Electric Piano (4), Warm Pad (89), Vibraphone (11), Nylon Guitar (24).
Melodies: Gentle jazz-influenced phrases. Seventh chord arpeggios. Warm, nostalgic. Range: C3-C5.
Velocity: 40-70. Very gentle and intimate. Bass: 55-70, melody: 45-65.
Keys: C, F, Bb, Eb. Warm flat keys.
Subtle: Notes slightly behind the grid. Rhodes chords sustained with gentle decay. Bass: simple root patterns. Sparse arrangement.""",

    "jazz": """GENRE: Jazz
Scales: Dorian, mixolydian, lydian, bebop dominant, altered.
Chord progressions: ii-V-I (Dm7-G7-Cmaj7), I-vi-ii-V turnarounds, tritone substitutions.
Rhythm: 4/4 swing. Syncopation and anticipations. Walking bass in quarter notes. 110-130 BPM.
Instruments: Piano (0), Jazz Guitar (26), Acoustic Bass (32), Tenor Sax (66), Vibraphone (11).
Melodies: Arpeggiate chord tones with chromatic passing tones. Bebop eighth-note lines. Range: varies.
Velocity: 50-100, highly dynamic. Ghost notes at 30-40. Accents on upbeats.
Keys: C, F, Bb, Eb. Use extended voicings (7ths, 9ths, 13ths).
Subtle: Swing all eighth notes. Comping: irregular rhythmic hits. Bass: quarter-note walk with chromatic approaches. Leave space.""",

    "rock": """GENRE: Rock
Scales: Minor pentatonic, natural minor, blues scale, power chord roots.
Chord progressions: I-IV-V, I-bVII-IV, i-bVI-bVII. 115-135 BPM.
Rhythm: 4/4, driving feel. Heavy downbeats, consistent eighth-note pulse. Accent 2 & 4.
Instruments: Overdriven Guitar (29), Distortion Guitar (30), Electric Bass (33), Warm Pad (89).
Melodies: Pentatonic riffs, power chord patterns. Strong, angular phrases. Range: E2-E5.
Velocity: 80-120. High energy, aggressive attacks. Bass locks with kick.
Keys: E minor, A minor, G major, D minor.
Subtle: Palm-muted verses (shorter durations), open sustain on choruses. Driving eighth-note bass.""",

    "hiphop": """GENRE: Hip Hop
Scales: Minor pentatonic, natural minor, dorian, blues. Dark and moody.
Chord progressions: i-bVI-bVII, i-iv. Often single-chord vamp. 85-95 BPM.
Rhythm: 4/4, straight feel. Kick on 1, snare on 3. Hi-hats: steady 16ths with rolls.
Instruments: Piano (0), Electric Piano (4), Synth Bass (38), Warm Pad (89), Vibraphone (11).
Melodies: Short looping motifs (2-4 bars). Bell-like sounds. Sparse, leaving room. Range: C3-C5.
Velocity: Bass 90-110, Melody 60-80. Hi-hats 40-90 variation.
Keys: C minor, D minor, A minor, F minor.
Subtle: Boom-bap: kick 1&3, snare 2&4. Bass: long sustained sub notes. Melodies behind the beat.""",

    "blues": """GENRE: Blues
Scales: Blues pentatonic (1-b3-4-b5-5-b7), mixolydian, dorian. Blue notes essential.
Chord progressions: 12-bar blues (I7-IV7-V7). 70-95 BPM.
Rhythm: 4/4, shuffle/swing feel. Triplet-based phrasing. Walking bass.
Instruments: Piano (0), Steel Guitar (25), Jazz Guitar (26), Electric Bass (33), Organ (16).
Melodies: Call-and-response. Bend-like grace notes. Blues licks with b3->3. Range: C3-C5.
Velocity: 50-95. Expressive dynamics. Gentle verses, powerful climaxes.
Keys: E, A, Bb, G. Dominant 7th voicings.
Subtle: Swing all eighths. Walking bass: root-3-5-chromatic approach. Piano comps on 2&4.""",

    "reggae": """GENRE: Reggae
Scales: Major, minor, mixolydian, pentatonic. Bright, positive. 72-85 BPM.
Chord progressions: I-IV, I-V-vi-IV. Simple, repetitive grooves.
Rhythm: 4/4, emphasis on offbeats. Guitar/keys on the "and" of every beat. Bass heavy on 1&3. One-drop: kick on 3.
Instruments: Nylon Guitar (24), Electric Bass (33), Organ (16), Piano (0).
Melodies: Vocal-style phrases, repetitive hooks. Minor pentatonic over major. Range: C3-C5.
Velocity: Guitar skank 60-75. Bass 80-95. Keys 50-70.
Keys: G, C, D, A minor.
Subtle: OFFBEAT EMPHASIS critical: keys silent on downbeats, play on upbeats. Bass: dotted quarter feel. One-drop kick on 3.""",

    "classical": """GENRE: Classical
Scales: Major, minor (natural, harmonic, melodic). Full chromatic vocabulary. 76-90 BPM.
Chord progressions: I-IV-V-I, i-iv-V-i. Functional harmony with proper voice leading.
Rhythm: 4/4 or 3/4. Precise. Clear 4/8/16 bar phrases.
Instruments: Piano (0), Strings (48), Violin (40), Cello (42), Flute (73).
Melodies: Lyrical, singable themes. Proper counterpoint. Balanced antecedent-consequent phrases. Full range.
Velocity: 40-100. Wide dynamic range. Crescendos and diminuendos.
Keys: C, G, D, A minor, E minor.
Subtle: Voice leading: smooth chord connections. Proper cadences (V-I). Strings sustain legato.""",

    "latin": """GENRE: Latin
Scales: Major, harmonic minor, phrygian dominant. 105-120 BPM.
Chord progressions: I-IV-V-I, i-bVII-bVI-V (Andalusian cadence), ii-V-I.
Rhythm: 4/4 with clave pattern (3-2 son clave). Syncopated, polyrhythmic. Montuno patterns.
Instruments: Nylon Guitar (24), Electric Bass (33), Piano (0), Flute (73).
Melodies: Syncopated, dance-oriented. Call-and-response. Montuno piano arpeggios. Range: C3-C6.
Velocity: 70-100. Rhythmic accents following clave. Bass: strong, punchy.
Keys: C, A minor, D minor, G.
Subtle: CLAVE fundamental: 3-2 son clave. Bass: tumbao pattern. Piano montuno: repetitive arpeggios.""",

    "electronic": """GENRE: Electronic/House
Scales: Minor, dorian, minor pentatonic. 124-132 BPM.
Chord progressions: i-iv, i-bVII, i-bVI-bVII-i. Simple, repetitive loops.
Rhythm: 4/4, four-on-the-floor kick. Offbeat hi-hats. Steady, driving.
Instruments: Warm Pad (89), Sawtooth Lead (81), Synth Bass (38), Electric Piano (4).
Melodies: Short vocal-like phrases. Filtered stabs. Arpeggiated synth patterns. Range: C1-C3 bass, C3-C5 melody.
Velocity: Bass 85-100. Chord stabs 70-85. Lead 75-90.
Keys: A minor, C minor, D minor, F minor.
Subtle: Four-on-floor: kick every quarter. Offbeat hi-hats: eighths between kicks. Bass: root octave pattern. Build/drop structure.""",
}

# Mode-specific overrides
MODE_OVERRIDES = {
    "sleep": {
        "tempo_range": "40-55 BPM",
        "character": "Extremely gentle, dark, sparse. Notes should be long (4-16 seconds). Very few notes per phrase. Low register (C2-C4). No percussion. Formless, enveloping warmth.",
        "velocity_cap": 55,
    },
    "relaxation": {
        "tempo_range": "55-70 BPM",
        "character": "Gentle, spacious, warm. Moderate sustains (2-8 seconds). Mid register (C3-C5). No percussion or very subtle. Floating, Lydian quality.",
        "velocity_cap": 70,
    },
    "focus": {
        "tempo_range": "65-85 BPM",
        "character": "Steady, predictable, non-distracting. Medium sustains (1-4 seconds). Pentatonic preferred for simplicity. Subtle rhythm OK. Should habituate within 2-3 minutes.",
        "velocity_cap": 80,
    },
    "energize": {
        "tempo_range": "100-135 BPM",
        "character": "Driving, rhythmic, energetic. Short punchy notes (0.3-2 seconds). Full percussion. Wide dynamic range. Builds energy and motivation.",
        "velocity_cap": 120,
    },
}

# ============================================================================
# TOOL DEFINITION
# ============================================================================

COMPOSE_TOOL = {
    "name": "compose_tracks",
    "description": "Compose a multi-track MIDI score with melody, bass, chords, and optional drums that are cohesive in key, scale, tempo, and style.",
    "input_schema": {
        "type": "object",
        "properties": {
            "tracks": {
                "type": "array",
                "minItems": 3,
                "maxItems": 5,
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string", "description": "Descriptive track name, max 25 chars"},
                        "program": {"type": "integer", "description": "GM instrument program number 0-127"},
                        "role": {"type": "string", "enum": ["melody", "bass", "chords", "drums", "texture"]},
                        "notes": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "note": {"type": "integer", "description": "MIDI note number 28-96"},
                                    "velocity": {"type": "integer", "description": "Note velocity 20-120"},
                                    "startTime": {"type": "number", "description": "Start time in seconds"},
                                    "duration": {"type": "number", "description": "Duration in seconds (min 0.1)"},
                                },
                                "required": ["note", "velocity", "startTime", "duration"],
                            },
                        },
                        "totalDuration": {"type": "number", "description": "Total duration in seconds"},
                    },
                    "required": ["name", "program", "role", "notes", "totalDuration"],
                },
            },
            "key": {"type": "string", "description": "Musical key (e.g., 'C', 'Am', 'F')"},
            "bpm": {"type": "integer", "description": "Tempo in BPM"},
            "scale": {"type": "string", "description": "Scale type used"},
        },
        "required": ["tracks", "key", "bpm", "scale"],
    },
}


def generate_midi_for_genre_mode(genre_id: str, mode: str) -> dict | None:
    """Generate MIDI sequences for a specific genre + mode combination."""
    genre_instructions = GENRE_INSTRUCTIONS.get(genre_id)
    mode_override = MODE_OVERRIDES.get(mode)
    if not genre_instructions or not mode_override:
        return None

    system_prompt = f"""You are an expert music composer generating MIDI note data for a therapeutic audio app called BioNaural.

{genre_instructions}

MODE: {mode.upper()}
Tempo: {mode_override['tempo_range']}
Character: {mode_override['character']}
Maximum velocity: {mode_override['velocity_cap']}

CRITICAL REQUIREMENTS:
1. ALL tracks must be in the SAME key and scale
2. ALL tracks must be at the SAME tempo
3. Bass notes must follow the chord progression roots
4. Melody must use notes from the specified scale only
5. Drums (if included) must lock to the tempo grid
6. Generate 30-60 seconds of music
7. Create AUTHENTIC {genre_id} music adapted for {mode} purpose
8. Notes must have realistic timing — not all on the grid, slight humanization
9. Chord voicings should be genre-appropriate (not just root position triads)
10. Include musical phrases that repeat with variation (not random notes)"""

    user_prompt = f"""Compose a {genre_id} track for {mode} mode. Use the compose_tracks tool to output the MIDI data.

The music should be authentically {genre_id} in style but adapted for the {mode} therapeutic purpose. Include:
- A melodic part with repeating phrases and gentle variation
- A bass line that follows the chord roots
- Sustained chord pads for harmonic foundation
{'- Appropriate drum/percussion pattern' if mode in ('focus', 'energize') else '- NO drums (this is for ' + mode + ')'}
{'- Optional texture/ambient layer' if mode in ('sleep', 'relaxation') else ''}

Make it sound like real music — coherent phrases, proper voice leading, genre-authentic rhythms and articulation."""

    try:
        response = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=8000,
            system=system_prompt,
            tools=[COMPOSE_TOOL],
            tool_choice={"type": "tool", "name": "compose_tracks"},
            messages=[{"role": "user", "content": user_prompt}],
        )

        # Extract tool use result
        for block in response.content:
            if block.type == "tool_use" and block.name == "compose_tracks":
                result = block.input

                # Validate and sanitize
                for track in result.get("tracks", []):
                    for note in track.get("notes", []):
                        note["note"] = max(0, min(127, note.get("note", 60)))
                        note["velocity"] = max(1, min(127, note.get("velocity", 60)))
                        note["startTime"] = max(0, note.get("startTime", 0))
                        note["duration"] = max(0.05, note.get("duration", 1))

                return {
                    "genre": genre_id,
                    "mode": mode,
                    "tracks": result.get("tracks", []),
                    "key": result.get("key", "C"),
                    "bpm": result.get("bpm", 80),
                    "scale": result.get("scale", "pentatonic"),
                }

    except Exception as e:
        print(f"  ERROR: {e}", file=sys.stderr)
        return None

    return None


def main():
    output_dir = Path(__file__).parent / "output"
    output_dir.mkdir(exist_ok=True)

    genres = list(GENRE_INSTRUCTIONS.keys())
    modes = list(MODE_OVERRIDES.keys())

    print(f"Generating MIDI for {len(genres)} genres × {len(modes)} modes = {len(genres) * len(modes)} combinations")
    print(f"Estimated cost: ~$3-8 (one-time)")
    print()

    all_sequences = []

    for genre in genres:
        for mode in modes:
            print(f"  Generating: {genre} × {mode}...", end=" ", flush=True)
            result = generate_midi_for_genre_mode(genre, mode)

            if result:
                all_sequences.append(result)
                track_count = len(result.get("tracks", []))
                note_count = sum(len(t.get("notes", [])) for t in result.get("tracks", []))
                print(f"OK — {track_count} tracks, {note_count} notes, {result['bpm']} BPM, key={result['key']}")

                # Save individual file
                fname = f"{genre}_{mode}.json"
                with open(output_dir / fname, "w") as f:
                    json.dump(result, f, indent=2)
            else:
                print("FAILED")

    # Save combined file for iOS app bundle
    combined_path = output_dir / "midi_sequences.json"
    with open(combined_path, "w") as f:
        json.dump({"sequences": all_sequences, "version": "1.0"}, f)

    print(f"\nGenerated {len(all_sequences)} sequences")
    print(f"Combined file: {combined_path}")
    print(f"Individual files: {output_dir}/")


if __name__ == "__main__":
    main()
