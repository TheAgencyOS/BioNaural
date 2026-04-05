# Mubert AI Music API -- Technical Research Document

**Date:** April 5, 2026
**Purpose:** Evaluate Mubert API for integration into a wellness/focus iOS app
**API Version:** v3.0 (current)

---

## 1. API Capabilities

### Architecture Overview

Mubert does NOT use a traditional AI model that synthesizes audio from scratch. Instead, it uses a proprietary system that:

1. Maintains a library of 2.5M+ pre-recorded samples (loops for bass, leads, pads, etc.) created by human musicians and sound designers
2. Uses AI to analyze, select, and arrange these samples into compositions in real time
3. Maps text/image inputs to internal "tags" via a transformer neural network (sentence embeddings mapped to tag vectors)

This means output quality is high (real musician recordings), but creative range is bounded by the sample library.

### Endpoints

**Base URL:** `https://music-api.mubert.com/api/v3/`

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/service/customers` | POST | Register end-user, returns customer-id + access-token |
| `/public/playlists` | GET | Discover 150+ channels with categories |
| `/public/tracks` | POST | Generate a track (text-to-music, image-to-music) |
| `/public/streaming/get-link` | GET | Get a streaming link (WebRTC or HTTP) |
| `/public/music-library/params` | GET | Get filterable parameters for curated library |
| `/public/music-library/tracks` | GET | Filter curated library (BPM, genre, duration) |
| `/service/licenses/{id}` | PUT | Configure webhooks for generation completion |

### Authentication

Two-tier credential system:
- **Service-level:** `company-id` + `license-token` headers (admin operations, customer registration)
- **Customer-level:** `customer-id` + `access-token` headers (public endpoints, generation, streaming)

### Generation Parameters

| Parameter | Values | Notes |
|-----------|--------|-------|
| `playlist_index` | e.g. "1.0.0" | Channel identifier from /playlists |
| `duration` | 15-1500 seconds | 15s jingles up to 25-minute mixes |
| `bitrate` | 32, 128, 320 | kbps |
| `format` | "wav", "mp3" | Output format |
| `intensity` | "low", "medium", "high" | Energy/mood level |
| `mode` | "track", "loop" | One-shot vs looping |
| `type` | "webrtc", "http" | Streaming protocol (for streaming endpoint) |

### Text-to-Music

Accepts text prompts up to 200 characters. Internally, the prompt is encoded via a sentence transformer (MiniLM-L6-v2) and matched against ~200 internal tags including: meditation, ambient, peaceful, dreamy, relaxing, calm, zen, yoga, sleep, chill, downtempo, atmospheric, lo-fi, etc.

### Image-to-Music

Accepts image file upload or URL (up to 10MB). Generates music matching the visual content's mood.

### Streaming

- **WebRTC:** Sub-second latency, continuous real-time streaming. Best for live/adaptive experiences.
- **HTTP:** Standard streaming with ~3 second buffering. Simpler to implement.
- **200+ channels** available for continuous streaming across genres/moods.

### Relevant Tags for Wellness/Focus

From the actual tag list in their codebase:
`meditation`, `ambient`, `peaceful`, `relaxing`, `calm`, `zen`, `yoga`, `dreamy`, `atmospheric`, `chill`, `downtempo`, `spiritual`, `meditative`, `sleepy ambient`, `lullaby`, `nature`, `pads`, `chillout`, `deep`, `lounge`, `beautiful`, `soft`, `acoustic`, `bells`

---

## 2. Technical Requirements

### SDK Availability

**There is no official iOS/Swift SDK.** Mubert provides:
- A REST API only (JSON over HTTPS)
- A Python notebook demo on GitHub (MubertAI/Mubert-Text-to-Music, 2.7K stars)
- No npm package, no CocoaPod, no Swift Package

**iOS integration approach:** Standard URLSession/Alamofire HTTP calls to the REST endpoints. For WebRTC streaming, you would need to integrate a WebRTC client library (e.g., Google's WebRTC framework for iOS) and connect it to the stream URL returned by Mubert's API.

### Server Requirements

- All generation happens server-side on Mubert's infrastructure
- No server of your own is required for basic integration
- Webhook support available if you need async notification of track completion
- Cloudflare-fronted infrastructure

### Bandwidth Needs

| Bitrate | Bandwidth Required | Use Case |
|---------|-------------------|----------|
| 32 kbps | ~240 KB/min | Low quality, minimal data |
| 128 kbps | ~960 KB/min | Standard quality |
| 320 kbps | ~2.4 MB/min | High quality |

For a 30-minute meditation session at 128 kbps: ~29 MB total.

### Offline Support

**No native offline support.** All generation requires an active internet connection to Mubert's servers. Possible workarounds:
- Pre-generate tracks via the API and cache locally (must comply with licensing terms)
- Use the curated library endpoint to download tracks ahead of time
- Note: licensing terms may restrict local caching -- this needs clarification with Mubert directly

### Latency

- **WebRTC streaming:** Sub-second latency (music starts almost immediately)
- **Track generation:** ~3 seconds for preview buffering
- **Full track render:** Longer depending on duration (not real-time for long tracks)

---

## 3. Pricing

### API Tiers (from mubert.com/use-cases/developers)

| Tier | Monthly Cost | Included | Notes |
|------|-------------|----------|-------|
| **Trial** | $49/mo | 100 generations/month | Testing and evaluation |
| **Startup** | $199/mo | 5,000 generations/month | Production apps |
| **Startup+** | $499/mo | 30,000 generations/month | Scaling apps |
| **Enterprise** | Custom | Custom volume | Dedicated infrastructure |

### Streaming Pricing

- **$0.01 per minute** of broadcasted/streamed content (pay-as-you-go)
- This is separate from or alternative to generation-based pricing
- Mubert markets this as: "Hardly any other service can provide high-quality music for such a modest price"

### Per-Track Licensing (Mubert Render -- separate product)

| License Type | One-Time Cost |
|-------------|--------------|
| Standard | $19 |
| Online Ads | $99 |
| All Media (TV/radio) | $149 |
| In-App Music | $199 |
| Sub-licensing | $499 |

### Consumer Plans (Mubert Render -- not API)

| Plan | Monthly Cost | Tracks/Month |
|------|-------------|-------------|
| Ambassador | Free | 25 (with attribution) |
| Creator | $14/mo | 500 |
| Pro | $39/mo | Unlimited |
| Business | $199/mo | Unlimited + API access |

### Licensing Terms

- All generated music is royalty-free
- 100% DMCA-safe (no copyright claims)
- Commercial use included across all API tiers
- Sub-licensing rights available (important for UGC platforms)
- **CANNOT** distribute tracks on DSPs (Spotify, Apple Music, etc.) as your own
- **CANNOT** register tracks via Content ID systems
- Free tier requires attribution (@mubertapp + #mubert)

---

## 4. Integration Examples

### Confirmed Integrations

| Partner | Use Case | Details |
|---------|----------|---------|
| **Picsart** | UGC platform | Background music for user-created content |
| **Canva** | Design tool | Audio for video projects |
| **Restream** | Live streaming | Dynamic soundscapes adapting to stream content/mood |
| **Gravity Fitness** | Fitness app | Workout music; reported increased user check-ins and longer training sessions |
| **Hybrid Xperience** | Art installation | Al Marmoom Film Festival, Abu Dhabi -- immersive AI music installation |
| **DELIVERED** | Art installation | Live pianist playing alongside real-time AI training |

### Wellness-Specific Claims

- A "top 10 wellness app" (unnamed) reports generating 10,000+ tracks daily for meditation with zero downtime
- Fitness apps report music tempo adapting in real-time to heart rate via API
- Mubert specifically markets meditation, relaxation, focus, and sleep channels

### Developer Experience Reports

**Positive:**
- "The API actually worked great -- better than expected"
- "Clear documentation and fast response times"
- "No weird bugs"
- REST API is straightforward to integrate ("a few lines of code")

**Negative:**
- Customer support response times of 6+ days reported
- Confusing cancellation flows
- Must contact sales for API access (no self-serve signup for API tier)
- Limited developer community (no Stack Overflow presence, sparse GitHub activity)

---

## 5. Audio Quality

### Technical Specs

| Parameter | Value |
|-----------|-------|
| Bitrate options | 32, 128, 320 kbps |
| Formats | WAV, MP3 |
| Sample rate | Not publicly documented (likely 44.1 kHz based on standard audio) |
| Source material | 2.5M+ professionally recorded samples |
| Channels | Stereo |

### Quality Assessment for Wellness/Ambient Use

**Strengths:**
- Electronic genres (lo-fi, ambient, synthwave, chill) are Mubert's strongest output
- Ambient and meditation tracks sound professional -- ethereal pads, soothing drones, atmospheric textures
- Source material is from real musicians, not synthesized by neural networks
- Good for background/functional music where subtlety matters

**Weaknesses:**
- ~60% first-try success rate; 40% of generations may need retry
- After extended use, patterns become noticeable (AI reuses melodic ideas and rhythmic structures)
- All output is instrumental only -- no vocals whatsoever
- Cannot fine-tune composition details (no stem control, no instrument isolation)
- Cannot adjust post-generation (what the AI generates is what you get)
- Organic genres (rock, jazz, acoustic) sound more robotic

### Wellness Suitability Rating: GOOD (with caveats)

Mubert's ambient/meditation output is among its best categories. The pre-recorded sample approach means individual sounds are high quality. However, the lack of fine-tuning means you cannot, for example, layer binaural beats at specific frequencies or precisely control harmonic content -- you get a mood-appropriate ambient track, not a scientifically calibrated therapeutic audio experience.

---

## 6. Limitations

### Hard Limitations

1. **No offline generation** -- requires internet connection to Mubert servers at all times
2. **No iOS SDK** -- must build your own HTTP + WebRTC integration layer
3. **No vocal output** -- everything is instrumental
4. **No stem/instrument control** -- cannot isolate or adjust individual elements
5. **No post-generation editing** -- output is final
6. **No binaural beat generation** -- cannot specify Hz frequencies for entrainment
7. **No BPM locking for real-time adaptation** -- you pick intensity, not exact tempo
8. **200-character prompt limit** for text-to-music
9. **Image-to-music limited to 10MB** file size
10. **No self-serve API signup** -- must contact sales team

### Practical Concerns

1. **Repetitiveness over time** -- users who listen for extended periods will notice pattern recycling
2. **40% retry rate** -- not every generation produces good output on first attempt
3. **Customer support is slow** -- 6+ day response times reported
4. **Billing confusion** -- multiple reports of cancellation difficulty
5. **No guaranteed uptime SLA** published for non-enterprise tiers
6. **Vendor lock-in risk** -- all music is generated server-side; if Mubert goes down or changes terms, your app has no audio
7. **Pricing can scale quickly** -- $0.01/min sounds cheap, but 10K daily active users listening 30 min/day = $90K/month

### Distribution Restrictions

- Cannot release tracks on streaming platforms (Spotify, Apple Music, etc.)
- Cannot register with Content ID
- Cannot claim ownership of generated tracks
- Free usage requires attribution

---

## 7. Cost Projection for a Wellness/Focus App

### Scenario: 1,000 DAU, 20 min average session

| Model | Monthly Cost |
|-------|-------------|
| Streaming at $0.01/min | 1,000 x 20 x 30 x $0.01 = **$6,000/mo** |
| Pre-generated tracks (Startup tier) | **$199/mo** (5,000 generations) |

### Scenario: 10,000 DAU, 30 min average session

| Model | Monthly Cost |
|-------|-------------|
| Streaming at $0.01/min | 10,000 x 30 x 30 x $0.01 = **$90,000/mo** |
| Pre-generated tracks (Startup+ tier) | **$499/mo** (30,000 generations) |

**Key takeaway:** Pre-generating a library of tracks and caching them is dramatically cheaper than real-time streaming per user. The streaming model only makes sense for truly adaptive/personalized experiences where each user needs unique audio in real time.

---

## 8. Assessment for BioNaural Focus App

### Fit Score: 5/10

**What works:**
- Ambient/meditation quality is genuinely good
- WebRTC streaming enables real-time adaptive audio
- Royalty-free licensing simplifies legal concerns
- REST API is simple to integrate from Swift
- $0.01/min streaming could work for MVP testing
- 150+ mood channels cover focus/meditation/relaxation well

**What does NOT work:**
- No binaural beat generation or Hz-frequency control (core to BioNaural concept)
- No way to layer Mubert output with binaural frequencies in real-time server-side
- No offline mode (bad for meditation sessions in airplane mode, poor connectivity)
- No iOS SDK means more integration work
- Pattern repetition problem conflicts with extended focus sessions
- Cost scales badly with DAU for streaming model
- No fine-grained BPM/tempo control for heart-rate-adaptive music
- Cannot modify or remix output post-generation

### Recommendation

Mubert could serve as ONE LAYER of the audio experience -- providing ambient textures and musical backgrounds -- while a separate local audio engine handles binaural beat generation, frequency targeting, and heart-rate-driven tempo adaptation. However, this hybrid approach adds complexity and the offline limitation remains a serious concern for a wellness app.

**Alternatives worth investigating:**
- **Soundverse API** -- more compositional control, stem separation, but pricier
- **AIVA** -- better for structured composition with more control
- **Custom AudioKit/AVAudioEngine solution** -- full control over binaural beats, offline support, no per-use cost, but requires building the generative system yourself
- **Brain.fm** -- purpose-built for focus/wellness (but may not have a public API)

---

## Sources

- [Mubert API Landing Page](https://mubert.com/api)
- [Mubert API 3.0 (redirect)](https://landing.mubert.com/)
- [Mubert API v3 Apiary Docs](https://mubertmusicapiv3.docs.apiary.io/)
- [Mubert Use Cases for Developers](https://mubert.com/use-cases/developers)
- [Mubert Blog: Why Developers Should Build with Generative Music APIs](https://mubert.com/blog/why-developers-should-build-with-generative-music-apis)
- [Mubert Blog: Integration Guide for Video/UGC Tools](https://mubert.com/blog/how-to-integrate-ai-music-into-your-video-editing-or-ugc-tool-the-complete-beginners-guide)
- [Mubert Blog: Make Your App Sound Great](https://mubert.com/blog/make-your-app-sound-great)
- [Mubert Blog: Introducing API 2.0](https://mubert.com/blog/introducing-mubert-api-2-0)
- [Mubert Render Pricing](https://mubert.com/render/pricing)
- [Mubert GitHub: Text-to-Music Notebook](https://github.com/MubertAI/Mubert-Text-to-Music)
- [Soundverse API vs Mubert API Comparison (2025)](https://www.soundverse.ai/blog/article/soundverse-api-vs-mubert-api-which-one-should-developers-choose-in-2025)
- [Mubert Review 2026 (aisongcreator.pro)](https://aisongcreator.pro/blog/mubert-review)
- [Mubert AI Review (Elegant Themes)](https://www.elegantthemes.com/blog/business/mubert-ai)
- [Mubert AI Review (Fritz AI)](https://fritz.ai/mubert-ai-review/)
- [Mubert G2 Reviews](https://www.g2.com/products/mubert-inc-mubert/reviews)
- [Mubert Pricing on G2](https://www.g2.com/products/mubert-inc-mubert/pricing)
- [AI Meditation & Ambient Sound Generation 2026](https://www.aimagicx.com/blog/ai-meditation-ambient-sound-generation-2026)
- [Jack Righteous: Mubert Licensing, Limits, and Best Uses](https://jackrighteous.com/en-us/blogs/music-creation-process-guide/mubert-ai-review-licensing-limits-and-best-uses-for-creators)
