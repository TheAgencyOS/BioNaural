# AI Audio Integration — Technical Architecture

*April 5, 2026 — Implementation spec derived from Tech-AI-Audio-Viability.md*

---

## Overview

This document specifies the exact code changes needed to integrate AI-generated audio into BioNaural's existing 3-layer audio architecture. The integration adds two capabilities:

1. **Stem-based audio playback** — Play multiple audio stems simultaneously with independent per-stem volume control, driven by biometric state
2. **AI content pipeline** — Server-side generation of personalized ambient/melodic content via ACE-Step 1.5, delivered as downloadable content packs

The binaural beat synthesis layer (Layer 1) is **never touched**. All changes affect Layer 2 (Ambient) and Layer 3 (Melodic) only.

---

## Architecture Principle: Additive, Not Replacing

The existing `AmbienceLayer` and `MelodicLayer` continue to work exactly as they do today. The new `StemAudioLayer` is an **optional upgrade path** that the `AudioEngine` can use when stem-separated content is available. Users on the free tier or without downloaded content packs use the existing file-based layers. Premium users with content packs get stem-based adaptive mixing.

```
AudioEngine (existing)
├── BinauralBeatNode (unchanged — real-time DSP synthesis)
├── Reverb (unchanged)
├── AmbienceLayer (unchanged — file-based ambient beds)
├── MelodicLayer (unchanged — file-based A/B crossfade)
└── StemAudioLayer (NEW — multi-stem playback with biometric mixing)
    ├── StemPlayerNode[0] — pads stem
    ├── StemPlayerNode[1] — texture stem
    ├── StemPlayerNode[2] — bass stem
    ├── StemPlayerNode[3] — rhythm stem (optional)
    └── StemSubmixer → MainMixer
```

---

## New Files

### Audio Layer

| File | Purpose |
|------|---------|
| `Audio/StemAudioLayer.swift` | Multi-stem playback engine with per-stem volume control |
| `Audio/BiometricStemMixer.swift` | Maps BiometricState → per-stem volume targets |
| `Audio/StemMetadata.swift` | Data model for stem packs (stems, tags, source info) |

### Content Pipeline

| File | Purpose |
|------|---------|
| `Services/AIContentService.swift` | Protocol + implementation for AI content generation requests |
| `Services/ContentPackManager.swift` | Downloads, caches, indexes content packs on device |
| `Services/SonicProfilePromptBuilder.swift` | Converts SoundProfile → ACE-Step text prompts |

### Models

| File | Purpose |
|------|---------|
| `Models/ContentPack.swift` | SwiftData @Model for downloaded content pack metadata |

---

## 1. StemAudioLayer

### Responsibilities
- Load a stem pack (4 audio files: pads, texture, bass, rhythm)
- Play all stems simultaneously with independent volume per stem
- Accept volume targets from BiometricStemMixer
- Crossfade between stem packs (A/B pattern, same as MelodicLayer)
- Expose `outputNode` for AudioEngine graph wiring

### Stem Slots

| Slot | Role | Biometric Response |
|------|------|--------------------|
| 0: Pads | Warm sustained tones | Volume UP when HR elevated (calming) |
| 1: Texture | Atmospheric detail | Volume DOWN when HR elevated (reduce stimulation) |
| 2: Bass | Low-frequency body | Stable — anchors the mix |
| 3: Rhythm | Percussive elements | Volume DOWN when HR elevated (Focus/Relax), UP in Energize |

### Volume Control

Per-stem volumes are `Float` values [0.0...1.0] set on each `AVAudioPlayerNode.volume`. The `BiometricStemMixer` computes targets every 100ms (matching the biometric control loop rate). Volume changes use exponential smoothing to avoid clicks:

```
stem[i].volume += (target[i] - stem[i].volume) * smoothingAlpha
```

Where `smoothingAlpha` comes from `Theme.Audio.StemMix.volumeSmoothingAlpha` (suggested: 0.05 = ~200ms settling time at 100ms update rate).

### AudioParameters Extension

Add atomic stem volume parameters to `AudioParameters`:

```swift
// Stem volume targets [0...1] — set by BiometricStemMixer, read by StemAudioLayer
private let _stemPadsVolume    = ManagedAtomic<UInt64>(1.0.bitPattern)
private let _stemTextureVolume = ManagedAtomic<UInt64>(1.0.bitPattern)
private let _stemBassVolume    = ManagedAtomic<UInt64>(1.0.bitPattern)
private let _stemRhythmVolume  = ManagedAtomic<UInt64>(0.8.bitPattern)
```

These are NOT read on the audio render thread (stem volumes are applied via `AVAudioPlayerNode.volume` which is thread-safe in AVAudioEngine). The atomics ensure safe reads from the main thread timer that drives volume updates.

---

## 2. BiometricStemMixer

### Responsibilities
- Receive `BiometricState` snapshots from the adaptation engine
- Compute per-stem volume targets based on mode + biometric state
- Write targets to `AudioParameters` stem volume atomics

### Mode-Dependent Mixing Rules

**Focus Mode:**
| State | Pads | Texture | Bass | Rhythm |
|-------|------|---------|------|--------|
| Calm | 0.8 | 0.7 | 0.6 | 0.4 |
| Focused | 0.9 | 0.5 | 0.7 | 0.3 |
| Elevated | 1.0 | 0.3 | 0.7 | 0.1 |
| Peak | 1.0 | 0.2 | 0.5 | 0.0 |

**Relaxation Mode:**
| State | Pads | Texture | Bass | Rhythm |
|-------|------|---------|------|--------|
| Calm | 1.0 | 0.8 | 0.5 | 0.2 |
| Focused | 0.9 | 0.6 | 0.5 | 0.2 |
| Elevated | 0.8 | 0.4 | 0.6 | 0.0 |
| Peak | 0.7 | 0.2 | 0.6 | 0.0 |

**Sleep Mode:**
| State | Pads | Texture | Bass | Rhythm |
|-------|------|---------|------|--------|
| Calm | 0.6 | 0.4 | 0.8 | 0.0 |
| Focused | 0.5 | 0.3 | 0.7 | 0.0 |
| Elevated | 0.4 | 0.2 | 0.6 | 0.0 |
| Peak | 0.3 | 0.1 | 0.5 | 0.0 |

**Energize Mode (opposite polarity):**
| State | Pads | Texture | Bass | Rhythm |
|-------|------|---------|------|--------|
| Calm | 0.5 | 0.6 | 0.7 | 0.6 |
| Focused | 0.6 | 0.7 | 0.8 | 0.7 |
| Elevated | 0.7 | 0.8 | 0.9 | 0.9 |
| Peak | 0.8 | 0.9 | 1.0 | 1.0 |

All values come from `Theme.Audio.StemMix` tokens — never hardcoded.

### Interpolation

The mixer doesn't jump between discrete states. It interpolates between the current and target volumes using the biometric processor's continuous HR_normalized value:

```swift
func computeTargets(mode: FocusMode, hrNormalized: Double) -> StemVolumeTargets {
    // Interpolate between the two bracketing states
    let (lower, upper, fraction) = bracketState(hrNormalized)
    return StemVolumeTargets(
        pads:    lerp(lower.pads, upper.pads, fraction),
        texture: lerp(lower.texture, upper.texture, fraction),
        bass:    lerp(lower.bass, upper.bass, fraction),
        rhythm:  lerp(lower.rhythm, upper.rhythm, fraction)
    )
}
```

---

## 3. StemMetadata

```swift
/// Describes a stem pack — a set of audio files meant to be played simultaneously.
public struct StemPackMetadata: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    
    /// File names for each stem slot (relative to content pack directory).
    public let padsFileName: String
    public let textureFileName: String
    public let bassFileName: String
    public let rhythmFileName: String?  // Optional — not all packs have rhythm
    
    /// Tags for selection (same schema as SoundMetadata).
    public let energy: Double           // 0-1
    public let brightness: Double       // 0-1
    public let warmth: Double           // 0-1
    public let tempo: Double?           // BPM or nil
    public let key: String?             // Musical key
    public let modeAffinity: [FocusMode]
    
    /// Source metadata.
    public let generatedBy: StemPackSource  // .aceStep, .demucs, .manual
    public let generationPrompt: String? // The prompt used (if AI-generated)
}
```

---

## 4. AIContentService

### Protocol

```swift
/// Contract for requesting AI-generated audio content.
/// v2 implementation hits an ACE-Step server. Mock implementation
/// returns bundled demo packs for development and testing.
public protocol AIContentServiceProtocol {
    /// Request generation of a stem pack matching the given prompt.
    func generateStemPack(prompt: String, mode: FocusMode) async throws -> StemPackGenerationResult
    
    /// Check if new personalized content is available for download.
    func checkForUpdates(profileHash: String) async throws -> [ContentPackManifest]
    
    /// Download a content pack to local storage.
    func downloadPack(manifest: ContentPackManifest) async throws -> URL
}
```

### ACE-Step Implementation (v2)

The server-side pipeline:
1. App sends SonicProfile-derived prompt + mode to server
2. Server runs ACE-Step 1.5 to generate a full ambient track
3. Server runs Demucs to separate into stems (pads, texture, bass, rhythm)
4. Server normalizes stems (-18 LUFS), applies crossfade loop points
5. Server packages stems + metadata JSON into a content pack (.zip)
6. App downloads pack, ContentPackManager indexes it

### Mock Implementation (v1.5 / Development)

Returns bundled stem packs from the app bundle. This lets us build and test the entire StemAudioLayer + BiometricStemMixer pipeline before the server infrastructure exists.

---

## 5. ContentPackManager

### Responsibilities
- Maintain a local directory of downloaded content packs
- Index packs by mode, tags, generation source
- Manage storage (LRU eviction when over budget)
- Provide stem pack URLs to StemAudioLayer

### Storage Layout

```
Documents/
└── ContentPacks/
    ├── manifest.json          — index of all downloaded packs
    ├── pack_focus_warm_01/
    │   ├── metadata.json      — StemPackMetadata
    │   ├── pads.m4a
    │   ├── texture.m4a
    │   ├── bass.m4a
    │   └── rhythm.m4a
    ���── pack_sleep_dark_01/
    │   ├── metadata.json
    │   ├── pads.m4a
    │   ├── texture.m4a
    │   └── bass.m4a
    └── ...
```

### Storage Budget
- Default: 500 MB
- Configurable in Settings
- LRU eviction: least-recently-played packs removed first
- Always keep at least 1 pack per mode

---

## 6. SonicProfilePromptBuilder

Converts the user's `SoundProfile` preferences into natural language prompts for ACE-Step:

```swift
public struct SonicProfilePromptBuilder {
    
    static func buildPrompt(profile: SoundProfile, mode: FocusMode) -> String {
        var parts: [String] = []
        
        // Mode-specific base
        parts.append(modeBase(mode))
        
        // Warmth/brightness
        if let warmth = profile.warmthPreference {
            parts.append(warmth > 0.6 ? "warm" : warmth < 0.4 ? "bright" : "neutral")
        }
        
        // Energy
        let energy = profile.energyPreference[mode.rawValue] ?? 0.5
        parts.append(energy < 0.3 ? "minimal" : energy > 0.7 ? "rich" : "moderate")
        
        // Tempo
        if let bpm = profile.tempoAffinity {
            parts.append("\(Int(bpm)) BPM")
        }
        
        // Key
        if let key = profile.keyPreference {
            parts.append("\(key) minor")  // Default to minor for wellness
        }
        
        // Density
        parts.append(profile.densityPreference < 0.3 ? "sparse" : "evolving")
        
        // Universal suffix
        parts.append("no drums, no vocals, seamless loop")
        
        return parts.joined(separator: ", ")
    }
    
    private static func modeBase(_ mode: FocusMode) -> String {
        switch mode {
        case .focus:     return "subtle ambient electronic texture"
        case .relaxation: return "warm flowing ambient pad"
        case .sleep:     return "deep dark ambient drone"
        case .energize:  return "bright uplifting ambient texture"
        }
    }
}
```

Example outputs:
- Focus: `"subtle ambient electronic texture, warm, moderate, 88 BPM, A minor, sparse, no drums, no vocals, seamless loop"`
- Sleep: `"deep dark ambient drone, warm, minimal, 55 BPM, sparse, no drums, no vocals, seamless loop"`

---

## 7. AudioEngine Integration

### Wiring

StemAudioLayer is added as an optional fourth layer in `AudioEngine.setup()`:

```swift
// -- Stem audio layer (v2 — AI-generated content) -----------
let stem = StemAudioLayer(engine: engine, parameters: parameters)
engine.connect(stem.outputNode, to: engine.mainMixerNode, format: nil)
self.stemAudioLayer = stem
```

Stem packs are loaded on demand via `loadStemPack(_:baseURL:)` / `unloadStemPack()`, not during setup.

### Coexistence Rules

When StemAudioLayer is active:
- `MelodicLayer` is **paused** (stems replace individual melodic loops)
- `AmbienceLayer` continues at reduced volume (stems contain their own ambient texture)
- `BinauralBeatNode` is completely unaffected

When no stem pack is loaded:
- Falls back to existing `MelodicLayer` + `AmbienceLayer` behavior
- Zero regression for existing functionality

### AudioEngineProtocol Extension

```swift
/// Load a stem-separated content pack for biometric-adaptive mixing.
/// Falls back to file-based melodic layer if no pack is available.
func loadStemPack(_ pack: StemPackMetadata) throws

/// Whether stem-based mixing is currently active.
var isStemMixingActive: Bool { get }
```

---

## 8. Theme.Audio Extensions

All new constants live in `Theme.Audio.StemMix`:

```swift
enum StemMix {
    // Volume smoothing
    static let volumeSmoothingAlpha: Float = 0.05
    static let updateInterval: TimeInterval = 0.1  // 100ms = 10 Hz
    
    // Focus mode stem volumes per biometric state
    enum Focus {
        static let calm     = StemVolumeTargets(pads: 0.8, texture: 0.7, bass: 0.6, rhythm: 0.4)
        static let focused  = StemVolumeTargets(pads: 0.9, texture: 0.5, bass: 0.7, rhythm: 0.3)
        static let elevated = StemVolumeTargets(pads: 1.0, texture: 0.3, bass: 0.7, rhythm: 0.1)
        static let peak     = StemVolumeTargets(pads: 1.0, texture: 0.2, bass: 0.5, rhythm: 0.0)
    }
    // ... Relaxation, Sleep, Energize (same nested enum pattern)
    
    // Content pack storage
    static let maxStorageMB: Int = 500
    static let minPacksPerMode: Int = 1
}
```

---

## 9. SwiftData Model

```swift
@Model
public final class ContentPack {
    @Attribute(.unique)
    public var id: String
    public var name: String
    public var mode: String           // FocusMode.rawValue
    public var downloadDate: Date
    public var lastPlayedDate: Date?
    public var sizeBytes: Int64
    public var localPath: String      // Relative to Documents/ContentPacks/
    public var generationPrompt: String?
    public var energy: Double
    public var brightness: Double
    public var warmth: Double
    public var playCount: Int
}
```

---

## 10. Implementation Order

| Step | What | Depends On | Effort |
|------|------|-----------|--------|
| 1 | `StemMetadata.swift` — data models | Nothing | 1 hr |
| 2 | `AudioParameters` — add stem volume atomics | Nothing | 30 min |
| 3 | `BiometricStemMixer.swift` — mapping logic | StemMetadata | 2 hrs |
| 4 | `StemAudioLayer.swift` — multi-stem playback | StemMetadata, AudioParams | 4 hrs |
| 5 | Wire into `AudioEngine` | StemAudioLayer | 2 hrs |
| 6 | `Theme.Audio.StemMix` tokens | BiometricStemMixer | 1 hr |
| 7 | `ContentPack.swift` SwiftData model | Nothing | 30 min |
| 8 | `ContentPackManager.swift` | ContentPack, StemMetadata | 3 hrs |
| 9 | `AIContentService` protocol + mock | ContentPackManager | 2 hrs |
| 10 | `SonicProfilePromptBuilder` | SoundProfile | 1 hr |
| 11 | Build plan update | All above | 1 hr |

**Total estimated: ~18 hours of implementation**

---

## Testing Strategy

1. **Unit test BiometricStemMixer** — verify all 4 modes produce correct volume targets for each biometric state
2. **Unit test SonicProfilePromptBuilder** — verify prompt generation from various SoundProfile states
3. **Integration test StemAudioLayer** — load a test stem pack, verify all 4 players start/stop/crossfade
4. **Manual audio test** — listen to stem mixing with simulated biometric input for 30+ minutes, verify smooth transitions and no fatigue
5. **Mock content service** — test full pipeline from "check for updates" through download to playback without server

---

## Migration Path

- **v1.5:** Ship with bundled demo stem packs (created via Demucs from licensed ambient tracks). StemAudioLayer + BiometricStemMixer fully functional. No server needed.
- **v2.0:** ACE-Step server goes live. ContentPackManager downloads personalized packs. SonicProfilePromptBuilder drives generation.
- **v2.5:** Biometric outcome data feeds back into prompt refinement. Weekly auto-refresh of content packs.

---

## What Does NOT Change

- `BinauralBeatNode` — untouched
- `AudioParameters` core fields — untouched (only extended)
- `AmbienceLayer` — untouched
- `MelodicLayer` — untouched (fallback when no stems)
- `SoundSelector` — untouched (continues to work for non-stem content)
- `SoundLibrary` — untouched (stems have their own metadata)
- All existing session flow — untouched
