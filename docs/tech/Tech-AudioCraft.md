# Meta AudioCraft / MusicGen -- Technical Research Deep Dive

**Date:** April 5, 2026
**Purpose:** Evaluate AudioCraft stack for potential integration into an iOS wellness/focus app
**Repo:** github.com/facebookresearch/audiocraft (23.1k stars, 2.6k forks, MIT code license)

---

## 1. Architecture

### EnCodec (Audio Tokenizer)

EnCodec is a neural audio codec that converts raw audio into discrete tokens and back. It has three stages:

- **Encoder:** Fully convolutional (SEANet-based) with strided downsampling + bidirectional LSTM for temporal context. Takes raw 32kHz mono audio waveform as input.
- **Quantizer:** Residual Vector Quantization (RVQ) with **4 codebooks**, each containing 1024 entries (10-bit per codebook). Instead of one massive codebook (which would need 2^40 entries), RVQ quantizes the residual error at each stage -- codebook 1 handles the coarse signal, codebook 2 quantizes what codebook 1 missed, and so on. This produces **4 parallel token streams at 50 Hz** (50 tokens/second per codebook = 200 tokens/second total).
- **Decoder:** Symmetric deconvolutional stack that reconstructs the waveform from quantized codes.

The compression is dramatic: 32kHz audio (32,000 samples/sec) becomes 50 discrete tokens/sec per codebook.

### MusicGen (Transformer Language Model)

MusicGen is an autoregressive transformer that operates over EnCodec tokens:

- **Input:** Text prompt (via T5 text encoder) and/or melody conditioning (via chroma features)
- **Core innovation -- Delay Pattern:** Rather than flattening all 4 codebooks into one long sequence (which would be slow) or using separate models per codebook (like MusicLM), MusicGen introduces a small delay offset between codebooks. Codebook 1 starts at step 0, codebook 2 at step 1, codebook 3 at step 2, codebook 4 at step 3. This allows **parallel prediction of all 4 codebooks** with only **50 autoregressive steps per second of audio**.
- **Conditioning:** Text via cross-attention from T5 embeddings. Melody via chroma token interleaving (extracts pitch-class profiles from reference audio). Classifier-free guidance at inference.

### Model Sizes

| Variant | Parameters | Notes |
|---------|-----------|-------|
| **small** | 300M | Fastest, lowest quality |
| **medium** | 1.5B | Good balance |
| **large** | 3.3B | Best quality, text-only conditioning |
| **melody** | 1.5B | Medium-size + melody/audio conditioning |
| **stereo variants** | same sizes | Stereo output support |
| **musicgen-style** | 1.5B | Style conditioning via audio reference (Nov 2024) |

### Quality Benchmarks (MusicCaps eval set)

| Model | FAD (lower=better) | KLD | Text Consistency |
|-------|---------------------|-----|-----------------|
| small | ~7.5 | ~1.5 | ~0.25 |
| medium | ~6.2 | ~1.4 | ~0.27 |
| large | **5.48** | **1.37** | **0.28** |

### JASCO (January 2025 addition)

The newest model in AudioCraft, based on flow matching (not autoregressive). Supports conditioning on text + chord progressions + drum patterns + melody. Available in 400M and 1B sizes. Uses EnCodec for tokenization but generates via continuous flow matching rather than discrete token prediction.

---

## 2. Deployment Options

### On-Device iOS: NOT FEASIBLE TODAY

There is **no existing CoreML or ONNX conversion** of MusicGen. Key blockers:

- **Model size:** Even the small model (300M params) is ~600MB in FP16, ~300MB in INT8. The large model would be ~6.6GB in FP16. These are substantial for mobile.
- **Architecture complexity:** The autoregressive loop with delay pattern codebook interleaving, cross-attention conditioning, and EnCodec decoder would require significant custom work to convert to CoreML.
- **No community precedent:** No one has publicly shipped MusicGen on iOS. No ONNX exports exist in the repo or community.
- **Theoretical path:** PyTorch -> coremltools direct conversion is possible in theory. You would need to trace/script the model, handle the autoregressive loop, and deal with the EnCodec decoder. Expect weeks of engineering work with uncertain results.
- **Memory:** iPhone 15 Pro has 8GB RAM total (shared with OS). Running even the small model in FP16 would consume most available memory. INT4 quantization would be required.

**Verdict:** On-device generation is not practical for MusicGen in the near term. The viable path for an iOS app is server-side generation with audio streaming to the device.

### Server Requirements

| Model | Min VRAM (FP16) | Recommended GPU |
|-------|-----------------|-----------------|
| small (300M) | ~4 GB | T4 (16GB), L4 |
| medium (1.5B) | ~8 GB | A10G (24GB), L4 |
| large (3.3B) | ~16 GB | A100 (40/80GB), A10G |

**Important caveat:** MusicGen has a known CPU bottleneck (GitHub issue #192). The autoregressive generation loop is single-core CPU-bound. GPU utilization is often low. Upgrading from a 3090 to an A100 provides minimal speedup. This is architectural -- the sequential token-by-token generation cannot be parallelized on the GPU.

### Cloud Hosting Options

| Platform | GPU | Cost | Notes |
|----------|-----|------|-------|
| **Replicate** | A100 (80GB) | **~$0.047/run** (~34s per generation) | Simplest. Pay-per-use. Cold starts possible. |
| **Hugging Face Inference Endpoints** | Various (16GB+) | ~$1.30-$5.00/hr (dedicated) | Custom handler needed. Good for dedicated endpoints. |
| **AWS SageMaker (ml.g5.xlarge)** | A10G (24GB) | ~$1.41/hr | Production-grade. Auto-scaling. |
| **AWS SageMaker (ml.g5.4xlarge)** | A10G (24GB) | ~$1.62/hr | More CPU for the bottleneck |
| **AWS EC2 g5.xlarge** | A10G | ~$1.01/hr on-demand, ~$0.30-0.40/hr spot | Self-managed |
| **GCP (a2-highgpu-1g)** | A100 40GB | ~$3.67/hr | |
| **Modal / RunPod** | Various | $0.50-$2.00/hr | Serverless GPU options |

**Cost estimate for a wellness app:**
- If each user session generates 5 minutes of audio (10 generations of 30s each)
- At ~$0.047 per generation on Replicate: **~$0.47 per session**
- At 1000 DAU with 1 session/day: **~$470/day = ~$14,100/month**
- With pre-generation and caching: could reduce to $2,000-5,000/month

---

## 3. Fine-Tuning

### Yes, fine-tuning is supported. Two main approaches:

#### A. Full Fine-Tuning (via Dora/AudioCraft trainer)

- Built into AudioCraft's training pipeline (uses Dora experiment manager)
- **Data needed:** As few as **9-10 tracks**, each >30 seconds. The trainer auto-chunks long audio into 30s segments.
- **Auto-labeling:** The Replicate fine-tuner can auto-generate text descriptions (genre, mood, instrumentation, key, BPM) for each track.
- **Vocal handling:** Vocals are stripped automatically via HT-Demucs (disable if your audio has no vocals -- which ambient/binaural would not).
- **Hardware:** ~15 minutes on 8x A40 GPUs for a full training run.
- **Available on Replicate:** sakemin/musicgen-fine-tuner wraps this into a simple API.
- **Model versions supported:** small, medium, melody (not large due to memory).

#### B. LoRA Fine-Tuning (lightweight)

- **ylacombe/musicgen-dreamboothing** on GitHub
- Designed for consumer GPUs (single GPU fine-tuning)
- Much lower memory footprint
- Can run on a single A10G or even consumer 24GB GPU
- Quality may be slightly lower than full fine-tuning

### Relevance for Binaural/Ambient

Fine-tuning MusicGen on ambient/binaural audio is technically possible but comes with caveats:

- MusicGen was trained on **music** (20K hours of licensed tracks). Ambient soundscapes and binaural beats are substantially different from its training distribution.
- Binaural beats specifically require **precise frequency control** (e.g., 40Hz difference between L/R channels for gamma). MusicGen generates **mono at 32kHz** -- it has no concept of binaural channel separation.
- For ambient textures (drones, pads, nature sounds), fine-tuning could work reasonably well since these are closer to musical timbres.
- For actual binaural beats, you would need to: (1) generate ambient audio via MusicGen, then (2) layer programmatically generated binaural tones on top using DSP.

---

## 4. Latency and Real-Time Capability

### MusicGen is NOT real-time.

Generation is strictly offline/batch. The autoregressive loop generates one time-step (covering all 4 codebooks) per forward pass, requiring 50 steps per second of output audio.

### Measured Generation Times

| Hardware | Audio Length | Model | Approx. Time |
|----------|-------------|-------|---------------|
| T4 (16GB) | 10 seconds | small | ~35 seconds |
| RTX 4070 | 10-12 seconds | small | ~4-8 seconds |
| RTX 4070 | 30 seconds | small | ~20-40 seconds |
| A100 (80GB) | 30 seconds | large | ~30-40 seconds |
| CPU only | 10 seconds | small | ~9 minutes |

**Key finding:** Due to the CPU bottleneck (issue #192), A100 and RTX 3090 produce nearly identical generation times. The autoregressive loop saturates a single CPU core regardless of GPU power.

### Generation Time Estimates for Longer Audio

MusicGen's native window is 30 seconds (1503 tokens max). For longer audio, you use a sliding window: generate 30s, keep the last 20s as context, generate the next 30s, etc.

| Target Length | Estimated Time (GPU) | Generations Needed |
|---------------|----------------------|-------------------|
| 30 seconds | 30-40s | 1 |
| 60 seconds | ~90-120s | 4 (overlapping windows) |
| 5 minutes | ~10-15 min | ~28 windows |

### Implications for a Wellness App

- **Pre-generation is the only viable strategy.** Generate audio sessions on the server, cache them, and stream to the device.
- A hybrid approach could work: pre-generate a library of ambient segments, then crossfade/loop them on-device.
- Real-time adaptive generation (e.g., changing audio based on live heart rate) is not feasible with MusicGen's latency. You would need a different approach for reactivity (e.g., pre-generate multiple variants, switch between them based on biometrics).

---

## 5. Output Quality

### Technical Specs

- **Sample rate:** 32 kHz (lower than CD quality 44.1kHz, but adequate for ambient/wellness audio)
- **Channels:** Mono by default. Stereo variants available (musicgen-stereo-small/medium/large).
- **Bit depth:** 32-bit float output (via PyTorch tensor), saved to WAV or any format
- **Codec quality:** EnCodec at 32kHz with 4 codebooks produces good quality for music. Some artifacts on transients and high frequencies.

### Long-Form Generation

- Native limit: **30 seconds per generation** (1503 tokens)
- Extended generation via sliding window: keep last 20s as context, generate next chunk. Can produce **2+ minute tracks** this way.
- Quality degrades over long sequences -- repetition and drift increase beyond ~60-90 seconds.
- No built-in loop point detection or seamless looping.

### Looping

- **Not natively supported.** GitHub issue #222 confirms this.
- Workaround: Generate longer segments, then use audio DSP to find good crossfade/loop points. Libraries like `librosa` can detect similar sections for crossfading.
- For ambient music, long crossfades (5-10 seconds) between generated segments work well.

### Quality Assessment for Wellness/Ambient

- MusicGen excels at textured, atmospheric music when prompted correctly (e.g., "ambient electronic meditation music, soft pads, no drums, peaceful")
- It struggles with: precise frequency requirements, very long coherent structures, clinical/medical audio precision
- The 32kHz sample rate is fine for ambient listening but worth noting if users compare to streaming services (typically 44.1kHz+)

---

## 6. Licensing -- CRITICAL ISSUE

### The Two-License Structure

| Component | License | Commercial Use? |
|-----------|---------|-----------------|
| **AudioCraft code** (training, inference, architecture) | **MIT** | YES -- fully permissive |
| **Pre-trained model weights** (small, medium, large, melody, etc.) | **CC-BY-NC 4.0** | **NO -- non-commercial only** |

### What This Means

**You cannot use Meta's pre-trained MusicGen weights in a commercial product.** The CC-BY-NC 4.0 license explicitly prohibits commercial use. This was confirmed by Meta developer Alexandre Defossez in GitHub issue #198: "This is not possible... the rights were negotiated for a research purpose."

The reason: Meta's training data (20K hours) was licensed specifically for research. Meta does not have the rights to sublicense for commercial use.

### Paths to Commercial Use

1. **Train your own weights from scratch** using the MIT-licensed code and your own commercially-licensed audio dataset. This is the cleanest legal path but requires significant compute (Meta used substantial GPU clusters) and a large licensed dataset.

2. **Fine-tune on your own data** -- legally ambiguous. The fine-tuned weights are derivative of CC-BY-NC weights. Most legal interpretations suggest the NC restriction propagates to fine-tuned models.

3. **Use the generated audio outputs** -- gray area. Some argue CC-BY-NC applies to the weights (the software artifact), not the outputs. The US Copyright Office has indicated AI-generated content without sufficient human intervention may not be copyrightable at all. This is legally untested for CC-BY-NC model weights specifically. **Not recommended without legal counsel.**

4. **Contact Meta for a commercial license** -- Meta has not offered this path. Issue #198 was closed without a commercial licensing option.

### Bottom Line

For a commercial iOS app, the pre-trained weights are a **no-go** without legal risk. The viable commercial path is training your own weights on licensed data using the MIT-licensed AudioCraft codebase. This is a significant undertaking.

---

## 7. Community and Ecosystem

### Development Activity

- **Last significant code push:** March 2025 (bugfix for checkpoint loading)
- **Last major feature:** January 2025 (JASCO release -- chords + drums conditioning)
- **MusicGen-Style:** November 2024 (style transfer via audio reference)
- **Open issues:** 381 (many unanswered)
- **Commit frequency:** Slowing down. Major updates every 3-6 months. Not abandoned but not actively developed either.
- **Python version support:** Issues with Python 3.12 compatibility (issue #602, March 2026)

### Community Tools

| Tool | Purpose |
|------|---------|
| [sakemin/cog-musicgen-fine-tuner](https://github.com/sakemin/cog-musicgen-fine-tuner) | One-click fine-tuning on Replicate |
| [ylacombe/musicgen-dreamboothing](https://github.com/ylacombe/musicgen-dreamboothing) | LoRA fine-tuning for consumer GPUs |
| [chavinlo/musicgen_trainer](https://github.com/chavinlo/musicgen_trainer) | Simple standalone trainer |
| [Hugging Face Transformers](https://huggingface.co/docs/transformers/model_doc/musicgen) | Full integration in HF ecosystem |
| [aime-labs/MusicGen](https://github.com/aime-labs/MusicGen) | Community fork with enhancements |
| Replicate hosted API | meta/musicgen on Replicate |

### Ecosystem Position (as of early 2026)

MusicGen remains a solid research model but the music generation space has evolved:
- **Stable Audio (Stability AI)** -- diffusion-based, potentially better for ambient
- **Udio / Suno** -- commercial APIs, higher quality but proprietary and expensive
- **JASCO** (within AudioCraft) -- flow matching, newer architecture
- MusicGen's advantage: best-documented open-source option with the most community tooling

---

## Summary Assessment for BioNaural / Wellness App

### Strengths
- Well-documented, well-understood architecture
- MIT-licensed code enables training custom models
- Fine-tuning pipeline exists and works with small datasets
- Can generate atmospheric/ambient audio with good quality
- Active (if slowing) community with useful tooling

### Blockers
- **CC-BY-NC weights cannot be used commercially** -- this is the single biggest issue
- **Not real-time** -- cannot adapt audio to live biometrics in real-time
- **Cannot generate binaural beats** -- mono output, no frequency precision for L/R channel separation
- **No on-device iOS path** -- server-only deployment, ongoing cloud costs

### Recommendation

MusicGen could serve as the **ambient texture generator** in a hybrid architecture:
1. Use MusicGen (with custom-trained weights on licensed ambient music) to generate ambient soundscapes on a server
2. Use traditional DSP on-device to generate precise binaural beat frequencies
3. Layer the two together on the iOS device
4. Pre-generate and cache ambient segments rather than generating in real-time
5. Use biometric data to select from pre-generated variants rather than generating on-the-fly

The commercial licensing issue means you would need to either train your own weights (significant investment) or explore alternative models with permissive licenses for the ambient generation layer.

---

## Sources

- [AudioCraft GitHub Repository](https://github.com/facebookresearch/audiocraft)
- [MusicGen Documentation](https://github.com/facebookresearch/audiocraft/blob/main/docs/MUSICGEN.md)
- [MusicGen-Large Model Card (Hugging Face)](https://huggingface.co/facebook/musicgen-large)
- [MusicGen-Style Model Card](https://github.com/facebookresearch/audiocraft/blob/main/model_cards/MUSICGEN_STYLE_MODEL_CARD.md)
- [JASCO Documentation](https://github.com/facebookresearch/audiocraft/blob/main/docs/JASCO.md)
- [Deploy MusicGen with HF Inference Endpoints](https://huggingface.co/blog/run-musicgen-as-an-api)
- [MusicGen on Replicate](https://replicate.com/meta/musicgen)
- [Fine-tune MusicGen -- Replicate Blog](https://replicate.com/blog/fine-tune-musicgen)
- [MusicGen LoRA Fine-Tuning](https://huggingface.co/blog/theeseus-ai/musicgen-lora-large)
- [CC-BY-NC Licensing Discussion (Issue #198)](https://github.com/facebookresearch/audiocraft/issues/198)
- [CPU Bottleneck Analysis (Issue #192)](https://github.com/facebookresearch/audiocraft/issues/192)
- [Looping Discussion (Issue #222)](https://github.com/facebookresearch/audiocraft/issues/222)
- [MusicGen Architecture Explained](https://www.ai-bites.net/musicgen-from-meta-ai-model-architecture-vector-quantization-and-model-conditining-explained/)
- [What is Residual Vector Quantization (AssemblyAI)](https://www.assemblyai.com/blog/what-is-residual-vector-quantization)
- [AWS SageMaker Pricing](https://aws.amazon.com/sagemaker/ai/pricing/)
- [AudioCraft MusicGen Paper (arXiv)](https://arxiv.org/pdf/2306.05284)
- [Meta AI Blog -- AudioCraft](https://ai.meta.com/blog/audiocraft-musicgen-audiogen-encodec-generative-ai-audio/)
