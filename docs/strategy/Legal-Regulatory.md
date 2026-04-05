# BioNaural — Legal & Regulatory Guide

> FDA, health claims, App Store review, privacy, IP, and disclaimers.

---

## FDA Regulation

### General Wellness Exemption (FDA-2014-N-1039, 2019)

BioNaural qualifies as **general wellness** if it meets both criteria:
1. **Low risk** — non-invasive, no implantation, no ionizing radiation
2. **General wellness claims only** — no reference to specific diseases or conditions

### The Language Line

| Acceptable (General Wellness) | Unacceptable (Medical Device) |
|------------------------------|------------------------------|
| "Supports focus and concentration" | "Treats ADHD" |
| "Promotes relaxation" | "Treats anxiety disorder" |
| "Designed to support restful sleep" | "Treats insomnia" |
| "Helps manage everyday stress" | "Reduces cortisolic stress response" |
| "Encourages a calm state of mind" | "Reduces symptoms of PTSD" |
| "Supports your meditation practice" | "Clinically proven to alter brainwave patterns" |

**The moment you name a diagnosable condition (ADHD, GAD, insomnia, depression), you've crossed into medical device territory** under 21 CFR Part 820.

### Does Biometric-Adaptive Audio Cross the Line?

**Gray zone.** Key distinctions:
- Adapting audio to "help you relax" based on elevated HR → likely **general wellness** (similar to fitness apps adjusting workout intensity by HR zones)
- Claiming to "detect stress episodes" or "identify anxiety states" from HRV and "treat" them → **medical device** (SaMD)
- Providing a "focus score" from biometric data → likely **general wellness** as long as not tied to a clinical condition

**Frame as personalization, not treatment:** "BioNaural reads your heart rate to personalize your audio experience" — NOT "BioNaural detects stress markers and delivers therapeutic audio."

### Enforcement Examples
- Calm and Headspace have NOT received FDA letters — they stick to general wellness language
- 23andMe (2013): FDA ordered them to stop making disease-specific claims
- Pear Therapeutics reSET: went through De Novo pathway because it made clinical claims for substance use disorders

**De Novo pathway ($10K-100K+ fees, 6-12+ months) is overkill for v1.** Stay within general wellness. Pursue clinical validation later if expanding to digital therapeutics.

---

## FTC Health Claims

### Claim Tiers

**Tier 1 — Safe (minimal substantiation):**
- "Designed to support relaxation"
- "Created to help you focus"
- "Personalized audio for your wellness routine"

**Tier 2 — Moderate (need published literature):**
- "Uses binaural beats, which research suggests may support focus"
- "Heart rate variability is an established indicator of relaxation"
- Must be able to point to peer-reviewed studies (Garcia-Argibay et al., 2019; Chaieb et al., 2015)

**Tier 3 — High risk (need product-specific clinical data):**
- "Clinically proven to reduce stress by 40%"
- Anything with specific numbers or outcome claims

**Rule:** Keep a file of literature supporting any claims you make.

---

## Apple App Store Review

### Guidelines 5.1.3 (Health, Fitness, Medical)
- Must make clear the app is not intended to replace professional medical advice
- If the app provides diagnosis or treatment advice, it may be classified as medical device
- Must clearly disclose health data collection and use practices

### HealthKit Review Requirements
1. Clear privacy policy linked in app and App Store Connect
2. Explain to Apple in review notes exactly what HealthKit data you read and why
3. HealthKit data CANNOT be used for advertising or sold to third parties
4. Request only minimum necessary data types
5. Handle denied permissions gracefully (app must still work)
6. Clear `NSHealthShareUsageDescription`: "BioNaural reads your heart rate to personalize your audio experience in real time."

### Common Rejection Triggers
- Unsubstantiated therapeutic claims
- Requesting HealthKit permissions without clear justification
- Missing medical disclaimer

---

## Privacy & Data

### Architecture: On-Device First

**Keep on-device (required or recommended):**
- Raw biometric data (HR, HRV readings)
- Session-level biometric time series
- HealthKit data (Apple requires this)
- Audio adaptation parameters

**Can be in cloud (with encryption + consent):**
- Aggregated session metadata (duration, mode, satisfaction)
- User preferences/settings (cross-device sync)
- Account info
- Anonymized analytics

### GDPR (If Distributed in EU)
- HR and HRV are **biometric/health data** — "special category" under Article 9
- Requires **explicit consent** (not just legitimate interest)
- Data Protection Impact Assessment (DPIA) required
- Right to erasure (Art. 17) and data portability (Art. 20)
- Need EU representative if no EU establishment (Art. 27)

### HIPAA
**Does NOT apply** to a consumer wellness app that doesn't bill insurance, operate under a healthcare provider, or share data with covered entities. However, design privacy-first in case B2B/employer wellness later triggers HIPAA.

### State Laws to Watch
- **Washington My Health My Data Act (2023)** — applies to consumer health data regardless of HIPAA. Consent required. Private right of action.
- **California CCPA/CPRA** — health data is "sensitive personal information" requiring opt-in
- **Connecticut, Colorado, Virginia** — also have health data provisions

### Apple Privacy Nutrition Labels
Declare: Health & Fitness data (HR, HRV), Usage data (session length), Identifiers (if applicable). Less collected = better label = more trust.

---

## Intellectual Property

### Patent Landscape

**Brain.fm patents to watch:**
- US Patent 10,293,161 B2 — "Systems and methods for generating and providing audio signals for neural entrainment"
- US Patent 10,765,860 B2 — continuation patent
- Focus on neural phase-locking modulation patterns

**Risk:** If BioNaural's audio generation uses fundamentally different techniques, likely no infringement. If implementing similar neural phase-locking, get patent attorney review.

**Recommendation:** Commission a **freedom-to-operate (FTO) search** before launch. Budget $3,000-$8,000.

### BioNaural's Patentable Innovation
The adaptive biometric-to-audio mapping algorithm is potentially patentable if claimed as a specific technical implementation (not just the general concept). Consider a **provisional patent** ($320 small entity fee, 12 months priority).

### Font License (Satoshi)
Fontshare license permits commercial use in mobile apps. Cannot redistribute or modify the font files. Save a copy of the license terms at time of download.

---

## Epilepsy Disclaimer

### Standard Language

> **Seizure Warning:** A very small percentage of people may experience seizures when exposed to certain audio frequencies or visual patterns. If you have been diagnosed with epilepsy or any seizure disorder, consult your physician before using this app. Discontinue use immediately and consult a doctor if you experience dizziness, altered vision, muscle twitching, involuntary movements, loss of awareness, disorientation, or any other unusual sensation during use. Do not use while driving or operating heavy machinery.

### Placement
1. **Onboarding flow** — display before first session, require acknowledgment (tap to continue)
2. **Settings → Safety** — permanently accessible
3. **Terms of Service** — Health and Safety section
4. **App Store description** — brief mention
5. **Before first session** — non-intrusive reminder

**Do NOT bury this only in ToS.** Visible onboarding placement provides strongest legal protection.

---

## Terms of Service Must-Haves

1. **Medical disclaimer (prominent):** "BioNaural is not a medical device. Not intended to diagnose, treat, cure, or prevent any disease."
2. **Not a substitute** for professional medical advice
3. **Health warning** — epilepsy + general safety
4. **Limitation of liability** for health-related outcomes
5. **HealthKit data handling** — cross-reference privacy policy
6. **Subscription/payment terms** — auto-renewal, cancellation
7. **Age restriction** — 13+ (COPPA) or consider 18+ given binaural beat considerations

## Privacy Policy Must-Haves

1. Itemized data collection (HealthKit data, usage data, account data)
2. Purpose limitation (biometric data used solely for real-time audio personalization, on-device)
3. Data sharing (ideally: "no one" for health data)
4. Data retention and deletion
5. User rights (access, deletion, portability)
6. Security measures (TLS 1.2+, on-device processing)
7. HealthKit-specific disclosure (required by Apple)
8. California CCPA/CPRA disclosures
9. GDPR disclosures (if in EU)
10. Contact information / DPO

---

## Pre-Launch Legal Budget

| Item | Estimated Cost |
|------|---------------|
| FTO patent search | $3,000-$8,000 |
| Trademark search | $500-$1,500 |
| Privacy policy + ToS attorney review | $2,000-$5,000 |
| FDA regulatory consult (1-2 hours) | $500-$1,500 |
| **Total** | **$6,000-$16,000** |

This is investment in protection, not overhead. One FDA letter or App Store rejection costs far more in time and reputation.
