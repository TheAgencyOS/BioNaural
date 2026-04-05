# BioNaural — Sound Asset Pipeline

> How ambient audio beds are sourced, processed, and managed. The binaural beats are synthesized — the ambient layer needs real audio.

---

## What's Synthesized vs. What's Bundled

| Layer | Method | Why |
|-------|--------|-----|
| Binaural beat carrier | Real-time synthesis (AVAudioSourceNode) | Must adapt in real-time to biometrics. Cannot be pre-recorded. |
| Harmonic overtones | Real-time synthesis | Part of the carrier, must track frequency changes |
| LFO amplitude modulation | Real-time synthesis | Organic breathing quality |
| **Ambient beds (nature sounds)** | **Bundled audio files** | **Too complex to synthesize convincingly. Rain, ocean, forest need real recordings.** |
| **Noise layers (pink/brown)** | **Either** — can synthesize or bundle | Synthesized noise is perfectly adequate. Bundle if you want specific "flavored" noise. |
| Ambient pads/drones | Either — synthesize for variety, bundle for quality | Bundled pads sound more musical. Synthesized pads offer infinite variety. |

---

## Ambient Bed Requirements

### Per Mode

| Mode | Required Beds (Launch) | Character |
|------|----------------------|-----------|
| **Focus** | 3 minimum | Steady, non-distracting. Subtle nature or abstract. No birdsong (too unpredictable). |
| **Relaxation** | 3 minimum | Warm, water-forward. Flowing stream, gentle rain, soft wind. |
| **Sleep** | 3 minimum | Very dark, enveloping. Deep rain, distant ocean, minimal/silence option. |
| **Shared** | 1 "Silence" option per mode | Just the binaural beats, no ambient layer |

**Launch total: 10 ambient beds** (3 per mode + 1 silence option).

### Audio Specs

| Parameter | Spec | Why |
|-----------|------|-----|
| Format | AAC (.m4a) at 256 kbps | Good quality, small file size, native iOS decoding |
| Sample rate | 44100 Hz | Match the audio engine's synthesis rate. Avoids resampling. |
| Channels | Stereo | Some beds have subtle stereo movement |
| Duration | **Prime-number seconds** (37s, 61s, 97s, 127s) | Prevents audible loop points when multiple layers overlap |
| Loop point | Seamless crossfade (last 2s fade into first 2s) | No audible seam on repeat |
| Loudness | Normalized to -14 LUFS (integrated) | Consistent perceived volume across beds |
| High-pass | 35 Hz | Remove sub-bass rumble that causes headphone driver strain |
| Low-pass | 12 kHz | Remove hiss/artifacts above the useful range |
| File size target | < 3 MB per bed | 10 beds × 3 MB = 30 MB. Acceptable for app bundle. |

### Total Bundle Size Budget

| Component | Size |
|-----------|------|
| Ambient beds (10 × ~3 MB) | ~30 MB |
| Melodic loops (30-50 × ~1-2 MB) — see Tech-MelodicLayer.md | ~50-80 MB |
| Satoshi font (variable, 1 file) | ~200 KB |
| App binary + assets | ~10 MB |
| **Total app bundle** | **~100-130 MB** |

Under 200 MB avoids the cellular download warning. 100-130 MB is acceptable for a premium audio app (Calm is ~200 MB, Headspace is ~150 MB). Melodic loops are the largest component — optimize by using shorter loop lengths and higher compression if needed.

---

## Sourcing Strategy

### Option 1: Royalty-Free Libraries (Recommended for Launch)

| Source | License | Quality | Cost |
|--------|---------|---------|------|
| **Freesound.org** | CC0 / CC-BY (varies per file) | Variable — needs curation | Free |
| **Pixabay Audio** | Pixabay License (free commercial use) | Good | Free |
| **Artlist** | Unlimited commercial license | High | ~$200/yr |
| **Epidemic Sound** | Commercial license | High | ~$150/yr |
| **Splice Sounds** | Per-sample license | High | ~$10-30/mo |

**Recommended approach:** Start with Freesound (CC0 only — no attribution required) and Pixabay for launch. Upgrade to Artlist or Epidemic Sound if quality isn't sufficient.

**License rules:**
- Only use CC0 (public domain) or explicit commercial-use licenses
- Keep a license log: file name, source URL, license type, download date
- Never use Creative Commons NC (non-commercial) — BioNaural is a paid product
- Never use content that requires share-alike (CC-SA) — complicates distribution

### Option 2: Commission Custom Recordings

For v1.1+, commission a sound designer to create bespoke ambient beds:
- Cost: $500-$2000 for a set of 10 custom beds
- Advantage: unique to BioNaural, no licensing concerns, perfect character
- Find on: Fiverr (budget), SoundBetter (mid-range), direct outreach to ambient musicians

### Option 3: Field Recording (DIY)

Record your own nature sounds with a portable recorder (Zoom H5, ~$250):
- Rain: record under a covered porch during rain
- Stream: find a creek, record 10 minutes
- Ocean: beach with low wind
- Advantage: truly original, no licensing
- Disadvantage: requires good recording technique, post-processing skill

---

## Processing Pipeline

For every ambient bed, regardless of source:

```
1. Import raw audio
2. Trim to target duration (prime-number seconds)
3. High-pass filter at 35 Hz (remove sub-bass)
4. Low-pass filter at 12 kHz (remove hiss)
5. Normalize to -14 LUFS (integrated loudness)
6. Create seamless loop (2-second crossfade at loop point)
7. Export as AAC 256 kbps, 44100 Hz, stereo
8. Verify: play on loop for 10 minutes — listen for:
   - Audible loop seam (fix crossfade)
   - Annoying repeating patterns (use longer duration or different source)
   - Harshness or fatigue (adjust EQ)
   - Level inconsistency with other beds (re-normalize)
9. Name: mode_bedname_duration.m4a (e.g., focus_softrain_61s.m4a)
10. Add to license log
```

**Tools:** Audacity (free), Logic Pro, or Adobe Audition.

---

## Runtime Audio Management

### Loading Strategy

Don't load all beds into memory at once. Load the selected bed when the user picks a mode:

```swift
// AVAudioPlayerNode with file-based playback
let file = try AVAudioFile(forReading: bedURL)
playerNode.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) {
    // Schedule again for seamless loop
    playerNode.scheduleFile(file, at: nil) // ...
}
```

### Crossfading Between Beds

If the user changes ambient sound mid-session:
- Fade out current bed over 3 seconds
- Fade in new bed over 3 seconds
- Overlap the fades for a smooth transition
- Use two `AVAudioPlayerNode` instances (A/B) for crossfading

### Volume Hierarchy

| Layer | Relative Level | User Adjustable? |
|-------|---------------|-----------------|
| Ambient bed | 0 dB (reference, loudest) | Yes — "Ambient" slider |
| Binaural carrier | -6 to -12 dB below ambient | Yes — "Beats" slider |
| Noise layer (if used) | -10 to -6 dB | Tied to ambient slider |

The binaural carrier should be **felt more than heard**. If the user cranks the beats slider up, they hear more wobble. If they turn it down, the beats become subliminal.

---

## Naming Convention

```
{mode}_{description}_{duration}s.m4a

Examples:
focus_softrain_61s.m4a
focus_whitespace_97s.m4a
focus_minimal_37s.m4a
relax_stream_127s.m4a
relax_gentlewind_61s.m4a
relax_warmpad_97s.m4a
sleep_deeprain_127s.m4a
sleep_ocean_97s.m4a
sleep_nightforest_61s.m4a
silence_none_1s.m4a  (1 second of silence, looped)
```

---

## Launch Ambient Beds (Proposed Set)

| Mode | Bed 1 | Bed 2 | Bed 3 |
|------|-------|-------|-------|
| Focus | Soft rain (steady, no thunder) | White space (filtered pink noise, very subtle) | Minimal (almost silence, faint pad) |
| Relaxation | Flowing stream (water-forward) | Gentle wind through trees | Warm ambient pad (synthesized, slow filter modulation) |
| Sleep | Deep rain (heavy, low-passed, enveloping) | Distant ocean (slow waves, very dark) | Night forest (crickets, distant, sparse) |

Plus 1 "None/Silence" option available in every mode.
