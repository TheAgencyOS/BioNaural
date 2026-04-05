# Energize Mode: Safety & Regulatory

> Energize is the highest-risk mode in the app. The Watch biometrics flip from feature to safety net.
> This document covers medical safety, legal guardrails, and regulatory positioning.

---

## Risk Assessment

Energize is the **only mode that intentionally elevates physiological arousal**. This creates unique risks not present in Focus (calming), Relaxation (downward bias), or Sleep (descent).

### Primary Risks

**1. Overstimulation → Anxiety/Panic**
Beta/gamma binaural beats can provoke anxiety, agitation, and panic in susceptible individuals. Studies report increased state anxiety with 20+ Hz stimulation, particularly in those with pre-existing anxiety disorders.

**2. Anxiety Disorder Interaction (HIGHEST RISK)**
GAD, panic disorder, and PTSD involve existing hyperarousal. An energizing mode could trigger panic attacks or dissociative episodes. This is the single highest-risk interaction.

**3. Cardiac Concerns**
Caffeine + sympathetic audio stimulation is additive for HR and blood pressure. For users with hypertension or arrhythmias, combined use poses cardiovascular concern.

**4. Gamma Frequency and Seizures**
- Photosensitive epilepsy is triggered by *visual* flicker at 15-25 Hz
- **Audio-only gamma stimulation does not carry the same seizure risk** (photic driving requires visual cortex)
- Isolated case reports of audiogenic seizures exist but are extremely rare
- Risk is low but non-zero

**5. Runaway Positive Feedback**
If the system rewards increasing HR and uses elevated HR to further intensify stimulation, it can push users into genuine stress. This mirrors the panic disorder mechanism: perceived arousal triggers more arousal.

---

## Required Safety Guardrails

### Biometric Guardrails (Non-Negotiable)

| Guardrail | Trigger | Action |
|---|---|---|
| **HR ceiling** | Baseline + 15 BPM, or 100 BPM (whichever lower) | Immediate ramp to calming frequencies |
| **HR hard stop** | 0.75 × (220 - age), or 130 BPM | Emergency calm (theta) + user alert |
| **HRV floor** | RMSSD < 20 ms | Back off stimulation regardless of HR |
| **HRV crash** | RMSSD drops > 30% from session baseline | Reduce frequency by 3 Hz immediately |
| **Rate-of-change** | HR rises > 5 BPM within 60 seconds | Freeze frequency escalation |
| **Sympathetic dominance** | LF/HF ratio > 4.0 for 2+ minutes | Begin cool-down arc early |
| **Session time cap** | 20-30 minutes maximum | Mandatory cool-down phase |
| **Cool-down** | Final 3-5 minutes of every session | Automatic taper, non-skippable |

### Onboarding Screening

Energize mode should include a **first-use screening** (not blocking, but informing):

- "Do you have a history of seizures or epilepsy?"
- "Do you experience panic attacks or anxiety disorder?"
- "Do you have a cardiac condition or take heart medication?"
- "Are you pregnant?"

If yes to any: display enhanced warning, recommend medical consultation, but do not block access. Log the response for liability purposes.

### Contraindication Warnings

Display before first Energize session:
- Epilepsy (audio seizure risk is very low but exists)
- Panic disorder (hyperarousal risk)
- Uncontrolled hypertension
- Cardiac arrhythmias
- Pregnancy

### In-Session Safety UX

- Real-time HR display during Energize (optional, off by default)
- Visual indicator when safety guardrail activates ("Adjusting to keep you comfortable")
- Emergency stop button prominently accessible
- Post-session recovery check: if HR hasn't returned to within 5 BPM of baseline after 5 minutes, suggest deep breathing

---

## Regulatory Positioning

### FDA General Wellness Exemption

**Key risk:** "Fatigue" is a primary symptom of diagnosable conditions (CFS, hypothyroidism, narcolepsy, depression, anemia). Claiming to "increase energy" could pull the product out of general wellness and into Class II medical device territory (510(k) required).

**The line:**
- "Support focus" = general wellness (safe) ✓
- "Supports energy levels" = structure/function (generally permissible) ✓
- "Increases energy" = objective claim (risky) ✗
- "Combats fatigue" = disease-adjacent (problematic) ✗
- "Reduces fatigue" = disease claim territory (dangerous) ✗

### FTC Scrutiny

Energy claims receive **heightened FTC scrutiny** (see 5-Hour Energy, Red Bull enforcement actions).

- Claims must be backed by competent and reliable scientific evidence
- "Feeling more energized" (subjective, hedged) ≠ "increases energy" (objective, absolute)
- Audio products have less enforcement history, but novel claims attract attention

### Safe Language Framework

**Use:**
- "Support an energized feeling"
- "Promote a sense of vitality"
- "Designed to help you feel more alert and awake"
- "Adaptive audio matched to your body's energy needs"

**Never use:**
- "Increases energy" / "boosts energy levels"
- "Fights fatigue" / "combats tiredness"
- "Reduces fatigue"
- Any reference to fatigue-related medical conditions
- "Replaces caffeine" / "better than caffeine"
- "Clinically proven to boost energy"

### "Energize" as a Mode Name

The name itself is likely fine — it's an action/experience label, not a medical claim. The risk lives entirely in the surrounding copy and marketing claims.

### Structural Safeguards

- Frame as **subjective experience** ("designed to help you *feel*..."), never objective physiological change
- Include general wellness disclaimer: "Not intended to diagnose, treat, cure, or prevent any disease"
- Never target marketing toward people with diagnosed fatigue conditions
- Keep App Store metadata and in-app language consistent
- Treat every word of copy as a regulatory decision

---

## Competitive Safety Advantage

Most apps include generic "consult your doctor" disclaimers but **no active monitoring**. BioNaural's Watch-based HR guardrails are a genuine differentiator AND liability shield. The Watch turns from a feature into a safety net — this can be marketed as responsible innovation.

---

## Legal Budget Addition

Add to existing $6-16K legal budget:
- **FTO search update** for energy-related audio patents: ~$2-4K
- **FDA regulatory consultant** review of Energize claims: ~$1-2K
- **FTC advertising review** of Energize marketing copy: ~$1K
- **Total Energize-specific legal:** ~$4-7K additional
