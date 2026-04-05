# BioNaural — Monetization & Pricing Strategy

> Competitor pricing, free tier design, conversion benchmarks, and revenue strategy.

---

## Competitor Pricing Landscape

| App | Monthly | Annual | Lifetime | Free Tier |
|-----|---------|--------|----------|-----------|
| **Brain.fm** | $6.99 | $49.99 | $199.99 | 3 sessions/day |
| **Calm** | $14.99 | $69.99 | $399.99 | ~5-10% content free |
| **Headspace** | $12.99 | $69.99 | — | Basic courses free |
| **Endel** | $5.99 | $49.99 | $79.99 | ~5-10 min/day |
| **Focus@Will** | $9.99 | $52.49 | — | 2-3 free sessions |
| **Dark Noise** | — | — | $9.99 (one-time) | — |
| **Oak** | Free | Free | — | Entirely free |
| **Tide** | $2.99 | $14.99 | — | Generous free tier |

**Key insight:** $49.99/yr is the magic number. Both Brain.fm and Endel use it. It's ~$1/week framing — low enough to feel like a no-brainer.

---

## Recommended Pricing

| Plan | Price | Rationale |
|------|-------|-----------|
| **Monthly** | $5.99/mo | Mid-range, competitive with Brain.fm/Endel |
| **Annual** | $49.99/yr (~$4.17/mo) | 40% discount vs. monthly. The promoted plan. |
| **Lifetime** | $149.99 | 3x annual. Pressure valve for subscription-fatigued users. |

Monthly functions partly as an **anchor** — its high per-month cost makes annual look like a deal. Typical subscriber mix: 60-70% annual, 25-35% monthly, 5-15% lifetime.

---

## Free Tier Design

### Free (Hook the User)
- 2 modes (Focus + Relaxation)
- Full-length sessions (never cut short — antithetical to a focus app)
- Binaural beats with basic time-based adaptation (session arc, not biometric-driven)
- 3 sessions per day
- 7 days of session history

### Premium (The Value)
- All 4 modes (Focus, Relaxation, Sleep, Energize)
- **Full biometric adaptation** (Apple Watch / Polar / BLE HR) — the core differentiator
- Unlimited sessions, unlimited duration
- Session analytics and trends
- All sound environments
- Offline mode

**Critical design decision:** The free tier uses time-based session arcs (not static beats). This means free users still get a dynamic, evolving experience — just not one that responds to their body. This avoids the trap of making the free tier identical to the competitors you're criticizing (static preset players). The premium upgrade is from "smart time-based arc" to "your body is driving the sound."

---

## Paywall Strategy

1. Let users complete their **first full session free** (no interruption)
2. After first session: soft paywall — "Unlock adaptive audio. Start your 7-day free trial."
3. If declined: continue with free tier (limited sessions/day)
4. Re-present contextually (when hitting session limit, tapping locked modes)

**Never interrupt a session with a paywall.** Cardinal sin of wellness monetization.

**Optimal timing data (RevenueCat 2024):**

| Paywall Timing | Conversion Rate |
|---------------|----------------|
| Hard paywall at launch | 2-3% |
| After onboarding | 4-6% |
| **After first session** | **5-8%** |
| After 3 days | 3-5% |
| Usage-based (at session limit) | 6-10% |

---

## Conversion & Retention Benchmarks

### Target Metrics

| Metric | Target | Good | Excellent |
|--------|--------|------|-----------|
| Free-to-paid conversion | 4-5% | 5-6% | 7%+ |
| Day 1 retention | 30% | 35% | 40%+ |
| Day 7 retention | 15% | 18% | 22%+ |
| Day 30 retention | 8% | 10% | 14%+ |
| Month 1 renewal (paid) | 75% | 80% | 85%+ |
| Annual renewal (year 2) | 45% | 50% | 55%+ |

### LTV Estimates

| Plan | Avg Lifespan | LTV (after Apple's cut) |
|------|-------------|------------------------|
| Monthly $5.99 | 4-6 months | $17-$25 |
| Annual $49.99 | 1.8-2.5 renewals | $63-$87 |
| Lifetime $149.99 | One-time | $105 |

**Blended LTV per paying user:** $50-$75
**LTV per install** (at 4% conversion): $2.00-$3.00

If you can acquire users for under $2 via Apple Search Ads or social media, you're in positive ROI.

---

## StoreKit 2 Implementation

- Single **subscription group** with Monthly + Annual
- **Introductory offer:** 7-day free trial (new subscribers only)
- **Win-back offers** (iOS 18+): target lapsed subscribers
- **Family Sharing:** Enabled — wellness is a household purchase
- **Promotional offer codes:** For partnerships, influencers, B2B deals (150K codes/quarter)
- Use `Transaction.currentEntitlements` for entitlement checks
- `Transaction.updates` async listener for real-time status changes

---

## Alternative Revenue (Future)

### B2B / Enterprise Wellness
- Corporate wellness is a $60B+ market
- Headspace/Calm charge $10-15/employee/month for enterprise
- Lower-lift approach: bulk App Store offer codes to companies
- Full approach: admin dashboard, usage reporting, SSO (later)

### Partnerships
- Apple Watch integration → Apple editorial featuring
- AirPods/headphone partnerships for binaural optimization
- HealthKit writing → ecosystem stickiness

### No Ads. Ever.
The absence of ads IS the product. Market explicitly: "No ads. No interruptions. Just focus."

---

## Key Decisions Summary

| Decision | Choice | Why |
|----------|--------|-----|
| Model | Freemium subscription | Industry standard, highest LTV |
| Annual price | $49.99 | Proven sweet spot (Brain.fm, Endel) |
| Lifetime | $149.99 | 3x annual, captures subscription-fatigued users |
| Free tier | 3 sessions/day, 2 modes (Focus + Relaxation), time-based arcs | Enough to form habit, not enough to satisfy. Sleep + Energize are premium. |
| Paywall timing | After first completed session | Best conversion without interrupting experience |
| Premium anchor | Biometric adaptation | Unique value, high-intent users (Watch owners) |
| Ads | Never | Antithetical to a focus app |
