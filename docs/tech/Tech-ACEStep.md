# BioNaural — ACE-Step Strategy

## Decision: ACE-Step is v1.5, not v1

ACE-Step generates beautiful static audio loops — but they can't respond to a heart rate spike at the note level. SF2Lib + GenerativeMIDIEngine can. When a user's HR jumps during Focus mode, the generative engine instantly thins out notes, shifts register, and slows phrase density. With ACE-Step loops, all you can do is crossfade to a different file — the same approach every competitor uses.

**The moat is biometric adaptation, not audio production quality.**

---

## What ACE-Step Is

A latent diffusion transformer for music generation. Apache 2.0 license. ~1.2-1.5B parameters. Takes text prompts, outputs stereo audio at 44.1kHz.

| Field | Value |
|-------|-------|
| **URL** | https://github.com/ace-step/ACE-Step |
| **License** | Apache 2.0 — fully commercial |
| **Input** | Text prompts ("ambient pad, 60 BPM, C major, calm") |
| **Output** | 44.1kHz stereo WAV, up to ~3 minutes |
| **Quality** | Good for ambient/textural content. Pads and drones are a strength. |
| **Generation time** | 15-45 sec for 30-sec clip on RTX 4090 |

---

## Why NOT v1

| Problem | Detail |
|---------|--------|
| **No note-level adaptation** | Pre-generated loops are static. Can only swap between files. |
| **Same as every competitor** | Endel, Brain.fm, Calm all use curated content with intelligent selection. That's exactly what ACE-Step loops give you. |
| **Server dependency** | Real-time generation requires GPU server. Pre-generation needs a pipeline. Both add cost and complexity before product-market fit is validated. |
| **The melodic layer is background** | It sits at -6 to -3 dB below the ambient bed. Users aren't critically listening. They're trying to focus or sleep. |

## Why v1.5

After v1 launches with SF2Lib generative MIDI, real user data will tell us:
1. Do users want richer audio textures? (feedback + retention metrics)
2. Which modes benefit most from produced audio? (session completion rates)
3. What prompts produce the best biometric outcomes? (v1 feedback logging)

---

## v1 Stack (Shipping)

```
ScaleMapper (Tonic) → valid pitches for mode + biometric state
    ↓
GenerativeMIDIEngine → note events (pitch, velocity, timing, duration)
    ↓
SF2MelodicRenderer → AVAudioUnitSampler (SF2 SoundFont) → submixer → mainMixer
    +
BinauralBeatNode → AVAudioSourceNode (phase accumulators) → reverb → mainMixer
    +
AmbienceLayer → AVAudioPlayerNode (rain, wind, noise) → submixer → mainMixer
```

**Why this works:**
- Note-level biometric adaptation (density, register, velocity respond to HR/HRV in real-time)
- Infinite variety (generative MIDI never repeats)
- ~15MB bundle (2-3 premium SoundFonts vs 200-500MB of loops)
- Zero server cost, 100% offline
- Long reverb + filter modulation transforms "MIDI" into "ambient texture"

---

## v1.5 Stack (ACE-Step Enrichment)

```
ACE-Step (pre-generated) → 50-100 evolving texture loops
    ↓
MelodicLayer A/B crossfade → submixer → mainMixer (as ambient texture bed)
    +
GenerativeMIDIEngine → SF2Lib (as biometric-reactive melodic accents on top)
    +
BinauralBeatNode + AmbienceLayer (unchanged)
```

**Two generative layers, two roles:**
- ACE-Step provides rich, organic sonic beds (long evolving drones, granular clouds, harmonic textures)
- SF2Lib provides the adaptive melodic accents (individual notes/phrases that respond to biometrics)
- ACE-Step handles atmosphere. SF2Lib handles adaptation.

---

## ACE-Step v1.5 Implementation Plan

### Pre-Generation Pipeline (Before v1.5 Ships)

1. Use v1 session data to understand which modes need richer textures
2. Generate ~500 candidate loops across all 4 modes using ACE-Step on a GPU server
3. Human-curate down to 50-100 high-quality, clean-looping clips
4. Post-process: crossfade loop points, normalize loudness, EQ for layering
5. Tag each with existing SoundMetadata schema (mode, energy, brightness, density, key)

### Prompt Templates

| Mode | Example Prompt |
|------|---------------|
| Focus | "subtle ambient electronic texture, 70 BPM, A minor, steady, minimal, no drums, no vocals" |
| Relaxation | "warm flowing ambient pad, 55 BPM, F major, spacious, gentle, evolving, no rhythm" |
| Sleep | "deep dark ambient drone, 40 BPM, Db major, enveloping, slow, formless, no melody" |
| Energize | "bright shimmering ambient pad, 110 BPM, D Lydian, airy, uplifting, no vocals" |

### Delivery

- Host on CDN, download per-mode on first use (~40-80 MB per mode)
- Or ship as a "Premium Soundscapes" downloadable content pack
- Play through existing MelodicLayer A/B crossfade (already built)
- SoundSelector picks from combined library (bundled + generated + SF2 fallback)

### Cost Estimates

| Item | Cost |
|------|------|
| GPU generation (one-time, ~500 clips) | $15-30 (spot instance) |
| CDN hosting (100 clips, 1K DAU) | $5-15/month |
| Post-processing labor | ~20-40 hours |
| **Total v1.5 launch cost** | **~$50 + labor** |

---

## Biometric-Conditioned Generation (v2+)

The v2 vision: generate loops per-user based on their biometric history.

| Biometric Context | Prompt Parameters |
|-------------------|-------------------|
| HR 55 bpm, high HRV, morning, Focus | "gentle morning ambient pad, 65 BPM, C major, airy, clear" |
| HR 85 bpm, low HRV, afternoon, Focus | "warm calming texture, 50 BPM, Ab major, enveloping, soft" |
| HR 90 bpm, Energize mode | "bright pulsing ambient, 120 BPM, D Lydian, rhythmic shimmer" |

Server generates 5-10 personalized loops after each session batch. Cached locally. Progressive replacement of generic content with personalized content.

**Only viable after:**
1. v1 validates product-market fit
2. v1.5 validates that users want richer textures
3. User model has enough data to meaningfully condition prompts
4. Revenue justifies per-user GPU cost

---

## Competitor Landscape

| App | Audio Approach | Truly Adaptive? |
|-----|---------------|----------------|
| **Endel** | Procedural/rule-based, human-composed elements remixed in real-time | Parametric mixing, not note-level |
| **Brain.fm** | Human-composed + psychoacoustic processing layer | Processing layer adapts, composition doesn't |
| **Calm** | Curated human-composed library | No |
| **Headspace** | Curated human-composed library | No |
| **BioNaural (v1)** | Generative MIDI + SoundFont, biometric-driven at the note level | **Yes — note-level adaptation** |
| **BioNaural (v1.5)** | Above + ACE-Step texture beds | Yes + richer textures |
| **BioNaural (v2)** | Above + per-user biometric-conditioned AI generation | Yes + personalized audio |

No competitor does note-level biometric adaptation. That's the moat.

---

## Alternatives to ACE-Step (Evaluate at v1.5)

| Model | Quality | License | Self-Host | Notes |
|-------|---------|---------|-----------|-------|
| **ACE-Step 1.5** | Good for ambient | Apache 2.0 | Yes | Primary candidate |
| **Stable Audio Open** | Very good for textures | Open | Yes | Test head-to-head with ACE-Step |
| **MusicGen (Meta)** | Decent | MIT | Yes | Smaller model, faster, 30s limit |
| **Suno/Udio** | Excellent | Proprietary | No | Too expensive at scale, can't self-host |

Test ACE-Step and Stable Audio Open head-to-head for ambient content before committing. Stable Audio Open may be better for atmospheric/textural content specifically.
