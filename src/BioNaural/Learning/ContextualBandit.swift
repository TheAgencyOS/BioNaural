// ContextualBandit.swift
// BioNaural
//
// Linear Thompson Sampling contextual bandit for personalized music
// generation parameter selection. Learns which combinations of scale,
// density, contour, rhythmic feel, and energy curve produce the best
// biometric outcomes for each user.
//
// Architecture:
// - 15-feature context vector (mode, biometrics, time, mood)
// - Per-arm precision matrix (15×15) + posterior mean (15×1)
// - ~48 KB total state for 50 arms
// - < 0.1 ms inference, incremental posterior update per session
// - Pure Swift + Accelerate — no Core ML dependency
//
// Based on Tech-MLModels.md linear Thompson Sampling specification.

import Accelerate
import Foundation
import OSLog

// MARK: - Generation Parameter Preset

/// A set of music generation parameters that the bandit selects between.
/// Each arm represents a distinct "sound recipe" for the generative engine.
public struct GenerationPreset: Codable, Sendable {
    public let id: Int
    public let label: String

    /// Scale type for melody generation.
    public let scaleType: String          // "pentatonic_major", "dorian", "lydian", etc.
    /// Note density multiplier (0.5 = sparse, 1.0 = normal, 2.0 = dense).
    public let densityMultiplier: Double
    /// Melodic contour bias ("ascending", "descending", "arch", "flat").
    public let contour: String
    /// Rhythmic feel ("straight", "swing", "syncopated").
    public let rhythmicFeel: String
    /// Energy curve shape ("plateau", "build_drop", "escalating", "breathing").
    public let energyCurve: String
}

// MARK: - Context Vector

/// The 15-feature context vector fed to the bandit at session start.
public struct BanditContext: Sendable {
    // Mode (one-hot encoded as 4 features internally)
    public let mode: Int                // 0=sleep, 1=relax, 2=focus, 3=energize
    // Biometrics
    public let hrNormalized: Double     // 0.0-1.0
    public let hrvNormalized: Double    // 0.0-1.0
    public let biometricState: Int      // 0=calm, 1=focused, 2=elevated, 3=peak
    // User state
    public let moodSelfReport: Double   // 0.0 (wired) to 1.0 (calm)
    public let entrainmentMethod: Int   // 0=binaural, 1=isochronic
    // Temporal
    public let hourOfDay: Double        // 0-23
    public let dayOfWeek: Double        // 0-6
    // HealthKit context
    public let sleepQuality: Double     // 0.0-1.0
    public let activityLevel: Double    // 0.0-1.0

    /// Convert to the 15-element feature vector.
    public func toFeatureVector() -> [Double] {
        // Mode one-hot (4 features)
        var vec = [Double](repeating: 0, count: 15)
        if mode >= 0 && mode < 4 { vec[mode] = 1.0 }

        // Scalar features
        vec[4] = Double(entrainmentMethod)
        vec[5] = hrNormalized
        vec[6] = hrvNormalized
        vec[7] = Double(biometricState) / 3.0  // normalize to 0-1
        vec[8] = moodSelfReport

        // Temporal (sin/cos encoding for cyclical features)
        vec[9]  = sin(2.0 * .pi * hourOfDay / 24.0)
        vec[10] = cos(2.0 * .pi * hourOfDay / 24.0)
        vec[11] = sin(2.0 * .pi * dayOfWeek / 7.0)
        vec[12] = cos(2.0 * .pi * dayOfWeek / 7.0)

        // HealthKit context
        vec[13] = sleepQuality
        vec[14] = activityLevel

        return vec
    }
}

// MARK: - Contextual Bandit

/// Linear Thompson Sampling bandit that learns per-user music preferences.
///
/// Each "arm" is a `GenerationPreset` (combination of scale, density,
/// contour, rhythm, energy curve). The bandit maintains a Bayesian linear
/// regression posterior per arm, updated after each session with the
/// observed reward (biometric success score + thumbs feedback).
///
/// Inference: sample weight vector from posterior → dot with context →
/// pick arm with highest sampled reward. O(K × d²) where K=arms, d=15.
public final class ContextualBandit: @unchecked Sendable {

    // MARK: - Configuration

    /// Feature dimension (15).
    private let d = 15

    /// Regularization parameter for the precision matrix.
    private let lambda: Double = 1.0

    /// Noise variance for reward observations.
    private let sigma2: Double = 0.25

    // MARK: - Arms

    /// Available generation presets (arms).
    public let presets: [GenerationPreset]

    // MARK: - Per-Arm Posterior State

    /// Precision matrix per arm: B_a = λI + Σ(x_t × x_t^T) / σ²
    /// Stored as flat [Double] of size d×d per arm.
    private var precisionMatrices: [[Double]]

    /// Weighted sum vector per arm: f_a = Σ(x_t × r_t) / σ²
    private var weightedSums: [[Double]]

    /// Number of observations per arm.
    private var armCounts: [Int]

    /// Serial queue for thread-safe updates.
    private let queue = DispatchQueue(label: "com.bionaural.bandit")

    // MARK: - Persistence

    private let persistenceKey = "com.bionaural.contextualBandit.state"

    // MARK: - Initialization

    public init(presets: [GenerationPreset]) {
        self.presets = presets

        // Initialize each arm with λI precision (uninformative prior)
        let identity = ContextualBandit.identityMatrix(d: 15, lambda: 1.0)
        self.precisionMatrices = Array(repeating: identity, count: presets.count)
        self.weightedSums = Array(repeating: [Double](repeating: 0, count: 15), count: presets.count)
        self.armCounts = Array(repeating: 0, count: presets.count)

        // Try to restore persisted state
        loadState()
    }

    // MARK: - Arm Selection (Thompson Sampling)

    /// Select the best arm for the given context using Thompson Sampling.
    ///
    /// 1. For each arm, compute posterior mean μ_a = B_a⁻¹ × f_a
    /// 2. Sample θ_a ~ N(μ_a, σ² × B_a⁻¹)
    /// 3. Compute predicted reward: r_a = θ_a · x
    /// 4. Return arm with highest sampled reward
    ///
    /// - Parameter context: The current session context.
    /// - Returns: The selected `GenerationPreset`.
    public func selectArm(context: BanditContext) -> GenerationPreset {
        let x = context.toFeatureVector()

        var bestArm = 0
        var bestReward = -Double.infinity

        for (i, _) in presets.enumerated() {
            // For arms with very few observations, explore with random bonus
            if armCounts[i] < 3 {
                let explorationBonus = Double.random(in: 0...1.0)
                if explorationBonus > bestReward {
                    bestReward = explorationBonus
                    bestArm = i
                }
                continue
            }

            // Compute posterior mean: μ = B⁻¹ × f
            let mu = solvePosteriorMean(arm: i)

            // Sample from posterior: θ ~ N(μ, σ² × B⁻¹)
            // Simplified: add Gaussian noise scaled by uncertainty
            let uncertainty = 1.0 / sqrt(Double(armCounts[i]))
            var theta = mu
            for j in 0..<d {
                theta[j] += uncertainty * gaussianRandom() * sigma2
            }

            // Predicted reward: r = θ · x
            var reward = 0.0
            for j in 0..<d {
                reward += theta[j] * x[j]
            }

            if reward > bestReward {
                bestReward = reward
                bestArm = i
            }
        }

        Logger.audio.info("Bandit selected arm \(bestArm) (\(self.presets[bestArm].label)) with sampled reward \(bestReward, format: .fixed(precision: 3))")
        return presets[bestArm]
    }

    // MARK: - Posterior Update

    /// Update the posterior for the selected arm with the observed reward.
    ///
    /// B_a ← B_a + x × x^T / σ²
    /// f_a ← f_a + x × r / σ²
    ///
    /// - Parameters:
    ///   - arm: The preset that was used.
    ///   - context: The session context.
    ///   - reward: The observed reward (0.0-1.0).
    public func updateArm(arm: GenerationPreset, context: BanditContext, reward: Double) {
        queue.sync {
            guard let idx = presets.firstIndex(where: { $0.id == arm.id }) else { return }

            let x = context.toFeatureVector()

            // Update precision matrix: B += x × x^T / σ²
            for i in 0..<d {
                for j in 0..<d {
                    precisionMatrices[idx][i * d + j] += (x[i] * x[j]) / sigma2
                }
            }

            // Update weighted sum: f += x × r / σ²
            for i in 0..<d {
                weightedSums[idx][i] += (x[i] * reward) / sigma2
            }

            armCounts[idx] += 1

            Logger.audio.info("Bandit updated arm \(idx) (\(arm.label)): reward=\(reward, format: .fixed(precision: 3)), observations=\(self.armCounts[idx])")

            // Persist state after update
            saveState()
        }
    }

    // MARK: - Linear Algebra Helpers

    /// Solve B × μ = f for μ (posterior mean).
    /// Uses simple iterative approach for small d=15.
    private func solvePosteriorMean(arm: Int) -> [Double] {
        let B = precisionMatrices[arm]
        let f = weightedSums[arm]

        // For d=15, direct Gaussian elimination is fast
        var augmented = [[Double]](repeating: [Double](repeating: 0, count: d + 1), count: d)
        for i in 0..<d {
            for j in 0..<d {
                augmented[i][j] = B[i * d + j]
            }
            augmented[i][d] = f[i]
        }

        // Forward elimination
        for i in 0..<d {
            // Find pivot
            var maxRow = i
            for k in (i + 1)..<d {
                if abs(augmented[k][i]) > abs(augmented[maxRow][i]) {
                    maxRow = k
                }
            }
            augmented.swapAt(i, maxRow)

            let pivot = augmented[i][i]
            guard abs(pivot) > 1e-12 else { continue }

            for k in (i + 1)..<d {
                let factor = augmented[k][i] / pivot
                for j in i...(d) {
                    augmented[k][j] -= factor * augmented[i][j]
                }
            }
        }

        // Back substitution
        var result = [Double](repeating: 0, count: d)
        for i in stride(from: d - 1, through: 0, by: -1) {
            var sum = augmented[i][d]
            for j in (i + 1)..<d {
                sum -= augmented[i][j] * result[j]
            }
            let pivot = augmented[i][i]
            result[i] = abs(pivot) > 1e-12 ? sum / pivot : 0
        }

        return result
    }

    /// Generate a standard normal random variable (Box-Muller transform).
    private func gaussianRandom() -> Double {
        let u1 = Double.random(in: 0.001...1.0)
        let u2 = Double.random(in: 0.001...1.0)
        return sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
    }

    /// Create a d×d identity matrix scaled by lambda (flat array).
    private static func identityMatrix(d: Int, lambda: Double) -> [Double] {
        var matrix = [Double](repeating: 0, count: d * d)
        for i in 0..<d {
            matrix[i * d + i] = lambda
        }
        return matrix
    }

    // MARK: - Persistence

    private func saveState() {
        let state = BanditState(
            precisionMatrices: precisionMatrices,
            weightedSums: weightedSums,
            armCounts: armCounts
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }

    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let state = try? JSONDecoder().decode(BanditState.self, from: data),
              state.armCounts.count == presets.count else { return }

        precisionMatrices = state.precisionMatrices
        weightedSums = state.weightedSums
        armCounts = state.armCounts
        Logger.audio.info("Bandit loaded state: \(self.armCounts.reduce(0, +)) total observations")
    }
}

// MARK: - Persistence Model

private struct BanditState: Codable {
    let precisionMatrices: [[Double]]
    let weightedSums: [[Double]]
    let armCounts: [Int]
}

// MARK: - Default Presets

extension ContextualBandit {

    /// The default set of generation parameter presets (arms).
    /// Covers the main musical variations across all modes.
    public static let defaultPresets: [GenerationPreset] = [
        // Pentatonic variations (safe, consonant)
        GenerationPreset(id: 0,  label: "pent_sparse_flat",      scaleType: "pentatonic_major", densityMultiplier: 0.6, contour: "flat",       rhythmicFeel: "straight",    energyCurve: "plateau"),
        GenerationPreset(id: 1,  label: "pent_moderate_arch",    scaleType: "pentatonic_major", densityMultiplier: 1.0, contour: "arch",       rhythmicFeel: "straight",    energyCurve: "breathing"),
        GenerationPreset(id: 2,  label: "pent_dense_ascending",  scaleType: "pentatonic_major", densityMultiplier: 1.4, contour: "ascending",  rhythmicFeel: "syncopated",  energyCurve: "build_drop"),
        GenerationPreset(id: 3,  label: "pent_swing_arch",       scaleType: "pentatonic_minor", densityMultiplier: 1.0, contour: "arch",       rhythmicFeel: "swing",       energyCurve: "breathing"),
        GenerationPreset(id: 4,  label: "pent_sparse_descend",   scaleType: "pentatonic_minor", densityMultiplier: 0.5, contour: "descending", rhythmicFeel: "straight",    energyCurve: "plateau"),

        // Dorian variations (minor with brightness)
        GenerationPreset(id: 5,  label: "dorian_moderate_flat",  scaleType: "dorian",           densityMultiplier: 1.0, contour: "flat",       rhythmicFeel: "straight",    energyCurve: "plateau"),
        GenerationPreset(id: 6,  label: "dorian_dense_ascend",   scaleType: "dorian",           densityMultiplier: 1.4, contour: "ascending",  rhythmicFeel: "syncopated",  energyCurve: "escalating"),
        GenerationPreset(id: 7,  label: "dorian_swing_arch",     scaleType: "dorian",           densityMultiplier: 1.0, contour: "arch",       rhythmicFeel: "swing",       energyCurve: "breathing"),

        // Lydian variations (bright, uplifting)
        GenerationPreset(id: 8,  label: "lydian_sparse_arch",    scaleType: "lydian",           densityMultiplier: 0.7, contour: "arch",       rhythmicFeel: "straight",    energyCurve: "breathing"),
        GenerationPreset(id: 9,  label: "lydian_moderate_ascend",scaleType: "lydian",           densityMultiplier: 1.0, contour: "ascending",  rhythmicFeel: "straight",    energyCurve: "escalating"),
        GenerationPreset(id: 10, label: "lydian_dense_build",    scaleType: "lydian",           densityMultiplier: 1.5, contour: "ascending",  rhythmicFeel: "syncopated",  energyCurve: "build_drop"),

        // Ionian/Major variations (classic, familiar)
        GenerationPreset(id: 11, label: "major_moderate_flat",   scaleType: "ionian",           densityMultiplier: 1.0, contour: "flat",       rhythmicFeel: "straight",    energyCurve: "plateau"),
        GenerationPreset(id: 12, label: "major_dense_build",     scaleType: "ionian",           densityMultiplier: 1.5, contour: "ascending",  rhythmicFeel: "syncopated",  energyCurve: "build_drop"),
        GenerationPreset(id: 13, label: "major_swing_breathing", scaleType: "ionian",           densityMultiplier: 1.0, contour: "arch",       rhythmicFeel: "swing",       energyCurve: "breathing"),

        // Mixolydian variations (rock/funk energy)
        GenerationPreset(id: 14, label: "mixo_moderate_ascend",  scaleType: "mixolydian",       densityMultiplier: 1.0, contour: "ascending",  rhythmicFeel: "straight",    energyCurve: "escalating"),
        GenerationPreset(id: 15, label: "mixo_dense_syncopated", scaleType: "mixolydian",       densityMultiplier: 1.4, contour: "ascending",  rhythmicFeel: "syncopated",  energyCurve: "build_drop"),

        // Whole tone (dreamy, sleep-friendly)
        GenerationPreset(id: 16, label: "whole_sparse_descend",  scaleType: "whole_tone",       densityMultiplier: 0.4, contour: "descending", rhythmicFeel: "straight",    energyCurve: "plateau"),

        // Aeolian/Natural minor (contemplative)
        GenerationPreset(id: 17, label: "aeolian_moderate_arch", scaleType: "aeolian",          densityMultiplier: 1.0, contour: "arch",       rhythmicFeel: "straight",    energyCurve: "breathing"),
        GenerationPreset(id: 18, label: "aeolian_sparse_descend",scaleType: "aeolian",          densityMultiplier: 0.6, contour: "descending", rhythmicFeel: "straight",    energyCurve: "plateau"),
        GenerationPreset(id: 19, label: "aeolian_dense_build",   scaleType: "aeolian",          densityMultiplier: 1.3, contour: "ascending",  rhythmicFeel: "syncopated",  energyCurve: "build_drop"),
    ]
}
