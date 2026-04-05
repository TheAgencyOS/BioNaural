// SoundDNAAnalyzer.swift
// BioNaural
//
// On-device audio feature extraction using Accelerate/vDSP.
// Extracts BPM, spectral centroid, brightness, warmth, energy,
// and density from a PCM audio buffer. No network calls. No SwiftUI.
//
// All normalization ranges, FFT sizes, and thresholds come from
// Theme.SoundDNA tokens — zero hardcoded analysis parameters.

import Foundation
import Accelerate

// MARK: - Extracted Features

/// Raw features extracted from audio via DSP analysis.
/// These are normalized to [0, 1] ranges using Theme.SoundDNA tokens
/// before being stored in a SoundDNASample.
public struct ExtractedAudioFeatures: Sendable {

    /// Detected BPM. `nil` if no clear beat.
    public let bpm: Double?

    /// Spectral centroid in Hz.
    public let spectralCentroidHz: Double

    /// Brightness [0.0 - 1.0], normalized from spectral centroid.
    public let brightness: Double

    /// Warmth [0.0 - 1.0], ratio of low-frequency energy to total.
    public let warmth: Double

    /// Energy [0.0 - 1.0], normalized from RMS amplitude.
    public let energy: Double

    /// Density [0.0 - 1.0], derived from spectral flatness.
    public let density: Double

    /// Detected key name (e.g., "C", "F#"). `nil` if detection failed.
    public let key: String?

    /// Major/minor classification.
    public let scale: DetectedScale
}

// MARK: - Protocol

/// Contract for on-device audio feature extraction.
/// Protocol-based to support mock implementations in tests.
public protocol SoundDNAAnalyzerProtocol: Sendable {

    /// Extract musical features from a PCM audio buffer.
    ///
    /// - Parameters:
    ///   - samples: Interleaved or mono float samples.
    ///   - sampleRate: Sample rate in Hz (e.g., 44100).
    ///   - channelCount: Number of audio channels (1 = mono, 2 = stereo).
    /// - Returns: Extracted features with normalized values.
    func analyze(
        samples: [Float],
        sampleRate: Double,
        channelCount: Int
    ) -> ExtractedAudioFeatures
}

// MARK: - SoundDNAAnalyzer

/// Extracts musical features from PCM audio using Accelerate/vDSP.
///
/// All analysis parameters (FFT size, normalization ranges, thresholds)
/// come from ``Theme.SoundDNA`` tokens. The analyzer is stateless and
/// thread-safe — each call operates on the provided buffer only.
public struct SoundDNAAnalyzer: SoundDNAAnalyzerProtocol {

    public init() {}

    public func analyze(
        samples: [Float],
        sampleRate: Double,
        channelCount: Int
    ) -> ExtractedAudioFeatures {
        // Mix down to mono if stereo
        let mono: [Float]
        if channelCount == 2 {
            mono = mixToMono(samples)
        } else {
            mono = samples
        }

        guard !mono.isEmpty else {
            return ExtractedAudioFeatures(
                bpm: nil,
                spectralCentroidHz: 0,
                brightness: 0.5,
                warmth: 0.5,
                energy: 0.5,
                density: 0.5,
                key: nil,
                scale: .unknown
            )
        }

        // Compute features
        let rmsEnergy = computeRMS(mono)
        let spectralResult = computeSpectralFeatures(mono, sampleRate: sampleRate)
        let bpm = detectTempo(mono, sampleRate: sampleRate)
        let keyResult = detectKey(mono, sampleRate: sampleRate)

        // Normalize using Theme tokens
        let normalizedBrightness = normalize(
            spectralResult.centroid,
            range: Theme.SoundDNA.spectralCentroidRange
        )
        let normalizedEnergy = normalize(
            Double(rmsEnergy),
            range: Theme.SoundDNA.rmsEnergyRange
        )

        return ExtractedAudioFeatures(
            bpm: bpm,
            spectralCentroidHz: spectralResult.centroid,
            brightness: normalizedBrightness,
            warmth: spectralResult.warmth,
            energy: normalizedEnergy,
            density: spectralResult.density,
            key: keyResult.key,
            scale: keyResult.scale
        )
    }

    // MARK: - Mono Mixdown

    /// Mix interleaved stereo samples to mono by averaging L+R.
    private func mixToMono(_ stereo: [Float]) -> [Float] {
        let frameCount = stereo.count / 2
        var mono = [Float](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            mono[i] = (stereo[i * 2] + stereo[i * 2 + 1]) * 0.5
        }
        return mono
    }

    // MARK: - RMS Energy

    /// Compute root-mean-square amplitude.
    private func computeRMS(_ samples: [Float]) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return rms
    }

    // MARK: - Spectral Features

    private struct SpectralResult {
        let centroid: Double    // Hz
        let warmth: Double      // [0, 1]
        let density: Double     // [0, 1]
    }

    /// Accumulated spectral statistics across FFT frames.
    private struct SpectralAccumulator {
        var totalCentroid: Double = 0
        var totalLowEnergy: Double = 0
        var totalEnergy: Double = 0
        var totalFlatness: Double = 0
        var frameCount: Int = 0
    }

    /// Compute magnitude spectrum from a windowed frame via forward FFT.
    private func computeFrameMagnitudes(
        _ windowed: [Float],
        fftSetup: FFTSetup,
        fftSize: Int,
        halfFFT: Int
    ) -> [Float] {
        var realPart = [Float](repeating: 0, count: halfFFT)
        var imagPart = [Float](repeating: 0, count: halfFFT)
        windowed.withUnsafeBufferPointer { buffer in
            realPart.withUnsafeMutableBufferPointer { realBuf in
                imagPart.withUnsafeMutableBufferPointer { imagBuf in
                    var splitComplex = DSPSplitComplex(
                        realp: realBuf.baseAddress!,
                        imagp: imagBuf.baseAddress!
                    )
                    buffer.baseAddress!.withMemoryRebound(
                        to: DSPComplex.self,
                        capacity: halfFFT
                    ) { complexPtr in
                        vDSP_ctoz(
                            complexPtr, 2,
                            &splitComplex, 1,
                            vDSP_Length(halfFFT)
                        )
                    }
                    vDSP_fft_zrip(
                        fftSetup,
                        &splitComplex, 1,
                        vDSP_Length(log2(Double(fftSize))),
                        FFTDirection(FFT_FORWARD)
                    )
                }
            }
        }

        var magnitudes = [Float](repeating: 0, count: halfFFT)
        realPart.withUnsafeBufferPointer { realBuf in
            imagPart.withUnsafeBufferPointer { imagBuf in
                var split = DSPSplitComplex(
                    realp: UnsafeMutablePointer(mutating: realBuf.baseAddress!),
                    imagp: UnsafeMutablePointer(mutating: imagBuf.baseAddress!)
                )
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(halfFFT))
            }
        }
        return magnitudes
    }

    /// Accumulate spectral centroid, warmth, and flatness from one frame's magnitudes.
    private func accumulateSpectralBins(
        magnitudes: [Float],
        binWidth: Double,
        warmthBin: Int,
        halfFFT: Int,
        accumulator: inout SpectralAccumulator
    ) {
        // Spectral centroid
        var weightedSum: Float = 0
        var magSum: Float = 0
        for bin in 1..<halfFFT {
            let freq = Float(bin) * Float(binWidth)
            weightedSum += freq * magnitudes[bin]
            magSum += magnitudes[bin]
        }
        let frameCentroid = magSum > 0
                ? Double(weightedSum / magSum)
                : Theme.SoundDNA.fallbackSpectralCentroidHz
        accumulator.totalCentroid += frameCentroid

        // Low-frequency energy (warmth)
        var lowEnergy: Float = 0
        let lowBins = min(warmthBin, halfFFT)
        vDSP_sve(magnitudes, 1, &lowEnergy, vDSP_Length(lowBins))
        accumulator.totalLowEnergy += Double(lowEnergy)
        accumulator.totalEnergy += Double(magSum)

        // Spectral flatness (density)
        // Geometric mean / arithmetic mean of magnitude spectrum
        var logMags = [Float](repeating: 0, count: halfFFT)
        var count = Int32(halfFFT)
        vvlogf(&logMags, magnitudes, &count)
        var logMean: Float = 0
        vDSP_meanv(logMags, 1, &logMean, vDSP_Length(halfFFT))
        let geometricMean = exp(Double(logMean))
        let arithmeticMean = magSum > 0 ? Double(magSum) / Double(halfFFT) : 1.0
        let flatness = arithmeticMean > 0 ? geometricMean / arithmeticMean : 0.0
        accumulator.totalFlatness += flatness

        accumulator.frameCount += 1
    }

    /// Normalize accumulated spectral statistics into a final result.
    private func normalizeSpectralResult(
        _ accumulator: SpectralAccumulator
    ) -> SpectralResult {
        let avgCentroid = accumulator.totalCentroid / Double(accumulator.frameCount)
        let warmthRatio = accumulator.totalEnergy > 0
            ? accumulator.totalLowEnergy / accumulator.totalEnergy
            : Theme.SoundDNA.defaultFeatureValue
        let avgFlatness = accumulator.totalFlatness / Double(accumulator.frameCount)

        // Warmth: higher low-frequency ratio = warmer
        let warmth = min(max(warmthRatio, 0.0), 1.0)

        // Density: spectral flatness indicates noise-like (dense) vs. tonal (sparse)
        let densityThreshold = Theme.SoundDNA.densityFlatnessThreshold
        let density = min(max(avgFlatness / densityThreshold, 0.0), 1.0)

        return SpectralResult(
            centroid: avgCentroid,
            warmth: warmth,
            density: density
        )
    }

    /// Compute spectral centroid, warmth (low-frequency ratio), and
    /// density (spectral flatness) using windowed FFT.
    private func computeSpectralFeatures(
        _ samples: [Float],
        sampleRate: Double
    ) -> SpectralResult {
        let fftSize = Theme.SoundDNA.fftSize
        let hopSize = Theme.SoundDNA.fftHopSize
        let halfFFT = fftSize / 2
        let fallback = SpectralResult(
            centroid: Theme.SoundDNA.fallbackSpectralCentroidHz,
            warmth: Theme.SoundDNA.defaultFeatureValue,
            density: Theme.SoundDNA.defaultFeatureValue
        )

        guard samples.count >= fftSize else { return fallback }

        guard let fftSetup = vDSP_create_fftsetup(
            vDSP_Length(log2(Double(fftSize))),
            FFTRadix(kFFTRadix2)
        ) else { return fallback }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        let binWidth = sampleRate / Double(fftSize)
        let warmthBin = Int(Theme.SoundDNA.warmthCutoffHz / binWidth)
        var accumulator = SpectralAccumulator()

        var offset = 0
        while offset + fftSize <= samples.count {
            var windowed = [Float](repeating: 0, count: fftSize)
            vDSP_vmul(
                Array(samples[offset..<(offset + fftSize)]), 1,
                window, 1,
                &windowed, 1,
                vDSP_Length(fftSize)
            )

            let magnitudes = computeFrameMagnitudes(
                windowed, fftSetup: fftSetup, fftSize: fftSize, halfFFT: halfFFT
            )
            accumulateSpectralBins(
                magnitudes: magnitudes,
                binWidth: binWidth,
                warmthBin: warmthBin,
                halfFFT: halfFFT,
                accumulator: &accumulator
            )

            offset += hopSize
        }

        guard accumulator.frameCount > 0 else { return fallback }
        return normalizeSpectralResult(accumulator)
    }

    // MARK: - Tempo Detection

    /// Detect tempo via onset strength + autocorrelation.
    private func detectTempo(
        _ samples: [Float],
        sampleRate: Double
    ) -> Double? {
        let fftSize = Theme.SoundDNA.fftSize
        let hopSize = Theme.SoundDNA.fftHopSize
        let halfFFT = fftSize / 2

        guard samples.count >= fftSize * 2 else { return nil }

        guard let fftSetup = vDSP_create_fftsetup(
            vDSP_Length(log2(Double(fftSize))),
            FFTRadix(kFFTRadix2)
        ) else { return nil }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        // Compute onset strength envelope (spectral flux)
        var previousMagnitudes = [Float](repeating: 0, count: halfFFT)
        var onsetStrength: [Float] = []

        var offset = 0
        while offset + fftSize <= samples.count {
            var windowed = [Float](repeating: 0, count: fftSize)
            vDSP_vmul(
                Array(samples[offset..<(offset + fftSize)]), 1,
                window, 1,
                &windowed, 1,
                vDSP_Length(fftSize)
            )

            var realPart = [Float](repeating: 0, count: halfFFT)
            var imagPart = [Float](repeating: 0, count: halfFFT)
            windowed.withUnsafeBufferPointer { buffer in
                realPart.withUnsafeMutableBufferPointer { realBuf in
                    imagPart.withUnsafeMutableBufferPointer { imagBuf in
                        var splitComplex = DSPSplitComplex(
                            realp: realBuf.baseAddress!,
                            imagp: imagBuf.baseAddress!
                        )
                        buffer.baseAddress!.withMemoryRebound(
                            to: DSPComplex.self,
                            capacity: halfFFT
                        ) { complexPtr in
                            vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfFFT))
                        }
                        vDSP_fft_zrip(
                            fftSetup, &splitComplex, 1,
                            vDSP_Length(log2(Double(fftSize))),
                            FFTDirection(FFT_FORWARD)
                        )
                    }
                }
            }

            var magnitudes = [Float](repeating: 0, count: halfFFT)
            realPart.withUnsafeBufferPointer { realBuf in
                imagPart.withUnsafeBufferPointer { imagBuf in
                    var split = DSPSplitComplex(
                        realp: UnsafeMutablePointer(mutating: realBuf.baseAddress!),
                        imagp: UnsafeMutablePointer(mutating: imagBuf.baseAddress!)
                    )
                    vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(halfFFT))
                }
            }

            // Half-wave rectified spectral flux
            var flux: Float = 0
            for bin in 0..<halfFFT {
                let diff = magnitudes[bin] - previousMagnitudes[bin]
                if diff > 0 { flux += diff }
            }
            onsetStrength.append(flux)
            previousMagnitudes = magnitudes
            offset += hopSize
        }

        guard onsetStrength.count > Theme.SoundDNA.minOnsetFramesForTempo else { return nil }

        // Autocorrelation of onset strength
        let onsetCount = onsetStrength.count
        let hopsPerSecond = sampleRate / Double(hopSize)
        let minBPM = Theme.SoundDNA.bpmDetectionRange.lowerBound
        let maxBPM = Theme.SoundDNA.bpmDetectionRange.upperBound
        let minLag = Int(hopsPerSecond * 60.0 / maxBPM)
        let maxLag = min(Int(hopsPerSecond * 60.0 / minBPM), onsetCount - 1)

        guard minLag < maxLag, maxLag < onsetCount else { return nil }

        var bestLag = minLag
        var bestCorrelation: Float = -.greatestFiniteMagnitude

        for lag in minLag...maxLag {
            var correlation: Float = 0
            let length = onsetCount - lag
            vDSP_dotpr(
                onsetStrength, 1,
                Array(onsetStrength[lag...]), 1,
                &correlation,
                vDSP_Length(length)
            )
            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestLag = lag
            }
        }

        let bpm = (hopsPerSecond * 60.0) / Double(bestLag)

        // Validate against detection range
        guard Theme.SoundDNA.bpmDetectionRange.contains(bpm) else { return nil }

        return bpm
    }

    // MARK: - Key Detection

    private struct KeyResult {
        let key: String?
        let scale: DetectedScale
    }

    /// Build a normalized chromagram from audio samples using windowed FFT.
    /// Returns `nil` if no valid frames could be processed.
    private func buildChromagram(
        _ samples: [Float],
        sampleRate: Double,
        fftSetup: FFTSetup,
        fftSize: Int,
        hopSize: Int
    ) -> [Double]? {
        let halfFFT = fftSize / 2
        let binWidth = sampleRate / Double(fftSize)

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        var chroma = [Double](repeating: 0, count: 12)
        var frameCount = 0

        var offset = 0
        while offset + fftSize <= samples.count {
            var windowed = [Float](repeating: 0, count: fftSize)
            vDSP_vmul(
                Array(samples[offset..<(offset + fftSize)]), 1,
                window, 1,
                &windowed, 1,
                vDSP_Length(fftSize)
            )

            let magnitudes = computeFrameMagnitudes(
                windowed, fftSetup: fftSetup, fftSize: fftSize, halfFFT: halfFFT
            )

            // Map FFT bins to chroma (pitch class) bins
            for bin in 1..<halfFFT {
                let freq = Double(bin) * binWidth
                guard freq > Theme.SoundDNA.keyDetectionMinFreqHz
                      && freq < Theme.SoundDNA.keyDetectionMaxFreqHz else { continue }
                let midiNote = 12.0 * log2(freq / 440.0) + 69.0
                let pitchClass = Int(midiNote.rounded()) % 12
                let normalizedClass = pitchClass < 0 ? pitchClass + 12 : pitchClass
                chroma[normalizedClass] += Double(magnitudes[bin])
            }

            frameCount += 1
            offset += hopSize
        }

        guard frameCount > 0 else { return nil }

        // Normalize chroma
        let chromaMax = chroma.max() ?? 1.0
        if chromaMax > 0 {
            chroma = chroma.map { $0 / chromaMax }
        }
        return chroma
    }

    /// Correlate a normalized chromagram with Krumhansl-Schmuckler key profiles
    /// to determine the best-matching key and scale.
    private func correlateWithKeyProfiles(_ chroma: [Double]) -> KeyResult {
        let majorProfile = Theme.SoundDNA.majorKeyProfile
        let minorProfile = Theme.SoundDNA.minorKeyProfile
        let noteNames = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

        var bestCorrelation: Double = -.greatestFiniteMagnitude
        var bestKey = 0
        var bestIsMajor = true

        for shift in 0..<12 {
            let rotated = (0..<12).map { chroma[($0 + shift) % 12] }

            let majorCorr = pearsonCorrelation(rotated, majorProfile)
            if majorCorr > bestCorrelation {
                bestCorrelation = majorCorr
                bestKey = shift
                bestIsMajor = true
            }

            let minorCorr = pearsonCorrelation(rotated, minorProfile)
            if minorCorr > bestCorrelation {
                bestCorrelation = minorCorr
                bestKey = shift
                bestIsMajor = false
            }
        }

        return KeyResult(
            key: noteNames[bestKey],
            scale: bestIsMajor ? .major : .minor
        )
    }

    /// Detect musical key via chromagram + Krumhansl-Schmuckler profiles.
    private func detectKey(
        _ samples: [Float],
        sampleRate: Double
    ) -> KeyResult {
        let fftSize = Theme.SoundDNA.fftSize
        let hopSize = Theme.SoundDNA.fftHopSize

        guard samples.count >= fftSize else {
            return KeyResult(key: nil, scale: .unknown)
        }

        guard let fftSetup = vDSP_create_fftsetup(
            vDSP_Length(log2(Double(fftSize))),
            FFTRadix(kFFTRadix2)
        ) else {
            return KeyResult(key: nil, scale: .unknown)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        guard let chroma = buildChromagram(
            samples,
            sampleRate: sampleRate,
            fftSetup: fftSetup,
            fftSize: fftSize,
            hopSize: hopSize
        ) else {
            return KeyResult(key: nil, scale: .unknown)
        }

        return correlateWithKeyProfiles(chroma)
    }

    // MARK: - Utilities

    /// Normalize a value to [0, 1] given a range.
    private func normalize(_ value: Double, range: ClosedRange<Double>) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0.5 }
        return (clamped - range.lowerBound) / span
    }

    /// Pearson correlation coefficient between two arrays.
    private func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).reduce(0.0) { $0 + $1.0 * $1.1 }
        let sumX2 = x.reduce(0.0) { $0 + $1 * $1 }
        let sumY2 = y.reduce(0.0) { $0 + $1 * $1 }

        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))
        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }
}
