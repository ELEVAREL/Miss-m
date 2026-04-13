# Miss M — Commercialisation Plan (Hybrid Model)

_Internal strategy doc. Not published on the marketing site._

## Model

A **hybrid** model with two tiers:

| Tier | Price | Key flow | Audience |
|---|---|---|---|
| **Free — BYOK** | $0 | User pastes their own Anthropic key in onboarding. All traffic direct Mac → Anthropic. | Builders, students comfortable with an API console, privacy maximalists. |
| **Miss M Plus** | $12 / month | User signs in with email, we hand them a licence key. App sends Claude requests through our proxy, we pass them to Anthropic with our key. | Anyone who doesn't want to touch an API console. The broader market. |

Rationale:

- BYOK keeps infra cost at zero and lets us ship immediately.
- Plus unlocks the mass market where "set up an Anthropic account" is a
  20% conversion killer.
- Both tiers run the same macOS binary. Feature parity — the only
  difference is the auth and request path.

## Distribution

- Primary: **direct download via one-line installer**, served from GitHub
  Pages at `elevarel.github.io/miss-m`:
  ```
  curl -fsSL https://elevarel.github.io/miss-m/install.sh | bash
  ```
- Source of truth: `github.com/elevarel/miss-m`.
- Not on the Mac App Store — broad Calendar / Reminders / Contacts /
  HealthKit entitlements plus our managed-proxy behaviour would not pass
  review.
- Future option: **Setapp** listing for an additional distribution
  channel with a pre-existing subscription audience.

## Pricing math

Sonnet 4.6 is $3 input / $15 output per million tokens. A typical Plus
user on heavy daily use looks like:

- ~40 interactions/day × 1 200 tokens avg (60/40 in/out split) × 30 days
- ≈ 1.4M tokens/month ≈ **$12–15 in Anthropic cost**.

At $12/month list price, a heavy user is roughly break-even. To protect
margin we need:

1. Fair-use soft cap (documented in Terms §4).
2. Model routing — Haiku 4.5 for short/simple turns (weather, reminder
   add, "what time is my class"), Sonnet for planning / essays.
3. Prompt caching aggressively on the system prompt and recent tool
   definitions (Anthropic caching reduces repeated-prefix cost by ~90%).

Expected blended Plus margin after routing + caching: **40–55%**.

## Proxy architecture (to build for Plus)

- Lightweight Cloudflare Worker in front of `api.anthropic.com`.
- Auth: HMAC-signed licence key issued at subscription time, bound to a
  device ID hashed from the Mac's hardware UUID.
- The worker validates the signature, strips the client header, adds the
  real Anthropic key from a secret, forwards the streaming response
  unchanged.
- Logs: request timestamp, model, input/output tokens, licence ID, status
  code. **No prompt or completion content**.
- Retention: 30 days, then delete.

This is the minimum viable proxy. Do not build usage dashboards, A/B
experiments, or ML on top of this data — privacy is a headline feature.

## Payments

- Stripe Checkout or Paddle (Paddle handles EU/UK VAT automatically,
  which is the right choice given the governing law is England and
  Wales). Preferred: **Paddle**.
- On successful subscription, Paddle webhook → licence-issuing worker →
  licence email to customer.

## Marketing positioning

Lead with "private native macOS life-planner that understands your
cycle and your schedule." Don't lead with "AI chat" — the market is
saturated. The differentiators that Claude.ai / ChatGPT cannot match:

1. Reads your real Calendar / Reminders / HealthKit live.
2. Cycle- and energy-aware planning and fitness.
3. Lives in the menu bar, one keystroke away.
4. Data never leaves the Mac.

Target personas:

- **Student** — Marketing / Law / STEM undergrads juggling lectures,
  deadlines, home life.
- **Home manager** — meal planning, grocery, budget, family schedule.
- **ADHD / executive-function** — external brain with gentle nudges.
- **Cycle-aware wellness** — women who want planning that respects the
  cycle and have rejected advertising-funded period apps.

## Launch checklist

- [ ] Strip all hardcoded "Miss M" / "NyRiian" references from the app
      and replace with onboarding-captured identity fields.
- [ ] Replace iMessage auto-reply + AppleScript Messages polling with
      local notifications (see CLAUDE.md Phase 3 rewrite).
- [ ] Ship BYOK tier from the current codebase via `install.sh`.
- [ ] Stand up Paddle + licence-issuing worker.
- [ ] Build managed-proxy Cloudflare Worker.
- [ ] Wire Plus sign-in flow in Settings.
- [ ] Privacy policy and terms published (done — see `PRIVACY.md`, `TERMS.md`).
- [ ] Launch post on Hacker News "Show HN" + Product Hunt + one targeted
      subreddit (r/macapps, r/macOSBeta).

## Risks

1. **Apple tightens Contacts or HealthKit entitlements** — monitor
   macOS beta release notes each cycle. Our features degrade gracefully
   without them.
2. **Anthropic price change** — cost model depends on Sonnet staying at
   current pricing. Hedge by keeping Haiku fallback wired in.
3. **Model-routing errors frustrate users** — always give the user a
   per-chat override to force Sonnet.
4. **Refund abuse** — 14-day refund window with one-per-email.
5. **Licence leakage** — bind to hardware UUID, rotate keys if misuse
   detected.
