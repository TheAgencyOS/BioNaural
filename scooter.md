# Scooter — Sound Design Brief for BioNaural

Welcome. This doc tells you everything you need to know to build the SoundFont that powers BioNaural's melodic layer. Read this top to bottom and you'll understand the app, the audio architecture, what we need from you, and exactly how your sounds will be used.

---

## What Is BioNaural?

An iOS app that generates adaptive binaural beats driven by real-time Apple Watch biometrics (heart rate, HRV). Four modes: **Focus**, **Relaxation**, **Sleep**, **Energize**. Sessions run 10-90 minutes. The app reads your body and adjusts the audio to push you toward the target state.

The audio has **three layers** playing simultaneously:

| Layer | What | Volume | Source |
|-------|------|--------|--------|
| **Binaural** | Precise sine wave pair creating the binaural beat frequency | -12 to -6 dB | Synthesized in real-time (code) |
| **Ambient** | Texture bed (rain, wind, pink noise, ocean) | 0 dB (loudest) | Pre-recorded files |
| **Melodic** | Musical content — pads, piano, strings, bells | -6 to -3 dB | **This is what you're building** |

The melodic layer sits *underneath* the ambient bed. It's background. It adds warmth, color, and gentle movement. Users are not critically listening to it — they're trying to focus, relax, or fall asleep. It should be felt more than heard.

---

## How Your Sounds Will Be Used

This is the critical part. Your sounds will NOT be played as recordings. They will be **played as individual MIDI notes by a generative algorithm**.

Here's what happens:

1. The app reads the user's heart rate and HRV from their Apple Watch
2. A music theory engine (Tonic library) picks a **musical scale** based on the current biometric state and mode (e.g., pentatonic major for Focus when calm, pentatonic minor when stressed)
3. A **generative MIDI engine** creates note events — individual pitches, velocities, and durations — driven by the biometric data
4. Your SoundFont renders those notes into audio in real-time
5. The app adds **reverb** (medium hall, 15% wet) and routes to the output

So your sounds need to work as **individual notes played sparsely** — not as pre-composed loops or full arrangements. Think: a pad note here, a gentle piano note there, a string swell, silence, another note. Sparse, breathing, adaptive.

### What the generative engine does with your sounds:

| Parameter | How It's Controlled |
|-----------|-------------------|
| **Which notes** | Music theory engine picks from mode-appropriate scales. Focus = pentatonic major (C root). Relaxation = lydian (G root). Sleep = pentatonic minor (F root). Energize = major/lydian (D root). |
| **How many notes** | Biometric state controls density. Calm = very sparse (1-2 notes per phrase). Focused = moderate. Elevated = denser. Peak = simplified (back off under stress). |
| **How hard** | Velocity range 50-90 (never fortissimo). Calm = softer (velocity ~50-60). Elevated = louder (~80-90). |
| **How long** | Notes sustain 1.5-12 seconds depending on mode. Sleep = very long holds (3-12s). Energize = shorter (1-4s). Focus = medium (1.5-6s). |
| **How high/low** | Mode determines register. Sleep = low (C2-C3). Relaxation = low-mid (C2-C4). Focus = mid (C3-C5). Energize = mid-high (C3-C6). |
| **Silence between phrases** | 30% rest probability between phrases. Sleep has longest silences. |

### What this means for your sound design:

- **Every note must sound beautiful on its own.** Not as part of a chord or sequence — a single note, in isolation, held for 3-8 seconds with reverb, must be pleasant.
- **Long sustain and release are essential.** Notes will be held for up to 12 seconds (Sleep mode). The sustain loop must be seamless — no audible loop point, no timbral shift, no clicking.
- **Soft velocity layers matter.** Most notes will be played at velocity 50-70. The sound must be warm and present at low velocity, not thin or disappearing. Velocity 80-90 should bloom slightly — more body, not more brightness.
- **The attack must be gentle.** No sharp transients. Soft attack (50-200ms). The note should emerge, not strike. The binaural beats are doing the rhythmic work — the melodic layer provides color.
- **It must sit well under rain/wind/noise.** The ambient bed (rain, ocean, pink noise) is louder than your sounds. Your sounds peek through — a warm presence beneath the texture. Think: headphones on, rain falling, a distant piano note materializes and dissolves.

---

## The Four Presets We Need

One SF2 file containing four presets. Each preset is mapped to a mode. The generative engine automatically switches presets when the user starts a session in that mode.

### Preset 0 — Warm Evolving Pad (Focus, Sleep)

**Character:** Analog warmth. Think Juno-106 pad or Prophet-5 brass-pad, but softer. Slight filter movement — a slow LFO on the cutoff (0.05-0.1 Hz) that makes the timbre gently breathe even on a single held note. Stereo width but not exaggerated.

**Technical needs:**
- Root note range: C2 to C6 (multi-sampled every minor third minimum)
- Velocity layers: at least 2 (soft + medium). 3 is better (soft, medium, medium-loud)
- Sustain loop: seamless crossfade loop in the sustain portion. No click, no timbral jump. Loop length: 2-4 seconds minimum
- Release: 1.5-3 seconds natural decay after note-off
- Attack: 100-200ms fade-in. Not instant.
- Filter: If possible, encode a slow LFO modulating the filter cutoff in the SF2 modulators (generator 8 = initialFilterFc, modulator source = LFO1). If not, a static warm cutoff works — the app adds reverb which creates movement.
- No detuning or chorus baked in — the app may add its own chorus via the audio engine

**Reference sounds:** Brian Eno "Music for Airports" pad tones. Tycho "A Walk" background wash. The warm hum under Endel's Focus mode.

**This is the most important preset.** It plays in the two most-used modes (Focus and Sleep). It needs to be the most polished.

---

### Preset 1 — Gentle Ensemble Strings (Relaxation)

**Character:** Chamber strings, small ensemble (not full orchestra). Viola + cello warmth, not violin brightness. Like a string quartet playing sustained notes in a wooden room. Natural, not synthesized. Intimate, not cinematic.

**Technical needs:**
- Root note range: C2 to C5 (Relaxation uses low-mid register)
- Velocity layers: at least 2. Soft layer should be molto pianissimo — barely there
- Sustain loop: critical. Real string samples often have tricky loop points. Spend time here. The note will be held 3-8 seconds.
- Release: 1-2 seconds. Natural bow-lift decay.
- Attack: 200-400ms. Slow bow attack, not a pizzicato
- Vibrato: very subtle if any. This is background music, not a concerto solo. 0.5-1mm vibrato depth max.

**Reference sounds:** Max Richter "Sleep" string textures. Nils Frahm "Says" background strings. A string quartet heard from an adjacent room with the door open.

---

### Preset 2 — Deep Ambient Pad (Sleep)

**Character:** Almost formless. A dark, warm cloud of sound. Think: the lowest, softest synth pad imaginable. Barely melodic — more tonal texture than "music." The user is falling asleep. This should feel like being wrapped in a warm blanket of sound.

**Technical needs:**
- Root note range: C1 to C4 (Sleep uses the lowest register, C2-C3 primarily)
- Velocity layers: 2 minimum. Even the "loud" layer should be soft by normal standards
- Sustain loop: the longest and most seamless of all presets. Notes may sustain 6-12 seconds. Any loop artifact will be noticeable because the listener is in near-silence
- Release: 3-5 seconds. Very long fade. The note should melt away, not stop.
- Attack: 300-500ms minimum. Glacially slow. The note materializes from nothing.
- Filter cutoff: LOW. Roll off everything above 2-4 kHz. This should have no brightness, no edge, no presence. Pure warmth and body.
- Stereo: wide and diffuse. Feels like it surrounds you, not like it comes from a point.

**Reference sounds:** Stars of the Lid "Requiem for Dying Mothers." William Basinski "Disintegration Loops" (the soft parts). The lowest register of a church organ with the tremulant stop, heard from the back of the nave.

**This preset plays when someone is trying to fall asleep.** The bar for loop quality is highest here because any artifact will snap them awake.

---

### Preset 3 — Bright Bells / Celesta (Energize)

**Character:** Clear, crystalline, uplifting. Like a celesta, glockenspiel, or vibraphone with soft mallets. Each note should sparkle and decay naturally — not sustain forever like the pads. This is the only preset with a real percussive transient (though still soft). It's the "wake up" sound.

**Technical needs:**
- Root note range: C3 to C7 (Energize uses the highest register)
- Velocity layers: at least 2. Soft = gentle tap with long ring. Medium = clearer attack with bright shimmer
- Sustain: natural decay, not looped. 2-4 second ring-out. If the sample is long enough, no loop needed — the generative engine won't hold Energize notes longer than ~4 seconds
- Release: natural instrument release. 0.5-1 second.
- Attack: 5-30ms. This IS the one preset where a gentle transient is welcome. Not a hard mallet strike — a soft felt mallet tap. The "ding" should be round, not sharp.
- Brightness: open filter. Let the harmonics ring. This preset provides air and uplift.

**Reference sounds:** Bjork "Vespertine" celesta. Sigur Ros "Takk" glockenspiel moments. A music box heard from across a room.

---

## Technical SF2 Requirements

### File Format

- **SoundFont 2.x (.sf2)**. Not SF3 (compressed), not SFZ, not EXS24. Standard uncompressed SF2.
- One file containing all four presets
- **File name must be exactly:** `BioNaural-Melodic.sf2`
- **Target size:** 10-17 MB total. Budget ~3-5 MB per preset.

### Sample Format

- 44.1 kHz or 48 kHz sample rate (48 preferred — matches the app's audio engine)
- 16-bit or 24-bit depth (16-bit is fine — keeps file size down)
- Mono samples (the SF2 spec handles stereo panning). If you record in stereo, include stereo pairs.

### Multi-Sampling

Each preset should be sampled at minimum every **minor third** (3 semitones) across its range. More samples = less pitch-shifting artifacts. The sweet spot:

| Preset | Range | Minimum Samples | Ideal |
|--------|-------|----------------|-------|
| Warm Pad | C2-C6 | 16 | 24 |
| Strings | C2-C5 | 12 | 18 |
| Deep Pad | C1-C4 | 12 | 16 |
| Bells | C3-C7 | 16 | 24 |

### Velocity Layers

| Layer | Velocity Range | Character |
|-------|---------------|-----------|
| Soft (pp) | 1-63 | Primary playing range. Must sound full and warm, not thin. |
| Medium (mf) | 64-100 | Slightly more body and presence. Not dramatically different. |
| Loud (f) | 101-127 | Optional. If included, more bloom, not more brightness. |

The generative engine plays mostly in the 50-90 velocity range. The 1-49 and 91-127 extremes are hit rarely. Don't neglect the soft layer — it's where 60% of playing happens.

### Loop Points

This is the single most important technical requirement. Bad loop points will ruin the experience.

- Every sustaining preset (0, 1, 2) MUST have seamless sustain loops
- Use crossfade looping in your SF2 editor (Polyphone, Vienna)
- Loop length: minimum 2 seconds, ideally 3-4 seconds
- Test by holding a note for 30 seconds straight — listen for:
  - Clicking or popping at the loop boundary
  - Timbral shift (brightness change, filter jump)
  - Volume bump or dip
  - Phase cancellation artifacts
- Preset 2 (Deep Pad for Sleep) has the highest bar — test at 60 seconds

### SF2 Generators to Set

These are parameters you set in the SF2 editor (Polyphone) per preset:

| Generator | Preset 0 (Pad) | Preset 1 (Strings) | Preset 2 (Deep Pad) | Preset 3 (Bells) |
|-----------|---------------|-------------------|---------------------|------------------|
| Attack (vol env) | 100-200ms | 200-400ms | 300-500ms | 5-30ms |
| Decay (vol env) | 500ms | 300ms | 1000ms | 2000ms |
| Sustain (vol env) | -3 dB | -3 dB | 0 dB | -40 dB (natural decay) |
| Release (vol env) | 1500-3000ms | 1000-2000ms | 3000-5000ms | 500-1000ms |
| Filter cutoff | 8000 Hz | 6000 Hz | 3000 Hz | 12000 Hz (open) |
| Filter resonance | 0 dB | 0 dB | 0 dB | 0 dB |
| Chorus send | 0.3 | 0.2 | 0.1 | 0.4 |
| Reverb send | 0.4 | 0.3 | 0.5 | 0.5 |

### SF2 Modulators (Optional but Valuable)

If you know how to set up SF2 modulators, these will make the presets sound significantly more alive:

- **Velocity → Filter Cutoff:** Higher velocity = slightly brighter. Amount: +2000 cents for Preset 0, +1000 for Preset 2. This is what makes pads sound "expressive" vs "static."
- **LFO1 → Filter Cutoff:** Slow LFO (0.05-0.1 Hz) gently opening and closing the filter. Amount: ±500-1000 cents. Only for Preset 0 and 2. This creates the "breathing" quality.
- **Velocity → Volume:** Standard, usually auto-set. Make sure soft velocities aren't too quiet.

If you don't set modulators, the code still works — the app adds reverb externally. But modulators are what separate a "SoundFont that sounds like MIDI" from one that sounds alive.

---

## What We Don't Need

- **No drums, no percussion** (except the bells in Preset 3)
- **No bass** — the binaural beat's carrier frequency occupies the low end (100-600 Hz)
- **No staccato articulations** — everything is legato/sustained
- **No vibrato on the pads** — let the LFO filter modulation do the movement
- **No effects baked in** (no reverb, no delay, no chorus in the samples) — the app adds its own reverb. Dry samples only.
- **No extreme velocity dynamics** — the range between pp and f should be subtle, not dramatic

---

## How to Test

1. **Download Polyphone** (free, polyphone-soundfonts.com) — SF2 editor and player
2. Load your SF2 file
3. For each preset, hold a single note at velocity 60 for 30 seconds. Listen for:
   - Loop artifacts (clicking, timbral shift)
   - Whether it sounds pleasant on its own (not as part of a chord)
   - Whether it disappears or stays present at low velocity
4. Play sparse, slow notes in C pentatonic major (C, D, E, G, A). One note every 2-3 seconds, velocity 50-70. This simulates what the generative engine does.
5. Layer it over a rain/ocean ambient recording at -6 dB below the ambient. Does it peek through pleasantly?
6. Test Preset 2 (Deep Pad) in near-silence at very low volume. Any loop artifact? Any brightness that doesn't belong?

---

## Delivery

- One file: `BioNaural-Melodic.sf2`
- Four presets at program numbers 0, 1, 2, 3 (in the order listed above)
- Bank 0 (default melodic bank, MSB 0x79 / 121)
- 10-17 MB total
- 48 kHz sample rate preferred
- Dry samples — no baked-in effects

Drop it in the project at `src/BioNaural/Resources/SoundFonts/BioNaural-Melodic.sf2` and it's live. The code is already wired to load it.

---

## The Audio Context (What It Sounds Like Together)

Imagine headphones on, eyes closed:

1. **Rain** falling steadily (the ambient bed, loudest layer)
2. **A low hum** — barely perceptible — the binaural beat at 15 Hz, carrier around 375 Hz. You feel it more than hear it. It's doing the brainwave entrainment.
3. **Your pad** — a warm C4 materializes through the rain. Holds for 4 seconds. Fades. Silence for 2 seconds. A G3 appears, softer. Holds for 6 seconds. An E4 overlaps slightly. They dissolve together.
4. The user's heart rate drops. The app detects this. The notes become **sparser, softer, lower**. A single C3 pad tone every 8 seconds. The rain continues.
5. Heart rate rises slightly — the user got a notification. The app detects the spike. Notes stay sparse but shift to **pentatonic minor** (calming scale). One note. Silence. One note. The heart rate settles.

That's the experience. Your sounds are the warmth between the rain and the science.

---

## Timeline & Priority

This SF2 is for **v1.5** (3-6 months post-launch). For v1 launch, the app ships with pre-recorded melodic loops (already done). Your SoundFont replaces those loops with infinite generative variety — same three-layer architecture, same mix levels, but now the melodic layer is alive.

**Priority order:**
1. Preset 0 (Warm Pad) — plays in Focus AND Sleep, the two most-used modes
2. Preset 2 (Deep Pad) — Sleep mode is where loop quality matters most
3. Preset 1 (Strings) — Relaxation mode
4. Preset 3 (Bells) — Energize mode

If you want to deliver in phases, ship Presets 0+2 first. We can go live with those while you finish 1+3.

---

## ACE-Step: The Other Half of v1.5

Your SoundFont isn't the only new audio in v1.5. We're also integrating **ACE-Step 1.5** — an AI music generation model (MIT license, open source) that produces evolving ambient texture loops from text prompts. Here's why this matters to you and how the two pieces fit together:

### Two layers, two jobs

| Layer | Source | Role | Adapts to biometrics? |
|-------|--------|------|----------------------|
| **Texture beds** | ACE-Step (pre-generated loops, 30-60s each) | Atmosphere — rich evolving drones, granular clouds, harmonic washes | No — selected and crossfaded, not note-level |
| **Melodic accents** | **Your SoundFont** (real-time MIDI) | Adaptation — individual notes that respond to HR/HRV in real-time | **Yes — density, register, velocity, timing all driven by biometrics** |

**Your sounds are the adaptive brain. ACE-Step is the atmospheric bed.** The two play simultaneously. ACE-Step provides the richness and depth that SoundFont synthesis can't easily achieve (evolving granular textures, spectral movement, organic drones). Your SoundFont provides the musical responsiveness that static loops can't (a note appears when the user's heart rate dips, disappears when it spikes).

### What this means for your sound design

- **Your sounds need to sit on top of ACE-Step textures**, not compete with them. Think of ACE-Step as a richer version of the ambient bed (rain, wind) — always present, slowly evolving. Your notes peek through it.
- **Timbral separation matters.** If ACE-Step generates a warm pad drone in Focus mode, your Preset 0 (Warm Pad) needs to be distinct enough to be heard as a separate musical event on top of it. Consider this when choosing timbres — some brightness or attack character helps your notes cut through the AI-generated wash.
- **Your sounds are still the hero.** ACE-Step loops play at ambient levels. Your SoundFont plays at melodic levels (-6 to -3 dB above the texture bed). Users will hear your notes as the "music" — ACE-Step is felt as "environment."
- **Nothing about the SF2 spec changes.** Same presets, same file, same technical requirements. ACE-Step is a separate pipeline that doesn't touch your work. Just know it exists so you can design with the full sonic picture in mind.

### Example of what a v1.5 session sounds like

Headphones on, Focus mode, 25 minutes in:

1. **Rain** (ambient bed, loudest)
2. **ACE-Step texture** — a slowly evolving warm drone in A minor, shifting spectrally over 45 seconds, then crossfading to a slightly brighter variant. Sits just above the rain. Feels organic, alive, never quite the same.
3. **Your Warm Pad (Preset 0)** — a C4 note materializes through the texture. Holds 5 seconds. Fades. A G3. The generative engine picked these from A minor pentatonic because the user's HR is steady. The notes feel like they belong to the ACE-Step texture but are distinct musical events.
4. **Binaural hum** — 15 Hz beat, 375 Hz carrier. Barely perceptible. Doing the science.

That's four layers breathing together. Your SoundFont is the only one responding to biometrics in real-time.

### v2: Stem-Based Adaptive Mixing

Beyond v1.5, we're building a **stem-based mixing system** (v2). Here's what you need to know:

- ACE-Step generates full ambient tracks, then **Demucs** (MIT, Meta) separates them into stems: pads, texture, bass, rhythm
- A **BiometricStemMixer** dynamically adjusts per-stem volumes based on the user's heart rate (e.g., HR rising in Focus → pads up, texture down, rhythm fades)
- When stem packs are active, the SoundFont melodic layer **pauses** — the stems replace it
- When no stem pack is loaded (free tier, no downloaded content), **your SoundFont is the melodic layer**

**Your SoundFont is the foundation.** Stem mixing is a premium enhancement that sits on top. The SoundFont is what every user hears at launch and what premium users fall back to. Design it as the primary experience, not a fallback.

---

## Things to Know About the Engine

A few details that affect how your sounds will be heard:

**Polyphony cap:** The generative engine limits to **4 notes playing simultaneously** max. Usually it's 1-2. Don't worry about how your sounds stack in dense voicings — they won't.

**Energize has phases.** The app doesn't just slam into 30 Hz gamma:
- **Warm-up (0-3 min):** Starts at 10 Hz alpha, ramps to 14 Hz beta. Sound is gentler here.
- **Sustain (3-25 min):** 18-25 Hz beta range. Full energy. Your bells should sparkle here.
- **Cool-down (last 5 min):** Ramps back down to 8 Hz alpha. Sound becomes sparser, softer.
- So Preset 3 needs to work at *both* the bright sustain phase and the gentler ramp phases.

**Current renderer:** The code uses **SF2Lib** (MIT license, third-party renderer). It was chosen over Apple's `AVAudioUnitSampler` for full SF2 v2 modulator support, three-bus output (dry + chorus + reverb sends), and pre-allocated voice pooling. **Standard SF2 spec is what matters** — if it plays correctly in Polyphone, it'll work in the app.

**The reverb is applied by the app, not the SoundFont.** Medium hall, 15% wet/dry. Your presets set chorus and reverb *send levels* in the SF2 generators — the app's reverb unit receives those sends. Keep your samples bone dry.

**Carrier frequencies by mode** (the binaural hum — this is what occupies the low end):
- Focus: 300-450 Hz
- Relaxation: 150-250 Hz
- Sleep: 100-200 Hz
- Energize: 400-600 Hz

Your sounds sit above this. The carrier is felt, not heard — but avoid fundamental frequencies that would beat against it. Low register notes (C1-C2) in Sleep mode will coexist with a 100-200 Hz carrier, so keep them warm and smooth to blend rather than clash.

---

## Questions?

Text Eric. He'll loop me in if it's a technical architecture question. For sound design decisions (timbre, sample source, recording approach), you have full creative control within the constraints above.

The most important thing: **every single note must sound beautiful held alone for 8 seconds with reverb.** If that works, everything else follows.
