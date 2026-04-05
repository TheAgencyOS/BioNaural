# BioNaural — App Architecture

> MVVM + @Observable, project structure, data flow, concurrency model, Watch app, widgets.

---

## Pattern: MVVM with @Observable

**Why not TCA:** Reducer overhead adds latency to the hot data path (HR→audio). Boilerplate slows iteration.
**Why not pure MV:** Conflates model with service layer. Nowhere clean to put the audio engine or biometric processor.
**Why MVVM + @Observable:** Clean separation of real-time services from UI. `@Observable` (iOS 17+) gives fine-grained property tracking — SwiftUI only re-renders when the specific property a view reads changes.

```
View ←→ ViewModel (@Observable) ←→ Services (protocols)
                                      ├── AudioEngine
                                      ├── BiometricProcessor
                                      ├── HealthKitService
                                      ├── WatchConnectivityService
                                      └── SessionStore (SwiftData)
```

---

## Three Concurrency Domains

| Domain | Speed | Technology | Rules |
|--------|-------|-----------|-------|
| **Audio render** | 44100 Hz | C callback, raw pointers | No locks, no malloc, no ARC, no async/await |
| **Biometric processing** | ~1 Hz | Swift actor | Can allocate, lock, await. Writes to audio via atomics. |
| **UI** | ~60 Hz | @MainActor, @Observable | SwiftUI views read from ViewModel |

```
Swift Actor World                    Real-Time C World
─────────────────                    ──────────────────
BiometricProcessor ──atomic write──▶ AudioParameters ◀──atomic read── render callback
(can allocate, lock, await)          (lock-free)        (cannot allocate, lock, await)
```

---

## Project Structure

```
BioNaural/
├── BioNauralApp.swift
├── App/
│   ├── AppState.swift                  # Global @Observable state
│   ├── AppDependencies.swift           # DI container
│   └── Navigation/
│
├── Features/
│   ├── Session/
│   │   ├── SessionView.swift
│   │   ├── SessionViewModel.swift      # @Observable, bridges services → UI
│   │   ├── SessionControlsView.swift
│   │   └── BiometricOverlayView.swift
│   ├── ModeSelection/
│   ├── History/
│   ├── Onboarding/
│   └── Settings/
│
├── Design/                             # Theme (from DesignLanguage.md)
│   ├── Theme.swift
│   ├── AnimationConstants.swift
│   └── Components/
│       ├── OrbView.swift
│       ├── WavelengthView.swift
│       └── MetricCardView.swift
│
├── Audio/                              # NO SwiftUI imports
│   ├── AudioEngine.swift               # AVAudioEngine wrapper (three-layer mixing)
│   ├── EntrainmentNode.swift           # AVAudioSourceNode (real-time synthesis — binaural + isochronic)
│   ├── ToneGenerator.swift             # Carrier + harmonics + LFO
│   ├── AmbienceLayer.swift             # Ambient bed playback + looping
│   ├── MelodicLayer.swift              # Melodic sound selection + crossfade playback
│   ├── SoundLibrary.swift              # Tagged sound catalog, filtering, selection rules
│   ├── AudioParameters.swift           # Lock-free atomics (entrainment params + entrainmentMethod)
│   └── Protocols/AudioEngineProtocol.swift
│
├── Biometrics/                         # NO SwiftUI imports
│   ├── BiometricProcessor.swift        # Actor: HR/HRV → adaptation
│   ├── AdaptationEngine.swift          # Maps state → binaural params
│   ├── HeartRateAnalyzer.swift         # Trend detection, zones
│   ├── SignalQualityModel.swift        # Core ML: scores sample reliability (v1 ML)
│   ├── ParameterSelector.swift         # Protocol: deterministic now, ML-personalized in v1.5
│   └── Models/
│       ├── BiometricSample.swift
│       ├── BiometricState.swift
│       └── AdaptationEvent.swift
│
├── Learning/                           # Feedback loop + sound personalization
│   ├── SessionOutcomeRecorder.swift    # Records biometric outcomes + thumbs per session
│   ├── SoundProfileManager.swift       # User's sound preferences (learned + explicit)
│   ├── SoundSelector.swift             # Rules-based v1, ML contextual bandit v1.5
│   └── Models/
│       ├── SessionOutcome.swift        # Full outcome record (biometrics + feedback + sounds)
│       └── SoundProfile.swift          # Per-user instrument/energy/brightness weights
│
├── Services/
│   ├── HealthKit/
│   │   ├── HealthKitService.swift
│   │   └── HealthKitServiceProtocol.swift
│   ├── WatchConnectivity/
│   │   ├── WatchConnectivityService.swift
│   │   └── WatchConnectivityProtocol.swift
│   ├── Persistence/SessionStore.swift
│   └── Haptics/HapticService.swift
│
├── Models/                             # SwiftData
│   ├── FocusSession.swift              # @Model
│   ├── UserProfile.swift               # @Model
│   └── FocusMode.swift                 # Enum
│
├── Resources/
│   ├── Assets.xcassets
│   └── Ambience/                       # Bundled ambient audio
│
BioNauralWatch/                         # watchOS target
│   ├── Views/
│   │   ├── WatchSessionView.swift
│   │   └── WatchModeSelectionView.swift
│   └── Services/
│       └── WatchHealthKitService.swift
│
BioNauralWidgets/                       # Widget + Live Activity
│   ├── SessionSummaryWidget.swift
│   ├── QuickStartWidget.swift
│   └── LiveActivityView.swift
│
BioNauralShared/                        # Local Swift Package
│   ├── Sources/
│   │   ├── BiometricSample.swift
│   │   ├── FocusMode.swift
│   │   ├── WatchMessage.swift
│   │   └── FrequencyMath.swift
│   └── Package.swift
```

**Key rules:**
- `Audio/` and `Biometrics/` never import SwiftUI — pure Swift for testability
- Features organized by screen, not file type
- `BioNauralShared` is a local Swift Package shared across iPhone, Watch, Widget targets

---

## Data Flow: Watch → Audio → UI

```
Apple Watch (HKWorkoutSession, ~1 Hz HR)
    ↓ WCSession.sendMessage
WatchConnectivityService
    ↓ AsyncStream<BiometricSample>
BiometricProcessor (actor)
    ├──→ SignalQualityModel (Core ML) → confidence weight
    ├──→ ParameterSelector → entrainment method + beat frequency + carrier (adapted by biometrics)
    │       ↓ AudioParameters (atomic write) → Entrainment render callback → Headphones/Speakers
    ├──→ SoundSelector → melodic layer selection (adapted by biometrics + user profile)
    │       ↓ MelodicLayer (crossfade playback) → Mixer → Headphones
    ├──→ SessionOutcomeRecorder (logs biometrics + sounds for learning)
    └──→ SessionViewModel (@Observable, @MainActor) → SwiftUI Views

Post-session:
    SessionOutcome (biometric deltas + thumbs rating + sound IDs)
        → SoundProfileManager (updates user preference weights)
        → SwiftData (persists for ML training in v1.5)
```

---

## Dependency Injection

```swift
@Observable
final class AppDependencies {
    let audioEngine: AudioEngineProtocol
    let healthKitService: HealthKitServiceProtocol
    let watchConnectivity: WatchConnectivityProtocol
    let biometricProcessor: BiometricProcessing
    let modelContainer: ModelContainer
}

// At app entry:
@main
struct BioNauralApp: App {
    @State private var deps = AppDependencies()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(deps)
                .modelContainer(deps.modelContainer)
        }
    }
}
```

Protocol-based services enable mock injection for testing:

```swift
final class MockAudioEngine: AudioEngineProtocol {
    var startCallCount = 0
    func start(mode: FocusMode) { startCallCount += 1 }
}
```

---

## SwiftData Models

### FocusSession

```swift
@Model
final class FocusSession {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var mode: FocusMode
    var durationSeconds: Int
    var averageHeartRate: Double?
    var averageHRV: Double?
    var beatFrequencyStart: Double
    var beatFrequencyEnd: Double
    var adaptationEvents: [AdaptationEventRecord]  // Codable array, not separate @Model
    var wasCompleted: Bool
}
```

### UserProfile

```swift
@Model
final class UserProfile {
    var baselineRestingHR: Double?
    var baselineHRV: Double?
    var preferredMode: FocusMode
    var preferredDurationMinutes: Int
    var adaptationSensitivity: Double  // 0-1
}
```

### What to Persist vs Ephemeral

| Data | Storage |
|------|---------|
| Session history | SwiftData @Model |
| User profile/settings | SwiftData @Model |
| Baseline HR/HRV | SwiftData (UserProfile) |
| Current HR sample | In-memory @Observable |
| Audio engine state | In-memory (reconstructed each session) |
| Adaptation events during session | In-memory → flush to SwiftData on end |
| Raw HR time series | In-memory ring buffer → compute aggregates at end |
| HealthKit data | HealthKit's own store (never duplicate) |

---

## Watch App Architecture

Minimal. Three jobs: stream HR, show status, basic controls.

```swift
// Watch HR streaming
func workoutBuilder(_ builder: HKLiveWorkoutBuilder, 
                    didCollectDataOf types: Set<HKSampleType>) {
    guard types.contains(HKQuantityType(.heartRate)) else { return }
    let stats = builder.statistics(for: HKQuantityType(.heartRate))
    if let hr = stats?.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) {
        WCSession.default.sendMessage(BiometricSample(hr: hr).toDictionary(), 
                                       replyHandler: nil)
    }
}
```

**No shared SwiftData container** between Watch and iPhone for real-time data. WCSession for live streaming, `transferUserInfo` for session summaries.

---

## Live Activity + Dynamic Island

```swift
struct FocusActivityAttributes: ActivityAttributes {
    var sessionStartDate: Date
    var targetDurationMinutes: Int
    
    struct ContentState: Codable, Hashable {
        var currentHR: Int
        var currentMode: FocusMode
        var beatFrequency: Double
    }
}
```

- **Compact:** Orb icon (leading) + timer (trailing)
- **Expanded:** Session name, HR, beat frequency, timer
- **Lock Screen:** Mode color bar + timer
- Update at most every 5 seconds. Use `Text(timerInterval:)` for system-managed countdown.

---

## Key Technical Risks

| Risk | Mitigation |
|------|-----------|
| Audio glitches (thread priority inversion) | Render callback uses ONLY atomics + raw pointers. No locks, no ARC. |
| WCSession drops messages | Buffer on Watch, flush on reconnection via `transferUserInfo` |
| Background audio suspension | `.playback` category + `UIBackgroundModes: audio` |
| HealthKit auth denied | App works without biometrics (preset mode, no adaptation) |
| Watch battery drain | Session-based (not always-on). ~10-15% per hour. Max 90 min with warning. |
| Adaptation loop latency | End-to-end 1.2-1.5s. Physiological response is 3-5 min — latency is irrelevant. |
| App Store rejection | No medical claims. Frame as "personalized wellness audio." |

---

## Minimum Deployment Targets

- **iOS 17** — required for @Observable, SwiftData, modern HealthKit async APIs
- **watchOS 10** — required for SwiftData, Swift Charts, modern workout APIs
