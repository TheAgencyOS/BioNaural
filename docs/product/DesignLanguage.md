# BioNaural — Design Language

> A single signal in a dark room. Your body speaks, the sound responds, and the interface disappears.

---

## Design Philosophy

BioNaural is a **signal in noise**. The entire product is about reading a biological signal and translating it into sound. The design language follows the same logic — strip away everything until only the signal remains.

### Borrowed Principles (from AIZEN)
- 8pt grid with 4pt sub-grid, "internal < external" spacing rule
- Spring animations, never legacy timing functions
- Reduce Motion respect as a hard rule, not an afterthought
- Glass materials / Liquid Glass on iOS 26+
- Time-of-day adaptive theming
- Weight hierarchy: regular is the workhorse
- "If you notice it, it's too loud"

### New Principles (BioNaural-Specific)

1. **One element, one screen.** Every screen has exactly one focal point. If you're adding a second, you're adding noise.
2. **Biology over interface.** The app responds to the user's body. The UI should feel like it's part of the user's nervous system — slow when they're calm, subtly warmer when they're elevated.
3. **Sound is the product, screen is the container.** The visual layer exists to hold the audio experience, never to compete with it. The best session is one where the user never looks at the phone.
4. **Earned information.** Data is available, never imposed. The surface is calm. Tap to see more. The user chooses their depth.
5. **No celebrations.** No streaks, no badges, no "great job!" The app respects the state the user is in. Coming out of deep focus, the last thing you need is confetti.

---

## The Orb — Central Visual Metaphor

The heart of BioNaural's visual identity is **The Orb** — a single, soft-edged luminous shape that lives at the center of the session screen. It is the only visual element that matters.

### What It Is
A radial gradient with a soft bloom — not a circle with a hard border. Think bioluminescence. A deep-sea creature pulsing in the dark. A dim star seen through atmosphere.

### What It Does
The Orb is the visual translation of the adaptive audio engine. It maps biometric state to light.

| Biometric State | Orb Behavior |
|----------------|-------------|
| Calm (low HR, high HRV) | Small, cool-toned, slow pulse (~6 sec cycle), low opacity (20%) |
| Focused (steady alpha/beta) | Medium, accent-colored, gentle breathing (~4 sec cycle), medium opacity (30%) |
| Elevated (rising HR) | Larger, warmer edge color, slightly faster pulse (~3 sec), brighter (35%) |
| Peak (high HR, workout) | Largest, warm amber glow, steady pulse (~2 sec), most visible (40%) |
| Adaptation event | Smooth 3–5 sec transition between states. No snapping. |

### Rendering
- **SwiftUI Canvas or Metal shader** for smooth 60fps
- Stacked radial gradients with gaussian blur for the bloom effect
- Uses AIZEN's bloom glow technique (multi-layer stacked shadows) adapted for a radial shape
- At rest: ~25% of screen width. At peak: ~40%. Transitions are slow and eased.
- The bloom extends beyond the core orb as a faint halo — this halo shifts color during adaptation

### Rules
- The Orb never stops moving. Even at its calmest, there's a barely perceptible drift — like watching someone breathe while sleeping.
- The Orb never moves fast. The fastest pulse cycle is 2 seconds. Nothing should feel urgent.
- The Orb is the **only animated element** during a session. Everything else is static or hidden.

---

## Color System

### Foundation — The Dark Field

The canvas is dark, but not dead. A very slight blue undertone gives it depth, like looking into deep water.

| Token | Hex | Usage |
|-------|-----|-------|
| `canvas` | `#080C15` | Primary background — near-black with blue undertone |
| `surface` | `#111520` | Cards, sheets, elevated surfaces |
| `surfaceRaised` | `#1A1F2E` | Active states, pressed cards |
| `divider` | `#1E2336` | Subtle separators (use sparingly) |

### Text — Quiet Hierarchy

| Token | Hex | Opacity | Usage |
|-------|-----|---------|-------|
| `textPrimary` | `#E2E6F0` | 1.0 | Primary text — soft white, never pure #FFF |
| `textSecondary` | `#E2E6F0` | 0.55 | Secondary labels, metadata |
| `textTertiary` | `#E2E6F0` | 0.30 | Hints, disabled, timestamps |
| `textOnAccent` | `#FFFFFF` | 1.0 | Text on accent backgrounds |

### Primary Accent — Periwinkle

**`#6E7CF7`** — a medium periwinkle blue.

Why periwinkle:
- Distinct from AIZEN's mint — this is a new product
- Not the generic "tech blue" (#007AFF) — has personality
- The subtle red warmth in periwinkle prevents it from feeling cold or clinical
- Associates with neural activity, brainwaves, the mind
- Luminous on dark backgrounds without being harsh
- Sits between blue (logic) and violet (creativity) — the focus spectrum

| Token | Hex | Usage |
|-------|-----|-------|
| `accent` | `#6E7CF7` | Primary CTAs, selected states, the Orb's default color |
| `accentWash` | `#6E7CF7` at 5% | Page-level background tint |
| `accentLight` | `#6E7CF7` at 15% | Borders, secondary fills |
| `accentStrong` | `#6E7CF7` at 60% | Prominent indicators |

### Mode Colors — The Spectrum

Each focus mode has a signature color that tints the Orb and the ambient UI during a session. The palette moves from cool (cerebral) to warm (physical).

| Mode | Color | Hex | Why |
|------|-------|-----|-----|
| Focus | Indigo | `#5B6ABF` | Inward, cerebral, deep concentration |
| Relaxation | Soft teal | `#4EA8A6` | Calm, steady, parasympathetic |
| Sleep | Muted violet | `#9080C4` | Expansive, still, descending |
| Energize | Amber-gold | `#F5A623` | Warm, activating, uplifting arousal |

These are intentionally muted (Energize is slightly warmer and more saturated to convey activation). Full-saturation colors would be too loud for an app about focus.

### Biometric Signal Colors

Used for the small biometric readout and Orb color temperature shifts.

| State | Color | Hex | Meaning |
|-------|-------|-----|---------|
| Calm / Recovery | Cool teal | `#4EA8A6` | Low HR, high HRV, relaxed |
| Steady / Focus | Accent periwinkle | `#6E7CF7` | Optimal focus range |
| Elevated | Warm gold | `#D4954A` | Rising HR, increasing intensity |
| Peak | Soft coral | `#D46A5A` | High HR, max effort |

The Orb transitions through these colors as biometric state changes. The transition takes 3–5 seconds — always gradual, never sudden.

### Light Mode

Available but secondary. BioNaural is a dark-mode-first app.

| Token | Dark | Light |
|-------|------|-------|
| `canvas` | `#080C15` | `#F4F4F8` |
| `surface` | `#111520` | `#FFFFFF` |
| `surfaceRaised` | `#1A1F2E` | `#EDEDF2` |
| `textPrimary` | `#E2E6F0` | `#1A1A2E` |
| `accent` | `#6E7CF7` | `#5563D6` (slightly darker for contrast) |
| Mode/signal colors | Full value | 85% saturation (softened for light backgrounds) |

The Orb in light mode renders as a subtle, desaturated wash rather than a luminous glow.

---

## Typography

### Typeface: Satoshi

**One voice, not two.** AIZEN uses dual fonts (serif + sans) because it's a contemplative wellness app with a literary dimension. BioNaural is more focused (literally) — one typeface family reinforces the singularity of purpose.

**Satoshi** (by Indian Type Foundry / Fontshare):
- Neo-grotesque with geometric DNA — clean but not sterile
- Subtle quirks in letterforms (the lowercase 'a', the 'g') give it warmth without being decorative
- Free for commercial use (Fontshare license)
- Variable font available — smooth weight interpolation
- Renders crisply on iOS at all sizes

**SF Mono** for data — timers, HR values, frequency readouts. Creates a clear visual distinction: Satoshi is the interface, SF Mono is the signal.

### Type Scale

| Style | Font | Size | Weight | Usage |
|-------|------|------|--------|-------|
| `display` | Satoshi | 40pt | Light | Mode name on session screen — airy, premium |
| `title` | Satoshi | 28pt | Medium | Screen headers |
| `headline` | Satoshi | 20pt | Bold | Card hooks, section headers that need punch |
| `body` | Satoshi | 17pt | Regular | Primary content |
| `caption` | Satoshi | 13pt | Regular | Secondary labels, metadata |
| `small` | Satoshi | 11pt | Medium | Tertiary info, badges |
| `timer` | SF Mono | 32pt | Light | Session timer (large, airy) |
| `data` | SF Mono | 20pt | Regular | HR readout, frequency display |
| `dataSmall` | SF Mono | 14pt | Regular | Secondary metrics |

### Weight Philosophy
Four weight tiers create clear visual hierarchy:
- **Light** — Display and timer text only (32pt+). Light weight at large sizes feels calm and premium. At small sizes it's unreadable.
- **Medium** — Headers (title) and small labels. The anchor weight for navigation-level text.
- **Bold** — Headline hooks and section headers at 20pt. Punches through without being aggressive — the size/weight ratio keeps it balanced.
- **Regular** — 80% of all text. Body, captions, descriptions. The workhorse.

### Tracking & Leading
- Uppercase labels: +1.0pt tracking (breathable)
- Display text (28pt+): +0.5pt (open)
- Body text: 0 (default)
- Timer/data: +0.5pt (monospace needs room)
- Line spacing: Default for interface text. +4pt for any longer-form content (session summary descriptions).

---

## Spacing

Borrowed directly from AIZEN's proven 8pt system with one addition.

| Token | Value | Usage |
|-------|-------|-------|
| `xxs` | 4pt | Hairline gaps, icon-to-label |
| `xs` | 6pt | Tight vertical padding |
| `sm` | 8pt | Standard sibling spacing |
| `md` | 12pt | Related element spacing |
| `lg` | 16pt | Card internal padding |
| `xl` | 20pt | Page margins, standard card padding |
| `xxl` | 24pt | Generous card padding |
| `xxxl` | 32pt | Major section gaps |
| `jumbo` | 48pt | Screen-level breathing room |
| `mega` | 64pt | Session screen — space around the Orb |

**Page margin:** 20pt
**Card corner radius:** 16pt (continuous squircle, never circular arc)
**Button corner radius:** full-round for primary actions, 12pt for secondary
**The rule:** Internal padding < external gaps. Always.

---

## Animation

### Spring System (Borrowed from AIZEN)

| Preset | Duration | Bounce | Use |
|--------|----------|--------|-----|
| `press` | 0.12s | 0 | Button press scale feedback |
| `standard` | 0.25s | 0 | Toggles, state changes |
| `sheet` | 0.35s | Slight | Sheet/modal presentation |

### Orb Animations (New)

| Animation | Duration | Curve | Description |
|-----------|----------|-------|-------------|
| `orbBreathing` | 4–6s | Custom sine | Continuous slow scale pulse (0.95–1.05) |
| `orbAdaptation` | 3–5s | ease-in-out | Color and size shift during biometric change |
| `orbEntrance` | 1.5s | ease-in | Fade from 0 to resting opacity on session start |
| `orbExit` | 2.0s | ease-out | Slow fade to 0 on session end |
| `orbBloomPulse` | 2.0s | ease-in-out | Halo bloom expands subtly during adaptation |

The Orb's breathing cycle syncs loosely to the binaural beat frequency — not 1:1, but harmonically related. Slower beats = slower visual breathing.

### Wavelength Animations (New)

| Animation | Duration | Curve | Description |
|-----------|----------|-------|-------------|
| `waveScroll` | Continuous | Linear | Constant left-to-right drift, ~20pt/sec |
| `waveAdaptation` | 3–5s | ease-in-out | Frequency and amplitude shift on biometric change |
| `waveEntrance` | 1.0s | ease-in | Draws from center outward on session start |
| `waveExit` | 1.5s | ease-out | Amplitude reduces to flat line, then fades |

The Wavelength animates slightly ahead of the Orb during adaptation — the signal changes before the source visually responds. This reinforces the feeling that the wave is reading your body first.

### Reduce Motion
All Orb animations replaced with static soft gradient at resting opacity. Wavelength replaced with a static horizontal line. Color shifts happen instantly (no animation). Timer updates without transition. The experience is still complete — the audio is the product.

---

## The Wavelength — Live Biometric Signal

A single continuous sine wave drawn horizontally across the session screen. This is the user's body, visualized. Where the Orb is the *feeling*, the Wavelength is the *signal* — you can watch your biometrics translate into sound in real-time.

### What It Is
One smooth, continuous sinusoidal line spanning the full width of the screen, passing directly through the center of the Orb. The Orb sits on top of it — the Wavelength is behind, the Orb is in front. Together they form one composition: a signal with a source.

### How It Maps to Biometrics

| Biometric State | Frequency (visual) | Amplitude | Stroke | Color |
|----------------|--------------------|-----------| -------|-------|
| Calm (low HR, high HRV) | Long, slow waves (~1 cycle per screen width) | Low (±8pt) | 1.5pt | Mode color at 15% opacity |
| Focused (steady state) | Medium waves (~2 cycles) | Medium (±14pt) | 1.5pt | Mode color at 20% opacity |
| Elevated (rising HR) | Shorter waves (~3-4 cycles) | Higher (±22pt) | 2pt | Shifts warmer, 22% opacity |
| Peak (high HR, workout) | Tight waves (~5-6 cycles) | Highest (±30pt) | 2pt | Warm amber, 25% opacity |

The wave is always smooth — cubic bezier interpolation, never jagged. Even at peak intensity, it looks like an ocean swell, not an EKG.

### Rendering Details
- Drawn with SwiftUI Canvas or a single `Path` shape, updated on each biometric sample
- The wave scrolls continuously left-to-right at a slow, constant speed — it's alive even when biometrics are stable
- Transitions between states happen over 3–5 seconds. The wave's frequency and amplitude interpolate smoothly. No jumping.
- A subtle gaussian blur (1-2pt) softens the line — it should feel like light, not ink
- The wave extends edge-to-edge, bleeding off both sides of the screen. No endpoints visible.

### The Orb + Wavelength Relationship
The Orb sits at the vertical center of the Wavelength. The wave passes through the Orb's glow. Visually, the Orb looks like the *source* of the signal — the wave emanates outward from it. The Orb's bloom blends with the wave at the intersection point, creating a natural focal point.

When the biometric state shifts:
1. The Wavelength changes first (frequency/amplitude shift over 3s)
2. The Orb follows (color/size shift over 4-5s)
3. The audio adapts simultaneously with the Wavelength

This creates a perceptible chain: **body changes → wave changes → orb changes → sound has already adapted.** The user sees their biology driving the system.

### Reduce Motion
Wavelength replaced with a static horizontal line at center screen, in the mode color at 15% opacity. A thin, still horizon. The Orb sits on it as a static gradient. Still compositionally complete.

---

## Session Screen — The Primary Experience

This is the screen the user sees during a focus session. It follows the **Void + Orb + Wavelength** pattern.

```
┌─────────────────────────────────┐
│                                 │
│                                 │
│                                 │
│         Focus                   │  ← display, mode color, 40% opacity
│                                 │
│∿∿∿∿∿∿∿∿∿∿( · )∿∿∿∿∿∿∿∿∿∿∿∿│  ← Wavelength + Orb, center screen
│                                 │
│          32:15                  │  ← timer, SF Mono Light, 50% opacity
│                                 │
│                                 │
│                                 │
│                                 │
│         ♡ 64                   │  ← data, SF Mono, 30% opacity, bottom
│           ■                    │  ← stop button, small, recessive
└─────────────────────────────────┘
```

### Hierarchy of Attention
1. **The Orb + Wavelength** — center, the living composition, primary visual
2. **Timer** — below, glanceable, deliberately low opacity
3. **Mode name** — above, context, even lower opacity
4. **Biometric readout** — bottom, barely there, optional glance
5. **Stop button** — bottom center, small, no label

### What's Hidden by Default
- Detailed biometric data (HR, HRV, frequency) — tap anywhere to reveal for 3 seconds, then auto-hide
- Session settings — swipe down from top
- No navigation bar. No tab bar. No status bar tint. Full void.

### Energize Mode Session Behavior
In Energize mode, the Orb pulses faster (~2-3 sec cycle), with warm amber-gold color (#F5A623). Subtle particle effects drift upward from the Orb like rising embers. The Wavelength runs at higher visual frequency (tighter waves). A warm corona radiates from the Orb at slightly higher opacity (35-40%). The overall feel is activating without being aggressive.

### Canvas During Session
The background is `canvas` (#080C15) with a radial gradient of the mode color at 3–5% opacity, centered on the Orb. Barely perceptible — it creates depth without creating distraction. The gradient shifts subtly with time-of-day theming (slightly warmer at night).

---

## Mode Selection — The Entry Point

```
┌─────────────────────────────────┐
│                                 │
│     BioNaural                 │  ← title, Satoshi Medium 28pt
│                                 │
│  ┌────────────┐ ┌────────────┐  │
│  │ ◎  Focus   │ │ ∿  Relax   │  │  ← 2x2 mode grid
│  │ Sustained  │ │ Calm &     │  │     3pt left border in mode color
│  │ attention  │ │ de-stress  │  │     tap to start immediately
│  │ Beta       │ │ Alpha      │  │
│  │ 14–16 Hz   │ │ 8–11 Hz    │  │
│  └────────────┘ └────────────┘  │
│                                 │
│  ┌────────────┐ ┌────────────┐  │
│  │ ·  Sleep   │ │ ⚡ Energize│  │
│  │ Wind-down  │ │ Activate & │  │
│  │ to rest    │ │ uplift     │  │
│  │ Theta→Delta│ │ High-Beta  │  │
│  │ 6→2 Hz     │ │ 18–30 Hz   │  │
│  └────────────┘ └────────────┘  │
│                                 │
│         ♡ Connected        │    │  ← Watch status, tertiary opacity
└─────────────────────────────────┘
```

- **One tap to start.** No duration picker, no settings screen, no confirmation. Tap the card, the session begins. Duration and settings are in a long-press or swipe gesture for users who want them.
- Cards use `surface` background with glass material on iOS 26+.
- The 3pt left border in the mode color is the only color on the page until a card is pressed.
- Watch connection status at the bottom — tertiary opacity, not a banner.

---

## Session Report

```
┌─────────────────────────────────┐
│                                 │
│                                 │
│          48:32                  │  ← timer, SF Mono Light, large
│          Focus                  │  ← caption, mode color
│                                 │
│    Mean HR 64   HRV 48ms      │  ← data readouts, two columns
│    Adaptations (n=8)  Peak 22:14 │
��                                 │
│   [compressed wavelength]      │  ← the session's wavelength history
│                                 │     frozen — color and amplitude shifts visible
│                                 │
│          Done                  │  ← text button, returns to home
│                                 │
└─────────────────────────────────┘
```

- No congratulations. No "nice work." The data speaks.
- The compressed Orb timeline is a thin horizontal bar showing how the Orb's color shifted over the session — a visual record of the adaptation. Cool tones on the left where you started calm, warm bump in the middle where HR elevated, cool again at the end.
- Duration is the hero metric. Everything else is secondary.

---

## Dynamic Island & Live Activity

Since users will have BioNaural in the background during focus sessions, the Dynamic Island is a first-class design surface.

### Compact (Default)
- Leading: Small Orb (8pt), pulsing in mode color
- Trailing: Timer in SF Mono, `textSecondary` opacity

### Expanded
- The Orb, slightly larger (24pt), breathing
- Timer below
- Single HR readout (if Watch connected)
- Mode name in `caption` size

### Lock Screen Live Activity
- Thin bar with mode color gradient
- Timer + mode name
- Minimal — the point is that the user's phone is locked and they're focused

---

## Widgets

### Small Widget
- `canvas` background
- The Orb at center, static (no animation in widgets), mode color
- "Start Focus" label below
- Tap to launch directly into session

### Medium Widget
- Mode selection: 4 mode pills in a row (Focus, Relaxation, Sleep, Energize)
- Last session summary: duration + time ago
- Tap any mode to launch

---

## App Icon

**The Orb.**

- `canvas` (#080C15) background
- A single soft radial gradient in the accent color (#6E7CF7), centered slightly below middle
- Soft bloom extending to ~60% of the icon area
- No text. No symbol. No border. Just the Orb.
- At small sizes (notification badge, Spotlight), it reads as a glowing dot on black — immediately recognizable.

---

## Haptics

Borrowed principle from AIZEN: no haptics during sessions. The phone should feel silent.

| Event | Haptic | When |
|-------|--------|------|
| Mode card tap | `.impact(.light)` | Pre-session only |
| Session start | `.impact(.soft)` | Single gentle tap as audio fades in |
| Session end | `.notification(.success)` | One gentle pulse |
| Tap to reveal data | `.selection` | During session, minimal |
| Button press | `.impact(.light)` | Pre/post session screens |

---

## Accessibility

- **Dynamic Type:** Full support. Session screen stacks vertically at larger sizes.
- **VoiceOver:** Orb described as "Adaptive audio visualization, currently in [calm/focused/elevated] state." Biometric readouts announced with units: "Heart rate: 64 beats per minute."
- **Reduce Motion:** Orb replaced with static soft gradient. All transitions instant. Audio adaptation continues — the experience is complete without animation.
- **Color Blind Safe:** Biometric states communicated through labels and position, never color alone. Mode cards have text names, not just color indicators.
- **High Contrast:** Text opacity values increase. Orb bloom intensity increases. Card borders become visible.

---

## Brand Voice (for App Store, onboarding, any copy)

### Tone: Scientific Confidence
The voice is a calm researcher presenting findings, not a wellness brand selling transformation. BioNaural knows what it does. It doesn't need to convince you. Think: a lab that publishes in Nature doesn't explain what a p-value is on their homepage.

### Language Rules
- Short sentences. No exclamation marks.
- Never says "boost," "optimize," "hack," or "unlock your potential."
- Says: "adapt," "respond," "calibrate," "modulate," "shift."
- Never makes medical claims. "Designed to support focus" — not "improves focus."
- Use precise language where it builds trust: "Mean HR," not "Average heart rate." "Adaptation events (n=8)," not "8 changes." "Session report," not "summary."
- Frequency ranges on mode cards (e.g., "Alpha-dominant, 8–12 Hz") — users who know will trust instantly, users who don't will skip it. Either way it signals credibility.
- "Calibrating..." not "Getting started." "Session" not "playlist." "Signal" not "sound."

### App Store Subtitle
"Biometric Adaptive Audio" — not "Focus Music" or "Binaural Beats App."

### Example Onboarding Copy
> "Calibrating. Sit still for a moment."
> "Your body knows how to focus. BioNaural reads the signal."
> "Pick a mode. The audio adapts in real-time."
> "No playlists. No presets. Just your biometrics."

### Example Session Language
- "Session active" not "You're focusing!"
- "Adaptation event" not "Adjusting your sound"
- "HR elevated — modulating frequency" (in tap-to-reveal detail)
- "Session complete. Report ready." not "Great job! Here's your summary."

---

## Summary

| Decision | Choice | Why |
|----------|--------|-----|
| Visual metaphor | The Orb (soft-edged luminous shape) | Maps to biometric state, feels biological, one element |
| Primary accent | Periwinkle #6E7CF7 | Cerebral, warm enough, distinct from AIZEN's mint |
| Typeface | Satoshi (interface) + SF Mono (data) | One voice, geometric warmth, free commercial license |
| Visual system | Orb + Wavelength | Orb = feeling, Wavelength = signal, together = your body driving sound |
| Session pattern | Void + Orb + Wavelength | Audio is the product, screen disappears |
| Dark mode | Primary and default | Reduces stimulation, premium, OLED-friendly |
| Information model | Earned (tap to reveal) | Respects focus state, no imposed data |
| Celebrations | None | The app respects the user's mental state |
| Primary surfaces | Dynamic Island, Lock Screen, Widget | Users won't be looking at the app during focus |
