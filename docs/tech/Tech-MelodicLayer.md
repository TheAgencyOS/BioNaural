# BioNaural — The Melodic Layer (Third Audio Layer)

> Binaural beats are the science. Ambient is the texture. The melodic layer is why people fall in love with the app.

---

## Three-Layer Audio Architecture

| Layer | What | How Generated | Adapts To |
|-------|------|-------------|-----------|
| **Binaural** | The Hz frequency (e.g., 10 Hz theta beat) | Real-time synthesis (AVAudioSourceNode) | Biometrics (HR/HRV → frequency mapping) |
| **Ambient** | Texture bed (rain, noise, wind, silence) | Bundled files or synthesized noise | Mode selection + user preference |
| **Melodic** | Musical content (pads, piano, strings, bass, gentle percussion) | AI-curated from sound libraries, selected/mixed based on biometrics + user profile | Biometrics + user taste + learned outcomes |

The melodic layer is the experience layer. Users don't fall in love with a 10 Hz sine wave. They fall in love with the soft piano over forest sounds that always puts them to sleep.

---

## How the Melodic Layer Works

### Sound Library Architecture

The melodic layer draws from a **tagged library of musical loops and samples:**

```
Sound Library
├── Loops (2-8 bars, seamless)
│   ├── Pads (warm synth sustains, evolving textures)
│   ├── Piano (gentle, sparse, arrhythmic or slow tempo)
│   ├── Strings (sustained, legato, cello/viola)
│   ├── Guitar (ambient, clean, reverbed)
│   ├── Bass (sub-bass drones, gentle pulses)
│   └── Percussion (very soft — brush sounds, distant chimes, singing bowls)
├── One-Shots (single hits, used sparingly)
│   ├── Bells / Chimes
│   ├── Bowl strikes
│   └── Soft transients
└── Textures (long-form, evolving)
    ├── Granular clouds
    ├── Tape warble / vinyl warmth
    └── Harmonic drones
```

### Tagging System

Every sound in the library is tagged with metadata:

| Tag | Values | Purpose |
|-----|--------|---------|
| `energy` | 0.0-1.0 | How activating vs. calming (0 = deep sleep, 1 = high focus) |
| `tempo` | BPM or "free" | Rhythmic pace. "Free" = arrhythmic/ambient. |
| `key` | C, D, E, F, G, A, B + major/minor/modal | Musical key for harmonic compatibility |
| `scale` | pentatonic, whole-tone, major, minor, dorian | Scale type. Pentatonic and whole-tone = perpetually resolving, no tension. |
| `instrument` | pad, piano, strings, guitar, bass, percussion, texture | Primary instrument family |
| `brightness` | 0.0-1.0 | Spectral brightness (0 = very dark/filtered, 1 = bright/present) |
| `density` | 0.0-1.0 | How many notes/events per bar (0 = sparse, 1 = dense) |
| `mode_affinity` | [focus, relaxation, sleep] | Which modes this sound works for |
| `duration` | seconds | Loop length (prime numbers for non-repeating overlap) |

### Selection Logic: Rules + ML

**Layer 1 — Rules (v1, ships at launch):**

```
IF mode == .sleep AND biometric_state == .calm:
    SELECT sounds WHERE:
        energy < 0.3
        brightness < 0.4
        density < 0.3
        mode_affinity CONTAINS .sleep
        scale IN [pentatonic, whole_tone]
    SORT BY energy ASC
    PICK top 2-3 compatible sounds (key-matched)

IF mode == .focus AND biometric_state == .elevated:
    SELECT sounds WHERE:
        energy BETWEEN 0.3 AND 0.6
        brightness BETWEEN 0.3 AND 0.6
        mode_affinity CONTAINS .focus
    SORT BY energy matching current HR_normalized
    PICK top 2-3

IF mode == .relaxation AND HR_trend == .falling:
    SELECT sounds WHERE:
        energy < 0.4
        brightness < 0.5
        density < 0.4
        mode_affinity CONTAINS .relaxation
    MAINTAIN current selection (don't change while user is settling)
```

**Layer 2 — User Preferences (v1):**

User profile stores explicit preferences:
- Preferred instruments (piano? pads? nature-forward? musical?)
- Energy preference per mode (some people want more musical focus, others want near-silence)
- Collected from onboarding ("What sounds appeal to you?") and thumbs up/down over time

Rules filter the library. User preferences rank within that filtered set.

**Layer 3 — Learned Outcomes (v1.5+, ML):**

After 10-20 sessions with feedback data:
- Contextual bandit or collaborative filtering on Core ML
- Input: user profile + current biometric state + time of day + mode
- Output: ranked sound selections predicted to produce best biometric outcomes
- Training signal: biometric success (did HR drop? did HRV improve? did they fall asleep?) + thumbs rating

---

## Biometric-Driven Sound Adaptation

The melodic layer doesn't just play static loops. It adapts during the session:

### What Changes Based on Biometrics

| Biometric Signal | Melodic Response |
|-----------------|-----------------|
| HR dropping (calming) | Maintain current sounds. If already calm, reduce density (fewer notes). |
| HR rising (stress/activation) | Shift to lower-energy sounds. Reduce tempo. Filter to darker/warmer. |
| HRV improving | Deepen — introduce softer, more spacious elements. |
| HRV declining | Simplify — reduce layers, increase space between notes. |
| Sleep onset detected | Fade melodic layer to near-silence. Let ambient + binaural carry. |
| Sustained stillness (deep focus/relaxation) | Don't change anything. The worst thing to do in a deep state is introduce novelty. |

### Transition Rules

- **Never abruptly switch sounds mid-session.** Crossfade over 10-30 seconds.
- **Don't change more than one element at a time.** If swapping a pad, keep the piano. If changing piano, keep the pad.
- **Biometric-driven changes happen at most every 3-5 minutes.** More frequent = distracting.
- **The user's deep state is sacred.** If biometrics indicate deep focus/relaxation/sleep approach, HOLD everything steady. Don't optimize — maintain.

---

## Sound Selection by Mode

### Focus Mode

| Parameter | Value | Why |
|-----------|-------|-----|
| Energy | 0.3-0.5 (moderate) | Enough presence to mask distractions, not enough to distract |
| Tempo | 60-90 BPM or free | Slow enough to not drive rhythm, fast enough to feel alive |
| Scale | Pentatonic, major, dorian | No tension/resolution cycles that demand attention |
| Instruments | Pads, piano (sparse), light texture | Familiar, non-novel |
| Brightness | 0.3-0.5 | Present but not piercing |
| Density | 0.2-0.4 | Sparse. Long silences between notes. |

### Relaxation Mode

| Parameter | Value | Why |
|-----------|-------|-----|
| Energy | 0.1-0.3 (low) | Calming, not engaging |
| Tempo | 40-70 BPM or free | Slower than focus. Approaching stillness. |
| Scale | Pentatonic, whole-tone | Perpetually resolving. No tension. |
| Instruments | Pads (primary), strings, gentle piano | Warm, enveloping |
| Brightness | 0.2-0.4 | Darker than focus |
| Density | 0.1-0.3 | Very sparse. Mostly sustains and drones. |

### Sleep Mode

| Parameter | Value | Why |
|-----------|-------|-----|
| Energy | 0.0-0.2 (very low) | Barely there. Approaching silence. |
| Tempo | Free / arrhythmic | No pulse. Nothing to track. |
| Scale | Whole-tone, modal | Dreamlike, unresolved but not tense |
| Instruments | Deep pads, sub-bass drones, distant textures | Felt more than heard |
| Brightness | 0.0-0.2 | Very dark. Heavily filtered. |
| Density | 0.0-0.1 | Almost nothing. Single sustained notes with long silences. |
| Volume arc | Fades toward silence over session duration | Melodic layer should be nearly gone by sleep onset |

---

## Sound Library Sourcing Strategy

### v1 Launch: Bundled Library (30-50 Loops)

| Source | License | Quality | Cost |
|--------|---------|---------|------|
| **Freesound.org** (CC0 only) | Public domain | Variable | Free |
| **Pixabay Music** | Pixabay License | Good | Free |
| **Looperman** | Royalty-free loops | Variable | Free |
| **Splice** | Per-sample commercial license | High | $10-30/mo |
| **Custom commission** | Work-for-hire, full ownership | Highest | $500-2000 |

**Target:** 30-50 loops at launch, tagged and processed:
- 10-15 for Focus (pads, piano, light textures)
- 10-15 for Relaxation (warm pads, strings, gentle piano)
- 10-15 for Sleep (deep drones, sub-bass, distant textures)

**Each loop:**
- AAC 256kbps, 44100 Hz, stereo
- 8-30 seconds (prime number durations for non-repeating overlap)
- Seamless loop point (2s crossfade)
- Normalized to -18 LUFS (quieter than ambient bed — melodic sits underneath)
- Tagged with full metadata (energy, tempo, key, scale, instrument, brightness, density)

**Bundle size:** 30-50 loops × ~1-2 MB each = ~50-80 MB. Combined with ambient beds (~30 MB), total audio assets ~80-110 MB. Acceptable.

### v1.5+: Expanded Library (Streaming/Download)

- Host additional loops on CDN (CloudKit or S3)
- Download packs by genre/mood (user chooses, or app suggests based on profile)
- 200-500 total loops
- Optional: partner with ambient musicians for exclusive content (the Endel/Calm playbook)

### v2+: Generative Elements

- Use Apple's `AVAudioUnitSampler` or `AUSampler` to play MIDI-driven generative melodies through sampled instruments
- Algorithm composes simple, sparse melodic patterns (pentatonic, 2-4 notes, slow tempo) using rules
- Not full AI music generation (AudioCraft is too heavy) — just rule-based MIDI generation through quality samples
- This gives infinite variety with small file size (MIDI + samples vs. pre-rendered audio)

---

## User Preference Profiling

### Onboarding (First Launch)

After mode selection, before first session:

> "What kind of sounds do you prefer?"
>
> [Nature-forward] — streams, rain, wind, birdsong
> [Musical] — piano, pads, strings, ambient
> [Minimal] — as little as possible, mostly silence
> [Mix of everything]

This sets the initial melodic layer weight:
- Nature-forward: ambient layer dominant, melodic layer quiet
- Musical: melodic layer prominent, ambient layer as texture
- Minimal: both layers very quiet, binaural beats forward
- Mix: balanced

### Ongoing Learning

| Signal | What It Tells Us | How We Use It |
|--------|-----------------|---------------|
| Thumbs up | User likes this sound combination | Increase weight for these tags in future selections |
| Thumbs down | User dislikes this | Decrease weight, avoid similar tag combinations |
| Skip (if we add it) | Not offensive but not right | Slight decrease, try alternatives |
| Biometric improvement | This sound objectively helped | Strong positive signal — prioritize for this user in similar states |
| Biometric neutral | No measurable effect | Weak signal — maintain current weight |
| Biometric worsened | This sound made things worse | Strong negative — avoid for this user in this state |

**The biometric signal is more reliable than thumbs.** Someone might thumbs-up a sound they enjoy but that doesn't actually calm them. The biometrics don't lie.

### Profile Storage

```swift
struct SoundProfile {
    var preferredInstruments: [Instrument: Double]  // weight 0-1 per instrument
    var energyPreference: [FocusMode: Double]       // preferred energy level per mode
    var brightnessPreference: Double                 // global brightness preference
    var densityPreference: Double                    // global density preference
    var successfulSounds: [SoundID: SuccessRecord]   // sounds that produced good outcomes
    var dislikedSounds: Set<SoundID>                 // thumbs-downed
}
```

Stored in SwiftData. Updated after every session.

---

## Mixing Architecture (Three Layers)

```
AVAudioSourceNode (Binaural Beat Generator)
    ↓
AVAudioMixerNode (binaural submix — volume controlled by adaptive engine)
    ↓
AVAudioPlayerNode (Ambient Bed — nature/noise loop)         ──┐
    ↓                                                         │
AVAudioMixerNode (ambient submix)                             ├──→ AVAudioMixerNode (master)
    ↓                                                         │         ↓
AVAudioPlayerNode (Melodic Layer — loop A)                    │    AVAudioUnitReverb
AVAudioPlayerNode (Melodic Layer — loop B, for crossfading)  ──┘         ↓
    ↓                                                              AVAudioOutputNode
AVAudioMixerNode (melodic submix — volume + crossfade control)
```

**Volume hierarchy (default):**

| Layer | Level | User Adjustable? |
|-------|-------|-----------------|
| Ambient bed | 0 dB (reference) | Yes — "Ambient" slider |
| Melodic layer | -6 to -3 dB | Yes — "Melodic" slider |
| Binaural carrier | -12 to -6 dB | Yes — "Beats" slider |

**The binaural layer should always be the quietest.** It's felt, not heard. The melodic layer is what the user consciously experiences. The ambient layer is the foundation.

---

## Transition Logic During Sessions

### When Biometrics Trigger a Melodic Change

1. **Evaluate:** Every 3-5 minutes, compare current biometric state to the sound profile's optimal parameters
2. **Select:** If current sounds are mismatched (e.g., energy too high for a calming state), pick a better alternative from the library
3. **Crossfade:** Fade out the departing loop on Player A over 10-15 seconds. Fade in the arriving loop on Player B. The two overlap.
4. **Log:** Record the change as an adaptation event (for the adaptation map and training data)
5. **Respect deep states:** If the user has been in a deep state for 5+ minutes, DO NOT change sounds. Stability is more valuable than optimization.

### Key Constraint

**The melodic layer changes SLOWER than the binaural layer.** The binaural frequency adjusts every few seconds (imperceptibly). The melodic selection changes at most every 3-5 minutes, with 10-15 second crossfades. This feels like natural musical evolution, not a DJ switching tracks.

---

## What This Means for the Product

1. **The melodic layer is what people remember.** "That soft piano track that always helps me sleep" — that's the hook. That's what they tell friends about.
2. **The learning loop is the moat.** After 50 sessions, the app knows which sounds → which outcomes for this specific person. Switching to a competitor = starting from zero.
3. **The binaural beats are invisible infrastructure.** Important, scientifically grounded, but not what the user falls in love with.
4. **Three sliders give the user control without complexity:** Ambient, Melodic, Beats. Most users leave them at defaults. Power users dial in their preference.
