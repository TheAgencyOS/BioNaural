# AI Audio Integration — Implementation Record

*April 5, 2026 — Documents everything built, why, and how to activate it*

---

## What Was Built

A complete backend infrastructure for AI-generated, biometric-adaptive stem audio — the system described in Tech-AI-Audio-Viability.md. This is the v1.5/v2 audio pipeline that sits alongside (not replacing) the existing 3-layer audio engine.

The core idea: instead of playing a single melodic loop, play 3-4 audio stems simultaneously (pads, texture, bass, rhythm) with independent per-stem volume control driven by the user's real-time biometric state. HR elevated during Focus? Pad volume rises (calming), texture and rhythm fade (reduce stimulation). In Energize mode, the opposite — rising HR pushes all stems louder.

This is the bridge between the AI audio generation research (ACE-Step 1.5, Demucs) and the existing on-device audio engine. The server generates and separates audio into stems. The device plays and mixes them adaptively.

---

## New Files (7)

### Audio Layer

**`Audio/StemMetadata.swift`**

Data models for the stem system. Three types:

- **`StemSlot`** — Enum identifying each stem role: `.pads`, `.texture`, `.bass`, `.rhythm`. Each slot has a defined behavior in the biometric mixing rules (pads calm, texture reduces stimulation, bass anchors, rhythm varies by mode).

- **`StemVolumeTargets`** — Value type holding per-stem volume levels (all `Float`, 0.0–1.0). Produced by BiometricStemMixer, consumed by StemAudioLayer. Supports subscript access by slot.

- **`StemPackMetadata`** — Codable struct describing a content pack. Contains filenames for each stem, tags (energy, brightness, warmth, tempo, key, mode affinity), and source metadata (how it was generated — ACE-Step, Demucs, or manual). Loaded from `metadata.json` inside each content pack directory.

- **`StemPackSource`** — Enum tracking pack provenance: `.aceStep` (AI-generated), `.demucs` (stem-separated from existing audio), `.manual` (hand-crafted by sound designer).

---

**`Audio/BiometricStemMixer.swift`**

Pure computation struct that maps biometric state to per-stem volume targets. Stateless, `Sendable`, no side effects.

**How it works:**

1. Takes `FocusMode` + `hrNormalized` (0.0 = resting, 1.0 = max exertion) as input
2. Determines which two biometric states bracket the current HR (e.g., between Calm and Focused)
3. Linearly interpolates between those states' volume targets
4. Returns a `StemVolumeTargets` with smooth, continuous per-stem volumes

**Mode-specific mixing philosophy:**

| Mode | Rising HR Response |
|------|--------------------|
| Focus | Pads UP (calming), texture DOWN, rhythm DOWN |
| Relaxation | Pads stable, texture DOWN, rhythm OFF |
| Sleep | Everything fades toward bass-only |
| Energize | Everything UP (opposite of Focus — positive feedback) |

All volume values come from `Theme.Audio.StemMix.{Mode}.{state}` tokens. The mixer reads zone boundaries from `Theme.Audio.HRZone` (same boundaries used by the existing biometric processor for state classification).

The interpolation means volumes never jump between discrete states. As HR_normalized moves from 0.20 (calm ceiling) to 0.45 (focused ceiling), volumes smoothly transition between the calm and focused target sets. This produces the same imperceptible adaptation feel as the existing beat frequency slew rate limiting.

---

**`Audio/StemAudioLayer.swift`**

The playback engine. Manages 3-4 `AVAudioPlayerNode` instances (one per stem) with independent volume control.

**Architecture:**

```
StemPlayerNode[pads]    ──┐
StemPlayerNode[texture] ──┤
StemPlayerNode[bass]    ──┼──→ StemSubmixer ──→ MainMixer
StemPlayerNode[rhythm]  ──┘
```

**Key behaviors:**

- **Loading:** `play(pack:baseURL:)` loads stem audio files, wires players to the submixer, schedules seamless looping, starts playback.
- **Volume updates:** A 10 Hz timer reads volume targets from `AudioParameters` stem atomics and applies exponential smoothing (`alpha = 0.05`, ~200ms settling time). This prevents clicks from sudden volume changes.
- **Pack switching:** `crossfadeTo(pack:baseURL:)` uses equal-power A/B crossfading (same pattern as MelodicLayer). New stems fade in while old stems fade out over `Theme.Audio.StemMix.packCrossfadeDuration` (8 seconds).
- **Stop:** Equal-power fade-out using `cos(progress * π/2)` curve matching the crossfade pattern.

**Coexistence with existing layers:**

When StemAudioLayer is active, MelodicLayer is paused (stems replace individual loops) and AmbienceLayer volume is reduced to `Theme.Audio.StemMix.ambientVolumeWithStems` (0.3) since stems contain their own ambient texture. BinauralBeatNode is completely unaffected — the entrainment layer is never touched.

When no stem pack is loaded, the system falls back to the existing MelodicLayer + AmbienceLayer behavior. Zero regression.

---

### Content Pipeline

**`Services/ContentPackManager.swift`**

Manages downloaded content packs on disk. Protocol-based (`ContentPackManagerProtocol`) per CLAUDE.md rules.

**Storage structure:**

```
Documents/
└── ContentPacks/
    ├── pack_focus_warm_01/
    │   ├── metadata.json     ← StemPackMetadata
    │   ├── pads.m4a
    │   ├── texture.m4a
    │   ├── bass.m4a
    │   └── rhythm.m4a
    └── pack_sleep_dark_01/
        ├── metadata.json
        ├── pads.m4a
        ├── texture.m4a
        └── bass.m4a
```

**Capabilities:**

- **Discovery:** `packs(for: .focus)` returns all downloaded focus packs sorted by most recently played. `activePack(for:)` returns the best candidate.
- **Installation:** `install(from:metadata:)` moves a downloaded pack directory into `ContentPacks/`, calculates storage size, creates a SwiftData record, and runs LRU eviction if over budget.
- **Storage management:** Bounded by `Theme.Audio.StemMix.maxStorageMB` (500 MB default). Evicts least-recently-played packs first, always keeping at least 1 pack per mode.
- **Metadata loading:** `loadMetadata(for:)` reads and decodes the `metadata.json` from a pack directory.

---

**`Services/AIContentService.swift`**

Protocol defining the contract for AI content generation. Two implementations:

- **`AIContentServiceProtocol`** — Three methods: `generateStemPack` (request generation), `checkForUpdates` (poll for new content), `downloadPack` (download to temp directory).
- **`MockAIContentService`** — Returns simulated results for development. Uses `Theme.Audio.StemMix.MockDefaults` tokens for mock metadata values and `mockGenerationDelaySeconds` for simulated latency. Enables full end-to-end testing of the pipeline without server infrastructure.

The v2 production implementation will hit an ACE-Step 1.5 server endpoint. The protocol is designed so the entire client-side pipeline can be built and tested before that server exists.

---

**`Services/SonicProfilePromptBuilder.swift`**

Converts the user's learned `SoundProfile` preferences into natural language prompts for ACE-Step.

**How it works:**

1. Starts with a mode-specific base prompt ("subtle ambient electronic texture" for Focus, "deep dark ambient drone" for Sleep, etc.)
2. Appends descriptors derived from the SoundProfile: warmth ("warm"/"bright"/"neutral"), energy ("minimal"/"moderate"/"rich"), density ("sparse"/"evolving"/"dense")
3. Adds tempo affinity from Sound DNA if available (e.g., "88 BPM")
4. Adds key preference from Sound DNA if available (e.g., "A minor")
5. Appends universal suffix: "no drums, no vocals, seamless loop"

**Example outputs:**

- Focus user with warm preferences: `"subtle ambient electronic texture, warm, moderate, 88 BPM, A minor, sparse, no drums, no vocals, seamless loop"`
- Sleep user, minimal preferences: `"deep dark ambient drone, warm, minimal, sparse, no drums, no vocals, seamless loop"`
- Energize user, bright preferences: `"bright uplifting ambient texture, bright, rich, 120 BPM, C major, evolving, no drums, no vocals, seamless loop"`

All thresholds (what counts as "warm" vs. "bright", etc.) come from `Theme.Audio.StemMix.PromptThresholds` tokens. Default energy levels per mode also come from tokens.

---

### Data Model

**`Models/ContentPack.swift`**

SwiftData `@Model` tracking downloaded content packs. Fields:

- Identity: `id` (unique, matches directory name), `name`
- Classification: `mode` (FocusMode raw value), `energy`, `brightness`, `warmth`
- Source: `generationPrompt` (the ACE-Step prompt, nil for manual packs)
- Lifecycle: `downloadDate`, `lastPlayedDate`, `playCount`
- Storage: `sizeBytes`, `localPath` (relative to Documents)

`recordPlay()` updates last-played date and increments play count — used by ContentPackManager for LRU eviction decisions.

---

## Modified Files (3)

**`Audio/AudioParameters.swift`**

Added 4 atomic stem volume properties (`stemPadsVolume`, `stemTextureVolume`, `stemBassVolume`, `stemRhythmVolume`) using the same `ManagedAtomic<UInt64>` bit-pattern encoding as existing audio parameters. Added `stemVolumeTargets` getter and `applyStemVolumes(_:)` setter for convenience.

Initial values reference Theme tokens: `Theme.Audio.Neutral.carrierFrequency` for frequencies (replacing previously hardcoded `200.0`), `Theme.Audio.StemMix.defaultRhythmVolume` for rhythm (replacing hardcoded `0.8`).

---

**`Audio/AudioEngine.swift`**

StemAudioLayer added as an optional 4th layer:

- Created in `setup()` alongside AmbienceLayer and MelodicLayer
- Connected to `mainMixerNode`
- Torn down and rebuilt on configuration changes (Bluetooth codec switch, etc.)
- Stopped gracefully on `stop()` calls

Two new public methods:

- `loadStemPack(_:baseURL:)` — Pauses MelodicLayer, reduces AmbienceLayer volume, starts stem playback
- `unloadStemPack()` — Stops stems, restores ambient volume, restarts MelodicLayer

`isStemMixingActive` computed property exposes whether stems are currently playing.

---

**`Design/Theme.swift`**

Added `Theme.Audio.StemMix` enum with 70+ tokens:

- **Volume smoothing:** `volumeSmoothingAlpha` (0.05), `updateInterval` (0.1s)
- **Crossfade:** `packCrossfadeDuration` (8s), `ambientVolumeWithStems` (0.3)
- **Per-mode stem volumes:** 4 nested enums (`Focus`, `Relaxation`, `Sleep`, `Energize`), each with 4 biometric state targets (`calm`, `focused`, `elevated`, `peak`), each containing 4 stem volumes
- **Defaults:** `defaultFullVolume` (1.0), `defaultRhythmVolume` (0.8)
- **Storage:** `maxStorageMB` (500), `bytesPerMB`, `minPacksPerMode` (1)
- **Mock:** `mockGenerationDelaySeconds`, `MockDefaults` enum with per-mode energy/brightness/warmth/tempo values
- **Prompt builder:** `PromptThresholds` enum with warmth/energy/density thresholds and per-mode default energies

---

## How It Connects to Existing Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ BIOMETRIC PROCESSOR (existing, unchanged)                    │
│ Watch HR → Dual-EMA → State Classification → HR_normalized   │
└──────────────────────────┬──────────────────────────────────┘
                           │
              ┌────────────┴────────────┐
              │                         │
              ▼                         ▼
┌─────────────────────────┐ ┌─────────────────────────┐
│ ADAPTATION ENGINE       │ │ BIOMETRIC STEM MIXER    │
│ (existing, unchanged)   │ │ (NEW)                   │
│ HR → beat frequency     │ │ HR → per-stem volumes   │
│ HR → carrier frequency  │ │ Mode-aware interpolation│
│ Writes to AudioParams   │ │ Writes to AudioParams   │
│ (beat, carrier, amp)    │ │ (stem volumes)          │
└────────────┬────────────┘ └────────────┬────────────┘
             │                           │
             ▼                           ▼
┌─────────────────────────────────────────────────────────────┐
│ AUDIO ENGINE                                                 │
│ ┌─────────────────┐                                          │
│ │ BinauralBeatNode │ ← reads beat/carrier/amp atomics        │
│ │ (unchanged)      │    (NEVER touched by stem system)       │
│ └────────┬────────┘                                          │
│ ┌────────┴────────┐                                          │
│ │ Reverb           │                                          │
│ └────────┬────────┘                                          │
│          ├── AmbienceLayer (existing, volume reduced w/stems)│
│          ├── MelodicLayer  (existing, paused when stems on)  │
│          └── StemAudioLayer (NEW, 4 independent stems)       │
│              reads stem volume atomics at 10 Hz              │
│              exponential smoothing per stem                   │
└─────────────────────────────────────────────────────────────┘
```

---

## What's NOT Built Yet (Future Work)

### Needed for v1.5 (Bundled Demo Stems)

1. **Actual stem audio files** — 2-3 stem packs per mode (Focus, Relaxation, Sleep, Energize). Created either by:
   - Running Demucs on licensed ambient tracks (MIT license, offline tool)
   - Commissioning a sound designer to produce stems directly
   - Using ACE-Step to generate → Demucs to separate

2. **Session integration** — Wire BiometricStemMixer into the existing biometric control loop (10 Hz tick in BiometricProcessor). Currently the mixer exists as a pure computation; it needs to be called from the control loop and its output written to AudioParameters.

3. **Pack selection logic** — Decide which stem pack to load for a session. Options:
   - Auto-select based on mode + SoundProfile preferences (extend SoundSelector)
   - Let the user choose in Compose tab
   - Load the most-recently-played pack for the current mode

4. **UI trigger** — A way to enable/disable stem mixing:
   - Toggle in session settings ("Adaptive Stems" on/off)
   - Auto-enable when premium + content packs are available
   - Section in Compose tab for browsing/previewing packs

### Needed for v2 (Server-Side Generation)

5. **ACE-Step server** — Server endpoint that accepts text prompts, generates audio via ACE-Step 1.5, separates via Demucs, normalizes, packages, and returns a download URL.

6. **Production AIContentService** — Replace MockAIContentService with a real implementation hitting the server. Authentication, retry logic, progress reporting.

7. **Content refresh flow** — Weekly background check: SonicProfilePromptBuilder generates prompts from current SoundProfile → server generates new packs → ContentPackManager downloads and installs → notification: "Your new personalized soundscapes are ready."

8. **Settings UI** — Content pack storage management (current usage, clear cache, storage limit slider).

### Needed for v2.5 (Outcome-Refined Generation)

9. **Prompt refinement loop** — After each session, log which stem pack was playing + biometric outcomes. Over time, identify which prompt parameters correlate with better outcomes. Adjust future prompts accordingly. This closes the loop: taste → generation → adaptation → outcomes → better generation.

---

## Audit History

The implementation went through 3 mandatory audit passes before the build was approved:

**Pass 1:** Found 25 violations across 5 files. Primary issues: hardcoded volume values in StemAudioLayer (should reference Theme tokens), hardcoded initial values in AudioParameters (should reference Theme.Audio.Neutral), hardcoded thresholds in SonicProfilePromptBuilder (should reference PromptThresholds tokens), missing protocol on ContentPackManager, hardcoded mock values in AIContentService. All 25 fixed.

**Pass 2:** Found 1 code bug + 5 doc drifts. Bug: StemAudioLayer.stop() had broken fade-out math (volume never reached zero). Fix: replaced with equal-power `cos(progress * π/2)` curve matching the crossfade pattern. Doc drifts: StemPackMetadata.generatedBy type mismatch, checkForUpdates signature mismatch, AudioEngine wiring example stale, Theme token naming pattern stale, smoothing alpha namespace path wrong. All 6 fixed.

**Pass 3:** Zero violations. PRISTINE — all clear for build.

**Build result:** BUILD SUCCEEDED. App launched on iPhone 17 Pro simulator.

---

## File Inventory

| File | Type | Lines | Purpose |
|------|------|-------|---------|
| `Audio/StemMetadata.swift` | New | ~120 | Stem pack data models |
| `Audio/BiometricStemMixer.swift` | New | ~130 | Biometric → stem volume mapping |
| `Audio/StemAudioLayer.swift` | New | ~280 | Multi-stem playback engine |
| `Models/ContentPack.swift` | New | ~100 | SwiftData model for packs |
| `Services/ContentPackManager.swift` | New | ~160 | Pack download/cache/eviction |
| `Services/AIContentService.swift` | New | ~140 | AI generation protocol + mock |
| `Services/SonicProfilePromptBuilder.swift` | New | ~100 | SoundProfile → prompt conversion |
| `Audio/AudioParameters.swift` | Modified | +50 | Stem volume atomics added |
| `Audio/AudioEngine.swift` | Modified | +40 | StemAudioLayer wired in |
| `Design/Theme.swift` | Modified | +80 | StemMix tokens added |

---

## Related Documents

- [Tech-AI-Audio-Viability.md](Tech-AI-Audio-Viability.md) — Research synthesis and viability assessment (the "why")
- [Tech-AI-Audio-Architecture.md](Tech-AI-Audio-Architecture.md) — Technical spec (the "what")
- This document — Implementation record (the "how" and "what's next")
- [Tech-AudioCraft.md](Tech-AudioCraft.md) — AudioCraft/MusicGen research (ruled out for commercial use)
- [Tech-MubertAPI.md](Tech-MubertAPI.md) — Mubert API research (rated 5/10 fit)
- [Tech-OpenSourceAudioAI.md](Tech-OpenSourceAudioAI.md) — Open-source model comparison (ACE-Step 1.5 selected)
- [Competitor-BrainFM.md](../strategy/Competitor-BrainFM.md) — Brain.fm competitive analysis
- [MarketLandscape-2025-2026.md](../product/MarketLandscape-2025-2026.md) — Market research
