# BioNaural — Audio Layering & Sound Design

> How to make binaural beats sound good enough for 30-120 minute sessions.

---

## Why Pure Sine Waves Fail

Pure sine waves are fatiguing for extended listening because:

1. **Spectral monotony** — zero harmonics. The auditory cortex habituates to unchanging stimuli in 5-15 minutes, then the tone becomes an irritant.
2. **Cochlear fatigue** — a steady sine excites a single narrow region of the basilar membrane. Those hair cells undergo temporary threshold shift (TTS), making the tone feel "harsh" over time.
3. **No temporal variation** — natural sounds always have micro-fluctuations. A mathematically perfect sine wave is profoundly unnatural, keeping it in conscious attention rather than letting it recede.
4. **Interaural conflict** — binaural beats require the brain to continuously reconcile slightly different frequencies between ears, creating subtle cognitive load.

**The fix:** Add spectral complexity, temporal variation, and distribute energy across the basilar membrane.

---

## Technique 1: Harmonic Layering

Add overtones to the carrier to create richer timbre.

| Harmonic | Ratio | Level (relative to fundamental) | Character |
|----------|-------|--------------------------------|-----------|
| 1st (fundamental) | 1:1 | 0 dB (reference) | Base tone |
| 2nd | 2:1 | -6 to -12 dB | Warmth |
| 3rd | 3:1 | -10 to -18 dB | Body |
| 4th | 4:1 | -14 to -22 dB | Brightness |
| 5th | 5:1 | -18 to -26 dB | Shimmer |

**Critical rule:** The binaural frequency difference must be preserved in the fundamental. If L=200 Hz and R=210 Hz (10 Hz beat), harmonics are added independently: L gets 200, 400, 600 Hz; R gets 210, 420, 630 Hz. Each harmonic level beats at a different rate (10, 20, 30 Hz), creating a rich, complex beating pattern that's more pleasant than a single monotone throb.

**Alternative:** Add harmonics at identical frequencies to both channels (e.g., 400 Hz in both L and R) so only the fundamental beats. Shared harmonics act as a timbral "bed."

**Recommended shape:** Roll off harmonics at -6 dB/octave (triangle wave character) — warm but not buzzy.

---

## Technique 2: LFO Amplitude Modulation

Slowly varying volume with low-frequency oscillators creates organic, breathing quality.

| LFO Rate | Mod Depth | Character |
|----------|-----------|-----------|
| 0.05-0.2 Hz | 3-6 dB | Gentle breathing, like wind or surf |
| 0.2-1.0 Hz | 2-4 dB | Subtle movement |
| Multiple detuned LFOs | 2-5 dB summed | Non-repeating envelope (resists habituation) |

**Best approach:** Use 2-3 LFOs at irrational frequency ratios (e.g., 0.07, 0.13, 0.31 Hz) summed together. The volume envelope never exactly repeats.

**Alternative:** Sweep a low-pass filter cutoff (300 Hz → 2 kHz at 0.1 Hz) instead of amplitude. Changes timbre without changing loudness — less disruptive.

**Rule:** Apply LFOs identically to both L and R channels. Do NOT modulate at the binaural beat frequency — this would create a competing monaural beat.

---

## Technique 3: Noise Beds

Broadband noise relaxes the auditory system (vs. tonal stimuli) and softens carrier harshness.

| Noise Type | Character | Best For | Level vs. Carrier |
|-----------|-----------|---------|-------------------|
| **White** | Hissy, bright | Rarely ideal — too harsh | -20 to -15 dB (very quiet) |
| **Pink** (1/f) | Balanced, "natural rain" | Focus / beta beats. Most versatile. | -6 to 0 dB |
| **Brown** (1/f²) | Deep, rumbly, distant thunder | Relaxation / delta beats. Very warm. | 0 to +6 dB (can be louder than carrier) |

**Pairing recommendations:**
- Focus (beta): Pink noise
- Relaxation (alpha): Pink or brown
- Sleep (delta): Brown noise
- Meditation (theta): Pink + brown blend

**Key:** The carrier should poke out 3-10 dB above the noise floor in its frequency region. If you can still perceive a gentle "wobble" in the center of your head, the binaural beat is working.

---

## Technique 4: Nature Sounds

Nature sounds are spectrally complex, temporally variable, and trigger biophilia response.

| Sound | Why It Works | Level vs. Carrier |
|-------|-------------|-------------------|
| **Rain** | Spectrally similar to pink/brown noise but with natural variation | -3 to +6 dB |
| **Ocean waves** | Natural 0.05-0.15 Hz amplitude modulation (the wave cycle) | 0 to +10 dB |
| **Wind** | Filtered broadband with slow spectral sweeping | Background layer |
| **Fire crackle** | Broadband hiss + transient pops | Good for relaxation |
| **Birdsong/forest** | Intermittent, unpredictable — prevents habituation | -10 to -3 dB |

**Key insight from commercial apps:** The binaural tone does NOT need to be the loudest element. Research shows beat perception works even when the carrier is 10-15 dB below a broadband masker. The brain's FFR can lock onto relatively quiet stimuli.

**Typical mix hierarchy:**

| Layer | Relative Level |
|-------|---------------|
| Nature sound bed | 0 dB (loudest, reference) |
| Ambient pad/drone | -6 to -3 dB |
| Binaural carrier | -12 to -6 dB (felt more than consciously heard) |
| Secondary texture | -15 to -10 dB |

---

## Technique 5: Reverb & Spatial Processing

Dry sine waves sound clinical. Reverb gives a sense of physical space.

**Recommended for carriers:** Algorithmic reverb (plate or hall):
- Decay: 3-8 seconds (long, diffuse)
- Pre-delay: 20-60 ms
- High-frequency damping: moderate (warm tail)
- Wet/dry: 40-70% wet

**Caution:** Heavy reverb can smear binaural beat perception. Solution: parallel processing — send only a portion of the carrier to reverb (via send bus), keeping the dry carrier intact for beat perception while the reverb tail adds ambience.

**Spatial width trick:** Slightly different reverb settings on L and R channels creates a wide, enveloping stereo field without disrupting the binaural frequency difference.

---

## Technique 6: Drone/Pad Synthesis (Most Important)

Instead of a bare sine wave, create a warm synthesizer pad with the binaural difference embedded in the fundamental.

**Recipe:**
1. **Left channel pad:** Oscillator at 150 Hz with detuned unison (150.0, 150.1, 149.9 Hz), filtered through warm low-pass at ~800 Hz
2. **Right channel pad:** Same architecture, fundamental at 156 Hz (6 Hz theta beat)
3. The binaural beat emerges from the fundamental difference. Internal detuning creates pleasant chorus/movement that is NOT binaural.
4. Add slow filter modulation (LFO on cutoff, 0.05-0.2 Hz)
5. Add hall reverb (4-6s decay, 50-60% wet)

**Result:** Warm ambient music that contains a functional binaural beat. Closer to Brian Eno than a clinical tone generator.

**Multiple binaural pairs:** Layer 2-3 pairs at different carriers (100 Hz, 200 Hz, 300 Hz) all with the same beat frequency. Creates a rich harmonic series that pulses together — like a chord breathing.

---

## Technique 7: Isochronic Tones — The Second Entrainment Method

**Isochronic tones are a core part of BioNaural's entrainment strategy (v1.1+), not an afterthought.** They complement binaural beats by excelling where binaural beats are weakest.

**What they are:** A single carrier tone amplitude-modulated on/off at the target brainwave frequency. ~50 dB modulation depth (vs ~3 dB for binaural beats). The rhythm exists in the physical sound wave — no perceptual illusion involved.

**Why they matter for BioNaural:**
- **Stronger cortical evoked response** — 2024 EEG study showed significantly greater EEG power changes than binaural beats (p < 0.001) at gamma frequencies
- **No headphones required** — works through speakers, enabling sleep sessions without headphones and speaker-based Focus sessions
- **Best at high frequencies** — beta/gamma (Focus/Energize) is exactly where isochronic excels
- **Effects persist after stimulation** — measurable EEG changes lasting minutes post-session

**Where binaural beats remain preferable:**
- Low frequencies (theta/delta for Sleep) — slow isochronic pulse rates are less effective
- Users who find the pulsing harsh — binaural beats are gentler for extended listening
- Relaxation sessions — the softer binaural quality better serves the calming intent

**Combined approaches:**
- **Sequential:** Start with isochronic for rapid entrainment, crossfade to binaural for sustained comfort
- **Complementary targeting:** Isochronic for high-frequency targets (Focus/Energize), binaural for low-frequency targets (Sleep/Relaxation)
- **Adaptive switching:** The engine selects the best method based on mode, frequency target, user preference, and learned biometric outcomes
- **Ambient layer embedding:** Gentle isochronic modulation on the ambient layer (1-3 dB depth, sinusoidal envelope) as a secondary entrainment pathway

**Monaural beats** (two tones mixed in the same channel creating physical acoustic beating) are a third option with intermediate strength. Stronger ASSR than binaural, works even with imperfect headphone seal.

See Science-IsochronicTones.md for full research, implementation specs, and mode-by-mode fit analysis. See Tech-AVAudioEngine.md for the render callback implementation.

---

## What Commercial Apps Do

**Brain.fm:** Uses rhythmic amplitude modulation embedded in AI-composed music (not simple binaural beats). Patented "neural phase locking." Modulates specific frequency bands, not the entire signal. Reduces modulation strength over time as entrainment establishes.

**Key commercial techniques:**
1. Adaptive modulation depth — starts stronger, reduces over time
2. Spectral morphing — slowly changing frequency content so sound evolves
3. Session arc — ramp up (5 min) → sustain (20 min) → ease off (5 min)
4. Carrier frequency drift — ±1.5 Hz slow random walk to prevent cochlear fatigue
5. Musical consonance — carrier frequencies that form pleasant intervals

---

## Extended Listening Design Rules (30-120 min)

1. **Never let anything stay perfectly static.** Every parameter needs micro-variation via slow, unsynchronized LFOs.
2. **Overall spectral balance: pink noise slope (-3 dB/octave).** Mixes that are too bright cause fatigue; too dark feels muddy.
3. **Avoid the 2-4 kHz presence region** for sustained tonal content. This is where the ear is most sensitive. Keep carriers below 500 Hz.
4. **Target 55-65 dB SPL.** Louder causes fatigue. Quieter loses the beat in ambient noise. ~60 dB SPL is ideal.
5. **Change something every 5-10 minutes** — new texture, harmonic shift, nature sound variation. Crossfades of 30-90 seconds.
6. **Dynamic range: 6-12 dB.** Too compressed (<4 dB) feels oppressive. Too dynamic (>15 dB) is jarring.
7. **Avoid perfect loops.** Use prime-number-length loops (37s, 61s) or multiple layers with different loop lengths.
8. **High-pass at 30-40 Hz** to remove sub-bass that causes headphone driver strain.

---

## Carrier Frequency Shaping

| Waveform | Fatigue Level | Character | Best Use |
|----------|-------------|-----------|----------|
| Pure sine | Highest | Clinical, piercing | Not recommended |
| Triangle wave | Low | Warm, clean | Good compromise |
| Filtered sawtooth | Low | Rich, analog | Warm synth pad feel |
| Formant-shaped (vowel filter) | Lowest | Organic, almost vocal | Most pleasant for long sessions |
| Additive with detuned partials | Lowest | Complex, lush | Best result, most complex to implement |

**Carrier by target state:**

| State | Beat Freq | Carrier | Why |
|-------|-----------|---------|-----|
| Sleep (theta→delta) | 6→2 Hz | 100-200 Hz | Deep, warm, descending |
| Relaxation (alpha) | 8-11 Hz | 150-250 Hz | Warm, chest-resonant, grounding |
| Focus (beta) | 14-16 Hz | 300-450 Hz | Brighter, alert, "heady" |

**Ceiling:** Above 500 Hz, binaural beat perception weakens. Above 1000 Hz, most listeners can't perceive it. Stay below 500 Hz.

---

## Three-Layer Audio Architecture

BioNaural uses three distinct audio layers, mixed in real-time:

| Layer | What | Source | Adapts To | Volume |
|-------|------|--------|-----------|--------|
| **Entrainment** | The Hz frequency (binaural v1, isochronic v1.1+) | Real-time synthesis (AVAudioSourceNode) | Biometrics (HR/HRV → frequency + method) | -12 to -6 dB binaural; -14 to -10 dB isochronic |
| **Ambient** | Texture bed (rain, noise, wind) | Bundled audio files (AVAudioPlayerNode) | Mode + user preference | 0 dB (reference, loudest) |
| **Melodic** | Musical content (pads, piano, strings) | Curated from tagged sound library (AVAudioPlayerNode × 2 for crossfading) | Biometrics + user taste + learned outcomes | -6 to -3 dB |

See `Tech-MelodicLayer.md` for full melodic layer spec and `Tech-FeedbackLoop.md` for the learning system.

**Mixing hierarchy:** Ambient (loudest) → Melodic (underneath) → Binaural (felt not heard). Three user-adjustable sliders: Ambient, Melodic, Beats.

**Melodic layer adapts slower than binaural.** Binaural frequency adjusts every few seconds (imperceptibly). Melodic selection changes at most every 3-5 minutes with 10-15 second crossfades. This feels like natural musical evolution, not track-switching.

---

## Practical Recipe: 30-Min Sleep Session (6→2 Hz)

| Layer | Spec |
|-------|------|
| **Binaural** | L=150 Hz, R=156 Hz → ramps to L=150, R=152 over 25 min. Triangle wave, filtered at 600 Hz. |
| Harmonics | Shared 300 Hz tone in both channels at -10 dB |
| LFOs | 3 unsynchronized (0.07, 0.13, 0.29 Hz) modulating carrier ±2 dB |
| Carrier drift | ±1.5 Hz slow random walk (maintaining beat difference) |
| **Ambient** | Deep rain or ocean at 0 dB (loudest). Brown noise bed at -3 dB underneath. |
| **Melodic** | 1-2 loops from sleep library: deep pads, sub-bass drone. Energy <0.2, density <0.1. At -6 dB. Fades toward silence over session. |
| Reverb | Large hall, 5s decay, 50% wet on binaural carrier (via parallel send) |
| Level | 60 dB SPL |
| Arc | 3-min fade in → layer buildup (5 min) → stable middle → melodic fades → binaural ramp to delta → ambient holds → fade out or sleep detection |
