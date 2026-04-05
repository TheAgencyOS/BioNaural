# SoundSample: Technical Architecture & Feasibility

## Research Date: April 2026

---

## System Architecture

```
┌─────────────────────────────────────────────────┐
│                 CAPTURE PHASE                    │
│                                                  │
│  Mic Input (AVAudioEngine)                       │
│       │                                          │
│       ├──→ ShazamKit Recognition (parallel)      │
│       │         │                                │
│       │    [Match?]──Yes──→ Apple Music metadata  │
│       │         │           (genre, artist)       │
│       │         │                                │
│       │        No──→ genre unknown, rely fully   │
│       │              on on-device analysis        │
│       │                                          │
│       └──→ On-Device MIR Analysis (parallel)     │
│             │                                    │
│             ├── Preprocessing (noise reduction)  │
│             ├── TempoCNN → BPM                   │
│             ├── Essentia Key Model → Key/Scale   │
│             ├── Essentia Mood Models → Mood      │
│             ├── vDSP FFT → Spectral features     │
│             └── YAMNet → "Is this music?"        │
│                                                  │
│       Combine Results → Song Feature Vector      │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│               MAPPING PHASE                      │
│                                                  │
│  Song Features ──→ Binaural Parameters           │
│  + User Goal (focus/relax/create/sleep)          │
│  + Watch Biometrics (HR, HRV)                    │
│                                                  │
│  User goal ALWAYS overrides mood inference       │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│             GENERATION PHASE                     │
│                                                  │
│  AVAudioEngine Graph:                            │
│  ├── AVAudioSourceNode (L carrier freq)          │
│  ├── AVAudioSourceNode (R carrier freq + beat)   │
│  ├── AVAudioSourceNode (ambient pad layer)       │
│  ├── AVAudioMixerNode (mixing + volume)          │
│  └── AVAudioOutputNode (to headphones)           │
└─────────────────────────────────────────────────┘
```

---

## Component-by-Component Feasibility

### Audio Capture from Microphone
| Aspect | Detail |
|---|---|
| **Difficulty** | Trivial |
| **Framework** | AVAudioEngine / AVAudioRecorder |
| **Time estimate** | 1-2 days |
| **Notes** | Standard iOS API. The hard part is everything after capture. |

### BPM / Tempo Detection
| Aspect | Detail |
|---|---|
| **Difficulty** | Hard |
| **Best approach** | Essentia TempoCNN model converted to Core ML, or onset detection + autocorrelation via vDSP |
| **Accuracy (clean audio)** | ~85-90% within +/- 2 BPM |
| **Accuracy (mic capture, preprocessed)** | ~65-75% within +/- 4% BPM |
| **Accuracy (mic capture, raw)** | ~55-65% |
| **Time estimate** | 2-4 weeks for reliable implementation |
| **Key limitation** | Octave errors (60 vs 120 BPM) are the #1 failure mode on short clips. Variable-tempo songs (jazz, classical) are unreliable. |

### Key / Scale Detection
| Aspect | Detail |
|---|---|
| **Difficulty** | Very Hard |
| **Best approach** | Chromagram (HPCP) + Krumhansl-Schmuckler via vDSP, or Essentia key model via Core ML |
| **Accuracy (clean audio)** | ~75-80% exact key |
| **Accuracy (mic capture, preprocessed)** | ~50-60% |
| **Time estimate** | 3-6 weeks |
| **Key limitation** | Graduate-level DSP. 10s clip may only contain 1-2 chord changes. If sample catches a non-tonic section, key is wrong. Ambient/electronic/atonal music returns meaningless results. |
| **Alternative** | Detect current pitch content (chroma) rather than global key — harmonize with what's playing *now*. |

### Mood / Energy Classification
| Aspect | Detail |
|---|---|
| **Difficulty** | Research-project-level (mood), Moderate (energy) |
| **Best approach for energy** | Heuristic from RMS loudness + spectral centroid + onset density + tempo. ~80% reliable even through mic. |
| **Best approach for mood** | Essentia mood models (happy, aggressive, relaxed, sad) converted to Core ML. ROC-AUC ~0.68-0.75 per class on clean audio. |
| **Accuracy (mic capture)** | Energy: ~75-80%. Mood: ~55-65% for 4-class. |
| **Time estimate** | 2-3 months for ML mood. 1-2 weeks for energy heuristic. |
| **Key insight** | Arousal (energy level) is much easier to detect than valence (positive/negative). Start with energy only. |

### Spectral Analysis
| Aspect | Detail |
|---|---|
| **Difficulty** | Moderate — most tractable DSP task |
| **Framework** | Accelerate/vDSP (hardware-optimized FFT) |
| **Features** | Spectral centroid (brightness), bandwidth, rolloff, energy distribution by sub-band, MFCCs |
| **Accuracy** | Deterministic/exact from clean audio. Mic capture shifts centroid down ~5-15% due to room acoustics. |
| **Time estimate** | ~1 week |

### Binaural Beat Generation Engine
| Aspect | Detail |
|---|---|
| **Difficulty** | Moderate-to-Hard |
| **Framework** | AVAudioEngine with AVAudioSourceNode (iOS 13+) |
| **Challenge** | Generating sine waves is trivial. Generating a *soundscape that doesn't sound like garbage* is hard. Needs layering, envelope shaping, ambient textures, crossfading. Pure binaural tones are unpleasant after 30 seconds. |
| **Time estimate** | 4-8 weeks for something people want to listen to |
| **Key insight** | This is as much sound design as engineering. |

### The Mapping Algorithm (Song Features → Binaural Parameters)
| Aspect | Detail |
|---|---|
| **Difficulty** | Very Hard (and underestimated) |
| **Nature** | This is a *design research problem*, not a coding problem |
| **Time estimate** | Months of iteration and user testing |
| **Key insight** | There's no established science here. You're inventing a translation layer between two domains without natural correspondence. |

---

## The Mapping Framework

### Principle: User Goal Overrides Everything

The user selects their intent (focus / relax / create / sleep). Song features influence the *aesthetic* (carrier tone, timbre, modulation feel) but **never** the *functional target* (beat frequency band). This is the single most important design decision.

### BPM → Amplitude Modulation Rate
- Song BPM / 60 = AM rate in Hz (e.g., 120 BPM → 2 Hz modulation pulse)
- Creates subtle rhythmic pulse mirroring the original song's feel
- **Scientific basis:** Plausible but unproven. Rhythmic auditory stimulation at specific rates has some evidence for enhancing entrainment.
- **Risk:** Low. Musical-tempo AM is subtle and generally pleasant.

### Spectral Centroid → Carrier Frequency
- Bright songs (high centroid) → higher carrier (300-450 Hz)
- Dark songs (low centroid) → lower carrier (150-250 Hz)
- **Scientific basis:** Aesthetically motivated, not neuroscientifically. Preserves the "feel" of the original music's tonal character.
- **Risk:** Low. All values in 150-450 Hz are perceptually fine.

### Key / Scale → Harmonic Layering
- Detected tonic → fundamental frequency of ambient pad layers (e.g., A minor → drone in A at 220 Hz)
- Minor keys → add minor third overtone; major keys → major third
- **Scientific basis:** Speculative for neuroscience, strong for UX continuity.
- **Risk:** Moderate. Can create dissonance if carrier and key tones conflict. Need harmonic compatibility check — snap carrier to nearest consonant frequency (octaves, fifths, fourths).

### Energy / Loudness → Beat Intensity & Mix Level
- High-energy songs → more prominent binaural beat relative to ambient layers
- Quiet/dynamic songs → softer beats embedded more deeply in ambient texture
- **Scientific basis:** Plausible. Sub-threshold binaural presentation has some evidence.
- **Risk:** Low-moderate. Cap maximum beat volume at -12 dB relative to ambient.

### Inferred Mood → Target Brainwave Band (OVERRIDDEN BY USER GOAL)
| Inferred Mood | Suggested Band | Beat Frequency |
|---|---|---|
| High energy, happy | Beta | 14-18 Hz |
| Calm, peaceful | Alpha | 8-12 Hz |
| Sad, introspective | Theta-Alpha | 6-10 Hz |
| Intense, aggressive | Low Beta | 12-15 Hz |
| Dreamy, atmospheric | Theta | 4-7 Hz |

**This mapping is the most speculative.** User goal always takes priority. Mood inference only flavors within the user's selected band.

### Hard Safety Bounds (All Parameters)
| Parameter | Min | Max |
|---|---|---|
| Carrier frequency | 150 Hz | 450 Hz |
| Beat frequency | 2 Hz | 40 Hz |
| AM depth | 0% | 60% |
| Beat volume vs. ambient | Always ≥ 6 dB below ambient |

---

## The Microphone Capture Problem

### Why Mic Capture Is Compromised

| Factor | Impact |
|---|---|
| Room reverb (RT60 0.3-0.8s) | Smears transients (hurts beat detection), blurs harmonics (hurts key detection) |
| Background noise | Below ~10 dB SNR, most MIR features unreliable |
| Phone mic frequency response | Flat 100 Hz - 8 kHz, rolloff below 100 Hz (loses bass → hurts key detection), presence boost 2-5 kHz |
| Headphone scenario | **Completely breaks mic capture** — no speaker output to record. Very common use case. |

### Accuracy Degradation Budget

| MIR Task | Clean Audio | Mic (preprocessed) | Mic (raw) |
|---|---|---|---|
| Tempo (±4% BPM) | 85-90% | 65-75% | 55-65% |
| Key detection | 75-80% | 50-60% | 40-50% |
| Mood (4-class) | 70-75% | 55-65% | 45-55% |
| Genre (broad, 5-class) | 80-85% | 65-75% | 55-65% |

### Preprocessing Pipeline (Improves Raw by ~10-15%)
1. Capture at 44.1 kHz / 16-bit via AVAudioEngine
2. High-pass filter at 60-80 Hz (remove rumble/handling noise)
3. Spectral subtraction for noise reduction (estimate noise from first 0.5s)
4. CMVN normalization on MFCCs before classification

### The Smart Workaround: ShazamKit → Apple Music Preview

If ShazamKit identifies the song, download the **Apple Music 30-second preview clip** (AAC, accessible without subscription) and analyze *that* instead of the noisy mic input. This gives you clean, consistent audio for feature extraction.

**This is the recommended primary path.** Mic-based on-device analysis becomes the fallback for unidentified songs.

---

## iOS Frameworks & Tools

### Apple Native Stack

| Framework | Role | MIR Value |
|---|---|---|
| **AVAudioEngine** | Audio capture, routing, playback, synthesis | Essential plumbing. No analysis built in. |
| **SoundAnalysis** | On-device sound classification (~300 categories) | Can confirm "this is music" but no BPM/key/mood. Useful as gate only. |
| **Accelerate / vDSP** | Hardware-optimized FFT, DSP primitives | The real workhorse. Builds spectrograms, chromagrams, onset detection. Microsecond-speed FFT on Apple Silicon. |
| **ShazamKit** | Song identification | Returns title, artist, genre, Apple Music ID. No audio features. |
| **MusicKit** | Apple Music catalog access | Genre, metadata. No BPM, key, mood, energy. |
| **Core ML** | On-device ML inference | Run converted Essentia models for tempo, key, mood. |

### Third-Party Libraries

| Library | Language | MIR Capabilities | iOS Feasibility |
|---|---|---|---|
| **Essentia** | C++ (AGPL) | Full MIR: BPM, key, chroma, spectral, mood models, genre | Compiles for iOS arm64 via CMake. Needs Obj-C++ bridging. 1-2 weeks integration. **AGPL license = must open-source your app OR buy commercial license.** |
| **AudioKit** | Swift (MIT) | FFT tap, pitch tracking, amplitude tracking | Great for audio I/O and basic analysis. No BPM/key/mood out of box. |
| **Essentia TF Models** | TensorFlow → Core ML | TempoCNN, key detection, mood classifiers (happy/aggressive/relaxed/sad), genre, danceability | Convert via coremltools. ~2-5 MB each. <100ms inference on A15+. **Best shortcut for ML features.** |
| **YAMNet** | TF → Core ML | Audio event classification (521 classes) | ~3.7 MB, ~10ms inference. Gate: "is this music?" |
| **TarsosDSP** | Java | N/A | Android only. Not usable on iOS. |
| **librosa** | Python | N/A | Not for iOS. Prototyping only. |

### Recommended Model Stack for iOS

| Model | Task | Size | Inference Time |
|---|---|---|---|
| YAMNet | Music detection gate | ~3.7 MB | ~10ms |
| Essentia TempoCNN | Tempo estimation | ~2-5 MB | ~20ms |
| Essentia Key Model | Key detection | ~2-5 MB | ~20ms |
| Essentia Mood Models (x4) | Mood classification | ~2-5 MB each | ~20ms each |
| vDSP custom | Spectral centroid, MFCCs, energy | 0 MB (built-in) | ~5ms |
| **Total** | | ~15-25 MB | <100ms total |

### Critical API Status

| API | Status (April 2026) |
|---|---|
| **Spotify Audio Features** | **DEPRECATED. Removed for new apps Nov 2024.** This was the best shortcut. No longer available. |
| **Spotify Audio Analysis** | **Also removed.** |
| **Apple Music API** | No audio features. Metadata only. |
| **AcousticBrainz** | **Shut down 2022.** Data dumps still available for pre-computed feature database. |
| **ACRCloud / Gracenote** | Commercial music recognition + features. Not free, but solve identification + extraction in one call. |

---

## MVP Strategy: What to Ship First

### v1.0 MVP (8-12 weeks, solo developer)

**Architecture:** ShazamKit identification → download Apple Music preview → on-device analysis of clean preview → map to pre-designed soundscape templates.

**Skip for MVP:**
- On-device mic audio analysis (use preview clip instead)
- ML-based mood classification (use energy heuristic + genre)
- Procedural soundscape generation (use 15-20 hand-crafted templates)

**Build for MVP:**
- ShazamKit integration + Apple Music preview download
- On-device BPM detection (onset + autocorrelation via vDSP)
- On-device spectral analysis (vDSP FFT → centroid, energy)
- Template-based soundscape engine (15-20 pre-designed templates by a sound designer)
- Basic Watch heart rate integration → adjusts binaural frequency
- UI/UX for capture flow + results + playback

**Template Matrix:**

| | Low Energy | Medium Energy | High Energy |
|---|---|---|---|
| **Major Key** | Template A | Template B | Template C |
| **Minor Key** | Template D | Template E | Template F |

Scale BPM mapping within each template. Sound designer produces these in a few weeks. Result sounds *dramatically* better than procedural generation.

### Iteration Path

| Version | Addition | Timeline |
|---|---|---|
| v1.1 | Add on-device key detection for better template matching | +2-3 weeks |
| v1.2 | Add spectral profile analysis to fine-tune within templates | +1-2 weeks |
| v1.3 | Real-time biometric modulation (soundscape adapts as HR changes) | +2-3 weeks |
| v2.0 | On-device mic analysis fallback for unidentified songs | +4-6 weeks |
| v2.x | ML mood classification, procedural soundscape generation | +3-6 months |

### Production Quality Timeline

| Milestone | Solo Dev Estimate |
|---|---|
| Working prototype | 8-12 weeks |
| App Store ready | 5-7 months |
| Full vision (procedural generation, on-device ML, real-time biometric adaptation) | 12-18 months |

---

## Pre-Computed Feature Database Option

Ship the app with or download a database of pre-analyzed popular tracks (keyed by ISRC or Shazam ID):

- **Source:** AcousticBrainz data dumps (still available, covers millions of tracks with tempo, key, mood, energy)
- **Alternative:** Batch-process top 100K-500K tracks through Essentia yourself
- **Benefit:** If ShazamKit identifies the song and it's in your database, you skip all on-device analysis entirely. Instant results, perfect accuracy.
- **This effectively replaces the dead Spotify Audio Features API with your own data.**

---

## Binaural Synthesis Engine (AVAudioEngine)

### Architecture
```swift
AVAudioEngine
├── AVAudioSourceNode (left channel: carrier freq)
├── AVAudioSourceNode (right channel: carrier freq + beat freq)
├── AVAudioSourceNode (ambient pad layer)
├── AVAudioMixerNode (mixing + volume control)
└── AVAudioOutputNode (to headphones)
```

### Implementation Notes
- **AVAudioSourceNode** (iOS 13+): render callback fills buffers with custom sample data. ~10 lines of code per oscillator for sine wave generation.
- **Phase-continuous oscillators:** Maintain phase accumulator, increment per sample. Ensures click-free audio during parameter changes.
- **Parameter smoothing:** Ramp values over 50-200ms during transitions to avoid clicks/pops.
- **Stereo routing:** Two mono source nodes routed to stereo mixer, or single stereo source filling L/R independently.
- **Ambient layers:** Additive synthesis (simplest), wavetable synthesis (richer), granular synthesis (richest), or pre-recorded loops with crossfading (best quality for MVP).
- **Background audio:** Enable `audio` background mode. AVAudioEngine continues when app is backgrounded.
- **Audio session:** `.playback` category. Binaural beats need exclusive playback — other audio interferes with dichotic presentation.

---

## Safeguards Against Bad Output

1. **User goal always overrides mood inference** — song features flavor the aesthetic, not the functional target
2. **Constrain all parameters to safe, pleasant ranges** (see Hard Safety Bounds above)
3. **Harmonic compatibility check** — verify carrier and harmonic layers are consonant before generating. Snap to nearest compatible frequency.
4. **5-second preview** before committing to a session. Also provides training data for learning preferences.
5. **Fallback presets** — if extraction fails or returns low confidence, fall back to well-tested default soundscape for the selected goal
6. **Beat volume cap** — binaural tone never louder than -12 dB relative to ambient layer
