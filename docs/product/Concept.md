# BioNaural

> Adaptive binaural audio that listens to your body so you can focus your mind.

---

## Elevator Pitch

Every focus app gives you the same static playlist regardless of what your body is doing. BioNaural is the first app that generates adaptive binaural beats layered with AI-curated melodic content, driven by your real-time biometrics — heart rate, HRV, and activity data from Apple Watch. Pick Focus, Relaxation, Sleep, or Energize, hit start, and three audio layers adapt as your body changes. Heart rate rising during a focus session? The sound calms you down. Winding down for sleep? It reads your descent and fades as you drift off. The app learns which sounds work for YOUR body — every session makes the next one smarter. One button, zero friction, fully adaptive.

---

## The Problem

### Focus Tools Are Static
- Existing binaural beat apps are glorified preset players — pick a frequency, press play
- Brain.fm and Focus@Will use pre-generated tracks with no real-time adaptation
- Your body and mental state change minute to minute, but the audio stays the same
- Users have to manually switch modes or tracks when their state changes

### Wearable Data Goes Unused
- **100M+ Apple Watch users** generating rich biometric data every second
- Heart rate, HRV, and activity data sit in HealthKit doing nothing during focus sessions
- No app creates a real-time feedback loop between your body's signals and your audio environment
- Endel uses some HealthKit data, but the adaptation is shallow and doesn't use binaural beats

### The Science Exists But Nobody's Applied It
- Binaural beats have measurable (if modest) effects on cognition and anxiety — backed by meta-analyses
- HRV biofeedback is well-supported in clinical literature for stress reduction
- Neurofeedback (adapting stimuli to brain/body signals) consistently outperforms static interventions
- Nobody has combined these concepts into a consumer-grade iOS app

---

## The Solution

BioNaural is a simple iOS app that generates adaptive binaural audio in real-time, modulated by your body's signals.

### Core Features (v1 — MVP)

#### Four Modes
- **Focus** — beta frequencies (14–16 Hz), sustained attention, suppresses stress responses
- **Relaxation** — alpha frequencies (8–11 Hz), parasympathetic activation, de-stress
- **Sleep** — theta-to-delta ramp (6→2 Hz over 25 min), mirrors natural sleep onset
- **Energize** — high-beta/low-gamma frequencies (18–30 Hz), uplifting arousal, pre-workout or morning activation

#### Adaptive Audio Engine
- Generates brainwave entrainment programmatically using AVAudioEngine — not pre-recorded tracks
- v1: binaural beats (stereo frequency difference, requires headphones)
- v1.1+: isochronic tones for Focus/Energize modes (amplitude-modulated single tone, no headphones required, stronger cortical response at beta/gamma frequencies). The adaptive engine selects the optimal entrainment method based on target frequency, mode, user preference, and learned biometric outcomes.
- Layers ambient textures and harmonics over pure tones for a musically pleasant experience
- Smooth frequency transitions (no jarring shifts) — user should never notice the adaptation
- Adjusts beat frequency, volume layers, and harmonic complexity based on biometric input

#### Biometric Integration (Apple Watch + HealthKit)
- Real-time heart rate monitoring via WatchOS companion app
- HRV sampling for stress/recovery state detection
- Activity level detection (sedentary vs. active) for automatic mode suggestions
- Graceful degradation — works without Apple Watch using smart presets

#### Simple UI
- One screen: pick a mode, hit start
- Minimal visual feedback — subtle breathing animation or waveform visualization
- Session timer with optional time goal
- Session report (mean HR, HRV trend, adaptation events with count)

### Future Features (v1.5+)

#### ML Personalization (v1.5)
- Per-user frequency optimization via on-device Core ML (learns after 10-20 sessions)
- Sleep onset prediction for smarter auto-fade
- Builds on v1's signal quality scoring model

#### Expanded Context (v1.1-v2)
- Morning sleep report correlating BioNaural sessions with Apple Watch sleep data (v1 — ships at launch)
- Oura/WHOOP API integration for readiness scores and richer pre-session data (v2)
- Polar BLE SDK for real-time HR without Apple Watch (v1.1)

#### Platform Expansion (v2+)
- iPad app with expanded visualizations
- Mac app for desktop focus
- Integration with Shortcuts for automated session triggers
- LLM coaching (aggregated summaries, opt-in, privacy-safe)

---

## How the Adaptive Engine Works

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ Apple Watch  │────▶│  Biometric       │────▶│  Audio Engine    │
│ (Heart Rate, │     │  Processor       │     │  (AVAudioEngine) │
│  HRV, Motion)│     │  - Trend analysis│     │  - Frequency     │
└─────────────┘     │  - State detect  │     │  - Amplitude     │
                    │  - Zone mapping  │     │  - Layers        │
                    └──────────────────┘     └─────────────────┘
```

### Adaptation Logic

| Biometric Signal | Focus Response | Relaxation Response | Sleep Response | Energize Response |
|-----------------|---------------|-------------------|---------------|------------------|
| HR rising | Lower frequency toward alpha (calming) | Gently increase to 11-12 Hz to "catch," ramp back down | Ignore (normal during onset) | Reinforce — push toward high-beta (25-30 Hz) |
| HR falling | Maintain beta (steady focus) | Sustain alpha (on track) | Deepen toward delta | Lift frequency to sustain arousal |
| HRV dropping (stress) | Introduce calming alpha layers | Shift toward lower alpha (8-9 Hz) | Hold current frequency | Sustain current — some stress is expected |
| HRV rising (recovery) | Maintain current (optimal focus) | Sustain — user is relaxing | Deepen toward delta | Maintain — balanced activation |
| Sustained stillness | Maintain (good sign) | Sustain (deep relaxation) | Begin audio fade-out (sleep detected) | Gently increase to re-energize |

### Frequency Reference

| Band | Range | Mental State | Used In |
|------|-------|-------------|---------|
| Delta | 0.5–4 Hz | Deep sleep, healing | Sleep (target) |
| Theta | 4–8 Hz | Drowsiness, creativity | Sleep (starting point), deep Relaxation |
| Alpha | 8–13 Hz | Relaxed wakefulness, calm focus | Relaxation (primary), Focus (calming) |
| Beta | 13–30 Hz | Active thinking, concentration | Focus (primary), Energize (high-beta 18-30 Hz) |

---

## Target Audience

### Primary: Knowledge Workers with Apple Watch (25–45)
- Remote/hybrid workers who struggle with focus and distractions
- Already invested in the Apple ecosystem and wearable health tracking
- Familiar with concepts like deep work, flow state, Pomodoro
- Willing to pay for tools that measurably improve productivity

### Secondary: Fitness Enthusiasts / Biohackers
- Quantified self community — track everything, optimize everything
- Already wearing Apple Watch during workouts
- Interested in any edge for performance and recovery
- Active on Reddit (r/biohacking, r/nootropics), podcasts, YouTube

### Tertiary: Meditation / Mindfulness Practitioners
- Regular meditators looking for deeper sessions
- Interested in binaural beats but frustrated by static apps
- Value the biometric feedback as validation of their practice

---

## Competitive Landscape

| App | Binaural Beats | Adaptive Audio | Real-Time Biometrics | Focus Modes | Design Quality | Price |
|-----|:-:|:-:|:-:|:-:|:-:|:-:|
| **BioNaural** | Yes | Yes (biometric-driven) | Yes (Apple Watch) | Yes | Premium | TBD |
| Brain.fm | No (AI music) | No | No | Yes | Good | $50/yr |
| Endel | No (ambient) | Partial (shallow) | Partial (HR + motion) | Yes | Excellent | $50/yr |
| Focus@Will | No (curated music) | No | No | Yes | Dated | $70/yr |
| Noisli | No (ambient noise) | No | No | No | Good | $10/yr |
| BrainWave | Yes | No | No | Yes (presets) | Basic | $5 one-time |
| Binaural Beats Therapy | Yes | No | No | Yes (presets) | Poor | Free + ads |

**BioNaural's moat:** Only app combining real-time binaural beat generation with a closed biometric feedback loop. Personalization data compounds over time — the longer you use it, the better it knows your body.

---

## Monetization

### Freemium Model

**Free Tier:**
- 2 modes (Focus + Relaxation)
- Binaural beats with basic time-based adaptation (not biometric)
- 3 sessions per day
- Session history (last 7 days)

**Premium ($5.99/mo or $49.99/yr or $149.99 lifetime):**
- All 4 modes (Focus, Relaxation, Sleep, Energize)
- Full biometric adaptation (Apple Watch / Polar / BLE HR)
- Unlimited sessions, unlimited duration
- Session analytics and trends
- All sound environments
- Offline mode

### Future Revenue
- B2B licensing (corporate wellness — requires SOC 2, admin dashboards, SSO)
- Partnerships with Apple (ecosystem showcasing)

---

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Platform | iOS 17+ / watchOS 10+ (Swift / SwiftUI) | Native performance for real-time audio + Watch integration |
| Audio Engine | AVAudioEngine + AVAudioSourceNode | Real-time synthesis, low latency, background audio support |
| Biometrics | HealthKit + WatchConnectivity | Real-time HR during workout sessions, HRV sampling |
| ML (v1) | Core ML — signal quality scoring | On-device, ~50KB model. Scores biometric sample reliability for adaptive engine. |
| ML (v1.5) | Core ML — personalization + sleep onset | Per-user frequency optimization + predictive sleep fade |
| Local Storage | SwiftData | Session history, user preferences, baseline data |
| Cloud Sync | CloudKit | Free, private sync across devices |
| Auth | Sign in with Apple | Frictionless, privacy-first |
| Analytics | TelemetryDeck | Privacy-respecting, App Store compliant |
| Payments | StoreKit 2 | Native subscriptions |

---

## Design Principles

- **Calm and minimal** — the app should feel like the focus state it creates
- **Scientific confidence** — precise language, not wellness fluff. "Calibrating," not "Getting started." "Session report," not "Summary." The tone is a researcher presenting findings.
- **One action to start** — pick mode, tap go. No configuration required.
- **Invisible adaptation** — the user should feel the effect, not see the machinery
- **Dark mode first** — less visual stimulation, premium feel
- **Subtle feedback** — gentle waveform or breathing animation, never distracting
- **Headphone-first** — clear onboarding that binaural beats require stereo headphones. Isochronic tones (v1.1+) unlock speaker mode for Focus/Energize.

---

## Go-to-Market

### Phase 1: Build & Validate (Months 1–3)
- Ship MVP with all 4 modes: Focus + Relaxation + Sleep + Energize
- Binaural beat engine with Apple Watch HR adaptation
- Spatial Audio test tone in onboarding (critical UX for AirPods users)
- TestFlight beta with 50-100 users from r/productivity, r/biohacking, r/AppleWatch
- Validate that users notice and value the adaptive behavior

### Phase 2: Launch (Months 4–6)
- App Store launch with ASO optimization
- Product Hunt launch
- Content marketing: "I let my Apple Watch control my focus music for 30 days"
- Micro-influencer outreach (productivity/biohacker YouTubers, 10K-50K followers)
- Apple editorial pitch (target May — Mental Health Awareness Month)

### Phase 3: Grow (Months 7–12)
- ML personalization (v1.5 — per-user frequency + sound optimization)
- Oura/WHOOP API integration for pre-session context
- Polar BLE SDK for non-Watch real-time HR
- Apple feature pitch with full platform integration story

### Phase 4: Expand (Year 2)
- iPad/Mac apps
- LLM coaching (opt-in, privacy-safe)
- International localization (Japanese, German, Korean)
- Evaluate B2B wellness (requires significant additional infrastructure)

---

## Key Metrics

| Metric | Target (Month 6) | Realistic Benchmark |
|--------|------------------|-------------------|
| Downloads | 5,000 | Organic + ASO + Product Hunt. No paid acquisition budget. |
| DAU/MAU ratio | 20%+ | Industry median for wellness: 15-25%. |
| Avg session length | 20+ min | 15 min minimum for binaural beat efficacy. |
| Sessions per user/week | 3+ | Habit formation threshold. |
| Premium conversion | 4-5% | Industry median for Health & Fitness. |
| Retention (Day 7) | 18%+ | Good for wellness category. |
| Retention (Day 30) | 10%+ | Top quartile for Health & Fitness. |
| App Store rating | 4.5+ | Requires solving AirPods Spatial Audio UX. |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Scientific claims scrutinized | Position as "adaptive wellness audio," not medical treatment. Use measured language: "designed to support focus." Never claim to treat ADHD, anxiety, or any condition. |
| Requires Apple Watch for full experience | Works without Watch using smart presets. Watch integration is the premium differentiator, not a hard requirement. |
| Requires headphones for binaural beats | Clear onboarding. Most knowledge workers and gym-goers already use headphones/earbuds. Isochronic tones (v1.1+) remove this requirement for Focus/Energize modes. |
| Battery drain from continuous HR monitoring | Session-based design (30–120 min), not always-on. Communicate expected battery impact. |
| Endel adds deeper biometric features | Move fast, go deeper on binaural beats specifically. Endel is ambient soundscapes — different product category. Build the personalization moat. |
| Subscription fatigue in wellness apps | Strong free tier that's genuinely useful. Premium unlocks the "magic" (biometric adaptation). One-week free trial. |
| Audio quality — pure sine waves are fatiguing | Layer ambient textures, nature sounds, and harmonics. Invest in sound design early. Partner with audio designers. |
