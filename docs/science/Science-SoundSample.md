# SoundSample: The Science of Music-to-Binaural Mapping

## Research Date: April 2026

---

## What the Science Actually Supports (Honest Assessment)

### Tier 1: Well-Established

**Binaural beats produce a measurable auditory percept.**
When two tones of slightly different frequencies are presented dichotically (one per ear), listeners perceive a beating tone at the difference frequency. This is uncontroversial physics/psychoacoustics.
- Oster, 1973; Licklider et al., 1950

**Music feature extraction from audio is a mature field.**
BPM, key, spectral features, MFCCs — these are well-solved problems with robust open-source tooling (Essentia, librosa, aubio). Apple's frameworks (AVAudioEngine + Accelerate) can handle most of these on-device.

**People focus better with personally chosen music.**
Rausch et al. (2023, Frontiers in Psychology) found that personally chosen music improved focus more than researcher-assigned music, even when the assigned music was "optimized." This is the strongest scientific argument for the SoundSample feature.

**Music tempo affects cognitive performance.**
Bottiroli et al. (2014) found faster tempos improved speed on spatial tasks, slower tempos improved accuracy. Directly supports tempo-aware audio generation.

**Lyrical music impairs focus; instrumental does not.**
Perham & Vizard (2011) found music with lyrics impairs reading comprehension vs. silence, but instrumental music does not. Supports converting lyrical music into instrumental binaural soundscapes.

### Tier 2: Supported with Caveats

**Binaural beats can modulate brainwave activity.**
EEG studies show binaural beat stimulation can produce frequency-following responses (FFR) in some subjects. However:
- Effect sizes are small
- Results are inconsistent across studies
- Many studies have methodological issues (small samples, no proper controls, no blinding)
- A 2023 meta-analysis (Garcia-Argibay et al.) found small but statistically significant effects on anxiety and memory, but noted high heterogeneity
- The most rigorous reviews: "promising but inconclusive"

**Individual differences are large.**
Some people respond strongly to binaural beats; others show no measurable EEG change. Entrainment susceptibility varies significantly between individuals.

**Preferred music activates reward circuits.**
Salimpoor et al. (2011, Nature Neuroscience) demonstrated dopamine release in the nucleus accumbens during peak emotional responses to preferred music. This suggests familiar musical qualities could increase engagement.

### Tier 3: Unproven / Speculative

**That binaural beats tuned to personal musical preferences are more effective.**
No peer-reviewed research on this specific claim. The reasoning chain is:
- Familiar musical qualities → increased engagement/comfort
- → better compliance/longer sessions
- → potentially better outcomes

This is a **UX/compliance argument, not a neuroscience one.** Plausible and reasonable, but not proven.

**That specific musical features should map to specific brainwave targets.**
Entirely a design decision, not a scientific finding. No research shows that a song in D minor should produce different brainwave entrainment than a song in G major.

**That mood-informed brainwave targeting is superior.**
The mood-to-brainwave mapping is the most speculative link. A user sampling aggressive metal might want focus beats for working out OR calming beats to wind down after. Intent cannot be inferred from music alone.

---

## Binaural Beat Parameters: What We Know

### Beat Frequency Bands

| Band | Frequency | Associated State | Evidence Level |
|---|---|---|---|
| Delta | 0.5-4 Hz | Deep sleep, unconscious processes | Moderate (sleep studies) |
| Theta | 4-8 Hz | Meditation, drowsiness, creativity | Moderate (meditation studies) |
| Alpha | 8-13 Hz | Relaxed alertness, calm focus | Moderate-strong (most studied) |
| Low Beta | 13-20 Hz | Active thinking, focus, concentration | Moderate |
| High Beta | 20-30 Hz | Alertness, anxiety (can be counterproductive) | Weak-moderate |
| Gamma | 30-50 Hz | High-level cognition, insight | Emerging (less studied) |

**For a focus app, the sweet spot is 10-20 Hz (alpha-to-beta).** This is the best-supported range for cognitive enhancement.

### Carrier Frequency

- Typical range: **100-500 Hz**
- Below 100 Hz: binaural beats harder to perceive
- Above ~1000 Hz: auditory system can't track interaural phase differences, binaural beat perception breaks down
- Research most commonly uses **200-400 Hz**
- Lower carriers (100-200 Hz) feel deeper/more immersive
- Higher carriers (300-500 Hz) feel more present/alert
- **No research shows one carrier frequency is more effective for entrainment than another** — it's perceptual preference

### Waveform

- Pure sine waves are standard
- Triangle waves: slightly warmer harmonics
- Rounded square: richer, buzzier
- **No research showing one waveform is more effective than another**

### Sub-threshold Presentation

Some studies suggest binaural beats don't need to be consciously audible to produce effects (beats masked by ambient sound). Results are mixed but this supports the approach of embedding beats under pleasant soundscapes.

---

## Music Information Retrieval: Accuracy on Real-World Audio

### Feature Extraction Accuracy

| Feature | Algorithm | Clean Audio | 10-15s Clip (clean) | Mic Capture (preprocessed) |
|---|---|---|---|---|
| **BPM** | Onset detection + autocorrelation | 90-95% (±2 BPM) | 80-85% | 65-75% |
| **BPM** | TempoCNN (Essentia ML) | 85-90% (±4%) | 80-85% | 65-75% |
| **Key** | Chromagram + K-S profiles | 70-80% exact | 60-70% | 50-60% |
| **Key** | Essentia ML model | ~80% exact | 65-75% | 50-60% |
| **Spectral centroid** | FFT (deterministic) | Exact | Exact | Shifted down 5-15% |
| **Energy/arousal** | RMS + centroid + onset density | ~85% | ~80% | ~75% |
| **Mood (4-class)** | Essentia mood models | 70-75% | 65-70% | 55-65% |
| **Genre (5-class)** | CNN on mel spectrograms | 80-85% | 75-80% | 65-75% |

### Key Limitations by Feature

**BPM on short clips:**
- 10-second sample at 120 BPM = only 20 beats. Sometimes not enough to disambiguate.
- Octave errors (60 vs 120 BPM) are the #1 failure mode.
- Variable-tempo songs (jazz, classical, live recordings, DJ transitions) are unreliable.
- Ambient/atmospheric music with no clear beat produces meaningless results.

**Key detection on short clips:**
- A 10-second sample may only contain 1-2 chord changes.
- If the sample catches a passage on a non-tonic chord, the key is wrong.
- Modal detection (Dorian, Mixolydian) is significantly less reliable than major/minor.
- Atonal, heavily processed, or percussive music returns meaningless results.

**Mood classification:**
- Arousal (energy) is much easier to detect than valence (positive/negative).
- Arousal correlates with loudness and spectral centroid — survives noise well.
- Valence weakly correlates with key (major=happy, minor=sad), tempo, brightness — but the correlation is weak.
- "Mood" is inherently subjective. ~60-70% agreement with human labels is the ceiling.

### The Microphone Degradation Problem

| Factor | Effect on MIR |
|---|---|
| Room reverb (0.3-0.8s RT60) | Smears transients → beat detection degrades. Blurs harmonics → key detection degrades. |
| Background noise (<10 dB SNR) | Most MIR features become unreliable |
| Phone mic rolloff below 100 Hz | Loses bass content → hurts key detection, misses kick drums for tempo |
| Phone mic presence boost 2-5 kHz | Partially compensates for high-frequency room loss |
| Headphones scenario | **Completely breaks mic capture** — no audio for mic to record |

### The Clean Audio Workaround

**ShazamKit → Apple Music 30-second preview clip → analyze the preview instead of mic audio.**

This eliminates all mic degradation issues. The preview is studio-quality AAC. Feature extraction accuracy returns to "clean audio" levels. This should be the primary analysis path, with mic analysis as fallback for unidentified songs.

---

## The Mapping Problem: What Science Can and Cannot Tell Us

### What science tells us:
1. Binaural beats in the 10-20 Hz range may support focus (moderate evidence)
2. Personally chosen music increases engagement (strong evidence)
3. Tempo affects cognitive performance (moderate evidence)
4. Instrumental audio is less distracting than lyrical (strong evidence)

### What science does NOT tell us:
1. How to map BPM to binaural pulse rate
2. How to map musical key to carrier frequency
3. How to map song energy to beat intensity
4. How to map mood to brainwave target band
5. Whether any of these specific mappings matter for efficacy

### The honest conclusion:

**The song-to-binaural mapping is fundamentally an aesthetic and personalization system, not a neuroscientific one.**

The science supports that:
- Binaural beats *might* do something
- Personalization *might* improve engagement
- The specific feature-to-parameter mappings are creative design choices

The app should be framed as:
> "Inspired by your music" — NOT — "Scientifically optimized from your music"

The strongest scientifically defensible pitch:
> "We use your music taste to create a personalized, pleasant binaural soundscape that you're more likely to enjoy and use consistently. Consistent use is the biggest predictor of any focus practice working."

---

## Risks of Bad Mappings

| Risk | Severity | Mitigation |
|---|---|---|
| Unpleasant dissonance (carrier + key tones clash) | High | Harmonic compatibility check — snap carrier to consonant frequency |
| Counterproductive brainwave targeting (theta when user wants focus) | High | **User goal always overrides mood inference** |
| Excessive binaural beat prominence | Medium | Cap beat volume at -12 dB below ambient |
| Very low carrier discomfort (<100 Hz on headphones) | Low | Hard floor at 150 Hz |
| High beat frequency buzzing (>30 Hz) | Low | Hard ceiling at 40 Hz, default ranges per goal |

### The Critical Design Safeguard

**User intent must always override automatic mapping.**

The user selects their goal (focus / relax / create / sleep). Song features influence the *aesthetic* — the carrier tone, the timbre, the modulation feel — but never the *functional target*. This prevents the worst failure mode: generating drowsy theta beats when someone wants to focus, just because their music happened to be slow and mellow.

---

## References

- Bottiroli, S., Rosi, A., Russo, R., Vecchi, T., & Cavallini, E. (2014). The cognitive effects of listening to background music on older adults. *Frontiers in Aging Neuroscience.*
- Garcia-Argibay, M., Santed, M. A., & Reales, J. M. (2023). Binaural auditory beats affect long-term memory. *Psychological Research.*
- Licklider, J. C. R., Webster, J. C., & Hedlun, J. M. (1950). On the frequency limits of binaural beats. *JASA.*
- Oster, G. (1973). Auditory beats in the brain. *Scientific American.*
- Perham, N., & Vizard, J. (2011). Can preference for background music mediate the irrelevant sound effect? *Applied Cognitive Psychology.*
- Rausch, V. H., Bauch, E. M., & Bunzeck, N. (2023). Preferred background music enhances attention. *Frontiers in Psychology.*
- Salimpoor, V. N., et al. (2011). Anatomically distinct dopamine release during anticipation and experience of peak emotion to music. *Nature Neuroscience.*
