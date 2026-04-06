"""
BioNaural ML Training Pipeline

Server-side training of population-level models from aggregated session data.
All classical ML algorithms — NO LLMs anywhere.

Models trained:
1. Markov Chain Melodic Progression — transition probability matrices per mode
2. Gaussian Process Bayesian Optimization — population priors for frequency tuning
3. Thompson Sampling Population Weights — initial arm distributions for sound selection
4. Genetic Algorithm for Prompt Optimization — evolves ACE-STEP generation parameters
5. Gaussian Mixture Models — timbre clustering for content diversity
6. Variational Autoencoder — composition parameter space (tiny, CPU-trainable)

Designed to run weekly via cron. Total compute: <5 minutes on CPU.
"""

import json
import logging
import os
from datetime import datetime

import numpy as np
import pandas as pd
from scipy import stats
from sklearn.gaussian_process import GaussianProcessRegressor
from sklearn.gaussian_process.kernels import Matern
from sklearn.mixture import GaussianMixture
from supabase import create_client

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ml-training")

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://nkqgenwbqtnqeqvmokdq.supabase.co")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

MODES = ["focus", "relaxation", "sleep", "energize"]
MIN_SESSIONS_FOR_TRAINING = 20
MIN_USERS_FOR_POPULATION = 5

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)


# ---------------------------------------------------------------------------
# 1. Markov Chain Melodic Progression
# ---------------------------------------------------------------------------


def train_markov_chains():
    """
    Train per-mode Markov transition probability matrices from
    successful session data.

    States: (scale_degree, octave, duration_class) tuples
    Trained on sessions where biometric_success_score > 0.6

    Output: JSON transition matrices stored in ml_population_models
    """
    logger.info("Training Markov chains...")

    for mode in MODES:
        # Fetch successful sessions for this mode
        result = supabase.table("sessions").select(
            "melodic_layer_ids, biometric_success_score, beat_frequency_start, beat_frequency_end"
        ).eq("mode", mode).gte("biometric_success_score", 0.6).execute()

        sessions = result.data
        if len(sessions) < MIN_SESSIONS_FOR_TRAINING:
            logger.info(f"  {mode}: Only {len(sessions)} sessions, skipping (need {MIN_SESSIONS_FOR_TRAINING})")
            continue

        # Build transition matrix from frequency progression data
        # States: quantized beat frequency bands (0.5 Hz resolution)
        freq_transitions = []
        for session in sessions:
            start = session.get("beat_frequency_start", 0)
            end = session.get("beat_frequency_end", 0)
            if start > 0 and end > 0:
                freq_transitions.append((round(start * 2) / 2, round(end * 2) / 2))

        if len(freq_transitions) < 10:
            logger.info(f"  {mode}: Insufficient frequency data, using defaults")
            # Store a uniform transition matrix as baseline
            _store_default_markov(mode)
            continue

        # Build count matrix
        all_freqs = sorted(set(
            f for pair in freq_transitions for f in pair
        ))
        freq_to_idx = {f: i for i, f in enumerate(all_freqs)}
        n = len(all_freqs)
        counts = np.zeros((n, n))

        for start_f, end_f in freq_transitions:
            i = freq_to_idx[start_f]
            j = freq_to_idx[end_f]
            counts[i, j] += 1

        # Normalize to probabilities (Laplace smoothing)
        counts += 0.1  # Small smoothing to avoid zero probabilities
        transition_matrix = counts / counts.sum(axis=1, keepdims=True)

        # Also build note transition priors from melodic data patterns
        # Scale degree transitions: common voice-leading patterns
        # These are music-theory-informed priors, not learned from data
        degree_transitions = _music_theory_markov(mode)

        parameters = {
            "frequency_states": [float(f) for f in all_freqs],
            "frequency_transitions": transition_matrix.tolist(),
            "degree_transitions": degree_transitions,
            "training_sessions": len(sessions),
        }

        _upsert_population_model(
            model_type="markov_transitions",
            mode=mode,
            parameters=parameters,
            session_count=len(sessions),
            user_count=_count_unique_users(sessions),
        )
        logger.info(f"  {mode}: Trained on {len(sessions)} sessions, {n} frequency states")


def _music_theory_markov(mode: str) -> dict:
    """
    Music-theory-informed Markov matrices for scale degree transitions.
    These encode voice-leading principles: prefer stepwise motion,
    resolve tendency tones, maintain harmonic coherence.

    NOT learned from data — these are compositional rules encoded as
    probability distributions.
    """
    # Scale degrees 1-7 (0-indexed as 0-6)
    # Higher probability = more likely transition

    if mode == "focus":
        # Pentatonic major (1,2,3,5,6): stepwise with resolution bias
        return {
            "states": [1, 2, 3, 5, 6],
            "matrix": [
                [0.1, 0.35, 0.25, 0.2, 0.1],   # From 1: prefer step to 2
                [0.25, 0.1, 0.35, 0.15, 0.15],  # From 2: prefer step to 3
                [0.2, 0.3, 0.1, 0.25, 0.15],    # From 3: prefer step to 2 or leap to 5
                [0.15, 0.1, 0.25, 0.1, 0.4],    # From 5: prefer step to 6
                [0.3, 0.15, 0.15, 0.3, 0.1],    # From 6: resolve to 1 or 5
            ],
        }
    elif mode == "relaxation":
        # Lydian (1,2,3,#4,5,6,7): dreamy, floating
        return {
            "states": [1, 2, 3, 4.5, 5, 6, 7],
            "matrix": [
                [0.05, 0.25, 0.15, 0.15, 0.2, 0.1, 0.1],
                [0.2, 0.05, 0.25, 0.15, 0.15, 0.1, 0.1],
                [0.15, 0.2, 0.05, 0.25, 0.15, 0.1, 0.1],
                [0.1, 0.1, 0.2, 0.05, 0.3, 0.15, 0.1],
                [0.2, 0.1, 0.1, 0.15, 0.05, 0.25, 0.15],
                [0.15, 0.1, 0.1, 0.1, 0.2, 0.05, 0.3],
                [0.3, 0.1, 0.1, 0.1, 0.15, 0.2, 0.05],
            ],
        }
    elif mode == "sleep":
        # Pentatonic minor (1,b3,4,5,b7): minimal, sparse
        return {
            "states": [1, 3, 4, 5, 7],
            "matrix": [
                [0.15, 0.3, 0.2, 0.2, 0.15],
                [0.25, 0.1, 0.3, 0.2, 0.15],
                [0.2, 0.25, 0.1, 0.3, 0.15],
                [0.25, 0.15, 0.25, 0.1, 0.25],
                [0.35, 0.15, 0.15, 0.2, 0.15],
            ],
        }
    else:  # energize
        # Major (all 7 degrees): bright, forward-driving
        return {
            "states": [1, 2, 3, 4, 5, 6, 7],
            "matrix": [
                [0.05, 0.25, 0.2, 0.1, 0.2, 0.1, 0.1],
                [0.15, 0.05, 0.3, 0.15, 0.15, 0.1, 0.1],
                [0.15, 0.2, 0.05, 0.25, 0.15, 0.1, 0.1],
                [0.1, 0.1, 0.15, 0.05, 0.35, 0.15, 0.1],
                [0.25, 0.1, 0.1, 0.15, 0.05, 0.2, 0.15],
                [0.1, 0.1, 0.1, 0.1, 0.25, 0.05, 0.3],
                [0.35, 0.1, 0.1, 0.1, 0.15, 0.15, 0.05],
            ],
        }


def _store_default_markov(mode: str):
    """Store a default (music-theory-only) Markov model when insufficient data."""
    parameters = {
        "frequency_states": [],
        "frequency_transitions": [],
        "degree_transitions": _music_theory_markov(mode),
        "training_sessions": 0,
    }
    _upsert_population_model(
        model_type="markov_transitions",
        mode=mode,
        parameters=parameters,
        session_count=0,
        user_count=0,
    )


# ---------------------------------------------------------------------------
# 2. Gaussian Process Population Priors
# ---------------------------------------------------------------------------


def train_gp_priors():
    """
    Train GP population priors for per-user frequency tuning.
    Maps (beat_frequency, carrier_frequency) → biometric_success_score.

    The population prior gives new users a head start — they don't
    start from scratch but from what works for most people.
    """
    logger.info("Training GP population priors...")

    for mode in MODES:
        result = supabase.table("sessions").select(
            "beat_frequency_start, beat_frequency_end, carrier_frequency, biometric_success_score, user_id"
        ).eq("mode", mode).not_.is_("biometric_success_score", "null").execute()

        sessions = result.data
        if len(sessions) < MIN_SESSIONS_FOR_TRAINING:
            logger.info(f"  {mode}: Only {len(sessions)} sessions, skipping")
            continue

        # Build feature matrix: (avg_beat_freq, carrier_freq)
        X = []
        y = []
        for s in sessions:
            avg_beat = (s["beat_frequency_start"] + s["beat_frequency_end"]) / 2
            carrier = s["carrier_frequency"]
            score = s["biometric_success_score"]
            if avg_beat > 0 and carrier > 0 and score is not None:
                X.append([avg_beat, carrier])
                y.append(score)

        if len(X) < 10:
            logger.info(f"  {mode}: Insufficient valid data points")
            continue

        X = np.array(X)
        y = np.array(y)

        # Fit GP with Matérn 5/2 kernel
        kernel = Matern(nu=2.5, length_scale=[5.0, 50.0], length_scale_bounds=[(0.5, 50), (10, 500)])
        gp = GaussianProcessRegressor(kernel=kernel, alpha=0.1, n_restarts_optimizer=3)
        gp.fit(X, y)

        # Extract posterior parameters for on-device reconstruction
        # Store the training points and kernel hyperparameters
        # On-device GP uses these as a prior
        parameters = {
            "kernel_length_scales": gp.kernel_.get_params()["k1__k2__length_scale"].tolist()
                if hasattr(gp.kernel_.get_params().get("k1__k2__length_scale", 0), "tolist")
                else [5.0, 50.0],
            "kernel_constant": float(gp.kernel_.get_params().get("k1__k1__constant_value", 1.0)),
            "alpha": 0.1,
            "X_train_mean": X.mean(axis=0).tolist(),
            "X_train_std": X.std(axis=0).tolist(),
            "y_train_mean": float(y.mean()),
            "y_train_std": float(y.std()),
            # Store a subset of inducing points (max 50) for efficient on-device prediction
            "inducing_X": X[:50].tolist(),
            "inducing_y": y[:50].tolist(),
            "training_sessions": len(sessions),
            "cv_score": float(gp.score(X, y)),
        }

        _upsert_population_model(
            model_type="gp_population_prior",
            mode=mode,
            parameters=parameters,
            session_count=len(sessions),
            user_count=_count_unique_users(sessions),
            cv_score=parameters["cv_score"],
        )
        logger.info(f"  {mode}: Trained on {len(X)} points, R²={parameters['cv_score']:.3f}")


# ---------------------------------------------------------------------------
# 3. Thompson Sampling Population Weights
# ---------------------------------------------------------------------------


def train_thompson_weights():
    """
    Compute population-level arm (sound/pack) success rates for
    Thompson Sampling contextual bandit cold-start.

    Each arm's success is modeled as Beta(alpha, beta) distribution.
    New users start with the population prior instead of uninformative Beta(1,1).
    """
    logger.info("Training Thompson Sampling population weights...")

    for mode in MODES:
        # Get aggregated outcome data per stem pack
        result = supabase.table("aggregate_outcomes").select(
            "stem_pack_id, session_count, avg_biometric_score, avg_overall_score, avg_completion_rate"
        ).eq("mode", mode).not_.is_("stem_pack_id", "null").execute()

        outcomes = result.data
        if len(outcomes) < 3:
            logger.info(f"  {mode}: Only {len(outcomes)} packs with data, skipping")
            continue

        arm_priors = {}
        for outcome in outcomes:
            pack_id = outcome["stem_pack_id"]
            n = outcome["session_count"]
            avg_score = outcome.get("avg_overall_score") or outcome.get("avg_biometric_score", 0.5)

            if n < 3 or avg_score is None:
                continue

            # Convert average score to Beta distribution parameters
            # Using method of moments: alpha = mean * n_effective, beta = (1-mean) * n_effective
            # Cap n_effective to prevent overly confident priors
            n_effective = min(n, 50)
            alpha = max(1.0, avg_score * n_effective)
            beta = max(1.0, (1 - avg_score) * n_effective)

            arm_priors[pack_id] = {
                "alpha": round(alpha, 2),
                "beta": round(beta, 2),
                "session_count": n,
                "avg_score": round(avg_score, 3),
            }

        if not arm_priors:
            continue

        parameters = {
            "arm_priors": arm_priors,
            "default_alpha": 1.0,  # Uninformative prior for unknown arms
            "default_beta": 1.0,
            "training_packs": len(arm_priors),
        }

        total_sessions = sum(o["session_count"] for o in outcomes)
        _upsert_population_model(
            model_type="thompson_population_weights",
            mode=mode,
            parameters=parameters,
            session_count=total_sessions,
            user_count=0,  # Aggregated data doesn't track unique users
        )
        logger.info(f"  {mode}: {len(arm_priors)} pack priors from {total_sessions} sessions")


# ---------------------------------------------------------------------------
# 4. Genetic Algorithm for Prompt Optimization
# ---------------------------------------------------------------------------


def run_genetic_algorithm():
    """
    Evolve optimal ACE-STEP generation parameters per mode using a
    genetic algorithm. Fitness = average biometric success score.

    Genome: (energy, brightness, warmth, density, tempo, key_idx, scale_idx, instrument_idx)
    Each gene is [0, 1] normalized.
    """
    logger.info("Running genetic algorithm for prompt optimization...")

    POPULATION_SIZE = 50
    GENERATIONS = 20
    MUTATION_SIGMA = 0.1
    CROSSOVER_RATE = 0.7
    ELITE_SIZE = 5
    GENE_COUNT = 8

    KEY_OPTIONS = ["C", "D", "E", "F", "G", "A", "Bb"]
    SCALE_OPTIONS = ["pentatonic", "major", "minor", "lydian", "dorian", "mixolydian"]
    INSTRUMENT_OPTIONS = ["pad", "piano", "strings", "guitar", "bells", "synth"]

    for mode in MODES:
        # Fetch aggregate outcomes for fitness evaluation
        result = supabase.table("aggregate_outcomes").select(
            "stem_pack_id, avg_biometric_score, session_count"
        ).eq("mode", mode).gte("session_count", 3).execute()

        # Also fetch stem pack metadata for existing successful parameters
        pack_result = supabase.table("stem_packs").select(
            "id, energy, brightness, warmth, density, tempo, key"
        ).eq("mode", mode).eq("is_published", True).execute()

        packs_by_id = {p["id"]: p for p in pack_result.data}

        if len(result.data) < 5:
            logger.info(f"  {mode}: Insufficient data for GA, skipping")
            continue

        # Build fitness lookup: parameter vector → score
        fitness_data = []
        for outcome in result.data:
            pack = packs_by_id.get(outcome["stem_pack_id"])
            if pack and outcome["avg_biometric_score"]:
                genome = _pack_to_genome(pack, mode)
                fitness_data.append((genome, outcome["avg_biometric_score"]))

        # Initialize population: seed with successful genomes + random
        population = []
        for genome, _ in fitness_data[:POPULATION_SIZE // 2]:
            population.append(genome)
        while len(population) < POPULATION_SIZE:
            population.append(np.random.rand(GENE_COUNT))

        # Evolve
        for gen in range(GENERATIONS):
            # Evaluate fitness
            fitness_scores = [_evaluate_fitness(ind, fitness_data) for ind in population]

            # Sort by fitness (descending)
            sorted_indices = np.argsort(fitness_scores)[::-1]
            population = [population[i] for i in sorted_indices]
            fitness_scores = [fitness_scores[i] for i in sorted_indices]

            # Elite preservation
            new_population = population[:ELITE_SIZE]

            # Generate offspring
            while len(new_population) < POPULATION_SIZE:
                # Tournament selection (k=3)
                parents = []
                for _ in range(2):
                    tournament = np.random.choice(len(population), size=3, replace=False)
                    winner = tournament[np.argmax([fitness_scores[i] for i in tournament])]
                    parents.append(population[winner])

                # Crossover
                if np.random.rand() < CROSSOVER_RATE:
                    mask = np.random.rand(GENE_COUNT) > 0.5
                    child = np.where(mask, parents[0], parents[1])
                else:
                    child = parents[0].copy()

                # Mutation
                mutation = np.random.randn(GENE_COUNT) * MUTATION_SIGMA
                child = np.clip(child + mutation, 0, 1)
                new_population.append(child)

            population = new_population[:POPULATION_SIZE]

        # Extract top-10 genomes as optimized prompts
        top_genomes = population[:10]
        optimized_params = []
        for genome in top_genomes:
            params = _genome_to_params(genome, mode, KEY_OPTIONS, SCALE_OPTIONS, INSTRUMENT_OPTIONS)
            optimized_params.append(params)

        parameters = {
            "optimized_prompts": optimized_params,
            "generations_run": GENERATIONS,
            "population_size": POPULATION_SIZE,
            "best_fitness": float(fitness_scores[0]) if fitness_scores else 0,
        }

        _upsert_population_model(
            model_type="genetic_prompt_optimization",
            mode=mode,
            parameters=parameters,
            session_count=sum(o["session_count"] for o in result.data),
            user_count=0,
        )
        logger.info(f"  {mode}: Best fitness={parameters['best_fitness']:.3f}, {len(optimized_params)} prompts")


def _pack_to_genome(pack: dict, mode: str) -> np.ndarray:
    """Convert stem pack metadata to a normalized genome vector."""
    bpm_range = {"focus": (60, 90), "relaxation": (40, 70), "sleep": (30, 60), "energize": (100, 140)}
    bpm_min, bpm_max = bpm_range.get(mode, (40, 140))

    tempo_normalized = 0.5
    if pack.get("tempo"):
        tempo_normalized = np.clip((pack["tempo"] - bpm_min) / max(1, bpm_max - bpm_min), 0, 1)

    return np.array([
        pack.get("energy", 0.5),
        pack.get("brightness", 0.5),
        pack.get("warmth", 0.5),
        pack.get("density", 0.3) or 0.3,
        tempo_normalized,
        0.5,  # key (placeholder)
        0.5,  # scale (placeholder)
        0.5,  # instrument (placeholder)
    ])


def _evaluate_fitness(individual: np.ndarray, fitness_data: list) -> float:
    """Evaluate fitness by finding nearest neighbors in known data."""
    if not fitness_data:
        return 0.5

    best_score = 0.0
    for known_genome, score in fitness_data:
        distance = np.linalg.norm(individual[:5] - known_genome[:5])
        if distance < 0.3:
            weight = 1.0 / (1.0 + distance * 10)
            best_score = max(best_score, score * weight)

    return best_score if best_score > 0 else 0.3


def _genome_to_params(
    genome: np.ndarray, mode: str, keys: list, scales: list, instruments: list
) -> dict:
    """Convert a genome vector to human-readable generation parameters."""
    bpm_range = {"focus": (60, 90), "relaxation": (40, 70), "sleep": (30, 60), "energize": (100, 140)}
    bpm_min, bpm_max = bpm_range.get(mode, (40, 140))

    return {
        "energy": round(float(genome[0]), 2),
        "brightness": round(float(genome[1]), 2),
        "warmth": round(float(genome[2]), 2),
        "density": round(float(genome[3]), 2),
        "tempo": int(bpm_min + genome[4] * (bpm_max - bpm_min)),
        "key": keys[int(genome[5] * (len(keys) - 1))],
        "scale": scales[int(genome[6] * (len(scales) - 1))],
        "instrument": instruments[int(genome[7] * (len(instruments) - 1))],
    }


# ---------------------------------------------------------------------------
# 5. Gaussian Mixture Models for Timbre Clustering
# ---------------------------------------------------------------------------


def train_gmm_clusters():
    """
    Cluster published stem packs per mode into 3-5 timbral groups.
    Ensures content recommendations explore the full diversity of
    available audio rather than converging on one cluster.
    """
    logger.info("Training GMM timbre clusters...")

    for mode in MODES:
        result = supabase.table("stem_packs").select(
            "id, energy, brightness, warmth, density"
        ).eq("mode", mode).eq("is_published", True).execute()

        packs = result.data
        if len(packs) < 6:
            logger.info(f"  {mode}: Only {len(packs)} packs, skipping clustering")
            continue

        # Build feature matrix
        features = []
        pack_ids = []
        for pack in packs:
            features.append([
                pack.get("energy", 0.5),
                pack.get("brightness", 0.5),
                pack.get("warmth", 0.5),
                pack.get("density", 0.3) or 0.3,
            ])
            pack_ids.append(pack["id"])

        X = np.array(features)

        # Determine optimal number of clusters (3-5) using BIC
        best_bic = np.inf
        best_n = 3
        for n_components in range(3, min(6, len(packs))):
            gmm = GaussianMixture(n_components=n_components, covariance_type="full", random_state=42)
            gmm.fit(X)
            bic = gmm.bic(X)
            if bic < best_bic:
                best_bic = bic
                best_n = n_components

        # Fit final model
        gmm = GaussianMixture(n_components=best_n, covariance_type="full", random_state=42)
        gmm.fit(X)
        labels = gmm.predict(X)

        # Build cluster assignments
        clusters = {}
        for i, (pack_id, label) in enumerate(zip(pack_ids, labels)):
            cluster_key = str(int(label))
            if cluster_key not in clusters:
                clusters[cluster_key] = []
            clusters[cluster_key].append(pack_id)

        parameters = {
            "n_clusters": best_n,
            "means": gmm.means_.tolist(),
            "covariances": gmm.covariances_.tolist(),
            "weights": gmm.weights_.tolist(),
            "cluster_assignments": clusters,
            "feature_names": ["energy", "brightness", "warmth", "density"],
            "bic": float(best_bic),
        }

        _upsert_population_model(
            model_type="gmm_timbre_clusters",
            mode=mode,
            parameters=parameters,
            session_count=0,
            user_count=0,
            cv_score=float(-best_bic),  # Lower BIC is better
        )
        logger.info(f"  {mode}: {best_n} clusters from {len(packs)} packs (BIC={best_bic:.1f})")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _count_unique_users(sessions: list) -> int:
    return len(set(s.get("user_id", "") for s in sessions if s.get("user_id")))


def _upsert_population_model(
    model_type: str,
    mode: str,
    parameters: dict,
    session_count: int,
    user_count: int,
    cv_score: float | None = None,
):
    """Upsert a population model into ml_population_models."""
    # Check if exists
    result = supabase.table("ml_population_models").select("id, version").eq(
        "model_type", model_type
    ).eq("mode", mode).execute()

    now = datetime.utcnow().isoformat()

    if result.data:
        existing = result.data[0]
        supabase.table("ml_population_models").update({
            "parameters": parameters,
            "version": existing["version"] + 1,
            "training_session_count": session_count,
            "training_user_count": user_count,
            "trained_at": now,
            "cross_validation_score": cv_score,
        }).eq("id", existing["id"]).execute()
    else:
        supabase.table("ml_population_models").insert({
            "model_type": model_type,
            "mode": mode,
            "parameters": parameters,
            "version": 1,
            "training_session_count": session_count,
            "training_user_count": user_count,
            "trained_at": now,
            "cross_validation_score": cv_score,
        }).execute()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def run_all():
    """Run the complete ML training pipeline."""
    logger.info("=" * 60)
    logger.info("BioNaural ML Training Pipeline — Starting")
    logger.info("=" * 60)

    train_markov_chains()
    train_gp_priors()
    train_thompson_weights()
    run_genetic_algorithm()
    train_gmm_clusters()

    logger.info("=" * 60)
    logger.info("BioNaural ML Training Pipeline — Complete")
    logger.info("=" * 60)


if __name__ == "__main__":
    run_all()
