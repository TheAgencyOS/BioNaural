# Open-Source AI Audio Generation: Technical Comparison for Wellness/Focus iOS App

**Date:** April 5, 2026
**Purpose:** Evaluate all viable open-source AI audio generation models for adaptive ambient soundscape generation in a wellness/focus iOS app (BioNaural context).

---

## Table of Contents

1. [Stable Audio Open](#1-stable-audio-open-stability-ai)
2. [Riffusion](#2-riffusion)
3. [Bark (Suno)](#3-bark-suno)
4. [AudioLDM / AudioLDM 2](#4-audioldm--audioldm-2)
5. [MusicLDM](#5-musicldm)
6. [Demucs](#6-demucs-meta)
7. [AudioCraft / MusicGen (Meta)](#7-audiocraft--musicgen-meta)
8. [New 2025-2026 Models](#8-new-2025-2026-models)
9. [Comparison Matrix](#9-comparison-matrix)
10. [Recommendations for BioNaural](#10-recommendations-for-bionaural)

---

## 1. Stable Audio Open (Stability AI)

**Repository:** [Stability-AI/stable-audio-tools](https://github.com/Stability-AI/stable-audio-tools)
**Stars:** 3,654 | **Last pushed:** Feb 2026 | **License:** Stability AI Community License

### Architecture
Latent diffusion model (~1.2B parameters) with three components:
- Autoencoder compressing 44.1kHz stereo waveforms to a latent space
- T5-based text embedding for conditioning
- Transformer-based diffusion model (DiT) operating in latent space

### Capabilities
- Generates variable-length stereo audio up to **47 seconds** at 44.1kHz
- Strong at sound effects, field recordings, ambient sounds, foley
- Modest at instrumental music generation
- Text-prompted generation from natural language descriptions

### Fine-Tuning
Full fine-tuning supported via `stable-audio-tools` library. You can fine-tune on custom audio datasets (e.g., your own ambient recordings, binaural textures). Training config and scripts provided. This is a major strength -- you could train on curated wellness/focus soundscapes.

### Licensing Details
- **Stability AI Community License** -- NOT fully open source
- Free for research, non-commercial, and commercial use if your org revenue < $1M/year
- Revenue > $1M requires an enterprise license from Stability AI
- Training data: all CC0, CC-BY, or CC Sampling+ licensed (486K recordings from FreeSound + Free Music Archive)

### Stability AI Company Status (April 2026)
- NOT shutting down -- they stabilized financially
- New CEO Prem Akkaraju eliminated $100M+ in debt via recapitalization
- $50M revenue in 2024, triple-digit growth reported
- Recent partnerships: EA (Feb 2026), Warner Music Group (Nov 2025)
- Won High Court copyright case vs Getty Images (Nov 2025)
- Latest funding: Corporate minority round, March 2025

### On-Device Feasibility
At 1.2B parameters, direct on-device inference on iPhone is not practical without heavy quantization and optimization. The 47s cap means you would need to chain generations for continuous playback. Server-side generation with on-device caching is the realistic path.

### Wellness/Ambient Suitability: HIGH
Explicitly designed for ambient sounds, foley, and sound design. The 47s cap is a limitation for continuous soundscapes but workable with overlap-and-crossfade strategies. Fine-tuning on wellness audio is straightforward.

---

## 2. Riffusion

**Repository:** [riffusion/riffusion-hobby](https://github.com/riffusion/riffusion-hobby)
**Stars:** 3,886 | **Last pushed:** July 2024 (hobby repo stale) | **License:** MIT

### How It Works
Riffusion fine-tuned Stable Diffusion v1.5 to generate **spectrograms as images**, which are then converted to audio via inverse STFT. This is a clever hack: it repurposes the image generation pipeline for audio.

1. Text prompt -> Stable Diffusion generates a mel spectrogram image
2. Spectrogram image -> inverse transform -> audio waveform
3. Interpolation between spectrograms enables smooth transitions

### Capabilities
- Generates short audio clips (typically 5-10 seconds)
- Naturally produces **loopable** clips -- good for ambient backgrounds
- Supports interpolation between prompts for evolving soundscapes
- The "Fuzz" model (early 2025) extended spectrogram-based capabilities

### Quality
- Audio quality is limited by the spectrogram-to-audio conversion (lossy)
- Phase information is approximated, not perfectly reconstructed
- Works well for atmospheric/ambient textures where precise fidelity is less critical
- Less suitable for clean melodic content

### Fine-Tuning
Yes -- standard Stable Diffusion fine-tuning applies (LoRA, DreamBooth, textual inversion). You need a dataset of spectrogram images with text descriptions. Fine-tuning on ambient/wellness spectrograms is feasible.

### Real-Time Capability
The original architecture supports near-real-time generation of short clips. On a GPU, generating a 5s clip takes ~2-3 seconds. Chaining clips with interpolation can create continuous evolving audio. Not real-time on mobile.

### On-Device Feasibility
The underlying Stable Diffusion v1.5 model has been converted to CoreML and runs on iPhone (Apple demonstrated this). However, inference takes 10-30+ seconds per image on device. Not suitable for real-time on-device generation, but pre-generation and caching is possible.

### Wellness/Ambient Suitability: MEDIUM-HIGH
The looping nature and atmospheric quality work well for ambient. The spectrogram approach adds a dreamy, textural quality that can be appealing for meditation/focus. Quality ceiling is lower than dedicated audio models. The hobby repo is stale (last push July 2024), though the commercial Riffusion product continues development separately.

---

## 3. Bark (Suno)

**Repository:** [suno-ai/bark](https://github.com/suno-ai/bark)
**Stars:** 39,068 | **Last pushed:** August 2024 (effectively abandoned) | **License:** MIT

### Architecture
GPT-style autoregressive transformer using EnCodec audio tokens. Three-stage pipeline:
1. Text -> semantic tokens (GPT-like)
2. Semantic tokens -> coarse acoustic tokens
3. Coarse -> fine acoustic tokens -> audio via EnCodec decoder

### What It Can Do Beyond Speech
- Multilingual speech (13+ languages)
- Music snippets (short, unpredictable quality)
- Sound effects (laughter, sighing, crowd noise, ambient sounds)
- Non-verbal vocalizations
- Environmental/background sounds

### Ambient/Music Capabilities
Bark can generate ambient-ish sounds, but it is **primarily a speech model**. Music generation is a side effect, not a core capability. Outputs are short (~13 seconds max), unpredictable, and hard to control for specific musical qualities. You cannot reliably prompt it for "40Hz binaural beat with rain sounds" and get consistent results.

### Fine-Tuning
- No official fine-tuning pipeline provided
- Community efforts exist (bark.cpp for C++ inference, various forks)
- Research papers propose improvements using EnCodec codebooks + HuBERT
- In practice, fine-tuning Bark is difficult and poorly documented

### Maintenance Status
**Effectively abandoned.** Last commit August 2024. 267 open issues. Suno pivoted entirely to their commercial product (suno.com). The open-source Bark was always a research demo, not a production tool.

### On-Device Feasibility
A C++ port exists (bark.cpp) which could theoretically run on device. The small model variant exists for faster inference. However, the short output length and unpredictable quality make this impractical for continuous ambient generation.

### Wellness/Ambient Suitability: LOW
Not designed for this. Speech-first model with incidental audio capabilities. Short outputs, unpredictable quality, abandoned maintenance. Not recommended.

---

## 4. AudioLDM / AudioLDM 2

**Repository:** [haoheliu/AudioLDM2](https://github.com/haoheliu/AudioLDM2)
**Stars:** 2,608 | **Last pushed:** Sept 2024 | **License:** Code: MIT / Weights: CC-BY-NC-4.0

### Architecture
Latent diffusion model with:
- AudioMAE-based audio representation learning
- CLAP + T5 text conditioning (AudioLDM 2 uses "language of audio" self-supervised pretraining)
- VAE for audio compression/decompression

### Capabilities
- **AudioLDM 1:** Text-to-audio (sound effects, environmental sounds, speech)
- **AudioLDM 2:** Unified model for speech, sound effects, AND music
- Three checkpoints available:
  - `audioldm2` -- general text-to-audio
  - `audioldm2-large` -- higher quality general audio
  - `audioldm2-music` -- dedicated music generation
  - `audioldm_48k` -- high-fidelity 48kHz output

### Quality
Good quality for environmental sounds and effects. The 48kHz variant produces high-fidelity output. Music generation is competent but not state-of-the-art compared to newer models. Well-integrated into HuggingFace Diffusers (from v0.21.0+), making it easy to use programmatically.

### Critical Licensing Issue
**The model weights are CC-BY-NC-4.0 (non-commercial).** While the code is MIT, you CANNOT use the pre-trained weights in a commercial app without retraining from scratch or negotiating a license. This is a dealbreaker for a commercial product unless you train your own weights.

### Fine-Tuning
Training code is provided. You can fine-tune on custom datasets. However, if you fine-tune from the CC-BY-NC weights, the derivative work likely inherits the non-commercial restriction.

### On-Device Feasibility
Multiple model sizes available. Integrated into Diffusers, which has ONNX export. CoreML conversion theoretically possible but not documented. Server-side deployment is the realistic path.

### Wellness/Ambient Suitability: MEDIUM (blocked by license)
Strong environmental sound generation. Good for rain, wind, forest, ocean textures. But the NC license kills commercial viability unless you train from scratch.

---

## 5. MusicLDM

**Repository:** [RetroCirce/MusicLDM](https://github.com/RetroCirce/MusicLDM)
**Stars:** 186 | **Last pushed:** January 2024 | **License:** Unclear (no explicit license in repo)

### Architecture
Adapts Stable Diffusion and AudioLDM architectures specifically for music. Uses beat-synchronous mixup strategies during training to improve novelty and reduce memorization.

### Capabilities
- Text-to-music generation
- Beat-synchronous output
- Multi-Track MusicLDM variant (2024) generates separate stems

### Quality
- Output at 16kHz (low for production use; 44.1kHz promised but never delivered)
- Trained on only 10,000 text-music pairs (455 hours) -- small dataset
- Improved FAD scores in multi-track variant

### Current Status
**Effectively dead.** 186 stars, last pushed Jan 2024, only 4 open issues. No training scripts released (only inference). The multi-track variant is a research paper, not a usable tool.

### On-Device Feasibility
Not practical. Limited model quality, no optimization for mobile, no active development.

### Wellness/Ambient Suitability: LOW
16kHz output is inadequate. No active development. No clear license. Not recommended.

---

## 6. Demucs (Meta)

**Repository:** [facebookresearch/demucs](https://github.com/facebookresearch/demucs)
**Stars:** 9,936 | **Last pushed:** April 2024 | **License:** MIT

### What It Does
Demucs is NOT a generation model -- it is a **source separation** model. It splits existing audio into stems: vocals, drums, bass, and other instruments.

### Architecture (v4 -- Hybrid Transformer Demucs)
Hybrid spectrogram + waveform model with Transformer encoder layers. Uses self-attention within each domain and cross-attention across domains.

### Wellness App Use Cases

1. **Stem isolation for remixing:** Take existing ambient/wellness tracks and isolate specific layers (remove vocals, keep atmospheric pads). Build a library of separated stems that can be remixed dynamically.

2. **Adaptive layering:** Separate a complex soundscape into components, then mix them back at different volumes based on biometric input (e.g., fade drums out when heart rate is elevated, boost ambient pads).

3. **Content curation:** Process licensed music to extract usable ambient layers, removing vocals or percussion that would be distracting for focus.

4. **Quality enhancement:** Isolate and remove unwanted elements from field recordings or ambient tracks.

### On-Device Feasibility
Demucs is relatively lightweight compared to generative models. Community ports exist. Processing a track takes seconds on GPU. On-device inference for pre-processing (not real-time) is feasible on modern iPhones.

### Wellness/Ambient Suitability: MEDIUM (complementary tool)
Not a generator, but a powerful preprocessing tool. Best used alongside a generative model to create a library of stem-separated ambient components that can be dynamically mixed.

---

## 7. AudioCraft / MusicGen (Meta)

**Repository:** [facebookresearch/audiocraft](https://github.com/facebookresearch/audiocraft)
**Stars:** 23,151 | **Last pushed:** March 2026 | **License:** Code: MIT / Weights: CC-BY-NC-4.0

### Models in AudioCraft
- **MusicGen:** Text-to-music (300M / 1.5B / 3.3B parameters)
- **AudioGen:** Text-to-sound-effects
- **EnCodec:** Audio compression codec (useful as a component)
- **MAGNeT:** Non-autoregressive variant (faster inference)

### Capabilities
- MusicGen Small (300M) generates 32kHz mono/stereo music from text
- Melodic conditioning available (hum a melody, get a full arrangement)
- AudioGen handles environmental sounds
- Full fine-tuning supported with training recipes

### Critical Licensing Issue
**Same as AudioLDM2: model weights are CC-BY-NC-4.0.** Code is MIT, but pre-trained weights cannot be used commercially. You would need to train from scratch on licensed data or negotiate with Meta.

### On-Device Feasibility
MusicGen Small (300M) is the most realistic candidate for on-device among all generative models here. It is still large for mobile but within the range of what modern iPhones can handle with INT8 quantization and CoreML optimization. No official CoreML export exists, but the model architecture (transformer + EnCodec) is convertible.

### Active Maintenance
Still actively maintained (last push March 2026). The most mature and well-documented codebase in this space.

### Wellness/Ambient Suitability: MEDIUM-HIGH (blocked by license)
Strong generation quality, good ambient capabilities, active maintenance. But NC license is a commercial blocker. If you could train your own weights, this would be a top choice.

---

## 8. New 2025-2026 Models

### ACE-Step 1.5 (April 2026)
**Repository:** [ace-step/ACE-Step-1.5](https://github.com/ace-step/ACE-Step-1.5)
**Stars:** 8,511 | **Last pushed:** April 5, 2026 (today!) | **License:** MIT

**This is the most significant new entrant.**

- **Architecture:** 4B-parameter DiT decoder + 1.7B language model (also 0.6B and 4B LM variants)
- **Speed:** Under 2 seconds per full song on A100, under 10 seconds on RTX 3090
- **Duration:** 10 seconds to 10 minutes (600s) -- no 47s cap
- **Quality:** Claims to exceed most commercial models
- **VRAM:** Runs with < 4GB VRAM (base), XL needs 12-20GB
- **Platform:** Supports Mac (MLX), AMD, Intel, CUDA
- **Fine-tuning:** LoRA training from just a few songs
- **Ambient:** Can generate instrumentals and soundscapes
- **License:** MIT -- fully open, commercial use allowed
- **Maintenance:** Extremely active, pushed today

**Key advantage:** MIT license + active development + Mac/MLX support + LoRA fine-tuning. The 0.6B LM variant + INT8 quantized DiT (~2.4GB) could potentially run on-device, though this is unproven.

### YuE (January 2025)
**Repository:** [multimodal-art-projection/YuE](https://github.com/multimodal-art-projection/YuE)
**Stars:** 6,117 | **Last pushed:** June 2025 | **License:** Apache 2.0

- Full-song generation up to 5 minutes
- Lyrics-to-song with vocal alignment
- Style cloning via in-context learning
- Primarily focused on songs with vocals -- less relevant for instrumental ambient
- Large model, not mobile-friendly

### DiffRhythm (March 2025)
**Repository:** [ASLP-lab/DiffRhythm](https://github.com/ASLP-lab/DiffRhythm)
**Stars:** 2,277 | **Last pushed:** Nov 2025 | **License:** Apache 2.0

- Non-autoregressive diffusion model for full-length songs (up to 285s)
- Trained on 1M songs
- v1.2 improved audio quality and arrangement
- Song editing and continuation support
- Focused on songs with vocals, less on pure ambient

### HeartMuLa (January 2026)
**Repository:** [HeartMuLa/heartlib](https://github.com/HeartMuLa/heartlib)
**Stars:** 4,412 | **Last pushed:** March 2026 | **License:** Apache 2.0

- Family of music foundation models (3B and 7B variants)
- Multi-conditional generation: text descriptions, lyrics, reference audio
- Fine-grained control over song sections (intro, verse, chorus)
- Short background music generation mode
- Multilingual support
- Active development
- Primarily song-focused, but the "short background music" mode could be useful for ambient

---

## 9. Comparison Matrix

| Model | License | Params | Max Duration | Sample Rate | Ambient Quality | On-Device Feasible | Fine-Tuning | Active Maint. | Commercial OK |
|---|---|---|---|---|---|---|---|---|---|
| **Stable Audio Open** | Stability Community | 1.2B | 47s | 44.1kHz stereo | **Excellent** | No (server) | Yes (full) | Yes (Feb 2026) | < $1M rev only |
| **Riffusion** | MIT | ~1B (SD 1.5) | 5-10s | Variable | Good | Marginal | Yes (SD methods) | No (July 2024) | Yes |
| **Bark** | MIT | ~1B | ~13s | 24kHz | Poor | Marginal (bark.cpp) | Difficult | No (Aug 2024) | Yes |
| **AudioLDM 2** | Code: MIT / Weights: CC-BY-NC | ~1B | ~10s | 16-48kHz | Good | No (server) | Yes | No (Sept 2024) | **NO (weights)** |
| **MusicLDM** | Unclear | ~1B | ~10s | 16kHz | Poor | No | Inference only | No (Jan 2024) | Unclear |
| **Demucs** | MIT | ~84M | N/A (separation) | 44.1kHz | N/A (tool) | Yes | N/A | Stale (Apr 2024) | Yes |
| **AudioCraft/MusicGen** | Code: MIT / Weights: CC-BY-NC | 300M-3.3B | 30s | 32kHz | Good-High | Maybe (300M) | Yes | Yes (Mar 2026) | **NO (weights)** |
| **ACE-Step 1.5** | **MIT** | 0.6B-4B | **600s** | 44.1kHz | High | Maybe (0.6B+quant) | Yes (LoRA) | **Very Active** | **Yes** |
| **YuE** | Apache 2.0 | Large | 300s | 44.1kHz | Medium | No | Yes | Moderate | Yes |
| **DiffRhythm** | Apache 2.0 | ~1B | 285s | 44.1kHz | Medium | No | Yes | Moderate | Yes |
| **HeartMuLa** | Apache 2.0 | 3B-7B | Variable | 44.1kHz | Medium | No | Yes | Active | Yes |

### Scoring Summary (1-5 scale, for wellness/focus ambient app)

| Model | Ambient Fit | License Safety | On-Device | Fine-Tune Ease | Maintenance | **Overall** |
|---|---|---|---|---|---|---|
| **ACE-Step 1.5** | 4 | 5 | 2 | 5 | 5 | **4.2** |
| **Stable Audio Open** | 5 | 3 | 1 | 4 | 4 | **3.4** |
| **AudioCraft/MusicGen** | 4 | 2 | 3 | 4 | 5 | **3.6** |
| **Riffusion** | 3 | 5 | 2 | 3 | 1 | **2.8** |
| **HeartMuLa** | 3 | 5 | 1 | 3 | 4 | **3.2** |
| **AudioLDM 2** | 4 | 1 | 1 | 3 | 1 | **2.0** |
| **Demucs** | N/A | 5 | 4 | N/A | 2 | **complementary** |
| **Bark** | 1 | 5 | 2 | 1 | 1 | **2.0** |
| **MusicLDM** | 1 | 1 | 1 | 1 | 1 | **1.0** |

---

## 10. Recommendations for BioNaural

### Top Tier: Investigate Further

**1. ACE-Step 1.5 (MIT) -- Strongest Overall Candidate**
- MIT license removes all commercial friction
- LoRA fine-tuning on a small set of ambient/wellness/binaural tracks is trivial
- 600s generation means you can produce long ambient pieces in one shot
- Mac/MLX support is relevant for development
- Extremely active development (pushed today)
- The 0.6B LM variant with INT8 quantized DiT (~2.4GB) is worth testing for on-device
- **Risk:** Very new, may have stability/quality issues that shake out over time

**2. Stable Audio Open -- Best Ambient Quality**
- Purpose-built for ambient sounds and sound design
- Excellent fine-tuning pipeline for custom wellness audio
- 44.1kHz stereo at high quality
- **Risk:** Revenue-capped license (< $1M), Stability AI's long-term reliability, 47s cap requires chaining

### Practical Architecture Suggestion

The most viable approach for BioNaural is likely a **hybrid architecture**:

1. **Server-side generation** using ACE-Step 1.5 or Stable Audio Open, fine-tuned on curated ambient/wellness/binaural audio
2. **Pre-generated asset library** of ambient layers and textures, generated offline and bundled or downloaded
3. **On-device mixing engine** (not AI -- traditional DSP) that layers, crossfades, and modulates pre-generated stems based on Apple Watch biometrics
4. **Demucs** as a preprocessing tool to separate and curate ambient stems from existing recordings
5. **On-device binaural beat synthesis** via standard audio DSP (sine wave generators with frequency offsets -- this does not need AI)

This avoids the unsolved problem of real-time AI audio generation on mobile while still delivering adaptive, AI-generated soundscapes.

### Models to Skip
- **Bark** -- Wrong tool for the job, abandoned
- **MusicLDM** -- Dead project, low quality
- **AudioLDM 2** -- NC license kills commercial use
- **AudioCraft/MusicGen weights** -- NC license (but watch for re-licensed versions or train your own)

---

## Sources

- [Stable Audio Open - Stability AI](https://stability.ai/research/stable-audio-open)
- [Stable Audio Open - HuggingFace](https://huggingface.co/stabilityai/stable-audio-open-1.0)
- [stable-audio-tools GitHub](https://github.com/Stability-AI/stable-audio-tools)
- [Stability AI Company Status](https://www.aimmediahouse.com/ai-startups/stability-ai-fights-back-from-collapse-to-dominate-generative-ai-again)
- [Riffusion GitHub](https://github.com/riffusion/riffusion-hobby)
- [Riffusion HuggingFace](https://huggingface.co/riffusion/riffusion-model-v1)
- [Riffusion Wikipedia](https://en.wikipedia.org/wiki/Riffusion)
- [Bark GitHub](https://github.com/suno-ai/bark)
- [Bark HuggingFace](https://huggingface.co/suno/bark)
- [AudioLDM2 GitHub](https://github.com/haoheliu/AudioLDM2)
- [AudioLDM2 HuggingFace Diffusers](https://huggingface.co/docs/diffusers/en/api/pipelines/audioldm2)
- [MusicLDM GitHub](https://github.com/RetroCirce/MusicLDM)
- [MusicLDM Paper](https://arxiv.org/abs/2308.01546)
- [Demucs GitHub](https://github.com/facebookresearch/demucs)
- [AudioCraft GitHub](https://github.com/facebookresearch/audiocraft)
- [MusicGen Small HuggingFace](https://huggingface.co/facebook/musicgen-small)
- [ACE-Step 1.5 GitHub](https://github.com/ace-step/ACE-Step-1.5)
- [ACE-Step 1.5 HuggingFace](https://huggingface.co/ACE-Step/Ace-Step1.5)
- [YuE GitHub](https://github.com/multimodal-art-projection/YuE)
- [DiffRhythm GitHub](https://github.com/ASLP-lab/DiffRhythm)
- [HeartMuLa GitHub](https://github.com/HeartMuLa/heartlib)
- [HeartMuLa Paper](https://arxiv.org/abs/2601.10547)
- [FluidAudio - CoreML Audio Models](https://github.com/FluidInference/FluidAudio)
- [Binaural Generator Tool](https://github.com/ksylvan/binaural-generator)
