# BioNaural — Watch → iPhone Biometric Pipeline

> Real-time heart rate streaming from Apple Watch to the adaptive audio engine.

---

## Architecture Overview

```
Watch HR Sensor (~1 Hz)
    → HKAnchoredObjectQuery (individual samples)
    → WCSession.sendMessage (50-200ms latency)
    → iPhone WCSessionDelegate (background queue)
    → Atomic variable / lock-free buffer
    → Audio render thread reads latest BPM
```

**End-to-end latency: ~1.2-1.5 seconds** from heartbeat to audio response. Well within perceptible "real-time" for biofeedback.

---

## Watch Side: Getting Heart Rate Data

### HKWorkoutSession (Required for Continuous HR)

Without an active workout session, the HR sensor samples every 5-10 minutes. A workout session unlocks **~1 Hz sampling** (one reading per second).

```swift
let configuration = HKWorkoutConfiguration()
configuration.activityType = .mindAndBody   // Maps to "Mindfulness" workout
configuration.locationType = .indoor

let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
let builder = session.associatedWorkoutBuilder()
builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, 
                                              workoutConfiguration: configuration)
session.startActivity(with: Date())
builder.beginCollection(withStart: Date()) { success, error in ... }
```

**Why `.mindAndBody`:**
- Doesn't show calorie burn goal ring
- Simpler UI (no distance/pace)
- Still unlocks high-frequency HR
- Shows as "Mindfulness" in Activity history — semantically correct

**What the workout session provides:**
- Continuous HR at ~1 Hz (green LED stays on)
- Background execution (app stays alive, screen off OK)
- Sensor access + network access (Bluetooth to iPhone)
- "Now Playing" style card on Watch face

### HKAnchoredObjectQuery (Best for Streaming)

Gives individual `HKQuantitySample` objects with precise timestamps:

```swift
let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
let query = HKAnchoredObjectQuery(type: hrType, predicate: predicate, 
                                   anchor: nil, limit: HKObjectQueryNoLimit) { ... }

query.updateHandler = { query, samples, deleted, anchor, error in
    guard let samples = samples as? [HKQuantitySample] else { return }
    for sample in samples {
        let bpm = sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
        let timestamp = sample.startDate
        self.sendToiPhone(bpm: bpm, timestamp: timestamp)
    }
}
healthStore.execute(query)
```

### Can You Get HR Without a Workout Session?

**No.** Without `HKWorkoutSession`: HR samples every 5-10 minutes or on wrist raise. No API to force the sensor on. The workout session is mandatory for real-time data.

---

## Watch → iPhone Communication

### WatchConnectivity: `sendMessage` (Lowest Latency)

**50-200ms delivery.** Nothing else comes close for Watch-to-iPhone real-time data.

```swift
let message: [String: Any] = [
    "type": "heartRate",
    "bpm": 72.0,
    "timestamp": Date().timeIntervalSince1970
]

if WCSession.default.isReachable {
    WCSession.default.sendMessage(message, replyHandler: nil) { error in
        self.bufferDataPoint(message)  // Connection lost — buffer
    }
}
```

### Communication Methods Compared

| Method | Latency | Guaranteed | Best For |
|--------|---------|-----------|---------|
| `sendMessage` | 50-200ms | No | **Live HR streaming (use this)** |
| `sendMessageData` | 50-200ms | No | Live streaming (binary variant) |
| `transferUserInfo` | 1s-minutes | Yes (queued) | Buffered data flush, session summaries |
| `updateApplicationContext` | 1s-minutes | Latest only | Current state snapshot |

### Battery Impact

1 Hz messaging over BLE during an active workout session:

| Duration | Battery Used | Remaining (from 100%) |
|----------|-------------|----------------------|
| 15-30 min | 3-8% | 92-97% |
| 1 hour | 10-15% | 85-90% |
| 2 hours | 20-30% | 70-80% |

Very acceptable for typical focus sessions.

**Optimizations:** Send every 2-3 seconds instead of every 1. Or send only when HR changes by >1 BPM (adaptive rate).

---

## HRV on Apple Watch

### The Limitation

Apple Watch does NOT expose raw RR intervals (inter-beat intervals) through any public API during a live session. `HKHeartbeatSeriesSample` objects are only written AFTER a workout ends.

`HKQuantityType(.heartRateVariabilitySDNN)` is NOT a streaming metric — sampled every few minutes at best.

### HRV Approximation Strategy: Deriving RMSSD from BPM

Apple Watch does not expose raw RR intervals during live `HKWorkoutSession`. This is a platform constraint, not an engineering gap. The designed approach:

Convert 1 Hz BPM readings to estimated RR intervals:

```swift
let rrInterval_ms = 60000.0 / bpm
```

Compute RMSSD over a 30-60 second sliding window:

```swift
func computeRMSSD(from rrIntervals: [Double]) -> Double {
    guard rrIntervals.count > 1 else { return 0 }
    var sumSquaredDiffs = 0.0
    for i in 1..<rrIntervals.count {
        let diff = rrIntervals[i] - rrIntervals[i-1]
        sumSquaredDiffs += diff * diff
    }
    return sqrt(sumSquaredDiffs / Double(rrIntervals.count - 1))
}
```

**Caveat:** Computing RR intervals from averaged BPM is lossy. True beat-to-beat variability is smoothed out. Results are directionally correct (rising/falling trends) but numerically approximate.

**Recommendation:** Use RMSSD for real-time feedback (30-sec window, responsive to moment-to-moment changes). Use SDNN for session summaries (5+ min window). Send HRV from Watch every 5-10 seconds, not every 1 second.

---

## Disconnection & Error Handling

### Buffer on Disconnect

```swift
func sessionReachabilityDidChange(_ session: WCSession) {
    if session.isReachable {
        flushBufferedDataPoints()  // Send buffered data
    } else {
        isBuffering = true  // Start local buffer
    }
}
```

Buffer: In-memory circular buffer (300 samples = 5 min at 1 Hz). On reconnection, flush via `transferUserInfo` (guaranteed delivery).

### Heartbeat Pings

`isReachable` can have detection delays. Supplement with heartbeat pings every 5 seconds. If 3 consecutive pings fail → consider connection lost.

---

## iPhone Side: Receiving & Processing

### WCSessionDelegate

```swift
func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    guard let type = message["type"] as? String, type == "heartRate",
          let bpm = message["bpm"] as? Double,
          let timestamp = message["timestamp"] as? TimeInterval else { return }
    heartRateProcessor.ingest(bpm: bpm, timestamp: timestamp)
}
```

**Called on a background serial queue** (NOT main thread). Ideal for audio processing — don't dispatch to main unless updating UI.

### Feeding the Audio Engine (Lock-Free)

The audio render callback runs on a **real-time thread**. You MUST NOT:
- Acquire locks
- Allocate memory
- Call Objective-C methods
- Block on any synchronization

**Pattern:** Use an atomic variable that the WCSession queue writes and the render thread reads:

```swift
class HeartRateProcessor {
    private let latestBPM = ManagedAtomic<Double>(60.0)  // Swift Atomics
    
    // Called from WCSession background queue
    func ingest(bpm: Double, timestamp: TimeInterval) {
        latestBPM.store(bpm, ordering: .relaxed)
    }
    
    // Called from audio render thread — lock-free
    func currentBPM() -> Double {
        return latestBPM.load(ordering: .relaxed)
    }
}
```

### Data Gap Interpolation

When Watch disconnects and reconnects, the iPhone holds the last known value and gradually fades adaptation toward neutral:

```swift
func hasRecentData(within seconds: TimeInterval = 5.0) -> Bool {
    return Date().timeIntervalSince1970 - lastSampleTimestamp < seconds
}
// If false → engage graceful degradation (hold → drift to neutral over 60s)
```

---

## No Apple Watch Fallback

```swift
func session(_ session: WCSession, 
             activationDidCompleteWith state: WCSessionActivationState, 
             error: Error?) {
    if !session.isPaired {
        // No Watch → offer preset-based experience (no adaptation)
    } else if !session.isWatchAppInstalled {
        // Watch paired but app not installed → prompt to install
    }
}
```

Without Watch: BioNaural works with smart presets based on mode selection. The biometric adaptation is the premium feature — not a hard requirement.

---

## watchOS App UI

### Always On Display (Series 5+)

```swift
@Environment(\.isLuminanceReduced) var isLuminanceReduced

var body: some View {
    if isLuminanceReduced {
        // Dimmed: dark background, just HR number and timer
        Text("\(heartRate) BPM").font(.title)
    } else {
        // Full: simplified Orb visualization, HR, timer, mode
        FullWatchView(heartRate: heartRate)
    }
}
```

### Haptics for Session Milestones

```swift
WKInterfaceDevice.current().play(.success)   // Session milestone
WKInterfaceDevice.current().play(.start)     // Session begin
WKInterfaceDevice.current().play(.stop)      // Session end
WKInterfaceDevice.current().play(.click)     // Phase transition
```

Works during background execution with active workout session.

---

## Latency Budget

| Stage | Time |
|-------|------|
| HR sensor → HealthKit sample | ~1 second (sensor averaging) |
| Anchored query callback | < 100ms |
| WatchConnectivity sendMessage | 50-200ms |
| iPhone processing + audio param update | < 10ms |
| **Total** | **~1.2-1.5 seconds** |
