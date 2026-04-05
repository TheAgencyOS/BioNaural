# BioNaural -- All HIGH Severity Issues (Compiled from 5 Deep Audits)

*Generated 2026-04-05. CRITICALs excluded (tracked separately). Only remaining HIGH issues.*

---

## Category: AUDIO_QUALITY (8 issues)

| # | File:Line | Issue | Fix | Effort |
|---|-----------|-------|-----|--------|
| 1 | AudioEngine.swift:186-209 | Stop has no audible fade-out -- amplitude jumps to 0 in one buffer, producing a click | Ramp `amplitude` from current to 0 over ~50ms before setting `isPlaying = false`; delay engine stop until ramp completes | 30 min |
| 2 | BinauralBeatNode.swift:60-62 | Smoothed initial freq hardcoded to 200/210 Hz -- causes audible sweep if mode starts at a different carrier | Init `smoothedFreqLeft/Right` from `Theme.Audio.Neutral.carrierFrequency` | 5 min |
| 3 | BinauralBeatNode.swift:190 | LFO gain can reach 1.78 (three LFOs constructive interference) -- audible pumping/clipping | Clamp combined LFO to `[0.5, 1.5]` or normalize by dividing sum by number of active LFOs | 15 min |
| 4 | AmbienceLayer.swift:169 | Crossfade timer on main thread -- UI jank causes audible volume stutter | Replace `Timer.scheduledTimer` with `DispatchSourceTimer` on a dedicated serial queue | 30 min |
| 5 | MelodicLayer.swift:163-186 | Same main-thread timer issue as AmbienceLayer crossfade | Same fix: `DispatchSourceTimer` on dedicated queue | 30 min |
| 6 | StemAudioLayer.swift:265 | Volume update timer on main thread -- biometric-driven volume stutters with UI interaction | Same fix: `DispatchSourceTimer` on dedicated queue | 30 min |
| 7 | GenerativeMIDIEngine.swift:103-110 | `stop()` clears pendingNoteOffs without sending them -- previously dispatched note-ons can fire after, causing stuck notes | Send all pending note-offs before clearing; add mutex or serial dispatch to prevent post-stop note-ons | 30 min |
| 8 | AudioEngine.swift:196-209 | Stop fade timer race -- calling start() between two stop() calls lets pending timer kill the new session | Cancel any pending stop timer at the top of `start()`; use a generation counter to invalidate stale timers | 30 min |

---

## Category: MEMORY (5 issues)

| # | File:Line | Issue | Fix | Effort |
|---|-----------|-------|-----|--------|
| 9 | AmbienceLayer.swift:235-237 | Entire audio file loaded into RAM -- 100-200MB per ambient loop | Use `AVAudioPlayerNode.scheduleSegment` with streaming, or cap file size and use `AVAudioFile` streaming reads | 1 hr |
| 10 | MelodicLayer.swift:246-258 | Same full-file-into-RAM issue for melodic loops | Same streaming fix as AmbienceLayer | 1 hr |
| 11 | StemAudioLayer.swift:312-325 | 4 stems loaded fully into RAM = ~240MB for a stem pack | Same streaming fix; or load stems lazily as needed | 1 hr |
| 12 | MelodicLayer.swift:184 | Outgoing player stopped but never detached from engine -- nodes leak over 2+ hour sessions | Call `engine.detach(outgoing)` after crossfade completes and player stops | 5 min |
| 13 | AudioEngine.swift:57 (cross-cutting) | No `syncVolume()` caller for AmbienceLayer/MelodicLayer/SF2MelodicRenderer -- user volume sliders write to atomics but nodes never read back (**also CRITICAL as a BUG**) | Add periodic `syncVolume()` calls from the engine's control loop or respond to parameter changes via observation | 30 min |

---

## Category: THREAD_SAFETY (4 issues)

| # | File:Line | Issue | Fix | Effort |
|---|-----------|-------|-----|--------|
| 14 | AudioEngine.swift:53 | `isSetUp` bool read/written from main thread AND `controlQueue` with no synchronization | Move all engine mutation to `controlQueue`; or use `OSAllocatedUnfairLock` to protect `isSetUp` | 30 min |
| 15 | AudioEngine.swift:56-57 | `currentMode` read/written from main thread AND `controlQueue` without sync | Same fix: protect with lock or unify mutation onto one queue | 15 min |
| 16 | WatchConnectivityService.swift:52 | `isWatchReachable` plain Bool written from WCSession delegate queue, read from any thread -- data race | Use `OSAllocatedUnfairLock<Bool>` or convert class to an actor | 15 min |
| 17 | WatchConnectivityService.swift:52 | (Duplicate found by both biometric and services audits -- same issue as #16) | -- | -- |

---

## Category: DATA_INTEGRITY (4 issues)

| # | File:Line | Issue | Fix | Effort |
|---|-----------|-------|-----|--------|
| 18 | HeartRateAnalyzer.swift:97-101 | First HR sample always accepted with no bounds check -- a 0 BPM or 250 BPM seed poisons EMA for ~23 seconds | Add physiological range guard (30-220 BPM) before accepting first sample | 5 min |
| 19 | BiometricProcessor.swift:311-314 | No validation on raw HR values entering pipeline -- NaN/Inf/negative/0 all accepted | Add `guard sample.heartRate.isFinite && (30...220).contains(sample.heartRate)` | 5 min |
| 20 | BiometricProcessor.swift:16-41 | BiometricSample.confidence (Int 0/1/2) never bridged to LocalBiometricSample.signalQuality (Double 0-1) -- signal quality weighting is dead code | Add mapping in the WCSession-to-processor adapter: `signalQuality = Double(confidence) / 2.0` | 15 min |
| 21 | WatchHealthKitService.swift:239-255 | No physiological range validation at Watch sensor level -- bad readings sent directly to iPhone | Add 30-220 BPM range check before yielding sample to stream | 5 min |

---

## Category: BUG (5 issues)

| # | File:Line | Issue | Fix | Effort |
|---|-----------|-------|-----|--------|
| 22 | NowPlayingManager.swift:199-228 | `addTarget` without removing old targets -- calling `configure()` twice registers duplicate handlers; remote commands fire twice | Call `removeTarget` for each command before re-registering, or guard against double-registration | 15 min |
| 23 | ContentView.swift:13 vs OnboardingView.swift:15 | Two different UserDefaults keys for onboarding complete (`bionaural_onboarding_complete` vs `onboardingComplete`) -- app either always or never shows onboarding | Unify to a single key in Constants | 5 min |
| 24 | ModeSelectionView.swift:322 | `let isConnected = false` hardcoded -- Watch connected status always shows false | Wire to actual `WatchConnectivityService.isWatchReachable` state | 15 min |
| 25 | SoundProfile.swift:121-158 | `updateFromOutcome` uses hardcoded `learningRate = 0.3` instead of `SoundLearningConfig` | Replace with `SoundLearningConfig.learningRate` (already exists) | 5 min |
| 26 | SubscriptionManager.swift:77-89 | Init fires async entitlement check -- window where stale cached premium state is visible before StoreKit verification completes | Set a `isVerifying` flag; block premium-gated features until verification completes or add a grace-period timeout | 30 min |

---

## Category: HARDCODED (12 issues)

| # | File:Line | Issue | Fix | Effort |
|---|-----------|-------|-----|--------|
| 27 | AudioParameters.swift:19-32 | No NaN/Inf validation on atomic setters -- garbage propagates to render callback | Add `guard value.isFinite` + clamp to valid range in each setter | 15 min |
| 28 | AdaptationEngine.swift:203-204 | Sleep mode hardcoded `0.5` midpoint, `2.0` scale, `0.5` blend | Move to `Theme.Audio.ModeDefaults.Sleep` tokens | 10 min |
| 29 | AdaptationEngine.swift:340-352 | All 4 branches of `computeMelodicLevel` use hardcoded coefficients | Move to `Theme.Audio.SecondaryMapping` tokens | 15 min |
| 30 | SoundProfile.swift:124,148,153 | Learning rates 0.3, 0.2, 0.05 and threshold 0.6 are local constants | Move to `SoundLearningConfig` enum | 10 min |
| 31 | WatchSessionManager.swift:518-523 | `restingHR: 65`, `estimatedMaxHR: 190` hardcoded -- zone classification wrong for users with different resting HR | Query HealthKit for actual resting HR; use Tanaka formula with user age for max HR | 1 hr |
| 32 | ModeSelectionView.swift:327 | `.fill(.green)` raw system color for Watch indicator | Replace with `Theme.Colors.confirmationGreen` (already exists) | 5 min |
| 33 | ModeSelectionView.swift:666, AdaptationInsightOverlay.swift:114, PostSessionScienceInsightView.swift:383 | Hardcoded `width: 3` accent bars (3 sites) | Create `Theme.Spacing.accentBorder` token | 10 min |
| 34 | SessionBackgroundView.swift:91-94 | Hardcoded `0.6`, `1.3`, `1.6` noise intensity multipliers | Move to `Theme.Background.noiseIntensity` tokens | 10 min |
| 35 | NebulaBokehBackground.swift:39-40,60-61 | Hardcoded blur/opacity ratios per Nebula orb | Move to `Theme.Nebula` tokens | 10 min |
| 36 | WatchSessionView.swift:184-188 | Hardcoded mode color hex values duplicate shared definition | Use existing `FocusMode.watchColor` extension | 5 min |
| 37 | ModeSelectionView.swift:746, AdaptationInsightOverlay.swift:225 | `size.height * 0.35` wave amplitude fraction hardcoded | Move to `Theme.Animation.waveAmplitudeFraction` token | 5 min |
| 38 | OnboardingScreens.swift:398 | `testDurationSeconds: 10` hardcoded | Move to `Theme.Session.testDuration` or `Constants` | 5 min |

---

## Category: MISSING_FEATURE (4 issues)

| # | File:Line | Issue | Fix | Effort |
|---|-----------|-------|-----|--------|
| 39 | AudioEngine.swift (cross-cutting) | No audio session interruption recovery for AmbienceLayer and StemAudioLayer -- user loses ambient/stem audio after phone call | In `resume()`, also call `ambienceLayer.play()` and `stemAudioLayer.resume()` to restore all layers | 30 min |
| 40 | SubscriptionManager (entire class) | No protocol -- untestable, tightly coupled singleton | Extract `SubscriptionManagerProtocol`, add mock implementation | 1 hr |
| 41 | SessionSummaryWidget.swift:44-84 | Energize mode completely absent from widgets -- no pill, wrong color, wrong icon | Add `.energize` case to `SessionModeParameter` and all widget color/icon resolution | 30 min |
| 42 | Shared/Config (cross-cutting) | Watch target + Widget target have no entitlements files; main app entitlements file is empty | Populate `BioNaural.entitlements` with HealthKit + App Groups; create Watch and Widget entitlements (**also CRITICAL**) | 30 min |

---

## Category: CRASH (1 issue -- remaining after CRITICALs)

| # | File:Line | Issue | Fix | Effort |
|---|-----------|-------|-----|--------|
| 43 | SoundProfileManager.swift:128,138,149,158 + UserModelBuilder.swift:362,471 | Silent `try?` on SwiftData saves -- in-memory state diverges from persisted state with no notification | Replace `try?` with `do/catch` that logs error and surfaces to caller; consider retry logic | 1 hr |

---

# Total: 42 unique HIGH issues

| Category | Count | Total Effort |
|----------|-------|-------------|
| AUDIO_QUALITY | 8 | ~3.5 hr |
| MEMORY | 5 | ~3.5 hr |
| THREAD_SAFETY | 3 (deduplicated) | ~1 hr |
| DATA_INTEGRITY | 4 | ~30 min |
| BUG | 5 | ~1 hr 10 min |
| HARDCODED | 12 | ~1 hr 40 min |
| MISSING_FEATURE | 4 | ~2.5 hr |
| CRASH | 1 | ~1 hr |

**Grand total estimated effort: ~15 hours**

---

# Recommended Execution Order

Fix categories in this order to maximize impact with minimum risk of introducing new bugs:

## Phase 1: Data Correctness (2 hours) -- HIGHEST IMPACT, LOWEST RISK
1. **DATA_INTEGRITY** -- 4 issues, ~30 min. These are input validation guards that prevent garbage from entering the pipeline. Pure additive changes, zero risk of breaking existing behavior.
2. **BUG** -- 5 issues, ~1 hr 10 min. The onboarding key conflict (5 min fix) and Watch connected status (15 min) are user-visible. The NowPlayingManager duplicate handler and learning rate issues are functional bugs with clear fixes.

## Phase 2: Audio Reliability (3.5 hours) -- CORE PRODUCT QUALITY
3. **AUDIO_QUALITY** -- 8 issues. Start with the quick wins: initial frequency hardcode (5 min), LFO clamp (15 min). Then do the three main-thread timer migrations together (AmbienceLayer, MelodicLayer, StemAudioLayer -- 1.5 hr total as they share the same pattern). Finish with stop fade and stop timer race.

## Phase 3: Thread Safety (1 hour) -- PREVENTS RARE BUT SERIOUS RACES
4. **THREAD_SAFETY** -- 3 issues. These are concurrency guards. Fix `isSetUp`/`currentMode` together since they are in the same file. Fix `isWatchReachable` separately. Small, focused changes.

## Phase 4: Memory (3.5 hours) -- LONG SESSION STABILITY
5. **MEMORY** -- 5 issues. The node detach fix is 5 min. The three streaming fixes (AmbienceLayer, MelodicLayer, StemAudioLayer) are the biggest refactor in this list -- do them together as they share the same pattern. Test with Instruments Allocations over a 30-min session.

## Phase 5: Hardcoded Values (1.5 hours) -- CODE QUALITY
6. **HARDCODED** -- 12 issues. Mostly mechanical: create tokens in Theme.swift, replace literals. Low risk but tedious. Group by file for efficiency.

## Phase 6: Missing Features + Crash Safety (3.5 hours) -- COMPLETENESS
7. **MISSING_FEATURE** -- 4 issues. Entitlements and Energize widget support are blocking for release. SubscriptionManager protocol is important for testability but not user-facing.
8. **CRASH** -- 1 issue (silent try? swallows). Important for debugging but not user-visible until a save actually fails.
