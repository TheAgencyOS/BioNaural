# BioNaural — Product Overview

## What Is It?

BioNaural is an iOS app that generates adaptive binaural beats layered with AI-curated melodic content, driven by real-time biometrics and a continuously improving user model. It reads your body's signals — heart rate, HRV, movement, sleep patterns — and tunes the audio in real time to help you focus, relax, sleep, or energize. The more you use it, the smarter it gets.

## The Core Idea

Most binaural beat apps play static audio tracks. BioNaural is different: it synthesizes audio in real time and adapts it based on what your body is actually doing. The product **is** the feedback loop — your biometrics shape the sound, the sound shapes your state, and the system learns what works for you specifically.

After ~50 sessions, BioNaural knows both what you *say* you need and what your body *actually* needs — and when those differ.

## Four Modes

| Mode | Purpose | Beat Range | Behavior |
|------|---------|------------|----------|
| **Focus** | Deep work, concentration | Beta (14-30 Hz) | Negative feedback — if HR spikes, it calms you down |
| **Relaxation** | Unwinding, stress relief | Alpha (8-11 Hz) | Gentle downward bias toward calm |
| **Sleep** | Falling asleep | Theta → Delta (6→2 Hz) | Continuous ramp down over ~25 min |
| **Energize** | Pre-workout, morning boost | High-beta/low-gamma (18-30 Hz) | Upward bias, reinforces arousal |

## Two Session Modes

- **Manual** — Time-based arcs with pre-session check-in. Available to all users, including free tier. This is a first-class experience, not a fallback.
- **Adaptive** — Everything in Manual plus real-time biometric-driven audio adaptation. Requires Apple Watch or BLE heart rate sensor. Premium feature.

Both modes start with a quick 2-tap check-in: "How are you feeling?" and "What are you trying to do?" — which sets the starting parameters. Skippable after 5+ similar sessions.

## Three Audio Layers

| Layer | Role | Example |
|-------|------|---------|
| **Entrainment** | The science — binaural beats (v1), isochronic tones (v1.1+) | Synthesized in real time |
| **Ambient** | Texture and atmosphere | Rain, white noise, wind |
| **Melodic** | The experience — musical content | Pads, piano, strings — AI-curated from a tagged sound library |

Users control the mix with three sliders (Ambient, Melodic, Beats). The melodic layer evolves during sessions, changing tracks every 3-5 minutes with smooth 10-15s crossfades based on your biometric state and learned preferences.

## How the Adaptive Engine Works

1. Apple Watch sends heart rate at ~1 Hz
2. Dual EMA smoothing filters the signal (fast + slow, MACD-style)
3. State classification with hysteresis: Calm → Focused → Elevated → Peak
4. Mode-dependent sigmoid mapping converts HR to beat frequency
5. Slew rate limiting caps changes at 0.3 Hz/sec (imperceptible transitions)
6. Proportional + feedforward control keeps everything smooth

The result: the audio responds to your body without you ever noticing the changes. It just feels like it's working.

## The Learning System

Three signals per session feed the model:

1. **Pre-session check-in** — subjective mood/stress self-report
2. **Biometric outcomes** — HR delta, HRV delta, time to calm, session completion rate
3. **Post-session feedback** — simple thumbs up/down

Between sessions, the app passively learns from HealthKit (sleep quality, resting HR trends), motion patterns, AirPods head stillness, and check-in history to build a full behavioral model.

**ML roadmap:**
- **v1:** Rule-based sound selection + feedback logging (training data collection)
- **v1.5:** ML contextual bandit learns optimal sounds per user; Bayesian beat frequency personalization
- **v2+:** Generative MIDI melodies, LLM coaching, cross-user collaborative filtering

## Tech Stack

- **Platform:** iOS 17+ / watchOS 10+, Swift, SwiftUI
- **Architecture:** MVVM + @Observable, protocol-based services, SwiftUI Environment DI
- **Audio:** AVAudioEngine + AVAudioSourceNode, real-time synthesis via phase accumulators, lock-free atomics for parameter passing
- **Biometrics:** HealthKit + HKWorkoutSession on Watch + WatchConnectivity streaming
- **Persistence:** SwiftData (sessions, user profile), HealthKit (health data)
- **Design:** Dark-first, Satoshi font + SF Mono, periwinkle accent (#6E7CF7), 8pt grid

## Device Tiers

| Tier | Setup | Capability |
|------|-------|------------|
| 1 | Watch + AirPods + iPhone | Full biometric + head tracking (100%) |
| 2 | Watch + iPhone | Full biometric, no head tracking (~85%) |
| 3 | AirPods + iPhone | Activity + head stillness, no HR (~50%) |
| 4 | iPhone only | Activity + optional camera PPG (~25%) |

Apple Watch can run sessions standalone — audio to AirPods, adaptive algorithm on-Watch, data syncs later.

## Monetization

- **Free:** Focus + Relaxation modes, 3 sessions/day, time-based adaptation only
- **Premium:** $5.99/mo · $49.99/yr · $149.99 lifetime — all 4 modes, biometric adaptation, unlimited sessions, analytics, all sounds, offline support
- No ads. Ever. Sessions are never interrupted by paywalls.

## Key Design Decisions

- **Apple Watch standalone:** Yes — full sessions run on Watch without iPhone
- **Pomodoro timer:** Yes — Focus mode supports 25/5 cycles with auto-mode-switching
- **SharePlay co-focus rooms:** Yes (v1.1) — native to FaceTime + Messages
- **CarPlay:** Explicitly blocked — drowsiness risk with binaural beats while driving
- **Offline:** Full support — everything works without network
- **No disease claims:** Stays within FDA "general wellness" language, never names conditions like ADHD or insomnia
- **Epilepsy disclaimer:** Required acknowledgment during onboarding

## What Makes It Different

1. **Real-time biometric adaptation** — no competitor does this well
2. **Always learning** — every session makes the next one smarter
3. **Three-layer audio** — science + texture + music, not just raw tones
4. **Apple ecosystem native** — Watch standalone, HealthKit, Live Activities, Widgets, Shortcuts
5. **Honest about the science** — "research suggests" tone, includes a "doesn't work for me" off-ramp after poor sessions

## Apple Featuring Strategy

The app is designed to showcase Apple's ecosystem: Watch as the hero in screenshots, HealthKit as the universal adapter (silently supports Oura, WHOOP, Garmin), immediate adoption of new WWDC APIs, targeting May (Mental Health Awareness Month) for editorial pitch.

## Project Status

The project has a detailed build plan with 48 phases + 12 post-launch phases, organized with mandatory audit checkpoints (CP1-CP6). An extensive research library of 50+ docs covers science, tech, strategy, product, execution, and design. The Xcode project structure is in place with iPhone, Watch, Widget, and shared package targets.
