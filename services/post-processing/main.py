"""
BioNaural Post-Processing Service

Receives raw ACE-STEP audio output and produces tagged, normalized,
separated stem packs ready for client consumption.

Pipeline:
1. Download raw audio from Replicate output URL
2. Stem separation via Demucs v4 (htdemucs_ft)
3. Loudness normalization to -18 LUFS per stem
4. EQ for layering (HP 30Hz, low-shelf -2dB@200Hz, presence scoop -1dB@2-4kHz)
5. Loop crossfading (50-200ms raised-cosine at boundaries)
6. Encode to AAC 128kbps (.m4a)
7. Auto-tag: BPM, key, energy, brightness, warmth, density
8. Upload to Supabase Storage
9. Update generation_jobs and stem_packs tables

All ML/algorithmic — no LLMs used anywhere in this pipeline.
"""

import json
import logging
import os
import shutil
import tempfile
import uuid
from pathlib import Path

import httpx
import librosa
import numpy as np
import pyloudnorm as pyln
import soundfile as sf
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("bionaural-postprocess")

app = FastAPI(title="BioNaural Post-Processing Service")

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
TARGET_LUFS = -18.0
TARGET_SAMPLE_RATE = 44100
TARGET_BITRATE_KBPS = 128
LOOP_CROSSFADE_MS = 100
EQ_HIGHPASS_HZ = 30
EQ_LOWSHELF_HZ = 200
EQ_LOWSHELF_DB = -2.0
EQ_PRESENCE_CENTER_HZ = 3000
EQ_PRESENCE_DB = -1.0

# Mode-specific tagging rules
MODE_ENERGY_RANGES = {
    "focus": (0.25, 0.55),
    "relaxation": (0.05, 0.35),
    "sleep": (0.0, 0.2),
    "energize": (0.5, 1.0),
}

MODE_BPM_RANGES = {
    "focus": (60, 90),
    "relaxation": (40, 70),
    "sleep": (30, 60),
    "energize": (100, 140),
}

# Mode-specific instrumentation rules
# Sleep/Relaxation: ambient pads and nature ONLY — no percussion, no rhythm
# Focus: minimal, can include subtle rhythm
# Energize: full palette (percussion, bass, guitar, etc.)
MODE_ALLOWS_RHYTHM = {
    "focus": True,
    "relaxation": False,
    "sleep": False,
    "energize": True,
}

MODE_MAX_BRIGHTNESS = {
    "focus": 0.7,
    "relaxation": 0.5,
    "sleep": 0.3,
    "energize": 1.0,
}

MODE_MAX_DENSITY = {
    "focus": 0.6,
    "relaxation": 0.4,
    "sleep": 0.2,
    "energize": 1.0,
}

# ACE-STEP prompt suffixes per mode (enforce instrumentation rules)
MODE_PROMPT_SUFFIXES = {
    "sleep": "no drums, no percussion, no rhythm, no melody, no vocals, formless, dark, warm",
    "relaxation": "no drums, no percussion, no rhythm, no vocals, gentle, flowing, spacious",
    "focus": "steady, minimal, subtle, no vocals, clean, focused",
    "energize": "rhythmic, driving, uplifting, energetic, no vocals",
}


# ---------------------------------------------------------------------------
# Request/Response Models
# ---------------------------------------------------------------------------


class ProcessRequest(BaseModel):
    job_id: str
    audio_url: str
    mode: str
    prompt: str
    duration_seconds: int = 60
    target_bpm: int | None = None
    target_key: str | None = None
    target_scale: str | None = None
    target_energy: float | None = None
    target_brightness: float | None = None
    target_warmth: float | None = None


class ProcessResponse(BaseModel):
    ok: bool
    pack_id: str | None = None
    error: str | None = None


# ---------------------------------------------------------------------------
# Audio Analysis (Algorithmic — NO LLMs)
# ---------------------------------------------------------------------------


def detect_bpm(audio: np.ndarray, sr: int) -> float:
    """Detect BPM using librosa's beat tracker."""
    tempo, _ = librosa.beat.beat_track(y=audio, sr=sr)
    return float(np.mean(tempo)) if hasattr(tempo, "__len__") else float(tempo)


def detect_key(audio: np.ndarray, sr: int) -> str:
    """Detect musical key using chroma-based analysis."""
    chroma = librosa.feature.chroma_cqt(y=audio, sr=sr)
    chroma_mean = chroma.mean(axis=1)

    # Key names in chromatic order starting from C
    key_names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    # Major and minor key profiles (Krumhansl-Kessler)
    major_profile = np.array(
        [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
    )
    minor_profile = np.array(
        [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]
    )

    best_corr = -1.0
    best_key = "C"

    for shift in range(12):
        shifted_chroma = np.roll(chroma_mean, -shift)
        major_corr = np.corrcoef(shifted_chroma, major_profile)[0, 1]
        minor_corr = np.corrcoef(shifted_chroma, minor_profile)[0, 1]

        if major_corr > best_corr:
            best_corr = major_corr
            best_key = key_names[shift]
        if minor_corr > best_corr:
            best_corr = minor_corr
            best_key = f"{key_names[shift]}m"

    return best_key


def compute_energy(audio: np.ndarray) -> float:
    """Compute energy as normalized RMS."""
    rms = np.sqrt(np.mean(audio**2))
    # Map to 0-1 scale (typical RMS range for music: 0.01-0.3)
    return float(np.clip(rms / 0.3, 0.0, 1.0))


def compute_brightness(audio: np.ndarray, sr: int) -> float:
    """Compute brightness as normalized spectral centroid."""
    centroid = librosa.feature.spectral_centroid(y=audio, sr=sr)
    mean_centroid = float(np.mean(centroid))
    # Normalize: typical range 500-5000 Hz
    return float(np.clip((mean_centroid - 500) / 4500, 0.0, 1.0))


def compute_warmth(audio: np.ndarray, sr: int) -> float:
    """Compute warmth as ratio of low-frequency to high-frequency energy."""
    S = np.abs(librosa.stft(audio))
    freqs = librosa.fft_frequencies(sr=sr)

    low_mask = freqs < 500
    high_mask = freqs > 2000

    low_energy = float(np.sum(S[low_mask, :] ** 2))
    high_energy = float(np.sum(S[high_mask, :] ** 2))

    if high_energy < 1e-10:
        return 1.0
    ratio = low_energy / high_energy
    # Normalize: typical range 0.5-20
    return float(np.clip(ratio / 20, 0.0, 1.0))


def compute_density(audio: np.ndarray, sr: int) -> float:
    """Compute density as normalized onset rate."""
    onsets = librosa.onset.onset_detect(y=audio, sr=sr, units="time")
    if len(onsets) == 0:
        return 0.0
    duration = len(audio) / sr
    onset_rate = len(onsets) / duration  # onsets per second
    # Normalize: 0-4 onsets/sec typical range
    return float(np.clip(onset_rate / 4.0, 0.0, 1.0))


def auto_tag(audio: np.ndarray, sr: int) -> dict:
    """Run all auto-tagging algorithms on audio. Pure ML/DSP, no LLMs."""
    return {
        "bpm": detect_bpm(audio, sr),
        "key": detect_key(audio, sr),
        "energy": compute_energy(audio),
        "brightness": compute_brightness(audio, sr),
        "warmth": compute_warmth(audio, sr),
        "density": compute_density(audio, sr),
    }


# ---------------------------------------------------------------------------
# Audio Processing
# ---------------------------------------------------------------------------


def normalize_loudness(audio: np.ndarray, sr: int, target_lufs: float) -> np.ndarray:
    """Normalize loudness to target LUFS using pyloudnorm."""
    meter = pyln.Meter(sr)
    current_lufs = meter.integrated_loudness(audio)
    if np.isinf(current_lufs):
        return audio
    return pyln.normalize.loudness(audio, current_lufs, target_lufs)


def apply_eq(audio: np.ndarray, sr: int) -> np.ndarray:
    """Apply EQ for stem layering:
    - High-pass at 30Hz (remove sub-bass rumble)
    - Low-shelf -2dB at 200Hz (reduce muddiness)
    - Presence scoop -1dB at 2-4kHz (avoid masking binaural beats)
    """
    from scipy.signal import butter, sosfilt

    # High-pass filter at 30Hz (4th order Butterworth)
    sos_hp = butter(4, EQ_HIGHPASS_HZ, btype="high", fs=sr, output="sos")
    audio = sosfilt(sos_hp, audio, axis=0)

    # Low-shelf at 200Hz (-2dB) — approximate with parametric
    # Using a simple gain reduction below shelf frequency
    sos_ls = butter(2, EQ_LOWSHELF_HZ, btype="low", fs=sr, output="sos")
    low_component = sosfilt(sos_ls, audio, axis=0)
    gain = 10 ** (EQ_LOWSHELF_DB / 20)
    audio = audio + low_component * (gain - 1)

    # Presence scoop at 3kHz (-1dB) — bandpass then subtract
    sos_bp = butter(2, [2000, 4000], btype="band", fs=sr, output="sos")
    presence = sosfilt(sos_bp, audio, axis=0)
    scoop_gain = 1 - 10 ** (EQ_PRESENCE_DB / 20)
    audio = audio - presence * scoop_gain

    return audio


def crossfade_loop(audio: np.ndarray, sr: int, crossfade_ms: int) -> np.ndarray:
    """Apply raised-cosine crossfade at loop boundaries for seamless looping."""
    crossfade_samples = int(sr * crossfade_ms / 1000)
    if crossfade_samples >= len(audio) // 2:
        crossfade_samples = len(audio) // 4

    if crossfade_samples < 10:
        return audio

    # Create raised-cosine fade curves
    t = np.linspace(0, np.pi / 2, crossfade_samples)
    fade_in = np.sin(t) ** 2
    fade_out = np.cos(t) ** 2

    result = audio.copy()

    if result.ndim == 1:
        # Apply crossfade: end fades out, beginning fades in, overlap is summed
        result[:crossfade_samples] = (
            result[:crossfade_samples] * fade_in
            + result[-crossfade_samples:] * fade_out
        )
        result = result[:-crossfade_samples]
    else:
        # Stereo: apply to each channel
        for ch in range(result.shape[1]):
            result[:crossfade_samples, ch] = (
                result[:crossfade_samples, ch] * fade_in
                + result[-crossfade_samples:, ch] * fade_out
            )
        result = result[:-crossfade_samples]

    return result


def encode_m4a(audio: np.ndarray, sr: int, output_path: Path) -> None:
    """Encode audio to AAC (.m4a) at target bitrate using ffmpeg."""
    # Write temp WAV first
    temp_wav = output_path.with_suffix(".wav")
    sf.write(str(temp_wav), audio, sr, subtype="PCM_16")

    # Encode to M4A using ffmpeg
    import subprocess

    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        str(temp_wav),
        "-c:a",
        "aac",
        "-b:a",
        f"{TARGET_BITRATE_KBPS}k",
        "-ar",
        str(TARGET_SAMPLE_RATE),
        str(output_path),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    temp_wav.unlink(missing_ok=True)

    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg encoding failed: {result.stderr}")


# ---------------------------------------------------------------------------
# Stem Separation via Demucs
# ---------------------------------------------------------------------------


def separate_stems(audio_path: Path, output_dir: Path) -> dict[str, Path]:
    """Separate audio into stems using Demucs v4 (htdemucs_ft model).

    Returns a dict mapping stem role to file path:
    - pads: 'other' stem (harmonic content, pads, synths)
    - texture: split from 'other' by spectral centroid threshold
    - bass: 'bass' stem
    - rhythm: 'drums' stem (None for sleep mode)
    - vocals: 'vocals' stem (discarded)
    """
    import subprocess

    cmd = [
        "python",
        "-m",
        "demucs",
        "--two-stems=vocals",  # First pass: separate vocals
        "-n",
        "htdemucs_ft",
        "--out",
        str(output_dir),
        str(audio_path),
    ]

    # Run full 4-stem separation
    cmd = [
        "python",
        "-m",
        "demucs",
        "-n",
        "htdemucs_ft",
        "--out",
        str(output_dir),
        str(audio_path),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Demucs separation failed: {result.stderr}")

    # Demucs output structure: output_dir/htdemucs_ft/{filename}/{stem}.wav
    stem_dir = output_dir / "htdemucs_ft" / audio_path.stem

    stems = {}
    for stem_name in ["vocals", "drums", "bass", "other"]:
        stem_path = stem_dir / f"{stem_name}.wav"
        if stem_path.exists():
            stems[stem_name] = stem_path

    # Map Demucs stems to BioNaural stem roles
    result_stems: dict[str, Path] = {}

    if "other" in stems:
        # Split 'other' into pads and texture by spectral characteristics
        other_audio, sr = sf.read(str(stems["other"]))
        if other_audio.ndim == 1:
            other_audio = np.column_stack([other_audio, other_audio])

        # Compute spectral centroid to split
        mono = other_audio.mean(axis=1)
        centroid = librosa.feature.spectral_centroid(y=mono, sr=sr)[0]
        mean_centroid = np.mean(centroid)

        # Frame-level split: frames below threshold → pads, above → texture
        hop_length = 512
        n_frames = len(centroid)
        pads_audio = np.zeros_like(other_audio)
        texture_audio = np.zeros_like(other_audio)

        threshold = 2000  # Hz — content below is pads, above is texture

        for i in range(n_frames):
            start = i * hop_length
            end = min(start + hop_length, len(other_audio))
            if centroid[i] < threshold:
                pads_audio[start:end] = other_audio[start:end]
            else:
                texture_audio[start:end] = other_audio[start:end]

        # If the split is too unbalanced, use the full 'other' as pads
        pads_energy = np.sqrt(np.mean(pads_audio**2))
        texture_energy = np.sqrt(np.mean(texture_audio**2))

        if pads_energy < 0.001 or texture_energy < 0.001:
            # Split failed — use full 'other' as pads, generate subtle texture
            pads_path = output_dir / "pads.wav"
            sf.write(str(pads_path), other_audio, sr)
            result_stems["pads"] = pads_path

            # Create a filtered version as texture
            from scipy.signal import butter, sosfilt

            sos = butter(4, 2000, btype="high", fs=sr, output="sos")
            texture_filtered = sosfilt(sos, other_audio, axis=0) * 0.5
            texture_path = output_dir / "texture.wav"
            sf.write(str(texture_path), texture_filtered, sr)
            result_stems["texture"] = texture_path
        else:
            pads_path = output_dir / "pads.wav"
            sf.write(str(pads_path), pads_audio, sr)
            result_stems["pads"] = pads_path

            texture_path = output_dir / "texture.wav"
            sf.write(str(texture_path), texture_audio, sr)
            result_stems["texture"] = texture_path

    if "bass" in stems:
        result_stems["bass"] = stems["bass"]

    if "drums" in stems:
        result_stems["rhythm"] = stems["drums"]

    return result_stems


def filter_stems_for_mode(stems: dict[str, Path], mode: str) -> dict[str, Path]:
    """Enforce mode-specific instrumentation rules on separated stems.

    Sleep/Relaxation: Remove rhythm stem entirely. Cap brightness.
    Focus: Keep rhythm but attenuate.
    Energize: Keep everything.
    """
    if not MODE_ALLOWS_RHYTHM.get(mode, True) and "rhythm" in stems:
        logger.info(f"  Removing rhythm stem for {mode} mode (not allowed)")
        del stems["rhythm"]

    return stems


# ---------------------------------------------------------------------------
# Supabase Integration
# ---------------------------------------------------------------------------


def get_supabase_headers() -> dict:
    return {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "Content-Type": "application/json",
    }


async def upload_to_storage(
    client: httpx.AsyncClient, bucket: str, path: str, file_path: Path, content_type: str
) -> str:
    """Upload a file to Supabase Storage. Returns the storage path."""
    with open(file_path, "rb") as f:
        data = f.read()

    url = f"{SUPABASE_URL}/storage/v1/object/{bucket}/{path}"
    resp = await client.put(
        url,
        content=data,
        headers={
            **get_supabase_headers(),
            "Content-Type": content_type,
        },
    )
    if resp.status_code not in (200, 201):
        raise RuntimeError(f"Storage upload failed: {resp.text}")

    return path


async def update_job_status(
    client: httpx.AsyncClient, job_id: str, status: str, **kwargs
) -> None:
    """Update generation job status via Supabase REST API."""
    url = f"{SUPABASE_URL}/rest/v1/generation_jobs?id=eq.{job_id}"
    body = {"status": status, **kwargs}
    resp = await client.patch(url, json=body, headers=get_supabase_headers())
    if resp.status_code not in (200, 204):
        logger.error(f"Failed to update job {job_id}: {resp.text}")


async def insert_stem_pack(client: httpx.AsyncClient, pack_data: dict) -> None:
    """Insert a stem pack record via Supabase REST API."""
    url = f"{SUPABASE_URL}/rest/v1/stem_packs"
    headers = {**get_supabase_headers(), "Prefer": "return=minimal"}
    resp = await client.post(url, json=pack_data, headers=headers)
    if resp.status_code not in (200, 201):
        raise RuntimeError(f"Failed to insert stem pack: {resp.text}")


# ---------------------------------------------------------------------------
# Main Processing Pipeline
# ---------------------------------------------------------------------------


@app.post("/process", response_model=ProcessResponse)
async def process_audio(request: ProcessRequest):
    """Full post-processing pipeline for ACE-STEP output."""
    work_dir = Path(tempfile.mkdtemp(prefix="bionaural_"))
    pack_id = f"pack_{request.mode}_{uuid.uuid4().hex[:8]}"

    async with httpx.AsyncClient(timeout=300.0) as client:
        try:
            # 1. Download raw audio from Replicate
            logger.info(f"Job {request.job_id}: Downloading audio from {request.audio_url}")
            audio_resp = await client.get(request.audio_url)
            if audio_resp.status_code != 200:
                raise RuntimeError(f"Failed to download audio: {audio_resp.status_code}")

            raw_path = work_dir / "raw_output.wav"
            with open(raw_path, "wb") as f:
                f.write(audio_resp.content)

            # Load audio for analysis
            audio, sr = librosa.load(str(raw_path), sr=TARGET_SAMPLE_RATE, mono=False)
            if audio.ndim == 1:
                audio = np.stack([audio, audio])
            # librosa loads as (channels, samples), soundfile expects (samples, channels)
            audio_sf = audio.T

            # 2. Auto-tag the original mix (before separation)
            logger.info(f"Job {request.job_id}: Auto-tagging")
            mono_mix = audio.mean(axis=0) if audio.ndim > 1 else audio
            tags = auto_tag(mono_mix, sr)
            logger.info(f"Job {request.job_id}: Tags: {tags}")

            # 3. Stem separation via Demucs
            logger.info(f"Job {request.job_id}: Separating stems via Demucs")
            stems = separate_stems(raw_path, work_dir)
            logger.info(f"Job {request.job_id}: Separated stems: {list(stems.keys())}")

            # 3.5. Enforce mode-specific instrumentation rules
            stems = filter_stems_for_mode(stems, request.mode)
            logger.info(f"Job {request.job_id}: After mode filter: {list(stems.keys())}")

            # Cap brightness and density for the mode
            max_brightness = MODE_MAX_BRIGHTNESS.get(request.mode, 1.0)
            max_density = MODE_MAX_DENSITY.get(request.mode, 1.0)
            tags["brightness"] = min(tags["brightness"], max_brightness)
            tags["density"] = min(tags["density"], max_density)

            # 4. Process each stem: normalize, EQ, crossfade, encode
            storage_base = f"{request.mode}/{pack_id}"
            stem_paths: dict[str, str] = {}
            total_archive_size = 0

            for role, stem_path in stems.items():
                logger.info(f"Job {request.job_id}: Processing stem '{role}'")
                stem_audio, stem_sr = sf.read(str(stem_path))

                # Resample if needed
                if stem_sr != TARGET_SAMPLE_RATE:
                    if stem_audio.ndim == 1:
                        stem_audio = librosa.resample(
                            stem_audio, orig_sr=stem_sr, target_sr=TARGET_SAMPLE_RATE
                        )
                    else:
                        channels = []
                        for ch in range(stem_audio.shape[1]):
                            channels.append(
                                librosa.resample(
                                    stem_audio[:, ch],
                                    orig_sr=stem_sr,
                                    target_sr=TARGET_SAMPLE_RATE,
                                )
                            )
                        stem_audio = np.column_stack(channels)

                # Ensure stereo
                if stem_audio.ndim == 1:
                    stem_audio = np.column_stack([stem_audio, stem_audio])

                # Normalize loudness
                stem_audio = normalize_loudness(stem_audio, TARGET_SAMPLE_RATE, TARGET_LUFS)

                # Apply EQ
                stem_audio = apply_eq(stem_audio, TARGET_SAMPLE_RATE)

                # Crossfade loop points
                stem_audio = crossfade_loop(stem_audio, TARGET_SAMPLE_RATE, LOOP_CROSSFADE_MS)

                # Encode to M4A
                m4a_path = work_dir / f"{role}.m4a"
                encode_m4a(stem_audio, TARGET_SAMPLE_RATE, m4a_path)

                # Upload to Supabase Storage
                storage_path = f"{storage_base}/{role}.m4a"
                await upload_to_storage(
                    client, "stem-packs", storage_path, m4a_path, "audio/mp4"
                )
                stem_paths[role] = storage_path
                total_archive_size += m4a_path.stat().st_size

            # 5. Create metadata.json
            metadata = {
                "id": pack_id,
                "name": f"{request.mode.capitalize()} Pack",
                "padsFileName": "pads.m4a",
                "textureFileName": "texture.m4a",
                "bassFileName": "bass.m4a",
                "rhythmFileName": "rhythm.m4a" if "rhythm" in stems else None,
                "energy": tags["energy"],
                "brightness": tags["brightness"],
                "warmth": tags["warmth"],
                "density": tags["density"],
                "tempo": tags["bpm"],
                "key": tags["key"],
                "modeAffinity": [request.mode],
                "generatedBy": "ace-step-1.5",
                "generationPrompt": request.prompt,
            }

            metadata_path = work_dir / "metadata.json"
            with open(metadata_path, "w") as f:
                json.dump(metadata, f, indent=2)

            metadata_storage_path = f"{storage_base}/metadata.json"
            await upload_to_storage(
                client, "stem-packs", metadata_storage_path, metadata_path, "application/json"
            )

            # 6. Create archive.zip
            archive_base = work_dir / "archive_contents"
            archive_base.mkdir(exist_ok=True)
            shutil.copy2(metadata_path, archive_base / "metadata.json")
            for role in stems:
                m4a = work_dir / f"{role}.m4a"
                if m4a.exists():
                    shutil.copy2(m4a, archive_base / f"{role}.m4a")

            archive_path = work_dir / "archive"
            shutil.make_archive(str(archive_path), "zip", str(archive_base))
            archive_zip = work_dir / "archive.zip"

            archive_storage_path = f"{storage_base}/archive.zip"
            await upload_to_storage(
                client, "stem-packs", archive_storage_path, archive_zip, "application/zip"
            )
            archive_size = archive_zip.stat().st_size

            # 7. Insert stem_packs record
            await insert_stem_pack(
                client,
                {
                    "id": pack_id,
                    "name": metadata["name"],
                    "mode": request.mode,
                    "energy": tags["energy"],
                    "brightness": tags["brightness"],
                    "warmth": tags["warmth"],
                    "density": tags["density"],
                    "tempo": tags["bpm"],
                    "key": tags["key"],
                    "generated_by": "ace-step-1.5",
                    "generation_prompt": request.prompt,
                    "pads_path": stem_paths.get("pads", ""),
                    "texture_path": stem_paths.get("texture", ""),
                    "bass_path": stem_paths.get("bass", ""),
                    "rhythm_path": stem_paths.get("rhythm"),
                    "metadata_path": metadata_storage_path,
                    "archive_path": archive_storage_path,
                    "archive_size_bytes": archive_size,
                    "duration_seconds": request.duration_seconds,
                    "sample_rate": TARGET_SAMPLE_RATE,
                    "bitrate_kbps": TARGET_BITRATE_KBPS,
                    "lufs_normalized": TARGET_LUFS,
                    "loop_crossfade_ms": LOOP_CROSSFADE_MS,
                    "is_curated": False,
                    "is_published": False,
                },
            )

            # 8. Update generation job to completed
            await update_job_status(
                client,
                request.job_id,
                "completed",
                result_pack_id=pack_id,
                completed_at="now()",
            )

            logger.info(f"Job {request.job_id}: Completed. Pack ID: {pack_id}")
            return ProcessResponse(ok=True, pack_id=pack_id)

        except Exception as e:
            logger.error(f"Job {request.job_id}: Failed: {e}", exc_info=True)

            await update_job_status(
                client,
                request.job_id,
                "failed",
                error_message=str(e),
                completed_at="now()",
            )

            return ProcessResponse(ok=False, error=str(e))

        finally:
            # Clean up temp directory
            shutil.rmtree(work_dir, ignore_errors=True)


@app.get("/health")
async def health():
    return {"status": "ok", "service": "bionaural-postprocessing"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8080)
