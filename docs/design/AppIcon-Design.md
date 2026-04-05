# BioNaural App Icon: Design Specification

> Synthesized from research on Apple HIG, competitor audit, color psychology, iconography, and featuring patterns.

---

## The Concept: "The Living Signal"

A luminous orb radiating a subtle interference pattern on a deep dark canvas. It depicts **the phenomenon itself** — the interaction of frequencies creating an emergent pattern — not a brain, not headphones, not a generic sine wave.

**One sentence:** A glowing periwinkle orb with a faint binaural interference ripple, centered on near-black.

---

## Why This Works

### Against Competitors

| App | Icon | BioNaural's Contrast |
|---|---|---|
| Brain.fm | Purple wave lines on dark | BioNaural: luminous orb, not lines |
| Endel | Geometric glyph on black | BioNaural: organic glow, not geometric |
| Calm | Blue landscape gradient | BioNaural: abstract signal, not nature |
| Headspace | Orange dot on white | BioNaural: dark + periwinkle (different temperature AND background) |
| Pzizz | Purple "P" gradient | BioNaural: no letterform, pure symbol |
| myNoise | Waveform on dark | BioNaural: orb, not waveform |

BioNaural's icon occupies **unique visual territory**: the only luminous orb on dark canvas in the category, with a color (periwinkle) that sits between the blues and purples everyone else uses.

### For Apple Featuring
- Single bold element (orb) — instant readability at all sizes
- Dark background with high-contrast glow — pops on both light and dark App Store
- Gradient (radial glow, not flat) — matches Apple's own design language
- No text, no fine detail — scales from 29pt to 1024pt
- Distinctive silhouette — recognizable even as a 16x16 favicon

---

## Color Specification

### Background
```
#080C15 (near-black with blue undertone)
```
The app's existing dark canvas. Deep enough to feel premium, blue-shifted enough to not disappear on pure-black OLED screens.

### Orb (Primary Element)
```
Core highlight:     #E8EAFF (near-white with cool tint)
Mid glow:           #6E7CF7 (periwinkle — the brand accent)
Outer glow:         #4A54C4 (deeper indigo)
Ambient bleed:      #6E7CF7 at 15-20% opacity (extends to ~85% of icon width)
```

Radial gradient from bright core to deep edge, with a soft ambient bleed that simulates light cast onto the canvas.

### Subtle Chromatic Rim (Optional)
A 2-3px band at @3x around the orb's edge, hinting at mode colors:
```
Indigo → Teal transition on one side
OR
Periwinkle → Amber-gold shift on the opposing edge
```
Keep this extremely subtle — it should be felt, not consciously seen. If it doesn't read at 87px, remove it.

---

## Composition

### Layout
- **Centered** — at small sizes, asymmetric placement reads as a mistake
- **Orb fills 60-70%** of the icon area
- **Safe zone:** Keep all visual weight in center 70% (superellipse clips corners)
- **Avoid top-right quadrant** for critical detail (notification badge overlap)

### Structure (Layers, Back to Front)

1. **Canvas** — solid #080C15 fill
2. **Ambient glow** — large soft radial, periwinkle at 15-20% opacity, extends to 85% of icon width. This is what separates a "glowing orb" from a "flat circle."
3. **Interference pattern** — extremely subtle concentric ripples or Lissajous-style distortion radiating from the orb. Should be barely visible at 60pt, more apparent at 1024pt. This is the "binaural beats made visible" element.
4. **The Orb** — radial gradient, bright core to deep periwinkle edge
5. **Specular highlight** — small, soft, off-center bright spot in upper-left third. Adds dimensionality. Keep soft — hard highlights look dated.
6. **Chromatic rim** (optional) — hair-thin color shift around orb edge

### What NOT to Include
- No text or letterforms
- No brain silhouette
- No headphones
- No explicit sine wave / waveform
- No headphone + brain combo
- No concentric radar ripples
- No all-four-mode-colors rainbow

---

## Size & Format Requirements

### Master Asset
- **1024 x 1024 px**, PNG, no transparency, no alpha channel
- sRGB color space
- No rounded corners (iOS applies superellipse mask automatically)

### Critical Test Sizes

| Size | Context | What Must Read |
|---|---|---|
| **87px** (@3x of 29pt) | Settings | Bright orb on dark — that's it |
| **120px** (@3x of 40pt) | Spotlight | Orb + glow visible |
| **180px** (@3x of 60pt) | Home screen | Orb + glow + hint of interference |
| **1024px** | App Store | Full detail: interference pattern, chromatic rim, specular highlight |

**Design rule:** If the glow and shape don't read at 87px, iterate before refining the large version.

---

## Rendering Approach

### Option A: "Pure Orb" (Recommended for v1)

The simplest, boldest version. A single luminous periwinkle sphere on dark canvas with ambient glow. No interference pattern, no chromatic rim. Maximum clarity at all sizes.

```
Layers:
1. #080C15 background
2. Soft radial glow (periwinkle, 20% opacity, fills 85% width)
3. Orb: radial gradient #E8EAFF center → #6E7CF7 mid → #4A54C4 edge
4. Specular highlight: soft white spot, upper-left, 30% opacity
```

**Pros:** Cleanest read at small sizes. Most "Apple-approved" in simplicity. Instantly distinctive in the category.
**Cons:** Doesn't communicate "audio" or "waves" — relies entirely on the orb as brand mark.

### Option B: "The Signal" (Recommended for Testing)

The orb with a faint interference/Lissajous pattern in the ambient glow layer. The pattern is visible at 180px+ but dissolves to pure glow at small sizes.

```
Layers:
1. #080C15 background
2. Interference pattern: 2-3 subtle concentric wave distortions in the glow field,
   periwinkle at 8-12% opacity. Spacing follows binaural beat interference math.
3. Soft radial glow (periwinkle, 15% opacity, fills 85% width)
4. Orb: radial gradient #E8EAFF center → #6E7CF7 mid → #4A54C4 edge
5. Specular highlight
```

**Pros:** Communicates "frequency interaction" at larger sizes. Scientifically grounded. Unique in category.
**Cons:** Risk of visual noise at small sizes. Must be extremely subtle.

### Option C: "Sunrise Orb" (Bold Differentiator)

A warm-cool gradient orb that shifts from periwinkle to amber-gold, suggesting the full daily cycle (calm → energized). More colorful, more distinctive in search results.

```
Layers:
1. #080C15 background
2. Ambient glow: warm-cool split (periwinkle left, amber-gold right, 15% opacity)
3. Orb: radial gradient with chromatic shift — upper-left periwinkle, lower-right
   amber warmth. Core remains bright white.
4. Specular highlight
```

**Pros:** Immediately stands out in the blue-purple sea. Communicates "energy + calm" duality. Warmer than any competitor.
**Cons:** Two-color orb may not read as cleanly as mono. Could look like a generic gradient.

---

## Recommendation

**Produce all three options.** Test Option A vs B vs C with:

1. **87px render test** — which reads clearest at Settings size?
2. **Category screenshot test** — place each option in a simulated App Store search result alongside Brain.fm, Endel, Calm, Headspace. Which one pops?
3. **Squint test** — blur your screen. Which icon's shape and luminosity survives?

**Prediction:** Option A will win on clarity. Option C will win on differentiation. Option B is the compromise.

---

## iOS 18+ Dark Mode & Tinted Variants

iOS 18 introduced automatic dark mode and tinted icon variants. Plan for:

- **Light mode:** Icon as designed (dark background pops against light wallpaper)
- **Dark mode:** Icon as designed (dark background blends — consider a very subtle 1px lighter border at 5% opacity to maintain edge definition)
- **Tinted mode:** Apple desaturates and applies a tint. The orb's luminosity should survive desaturation — test in grayscale to verify the glow reads without color

---

## Production Checklist

- [ ] Design at 1024x1024 in Figma/Sketch/Illustrator
- [ ] Export PNG, sRGB, no transparency
- [ ] Test at 87px, 120px, 180px, 1024px
- [ ] Test against competitors in simulated search results
- [ ] Test on light and dark home screens
- [ ] Test iOS 18 tinted mode (grayscale survivability)
- [ ] Test with notification badge overlay (top-right)
- [ ] Verify no critical detail in corner clip zones
- [ ] Get feedback from 5+ non-designer humans ("what does this app do?")

---

## Design Principles (From DesignLanguage.md)

These apply to the icon as they apply to the app:

- **"One element, one screen"** → One element, one icon: The Orb.
- **Dark-first canvas** → #080C15 background
- **Periwinkle accent** → #6E7CF7 as hero color
- **No celebrations, no streaks** → No flashy embellishments. Quiet confidence.
- **Earned information** → The full mode color palette is earned by using the app, not shown in the icon.

---

## One-Line Brief for a Designer

> "A single luminous periwinkle orb, glowing softly on a near-black canvas. It should feel like staring at a calm, intelligent light source — alive but not aggressive. Think: the moment before a star pulses. No text, no brain, no headphones."
