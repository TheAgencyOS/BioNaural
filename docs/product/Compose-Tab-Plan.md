# Compose Tab — Sound Composer Plan

> Replacing the Explore tab with a guided "choose your own adventure" sound creation experience.

---

## Overview

The Explore tab becomes **"Compose"** — a hub showing saved custom soundscapes with a guided 5-step creation flow. Users build a custom sound by choosing a brain state, building an ambient environment, selecting instruments, adjusting space and mix, then saving. Live audio preview plays throughout the creation process — sound starts at Step 1 and layers build with each choice.

**Core principles:**
- Simplicity above all — one focal point per step, never overwhelming
- Sound starts immediately — the user hears their creation evolving in real-time
- Premium, dark-first UI matching BioNaural's design language
- All values from Theme tokens — no hardcoded colors, spacing, or fonts

---

## Tab Structure

**Tab name:** Compose
**Tab icon:** `slider.horizontal.2.square`
**Replaces:** Explore tab (ExploreView.swift)

### Hub View (ComposerView)

Two zones:

1. **My Sounds grid** — 2-column `LazyVGrid` of glass cards showing saved compositions
2. **Floating "+" button** — bottom-trailing, accent-colored circle, opens creation sheet

**Empty state:** Small breathing Orb (accent-colored) + "Create your first sound" text + single button. Follows the existing empty state pattern elevated with the Orb as focal element.

**Saved composition cards:**
- Glass card with composition name, brain state color dot, instrument icons, ambient label
- **Tap** — starts a full session with those exact sound settings
- **Long-press** — context menu: Edit (re-opens sheet pre-filled), Duplicate, Delete

---

## The 5 Creation Steps

### Step 1: Brain State

The scientific foundation — which brainwave band the binaural beat targets.

**UI:** 2x2 grid of glass cards with mode color glows.

| Choice | Frequency | Color | Description |
|--------|-----------|-------|-------------|
| Deep Focus | Beta 12-20 Hz | Indigo #5B6ABF | Sustained concentration |
| Calm | Alpha 7-12 Hz | Teal #4EA8A6 | Relax and de-stress |
| Sleep | Theta-Delta 1-8 Hz | Violet #9080C4 | Wind down to rest |
| Energy | Beta 14-30 Hz | Amber #F5A623 | Activate and uplift |

Single-tap selects. Selected card gets accent border + mode color glow. **Binaural beat starts playing immediately** via `audioEngine.start(mode:)`.

**Audio effect:** Binaural beats begin within 1 second of first tap.

---

### Step 2: Soundscape

Build an ambient environment with a base layer and optional detail texture.

**Base Environment** — horizontal scroll of glass pills (pick one):
- Rain, Ocean, Forest, River, Wind, Night, Off

**Detail Texture** — horizontal scroll of smaller pills (optional, pick one):
- Distant Thunder, Birdsong, Crickets, Fire Crackle, Wind Chimes, None

**Examples of combinations:**
- Rain + Distant Thunder = cozy storm
- Forest + Birdsong = morning woods
- Ocean + Wind Chimes = zen beach
- Night + Crickets = summer evening

**Audio effect:** Base calls `ambienceLayer.play(bedName:)`. Detail plays on a second player node attached to the ambience submixer.

---

### Step 3: Melodic Layer

Choose instruments and adjust the character of the musical content.

**Instrument selection** — horizontal scroll of pills, multi-select (min 1):
- Piano, Pads, Strings, Guitar, Texture
- Bass and Percussion appear only when Energy brain state is selected

**Character sliders:**
- **Warm <-> Bright** — maps to `brightness` 0.0-1.0 in the sound catalog
- **Sparse <-> Dense** — maps to `density` 0.0-1.0 in the sound catalog

Defaults pre-set from brain state:
- Sleep: low brightness (0.15), low density (0.05)
- Calm: low-mid brightness (0.30), low density (0.20)
- Focus: mid brightness (0.40), mid density (0.30)
- Energy: mid-high brightness (0.65), mid density (0.45)

**Audio effect:** Slider changes debounced 500ms. Filters the 700+ sound catalog by selected instruments + brightness/density ranges, then crossfades to the best-matching sound.

---

### Step 4: Space & Mix

Adjust the reverb depth and balance the three audio layers.

**Space slider** — labeled **Intimate <-> Vast**:

| Position | Reverb Wet/Dry | Feel |
|----------|---------------|------|
| Intimate | 5% | Close, dry, headphone-focused |
| Room | 15% | Natural, present (current default) |
| Hall | 35% | Spacious, open |
| Cathedral | 55% | Epic, immersive |
| Vast | 75% | Ethereal, dreamlike |

At values >50%, the reverb factory preset also switches from medium hall to cathedral for a more convincing space.

**Volume Mix** — 3 labeled sliders:
- **Beats** — binaural beat volume (can make nearly silent for subliminal entrainment)
- **Soundscape** — ambient environment volume
- **Melodic** — musical content volume

**Audio effect:** All changes are live and immediate.

---

### Step 5: Save

Name, configure session settings, and save the composition.

- **Name field** — auto-generated default from selections (e.g., "Rain + Piano Focus"). Editable.
- **Duration picker** — segmented control with mode-appropriate options:
  - Focus: 15, 25, 45, 60, 90 min
  - Calm: 10, 15, 20, 30 min
  - Sleep: 20, 30, 45, 60, 90 min
  - Energy: 10, 15, 20, 30 min
- **Adaptive toggle** — "Adapts to your biometrics when Apple Watch is connected"
- **Save button** — full-width accent button

On save: persists to SwiftData, dismisses sheet, composition appears in hub grid with insertion animation.

---

## Data Model

### CustomComposition (SwiftData @Model)

```
Fields:
- id: UUID (unique)
- name: String
- createdDate: Date
- lastPlayedDate: Date?

Brain State (Step 1):
- brainState: String (FocusMode rawValue)
- beatFrequency: Double (Hz)
- carrierFrequency: Double (Hz)

Soundscape (Step 2):
- ambientBedName: String? (nil = silence)
- detailTextureName: String? (nil = none)

Melodic (Step 3):
- instruments: [String] (Instrument rawValues)
- brightness: Double (0-1)
- density: Double (0-1)

Space & Mix (Step 4):
- reverbWetDry: Float (5-75)
- binauralVolume: Double (0-1)
- ambientVolume: Double (0-1)
- melodicVolume: Double (0-1)

Save (Step 5):
- durationMinutes: Int
- isAdaptive: Bool
```

---

## New Files to Create

| File | Location | Purpose |
|------|----------|---------|
| `CustomComposition.swift` | `Models/` | SwiftData @Model for saved compositions |
| `ComposerView.swift` | `Features/Compose/` | Hub view replacing ExploreView |
| `ComposerSheetView.swift` | `Features/Compose/` | 5-step creation sheet with paged TabView + dot indicators |
| `ComposerViewModel.swift` | `Features/Compose/` | @Observable VM: step tracking, selections, live audio preview |
| `BrainStateStepView.swift` | `Features/Compose/Steps/` | Step 1: 2x2 brain state grid |
| `SoundscapeStepView.swift` | `Features/Compose/Steps/` | Step 2: base + detail texture pickers |
| `MelodicStepView.swift` | `Features/Compose/Steps/` | Step 3: instrument pills + sliders |
| `SpaceMixStepView.swift` | `Features/Compose/Steps/` | Step 4: reverb slider + volume mix |
| `SaveStepView.swift` | `Features/Compose/Steps/` | Step 5: name, duration, adaptive, save |
| `CompositionCardView.swift` | `Features/Compose/` | Reusable glass card for hub grid |

## Files to Modify

| File | Change |
|------|--------|
| `MainView.swift` | Replace ExploreView with ComposerView. Tab label "Compose", icon `slider.horizontal.2.square`. Add `composedSession(CustomComposition)` to AppDestination. Rename `AppTab.explore` to `.compose`. |
| `AppDependencies.swift` | Add `CustomComposition.self` to SwiftData Schema. |
| `AudioEngineProtocol.swift` | Add `ambienceLayer`, `melodicLayer`, `soundLibrary`, `reverb` accessors. |
| `AudioEngine.swift` | Conform to updated protocol. Add `startComposition(composition:)` method. |
| `AmbienceLayer.swift` | Add second AVAudioPlayerNode for detail textures. New: `playDetail(textureName:)`, `stopDetail()`. |
| `SessionViewModel.swift` | Add initializer accepting CustomComposition. |

---

## Implementation Phases

### Phase 1: Data Model + Hub Shell
1. Create CustomComposition model
2. Register in AppDependencies schema
3. Create ComposerView with empty state + grid
4. Create CompositionCardView
5. Replace ExploreView in MainView, update tab

### Phase 2: Creation Sheet Flow (UI only, no audio)
6. Create ComposerViewModel with step tracking
7. Create ComposerSheetView with paged TabView + dots
8. Create BrainStateStepView
9. Create SoundscapeStepView
10. Create MelodicStepView
11. Create SpaceMixStepView
12. Create SaveStepView with SwiftData persistence

### Phase 3: Audio Integration
13. Extend AudioEngineProtocol with layer accessors
14. Add detail texture support to AmbienceLayer
15. Wire live preview in ComposerViewModel (binaural -> ambient -> melodic -> reverb -> volume)
16. Handle sheet dismiss cleanup

### Phase 4: Session Launch
17. Add composedSession case to AppDestination
18. Add startComposition() to AudioEngine
19. Add composition initializer to SessionViewModel
20. Wire tap on card -> configure audio -> navigate to SessionView

### Phase 5: Edit + Polish
21. Edit flow (re-open sheet pre-filled)
22. Duplicate + delete context menu
23. Auto-generated composition names
24. Spring animations on transitions
25. Empty state Orb breathing animation

---

## Key Architecture Decisions

**Live preview lifecycle:** AudioEngine is shared via AppDependencies. ComposerViewModel calls `setup()` + `start(mode:)` on step 1, controls layers as user progresses. Sheet dismiss calls `stop()`.

**Detail texture player:** Second AVAudioPlayerNode added to AmbienceLayer's existing submixer. Same volume control covers both base + detail. Clean architecture — ambient layer manages all environmental sounds.

**Sound selection for preview:** When melodic preferences change, filter SoundLibrary with widening ranges:
1. Mode affinity + instruments + brightness +/- 0.15 + density +/- 0.15
2. If empty: widen to +/- 0.25
3. If still empty: drop instrument filter
4. Play top result via melodicLayer.crossfadeTo()

**Reverb control:** Expose the existing reverb unit through the protocol. ComposerViewModel adjusts wetDryMix directly. At >50%, switch factory preset to cathedral.

**Session launch from composition:** Tap card -> audioEngine.startComposition() configures all 3 layers + reverb from saved values -> navigate to SessionView. Session runs normally (timer, biometric adaptation if enabled, post-session flow).
