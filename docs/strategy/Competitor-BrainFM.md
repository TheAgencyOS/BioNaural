# Brain.fm -- Competitive Deep Dive

*Research compiled April 2026 for BioNaural competitive analysis*

---

## 1. Company Overview

- **Founded:** 2003 (rebranded/relaunched as Brain.fm in its current form around 2016)
- **Headquarters:** New York, NY
- **Team size:** ~11 employees (as of mid-2024)
- **Estimated annual revenue:** ~$2.6M (Growjo estimate)
- **Total funding raised:** $125K (NSF grant + Slow Ventures seed)
- **Platforms:** iOS, Android, Web, macOS desktop app
- **iOS App Store rating:** 4.4/5 (10,000+ ratings)
- **Trustpilot:** Reviews present but mixed

Brain.fm is a remarkably lean operation -- 11 people, minimal VC funding, bootstrapped to ~$2.6M ARR. This is notable: they've built a real business on subscription revenue without heavy venture backing.

---

## 2. Technology & How It Works

### 2.1 Core Mechanism: Neural Phase Locking (Not Binaural Beats)

Brain.fm's central technical claim is that they do NOT use binaural beats. Instead, they use **amplitude modulations embedded directly into the music's stereo channels** to achieve neural phase locking -- synchronizing neural populations into coordinated activity patterns.

**How it works technically:**
- Human composers create base musical compositions
- An AI system then applies targeted amplitude modulations (volume fluctuations) to specific frequency components within the music
- These modulations are tuned to specific Hz ranges corresponding to desired brain states (e.g., beta waves for focus, delta for sleep, alpha for relaxation)
- The modulations are designed to sound natural -- disguised as vibrato, reverberation, or rhythmic texture rather than an audible "beating"
- Modulations are applied directly in each stereo channel, not through stereo frequency separation like binaural beats

**Why they claim this is superior to binaural beats:**
- Binaural beats create a "phantom" beat perceived deep in the brainstem that becomes too weak by the time it reaches the cortex
- A 2023 systematic review they cite found only 5 of 14 studies supported the binaural entrainment hypothesis, with 8 contradictory
- Binaural beats are limited to carrier frequencies below 1000 Hz with beat differences constrained to ~30 Hz
- Their direct amplitude modulation produces "much stronger effects on brain activity" because the auditory system processes it immediately
- They target "preferred stimulus rates" around 4-8 Hz and 40 Hz, aligned with natural rhythmic processing

### 2.2 Patent Portfolio

Brain.fm holds **7 U.S. patents**:
- US 7,674,224 (primary -- method for incorporating brainwave entrainment into sound production)
- US 10,653,857
- US 11,205,414
- US 11,392,345
- US 11,532,298
- US 11,816,392
- US 11,966,661

**Key patent (US 7,674,224) details:**
- Describes selectively modulating specific frequency components (not the entire audio)
- Uses amplitude modulation, frequency modulation, stereo panning, and band-pass filter modulation
- Entrainment disguised as natural instrumental qualities (vibrato, reverb)
- This is their IP moat -- anyone building similar tech needs to navigate this patent landscape

### 2.3 AI's Role

Brain.fm's AI is NOT fully generative music in the way most people imagine:
- Human composers write the base music
- The AI applies and adjusts neuroscience-informed modulations on top of the compositions
- The AI adjusts amplitude of specific frequencies, volume of instruments, and modulation patterns based on the desired mental state
- This is more "AI-augmented composition" than "AI-generated music"

---

## 3. Scientific Backing

### 3.1 Key Published Research

**Primary study (2024):** "Rapid modulation in music supports attention in listeners with attentional difficulties"
- Published in *Communications Biology* (Nature portfolio journal), October 2024
- Conducted with Northeastern University's MIND Lab (Music, Imaging, and Neural Dynamics Laboratory)
- Funded by the U.S. National Science Foundation (Grant #NSF-STTR-1720698)
- Methods: behavioral tests, fMRI brain imaging, EEG recordings
- Finding: Brain.fm's modulated music produced significantly greater activation in brain networks associated with attention and cognitive control vs. unmodulated control music and pink noise
- Specific finding for ADHD: music with strong, targeted amplitude modulations sustained attention for people with ADHD symptoms

**Headline claims from their research:**
- 119% boost in focus-associated beta brainwaves
- Decreased tension by up to 200% in 4 minutes (relaxation mode)
- First-ever NSF grant to create music to support ADHD

### 3.2 Scientific Team

- **Kevin JP Woods, PhD** -- Director of Science (in-house)
- **Psyche Loui, PhD** -- Professor of Music & Neuroscience, Northeastern University (academic collaborator)
- **Benjamin Morillon, PhD** -- Institute of Systems Neuroscience, Aix-Marseille University (scientific advisor)

### 3.3 Assessment of Scientific Claims

**Strengths of their science:**
- Peer-reviewed publication in a reputable Nature portfolio journal
- NSF funding adds credibility (government-vetted)
- Used rigorous methods (fMRI + EEG + behavioral, with controls)
- Real academic collaborators with independent reputations

**Weaknesses / caveats:**
- Only one major peer-reviewed publication -- a single study, not a body of replicated work
- The "119% boost in beta waves" is a marketing stat without easy access to methodology details
- The company funded its own research (NSF grant went TO Brain.fm), so it's industry-funded science
- Neural entrainment via auditory stimulation is a real phenomenon, but the magnitude of real-world cognitive effects is still debated in neuroscience
- No long-term studies on sustained use outcomes
- Their argument against binaural beats, while grounded, also serves their competitive positioning -- it's motivated reasoning wrapped in legitimate science

---

## 4. Business Model & Pricing

### 4.1 Pricing Structure

| Plan | Price | Notes |
|------|-------|-------|
| Monthly | $14.99/mo | Cancel anytime |
| Annual | $99.99/yr (~$8.33/mo) | 40% discount badge |
| Student | 20% off annual | Requires .edu or student ID verification |
| Team/Enterprise | Custom pricing | Contact sales |

Promotional codes frequently circulate bringing effective annual cost down to ~$56/yr ($4.67/mo). Many affiliate reviewers cite $5-7/mo as the real price.

### 4.2 Free Trial

- 14-day free trial (some sources say 3-day -- may have changed or vary by platform)
- No payment details required upfront for the trial

### 4.3 Revenue Model Analysis

- Pure subscription SaaS -- no ads, no freemium tier beyond trial
- Cross-platform access included in all plans
- Offline downloads included (mobile/desktop only)
- No lifetime purchase option (common complaint)
- Estimated $2.6M ARR with 11 employees = lean, profitable-looking operation
- At ~$100/yr average, that implies roughly 26,000 paying subscribers (rough estimate)

### 4.4 Funding History

Remarkably capital-efficient:
- Seed round (2017, Slow Ventures)
- NSF STTR Grant #1720698 (2018)
- Total raised: ~$125K
- No Series A or significant VC rounds on record

This is either a bootstrapped success story or they have undisclosed revenue/funding. $2.6M ARR on $125K raised is exceptional capital efficiency.

---

## 5. UX & Product Design

### 5.1 Modes and Activities

**Four primary modes, each with sub-activities:**

| Mode | Sub-Activities |
|------|---------------|
| **Focus** | Deep Work, Creative Flow, Study & Read, Light Work |
| **Relax** | Chill, Recharge, Destress, Unwind |
| **Sleep** | Deep Sleep, Guided Sleep, Sleep & Wake Cycle, Wind Down, Power Nap |
| **Meditate** | Unguided, Guided |

### 5.2 Personalization Layers

1. **Neurotype onboarding:** Initial questions determine your "neurotype" and personalize neural effect intensity
2. **Neural effect intensity:** Three levels (Low, Medium, High) -- adjustable per session
3. **Genre/vibe selection:** Lo-fi, Cinematic, Electronic, Acoustic, Nature, Classical, and more
4. **Activity selection:** Fine-tunes audio within each mode
5. **Feedback loop:** App personalizes based on user feedback over time
6. **ADHD boost:** Specific stimulation level adjustment for ADHD users

### 5.3 Session & Timer Features

- Customizable session timers
- Built-in Pomodoro timer with configurable work/break intervals
- Effects typically onset within 5-15 minutes
- Sessions can run continuously (no forced limit)

### 5.4 UX Philosophy

- Minimal, "get out of your way" interface
- Choose mode -> choose genre -> press play
- Quick to start (under 1 minute to audio playing)
- Clean design, not feature-heavy

### 5.5 Platform Coverage

- iOS app
- Android app
- Web app (browser-based)
- macOS desktop app (M1+ required)
- Offline downloads on mobile and desktop

---

## 6. Strengths

1. **Legitimate science** -- Peer-reviewed Nature journal publication, NSF funding, real academic collaborators. This is rare in the focus/wellness audio space. Most competitors have zero peer-reviewed work.

2. **Patent moat** -- 7 US patents on their core amplitude modulation approach. Meaningful IP protection.

3. **Capital efficiency** -- ~$2.6M ARR on $125K raised with 11 employees. This is a real, sustainable business.

4. **Focus-first positioning** -- Unlike Endel (ambient/wellness) or Calm (meditation), Brain.fm leads with productivity. Their brand is "music to focus better."

5. **Fast time-to-value** -- Users report feeling effects within 5-15 minutes. The app gets you to audio in under 1 minute.

6. **Effective for ADHD** -- Strong organic word-of-mouth in the ADHD community, now backed by published research. This is a passionate user segment.

7. **Cross-platform** -- Available everywhere, including offline. No platform lock-in.

8. **Music quality** -- Human-composed base music means it actually sounds good, not like robotic generated audio. Users report it "sinks into your head" without being distracting.

---

## 7. Weaknesses & Common Complaints

### 7.1 Product Limitations

1. **No biometric integration** -- Brain.fm has ZERO real-time physiological feedback. No heart rate, no HRV, no wearable connectivity. Their "personalization" is static preference-setting, not adaptive. **This is BioNaural's primary competitive gap to exploit.**

2. **Limited customization** -- Users cannot choose specific instruments, filter by instrument, or deeply customize the audio beyond genre and intensity level.

3. **No custom timer flexibility** -- Timer presets don't support arbitrary durations easily. Pomodoro users with non-standard intervals (e.g., 25-minute sessions) report friction.

4. **Sleep mode is weak** -- Users report unexpected background noise in sleep tracks, unintuitive sleep section UI, and insufficient guidance on sleep features.

5. **Track library still growing** -- After years of operation, some users experience repetition. Library is expanding but not infinite.

6. **Headphones recommended** -- Optimal effects require headphones for the stereo channel modulations, limiting use in some contexts (speakers, open office).

### 7.2 Business/Pricing Complaints

7. **No lifetime purchase option** -- Subscription-only with no one-time buy. Vocal minority wants this.

8. **Trial confusion** -- Some users perceive the free trial as a "fake free trial" or find cancellation unclear. Trust issue.

9. **Notification nagging** -- App repeatedly asks to turn on notifications at launch, which is ironic for an app targeting focus-seeking users.

### 7.3 UX Issues

10. **Recent UI regressions** -- Multiple reviews cite that updates made the interface "more difficult to navigate, bulky, buggy." Sound selection sometimes doesn't respond to taps.

11. **Sparse onboarding** -- No prompts explaining how to get the most out of each section. Sleep mode in particular lacks guidance.

12. **macOS M1 requirement** -- Desktop app excludes Intel Mac users.

---

## 8. Competitive Implications for BioNaural

### 8.1 What Brain.fm Does That BioNaural Should Learn From

- **Lead with science.** Brain.fm's #1 differentiator is credibility. Their NSF grant and Nature publication set them apart from every competitor. BioNaural should invest in measurable validation (even informal EEG/HRV studies) and be transparent about evidence quality.
- **Focus-first branding.** They own the "focus music" positioning. BioNaural should consider whether to compete head-on or differentiate with the biometric angle.
- **Fast time-to-value.** Under 1 minute to audio. BioNaural should match or beat this.
- **Pomodoro integration.** Popular feature that BioNaural should consider.

### 8.2 Where BioNaural Has a Structural Advantage

- **Real-time biometric adaptation.** Brain.fm's "personalization" is static -- set your neurotype once, pick a genre, adjust intensity manually. BioNaural's closed-loop HR/HRV feedback is genuinely novel. Brain.fm cannot do this without hardware integration they've shown no interest in building.
- **Apple Watch ecosystem.** Brain.fm has zero wearable integration. BioNaural is purpose-built for Apple's health ecosystem. This aligns with Apple's platform priorities (potential featuring advantage).
- **Dynamic response.** Brain.fm plays the same modulation pattern regardless of whether you're actually entering a focus state. BioNaural can detect and respond to physiological changes in real time.
- **Binaural beats are not dead.** Brain.fm's argument against binaural beats is partially motivated by competitive positioning. The 2023 review they cite found mixed results, not a refutation. Binaural beats combined with real-time biometric feedback (BioNaural's approach) is a genuinely unexplored territory that may outperform static amplitude modulation.

### 8.3 Positioning Against Brain.fm

Brain.fm's messaging: "We use science to make music that works."
BioNaural's counter-positioning: "We use your body's real-time signals to make audio that adapts to YOU."

The key narrative: Brain.fm is one-size-fits-most (pick your neurotype, same modulation for everyone in that bucket). BioNaural is truly personalized -- your audio changes because your physiology changes. This is the difference between a static prescription and a dynamic, closed-loop system.

### 8.4 Patent Considerations

Brain.fm's 7 patents cover amplitude modulation techniques for neural entrainment. BioNaural's binaural beat generation driven by real-time biometric data is a fundamentally different mechanism:
- Different audio technique (binaural frequency differentials vs. amplitude modulation)
- Different adaptation mechanism (real-time physiological feedback vs. static preset selection)
- Different hardware dependency (Apple Watch biometrics vs. headphones-only)

However, any move toward amplitude modulation or "phase-locking" style techniques should be reviewed against their patent claims. Stick to binaural beat generation as the core mechanism to stay in clear IP space.

---

## Sources

- [Brain.fm Science Page](https://www.brain.fm/science)
- [Brain.fm Pricing](https://www.brain.fm/pricing)
- [Binaural Beats vs. Neural Phase-Locking -- Brain.fm Blog](https://www.brain.fm/blog/binaural-beats-vs-neural-phase-locking)
- [Brain.fm Adaptive Focus Music Technology](https://www.brain.fm/blog/adaptive-focus-music-technology-brain-fm)
- [Beta Waves & Brain.fm: Engineering Focus](https://www.brain.fm/blog/beta-waves-brain-fm-engineering-focus)
- [Brain.fm Review 2026 -- Outliyr](https://outliyr.com/brainfm-review)
- [BrainFM Review: 8-Year Journey -- Early Stage Marketing](https://earlystagemarketing.com/brain-fm-review/)
- [Brain.fm App Store Listing (US)](https://apps.apple.com/us/app/brain-fm-focus-sleep-music/id1110684238)
- [Brain.fm App Store Listing (CA)](https://apps.apple.com/ca/app/brain-fm-focus-music/id1110684238)
- [Brain.fm Trustpilot Reviews](https://www.trustpilot.com/review/brain.fm)
- [Brain.fm -- Crunchbase](https://www.crunchbase.com/organization/brain-fm)
- [Brain.fm Revenue & Competitors -- Growjo](https://growjo.com/company/Brain.fm)
- [Brain.fm Knowledge Base -- Science](https://brainfm.helpscoutdocs.com/article/16-science)
- [US Patent 7,674,224 -- Google Patents](https://patents.google.com/patent/US7674224B2/en)
- [Rockin' Patent -- Brain.fm Analysis (Russell IP)](https://www.russellip.com/rockin-patent-brain-fm-incs-method-for-incorporating-brain-wave-entrainment-into-sound-production/)
- [Brain.fm ADHD Study -- ADDitude Magazine](https://www.additudemag.com/background-music-amplitude-modulation-adhd-study/)
- [Brain.fm Fact Check -- Factually.co](https://factually.co/fact-checks/technology/brainfm-sound-technology-scientific-principles-ea382a)
- [Brain.fm + Muse Integration](https://choosemuse.com/blogs/news/achieve-deeper-focus-and-relaxation-with-muse-and-brain-fm)
- [Brain.fm JustUseApp Reviews](https://justuseapp.com/en/app/1110684238/brain-fm-focus-music/reviews)
