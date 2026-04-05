# Tech: Energize Sound Design

> Complete sound design specification for the Energize mode's three audio layers.
> Everything here differs from Focus/Relaxation/Sleep by design.

---

## Design Philosophy

Energize is the **sonic opposite of Focus** in almost every dimension. Where Focus removes stimulation, Energize adds controlled stimulation.

| Property | Focus Mode | Energize Mode |
|---|---|---|
| Spectral content | Narrow, smooth | Broad, textured |
| Temporal pattern | Steady, predictable | Intermittent micro-events |
| Presence (2-5 kHz) | Attenuated | Boosted |
| Sub-bass | Minimal | Pulsing, 40-60 Hz |
| Spatial imaging | Centered, static | Wide stereo, movement |
| Dynamic range | Compressed | Wider, with gentle peaks |
| Social cues | Absent | Present (crowd murmur, voices) |

---

## Layer 1: Binaural / Isochronic Beats

### Beat Frequencies
- Primary: High beta 18-25 Hz
- Gamma accents: 30 Hz touches (10-15 sec, not sustained)
- Cool-down: Ramp to 12 Hz alpha

### Carrier Frequencies
- Range: 400-600 Hz
- Gamma presets: Bias toward 400-500 Hz (preserves perception at 30+ Hz beats)
- Character: Brighter and more alert-feeling than Focus (300-450 Hz)

### Synthesis Enhancements
Same as existing modes plus:
- Harmonic layering (-6 dB/octave for triangle wave character)
- LFO amplitude modulation (2-3 irrational-frequency LFOs)
- Consider isochronic tones as primary for beta/gamma (stronger cortical entrainment above 25 Hz)
- Monaural beat fallback at gamma frequencies where binaural perception fades

---

## Layer 2: Ambient Sound Beds

### Sonic Palette: "Eventful and Pleasant"

The ISO 12913 soundscape framework maps environments on pleasant/annoying × eventful/uneventful axes. Energize needs the **upper-right quadrant**: eventful and pleasant.

### Recommended Environments

| Environment | Why It Works | Energy Level |
|---|---|---|
| **Cafe bustle** | Broadband noise + frequent micro-events, prevents habituation | High |
| **Dawn birdsong** | High species diversity, rapid overlapping calls = high temporal variability | Medium-High |
| **Rushing water** (rapids, mountain streams) | Continuous broadband with chaotic micro-fluctuations | Medium-High |
| **Morning city streets** | Footsteps, distant traffic, social energy | Medium |
| **Rhythmic mechanical** (train on tracks, printing press) | Tempo entrainment without erratic stress | Medium |

### Environments to Avoid
- Ocean waves (slow 0.1 Hz amplitude modulation → relaxation)
- Steady rain (predictable → calming)
- Isolated nature loops (too still)
- Close thunder (cortisol spike)

### Technical Specs (Same Pipeline as Existing Beds)
- Format: AAC 256kbps, 44100 Hz
- Duration: Prime-number-second lengths for non-repeating overlap
- Normalization: -14 LUFS
- Seamless 2-second crossfade loops
- Launch requirement: 3 Energize-specific beds + silence option

---

## Layer 3: Melodic Layer

### Creative Brief: "Texture Over Melody, Repetition Over Development"

Energize melodic content must feel forward-moving and motivating without becoming distracting.

### Instruments
| Instrument | Role | Priority |
|---|---|---|
| **Synth arpeggios** | Forward momentum, loop-friendly | Primary |
| **Light percussion** (shakers, sidestick, soft kick) | Arousal without demanding attention | Primary |
| **Marimba / vibraphone** | Percussive + melodic middle ground | Secondary |
| **Muted plucked strings** | Texture | Secondary |
| **Brass stabs/pads** | Brightness in small doses | Accent only |

### Musical Parameters
| Parameter | Energize Spec | Focus Comparison |
|---|---|---|
| **Tempo** | 120-130 BPM | No pulse / very slow |
| **Key** | D major, E major | Ambiguous / modal |
| **Mode** | Major, Lydian (raised 4th = lift), Mixolydian | Dorian, modal |
| **Rhythm** | Steady 16th-note subdivisions, syncopation | None |
| **Melodic motion** | Rising phrases, wide intervals (4ths, 5ths) | Sparse, static |
| **Dynamic range** | Gradual ramps, no spikes | Flat |

### Biometric-Driven Adaptation
- **Variable: Layer density** (add/remove rhythmic/textural layers based on biometric state)
- This keeps transitions seamless vs changing tempo or key
- More layers = more stimulation; fewer layers = backing off
- Change rate: Every 3-5 minutes with 10-15s crossfades (same as existing modes)

### Balance
- Rhythm > melody for arousal (Van Dyck et al., 2015: bass-frequency rhythm is the strongest driver of body movement)
- Mid-frequency emphasis: 200 Hz - 4 kHz carries energy clearly
- Avoid deep sub-bass (sedating) and sharp high-frequency transients (startling)

---

## The Dopamine Problem

Binaural beats alone cannot reliably trigger dopamine release. Music does (Salimpoor et al., 2011) — through anticipation/resolution cycles.

**The melodic layer is therefore essential, not optional, for Energize.** It provides the musical structure (groove, syncopation, harmonic resolution) that engages the mesolimbic reward pathway. The three-layer architecture is what makes Energize work — beats for cortical arousal, melody for dopaminergic motivation, ambients for environmental context.

---

## Optional: Breath-Pacing Audio Layer

An opt-in rhythmic element that paces energizing breathwork:
- Active phase: Percussive elements accelerating through 1-2 exhales/second
- Hold phase: Sustained tone
- Recovery phase: Slower tones transitioning to alpha

**Safety:** Must be opt-in, seated/lying position recommended, clear warnings for epilepsy/cardiac/panic conditions. Watch confirms sympathetic activation during active phase and safe recovery before prompting another round.

---

## Sound Sourcing for Launch

| Need | Count | Source |
|---|---|---|
| Ambient beds | 3 + silence | Freesound (CC0), Pixabay, commission for v1.1 |
| Melodic loops | 10-15 | Commission (must match tempo/key specs) |
| Total additional bundle size | ~30-40 MB | AAC 256kbps |

Tags per loop: energy, tempo, key, scale, instrument, brightness, density, rhythmic_intensity (extending existing metadata schema).
