# BioNaural — Testing Strategy

> The adaptive algorithm IS the product. If it's wrong, the app is wrong. Test it first, test it hardest.

---

## 1. Adaptive Algorithm Unit Tests

The most critical test suite. The adaptive engine must be deterministic and predictable.

### Input → Output Tests

```swift
// Given a sequence of HR inputs, verify the audio parameters
@Test func focusMode_risingHR_lowersFrequency() {
    let engine = DeterministicSelector(mode: .focus)
    // Simulate: HR rises from 65 → 85 over 20 samples
    let hrSequence = stride(from: 65.0, through: 85.0, by: 1.0).map { $0 }
    var lastFreq = engine.currentBeatFrequency
    for hr in hrSequence {
        engine.process(hr: hr, timestamp: .now)
        // In Focus mode, rising HR should DECREASE beat frequency (negative feedback)
        #expect(engine.currentBeatFrequency <= lastFreq + 0.1) // allow tiny float tolerance
        lastFreq = engine.currentBeatFrequency
    }
}

@Test func relaxationMode_stableHR_maintainsAlpha() {
    let engine = DeterministicSelector(mode: .relaxation)
    // Stable HR at 68 for 60 samples
    for _ in 0..<60 {
        engine.process(hr: 68.0, timestamp: .now)
    }
    // Should be in alpha range (8-11 Hz)
    #expect(engine.currentBeatFrequency >= 8.0)
    #expect(engine.currentBeatFrequency <= 11.0)
}

@Test func sleepMode_rampsDownOverTime() {
    let engine = DeterministicSelector(mode: .sleep)
    engine.process(hr: 60.0, timestamp: .now)
    let startFreq = engine.currentBeatFrequency
    // Simulate 25 minutes of stable HR
    for minute in 0..<25 {
        for _ in 0..<60 { // 60 samples per minute at 1 Hz
            engine.process(hr: 60.0, timestamp: .now.addingTimeInterval(Double(minute * 60)))
        }
    }
    let endFreq = engine.currentBeatFrequency
    // Should have ramped from ~6 Hz to ~2 Hz
    #expect(startFreq > 5.0)
    #expect(endFreq < 3.0)
}
```

### Hysteresis Tests

```swift
@Test func stateTransition_requiresHysteresis() {
    let classifier = StateClassifier()
    // HR oscillating right at the boundary (0.20)
    classifier.process(hrNormalized: 0.19) // Calm
    classifier.process(hrNormalized: 0.21) // Still Calm (hasn't crossed 0.23 enter threshold)
    classifier.process(hrNormalized: 0.19) // Still Calm
    #expect(classifier.currentState == .calm)
    
    // Must cross 0.23 to enter Focused
    classifier.process(hrNormalized: 0.24)
    // Must also wait 5 seconds (dwell time)
    // ... simulate 5 seconds of samples above 0.23
    #expect(classifier.currentState == .focused)
}
```

### Slew Rate Tests

```swift
@Test func slewRate_limitsFrequencyChange() {
    let engine = DeterministicSelector(mode: .focus)
    engine.setTargetBeatFrequency(18.0) // Jump from default 10 to 18
    engine.tick(dt: 0.1) // One 100ms tick
    // Max change: 0.3 Hz/sec × 0.1s = 0.03 Hz per tick
    #expect(abs(engine.currentBeatFrequency - 10.03) < 0.01)
}
```

### Artifact Rejection Tests

```swift
@Test func artifactRejection_ignoresSpike() {
    let processor = BiometricProcessor()
    processor.ingest(hr: 70.0)
    processor.ingest(hr: 72.0)
    processor.ingest(hr: 180.0) // artifact — 108 BPM jump in 1 second
    processor.ingest(hr: 71.0)
    // The 180 should be rejected, smoothed value should be ~71
    #expect(processor.smoothedHR > 69.0 && processor.smoothedHR < 73.0)
}
```

### Signal Quality Model Tests

```swift
@Test func signalQuality_lowOnHighVariance() {
    let model = SignalQualityModel()
    let noisySequence: [Double] = [70, 95, 65, 110, 72, 88] // high variance
    let score = model.score(samples: noisySequence)
    #expect(score < 0.5) // low confidence
}

@Test func signalQuality_highOnStableData() {
    let stableSequence: [Double] = [70, 71, 70, 72, 71, 70]
    let score = model.score(samples: stableSequence)
    #expect(score > 0.8) // high confidence
}
```

---

## 2. Audio Engine Tests

### Frequency Accuracy

```swift
@Test func binauralBeat_producesCorrectFrequency() {
    let engine = AudioTestHarness()
    engine.setCarrier(400.0)
    engine.setBeatFrequency(10.0)
    
    // Capture 1 second of audio output
    let buffer = engine.renderToBuffer(duration: 1.0)
    
    // FFT analysis on left channel
    let leftSpectrum = fft(buffer.leftChannel)
    let leftPeak = findPeakFrequency(leftSpectrum)
    #expect(abs(leftPeak - 395.0) < 1.0) // 400 - 10/2 = 395
    
    // FFT on right channel
    let rightSpectrum = fft(buffer.rightChannel)
    let rightPeak = findPeakFrequency(rightSpectrum)
    #expect(abs(rightPeak - 405.0) < 1.0) // 400 + 10/2 = 405
}
```

### Phase Accumulator Stability

```swift
@Test func phaseAccumulator_stableOverLongDuration() {
    var phase: Double = 0.0
    let frequency: Double = 400.0
    let sampleRate: Double = 44100.0
    let twoHoursOfSamples = Int(2 * 3600 * sampleRate)
    
    for _ in 0..<twoHoursOfSamples {
        phase += frequency / sampleRate
        if phase >= 1.0 { phase -= 1.0 }
    }
    
    // Phase should still be in [0, 1) and producing correct output
    #expect(phase >= 0.0 && phase < 1.0)
    let sample = sin(2.0 * .pi * phase)
    #expect(sample >= -1.0 && sample <= 1.0)
}
```

### No Clicks on Parameter Change

```swift
@Test func parameterChange_noDiscontinuity() {
    let engine = AudioTestHarness()
    engine.setAmplitude(0.5)
    
    // Render 512 samples
    let buffer1 = engine.renderToBuffer(frames: 512)
    
    // Change amplitude
    engine.setAmplitude(0.8)
    
    // Render next 512 samples
    let buffer2 = engine.renderToBuffer(frames: 512)
    
    // The transition between buffer1's last sample and buffer2's first sample
    // should be smooth (no discontinuity > threshold)
    let lastSample = buffer1.leftChannel.last!
    let firstSample = buffer2.leftChannel.first!
    let jump = abs(firstSample - lastSample)
    #expect(jump < 0.01) // smoothing should prevent jumps
}
```

---

## 3. Watch Pipeline Integration Tests

### Latency Verification

```swift
@Test func watchPipeline_latencyUnder3Seconds() async {
    // Requires actual Watch connection or simulator
    let connector = WatchConnectivityService()
    let startTime = Date()
    
    // Send test message from Watch
    connector.simulateWatchMessage(["type": "heartRate", "bpm": 72.0, "timestamp": startTime.timeIntervalSince1970])
    
    // Verify arrival on iPhone
    let received = await connector.waitForNextSample(timeout: 3.0)
    #expect(received != nil)
    let latency = Date().timeIntervalSince(startTime)
    #expect(latency < 3.0)
}
```

### Disconnect / Reconnect

```swift
@Test func watchDisconnect_gracefulDegradation() async {
    let processor = BiometricProcessor()
    
    // Feed some HR data
    processor.ingest(hr: 70.0)
    processor.ingest(hr: 72.0)
    
    // Simulate disconnect (no data for 15 seconds)
    try await Task.sleep(for: .seconds(15))
    
    // Should be drifting toward neutral
    #expect(processor.isInGracefulDegradation)
    // Audio parameters should be moving toward defaults
}
```

---

## 4. Performance Tests

### Battery and CPU

| Test | Method | Acceptable Result |
|------|--------|------------------|
| CPU during 30-min session | Instruments → Time Profiler | < 5% average CPU |
| Memory during 30-min session | Instruments → Allocations | No memory growth (leaks) |
| Watch battery per 30-min session | Manual: note battery before/after | < 8% Watch drain |
| iPhone battery per 30-min session | Manual | < 5% iPhone drain |
| Audio glitches per 30-min session | Instruments → Audio Unit hosting | Zero glitches |

### Long-Duration Stability

Run a 2-hour continuous session:
- Audio should not drift in frequency (phase accumulator stability)
- Memory should not grow (no leaks in the render callback)
- Watch pipeline should handle intermittent disconnects without crash
- UI should remain responsive if user brings app to foreground

---

## 5. User Testing Protocol

### TestFlight Beta (50-100 Users, 2 Weeks)

**Recruitment:** r/productivity, r/biohacking, r/AppleWatch, personal network. Target: 50% Apple Watch owners, 50% iPhone-only.

**What to collect:**

| Signal | Method |
|--------|--------|
| Audio quality | Post-session survey: "Did the audio feel pleasant for 15+ min?" (1-5 scale) |
| Adaptation perception | "Did you feel the audio respond to your body?" (Yes/Somewhat/No) |
| Spatial Audio issue | "Did you experience the test tone flow? Did it work?" |
| Session completion rate | Analytics: % of sessions that reach the intended duration |
| Mode preference | Analytics: which mode is most used |
| Bugs | In-app feedback button + TestFlight crash reports |
| Onboarding friction | Analytics: drop-off at each onboarding screen |
| AirPods vs wired | Analytics: audio route at session start |

**Feedback form (after first week):**
1. What mode do you use most? Why?
2. Does the audio feel good for 15+ minutes, or does it become fatiguing?
3. Did you notice the audio adapting to your body? Describe what you felt.
4. What would make you use BioNaural every day?
5. What almost made you stop using it?

---

## 6. App Store Review Pre-Check

Before submission, verify:

| Check | Status |
|-------|--------|
| HealthKit permissions justified in review notes | |
| Privacy policy linked in App Store Connect + in-app | |
| Epilepsy disclaimer in onboarding (acknowleded by user) | |
| No medical claims in description, screenshots, or preview | |
| App works without HealthKit permission (graceful degradation) | |
| App works without Apple Watch (time-based arcs) | |
| Background audio continues through lock screen | |
| Interruption handling works (phone call → resume) | |
| Headphone disconnect pauses audio | |
| Dynamic Type scales all text | |
| VoiceOver navigates all screens | |
| Reduce Motion disables Orb/Wavelength animation | |
