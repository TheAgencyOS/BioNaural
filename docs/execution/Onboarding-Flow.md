# BioNaural ��� Onboarding Flow

> The first 3 minutes determine whether the user stays or leaves. Every screen earns the right to ask for the next permission.

---

## Flow Overview

```
Launch → Welcome (3 screens) → Headphone Check → Spatial Audio Test Tone
    → Epilepsy Disclaimer → HealthKit Permission → Watch Detection
    → Optional Calibration → First Session
```

**Total: 8-10 screens, ~2-3 minutes.** No screen is skippable except calibration.

---

## Screen 1: Welcome — What BioNaural Does

> "Your brain runs on rhythms. BioNaural uses sound to guide them."

One sentence. The Orb animates gently in the center. Dark background. No buttons except "Continue."

**Purpose:** Set the mood. This is calm, not corporate.

---

## Screen 2: How It Works

> "Two slightly different tones — one in each ear. Your brain perceives a third rhythm. That rhythm gently nudges your brainwaves toward the state you choose."

Simple animation: two sine waves merging into a pulsing beat.

**Purpose:** The user understands the core mechanism in 5 seconds.

---

## Screen 3: The Adaptive Difference

> "Most apps play static audio. BioNaural reads your heart rate and adapts in real time. The sound responds to your body — not a preset."

Brief animation: a Wavelength shifting as a heart icon pulses.

**Purpose:** The differentiator. Why this isn't just another binaural beats app.

---

## Screen 4: Headphone Check (MANDATORY)

**Detect audio route via `AVAudioSession.sharedInstance().currentRoute`.**

**If headphones detected:**
> "Headphones connected. You're ready."
> [Continue]

**If speaker/no headphones:**
> "Binaural beats require headphones to work. Each ear needs to hear a different frequency — speakers blend the sound and the effect disappears."
> "Please connect any stereo headphones or earbuds."
> [Waiting for headphones... / Skip (not recommended)]

Skip is available but clearly marked as degrading the experience.

---

## Screen 5: Spatial Audio Test Tone (CRITICAL — MANDATORY FOR AIRPODS)

**This is the single most important UX flow in the app.** Without it, a large percentage of AirPods Pro/Max users will have a broken experience and never know why.

**If AirPods detected** (check `currentRoute.outputs` for port name containing "AirPods"):

> "One more thing for AirPods users."
>
> "Spatial Audio can interfere with binaural beats. Let's do a quick 10-second test to make sure everything is set up correctly."
>
> [Start Test]

**The test:**
1. Play a clear binaural beat at 10 Hz with a 400 Hz carrier for 10 seconds
2. The user should hear a distinct pulsing/wobbling in the center of their head
3. After 10 seconds, ask:

> "Did you hear a steady pulsing or wobbling sensation?"
>
> [Yes, I heard it] → "Perfect. You're set up correctly." → Continue
>
> [No / Not sure] → Show instructions:
> "Spatial Audio is likely on. To fix this:
> 1. Open Control Center (swipe down from top-right)
> 2. Long-press the volume slider
> 3. Tap 'Spatialize Stereo' to turn it off
> 4. Then tap 'Try Again' below"
>
> [Try Again] → Replay test
> [Continue Anyway] → Available but warns: "The binaural effect may be reduced."

**If non-AirPods headphones:** Skip this screen entirely. Spatial Audio only affects AirPods.

**Programmatic mitigation (belt-and-suspenders):**
Also set `engine.outputNode.spatializationEnabled = false` and `session.setSupportsMultichannelContent(false)` regardless. The test tone is the user-facing layer; the API calls are the technical layer.

---

## Screen 6: Epilepsy Disclaimer (MANDATORY)

> **Safety Information**
>
> A small number of people may experience adverse effects from rhythmic audio frequencies. If you have epilepsy or any seizure disorder, please consult your physician before using this app.
>
> Discontinue use if you experience dizziness, disorientation, or any unusual sensation.
>
> [I understand — Continue]

**Must tap to acknowledge.** No auto-dismiss. No skip. This is legal protection AND genuine user safety.

---

## Screen 7: HealthKit Permission

> "BioNaural uses your heart rate to adapt the audio in real time. The more it knows about your body, the better the experience."
>
> "All health data stays on your device. We never see it."
>
> [Connect Apple Health] → triggers `HKHealthStore.requestAuthorization`
> [Maybe Later] → app works without, no adaptation

**Request only what's needed:**
- Read: heartRate, heartRateVariabilitySDNN, restingHeartRate, sleepAnalysis
- Write: mindfulSession

**If denied:** App works as a time-based binaural beats player. The mode selection screen shows a subtle "Connect Apple Health for adaptive audio" prompt.

---

## Screen 8: Watch Detection

**Check `WCSession.default.isPaired` and `isWatchAppInstalled`.**

**If Watch paired + app installed:**
> "Apple Watch detected. BioNaural will read your heart rate during sessions for real-time adaptation."
> [Continue]

**If Watch paired + app NOT installed:**
> "You have an Apple Watch but the BioNaural companion app isn't installed yet. Install it for real-time heart rate adaptation."
> [Open Watch App Store] / [Skip for Now]

**If no Watch:**
> "No Apple Watch detected. BioNaural still works — sessions use smart time-based arcs instead of biometric adaptation."
>
> "For the full adaptive experience, pair an Apple Watch or connect a Bluetooth heart rate monitor in Settings."
> [Continue]

---

## Screen 9: Optional Calibration (Skippable)

**Only shown if HealthKit + Watch are connected.**

> "Want to calibrate? Sit still for 2 minutes and we'll learn your resting heart rate and HRV baseline. This makes the adaptive engine more accurate from your first session."
>
> [Start Calibration] → 2-minute timer, collecting HR/HRV baseline
> [Skip — Use Defaults] → Uses population defaults (HR 72, HRV lnRMSSD 3.5)

During calibration: show the Orb breathing gently, a countdown timer, and real-time HR as it appears.

After calibration:
> "Your resting heart rate: 62 BPM. HRV baseline: 45ms. We'll use this to personalize your sessions."
> [Start Your First Session]

---

## Screen 10: First Session Launch

Mode selection screen appears. The user picks a mode and starts their first session.

**Contextual science card appears** on the selected mode (first time only):
- Focus: "Beta-range binaural beats are associated with sustained attention..."
- Relaxation: "Alpha-range beats have the strongest anxiety reduction evidence..."
- Sleep: "Sleep mode mirrors your brain's natural descent..."

---

## Edge Cases

| Scenario | Handling |
|----------|---------|
| User force-quits during onboarding | Resume from last completed screen on next launch |
| User denies HealthKit then wants it later | Settings → Connected Services → Reconnect Apple Health (deep link to Settings) |
| AirPods disconnect mid-test-tone | Detect route change, pause test, prompt to reconnect |
| User has Beats/Sony headphones (not AirPods) | Skip Spatial Audio test — only AirPods have Spatial Audio |
| User is deaf/HoH | Headphone check shows: "BioNaural is primarily an audio experience. Visual and haptic elements are available." Offer isochronic mode if implemented. |
| User is under 13 | Age gate per COPPA. Consider 13+ or 18+ given binaural beat considerations. |

---

## Permission Request Order

The order is deliberate — each screen earns the right to the next ask:

1. **No permission needed** — Welcome, mechanism explanation, differentiator
2. **Headphone check** — AVAudioSession (no permission prompt, just route detection)
3. **Spatial Audio test** — plays audio (no new permission)
4. **Epilepsy disclaimer** — user acknowledgment (no system permission)
5. **HealthKit** — first real system permission prompt. User already understands WHY.
6. **Watch detection** — no prompt, just checking status
7. **Calibration** — optional, uses already-granted HealthKit

**Never ask for a permission before explaining why it matters.**
