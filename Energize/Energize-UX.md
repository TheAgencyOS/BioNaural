# Energize Mode: UX & Platform Integration

> Visual design, onboarding, Pomodoro, Watch, AirPods, and naming considerations.

---

## Visual Design: The Orb

### Color: Amber-Gold (#F5A623)

**Design principle: "Sunrise, not siren."**

| Mode | Color | Temperature |
|---|---|---|
| Focus | Indigo | Cool |
| Relaxation | Teal | Cool |
| Sleep | Violet | Cool |
| **Energize** | **Amber-Gold (#F5A623)** | **Warm** |

Maximum distance from the cool palette. Amber-gold sits in the sweet spot of high arousal without negative valence (Valdez & Mehrabian, 1994). Orange-amber = enthusiasm, vitality. Gold = sunlight, morning energy, optimism. **Red is contraindicated** (activates avoidance motivation, reads as stress).

### Orb Animation

| Property | Energize | Focus | Relaxation | Sleep |
|---|---|---|---|---|
| Pulse rate | 80-100 BPM (elevated heart rate cadence) | Steady glow | Gentle waves | Slow pulse |
| Particles | Rising upward (embers, sunlit dust) | None | None | None |
| Corona | Expanding/contracting warm glow | Subtle | None | Dim |
| Color shimmer | Micro-oscillation amber ↔ gold | Static | Static | Static |

**Rising particles** are the key differentiator — upward motion universally signals energy, growth, positivity. Downward/explosive motion reads as agitation.

---

## Naming

### Recommendation: "Energize" (or Consider "Alert")

**Pattern analysis:** Focus, Relaxation, Sleep are all states of being (nouns). An action verb ("Energize") breaks this pattern.

| Name | Type | Fits Pattern? | Trademark Risk | Notes |
|---|---|---|---|---|
| **Alert** | State ✓ | Yes | Very low | Strongest pattern match. Focus, Relaxation, Sleep, Alert. |
| **Energize** | Action verb | No | Moderate (Gatorade) | Most intuitive for the feature. Marketing-friendly. |
| **Awake** | State ✓ | Yes | Low | Softer, more approachable. Morning-coded. |
| Rise | State/verb | Borderline | Low-moderate (Rise Science exists) | Aspirational but competitor conflict |
| Boost | Verb | No | High (Nestle) | Too casual, marketing-heavy |
| Spark | Noun/verb | Borderline | Moderate | Creative connotation, implies brevity |

**If pattern consistency matters most:** "Alert" — reads as four clean mental states.
**If marketing impact matters most:** "Energize" — most immediately understood.

---

## Onboarding Impact

### Decision Paralysis: Low Risk
Going from 3 to 4 modes is marginal on Hick's Law (logarithmic, not linear). The four modes form a natural energy gradient: Energize > Focus > Relaxation > Sleep.

### UI: 2x2 Grid
Three modes likely use a vertical list. Four opens a **2x2 grid** — actually more balanced visually. Each cell: Orb in mode color + name + one-line descriptor.

### Don't Add an Onboarding Screen
Energize appears in the mode selection screen (Screen 10 of existing flow) with its contextual science card on first tap — same pattern as the other three modes. No additional onboarding length.

### Free Tier: 2 of 4 Modes
- Free: Focus + Energize (highest immediate value)
- Premium: All 4 modes + biometric adaptation + unlimited sessions
- 3 sessions/day cap unchanged — now creates productive friction across 4 modes

---

## Pomodoro Integration

### Energize as Session Opener (Not Per-Pomodoro)

Adding 5 min to every 25-min block inflates each cycle by 17%. Instead:

```
Energize (5 min) → Focus (25 min) → Relaxation (5 min) → 
Focus (25 min) → Relaxation (5 min) → ...
```

Energize precedes the **first** Focus block only. Users can re-trigger before any block if sluggish, but it's not automatic.

**"The app doesn't just sustain focus, it helps you get there."**

### Timer UI
- Three-phase ring: Amber (Energize) → Blue (Focus) → Green (Relaxation)
- "Start with Energize?" toggle — defaults ON for first block
- Skip affordance always available (power users will want this)

---

## Apple Watch Integration

### Energize Is Fundamentally Different on Watch

| Aspect | Energize (Watch) | Focus/Sleep (iPhone) |
|---|---|---|
| Duration | 2-5 min | 25-60 min |
| Primary output | Haptics + simple visuals | Binaural audio |
| Trigger | Proactive / on-demand | Scheduled / intentional |
| Sensor use | Real-time HRV + motion | Background monitoring |

The Watch Energize experience is a **quick intervention tool** — bite-sized, haptic-driven, triggered by detected fatigue.

### Complication
WidgetKit accessory widget displaying energy score derived from HRV + HR + activity patterns. Predictive, not just reflective — shows where the user is on their personal energy curve.

### Proactive Notifications
"Your energy usually drops around 2:30 PM — start a 5-minute Energize session?"

Triggered against predicted dip window using multi-day HRV and activity pattern analysis. Requires background app refresh, no server needed. Available after 7-14 days of baseline data.

### Standalone Watch Sessions
- **Haptic patterns** via `WKInterfaceDevice.play(_:)` for rhythmic breathing guidance
- `HKWorkoutActivityType.mindfulness` for Mindfulness ring credit
- `ExtendedRuntimeSession` to keep app active on-wrist

---

## AirPods Integration

### Head Movement as Activation Signal

`CMHeadphoneMotionManager` flips from Relaxation's stillness metric to an activation metric:

| Signal Combination | Interpretation | Action |
|---|---|---|
| Rising head movement + rising HR | Confirmed activation | Continue/intensify |
| Rising HR + no head movement | Possible anxiety | Back off stimulation |
| Low movement + low HR | Still fatigued | Increase stimulation |

This creates a **three-axis arousal model** (head movement + HR + beat frequency) no competitor can replicate.

### Adaptive Transparency Recommendation
No API to control it, but prompt users: "For Energize, try Adaptive Transparency" — lets them hear energizing audio while staying aware of environment (useful for pre-workout).

### Spatial Audio: Must Remain Disabled
Same as all modes — stereo separation is essential for binaural beats.

---

## Session Duration Presets

| Preset | Duration | Default For |
|---|---|---|
| Quick Boost | 5 min | Watch standalone, pre-meeting |
| Standard | 10 min | Afternoon slump, general use |
| Morning Ramp | 15 min | Wake-up, pre-workout |
| Deep Energize | 20 min | Jet lag, severe fatigue |

Default: 10 minutes. Maximum: 20 minutes (sustained sympathetic drive beyond this increases cortisol without benefit).
