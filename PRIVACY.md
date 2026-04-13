# Miss M — Privacy Policy

_Last updated: April 13, 2026_

Miss M is built for privacy. This policy explains exactly what the app does,
does not do, and how the two pricing tiers differ in the data they touch.

A formatted version of this document lives at
<https://elevarel.github.io/miss-m/privacy.html>.

## 1. Who we are

Miss M is developed and distributed by **Elevarel** ("we", "us"). Contact:
<privacy@elevarel.io>.

## 2. The short version

- The Miss M macOS app runs entirely on your Mac.
- Your personal data — calendar, reminders, health data, notes, chat
  history — never leaves your device except when sent to Anthropic to
  generate a response.
- We do not operate analytics, ad networks, trackers, or crash reporters.
- On the **Free (BYOK)** tier, we do not receive any of your data. Ever.
- On **Miss M Plus** (managed), we proxy requests to Anthropic. We do not
  store the content of those requests beyond short-lived operational logs.

## 3. Data stored on your Mac

The following data is stored locally on your Mac and never transmitted by us:

- Your Anthropic API key (stored in the macOS Keychain on the Free tier).
- Chat history, assignments, meal plans, grocery lists, budget entries,
  planner data, flashcards, essays.
- Preferences, theme settings, and schedule configuration.

## 4. Apple system data

Miss M requests permission to read and/or write the following Apple system
frameworks, only when you use features that depend on them:

- **Calendar (EventKit)** — read/write events.
- **Reminders (EventKit)** — read/write reminders.
- **Contacts (CNContactStore)** — look up contacts you mention by name.
- **HealthKit** — read steps, sleep, heart rate, HRV, cycle data. Health
  data is never transmitted off-device unless you explicitly paste it into
  a Claude chat.
- **Microphone & Speech Recognition** — transcribe voice input locally via
  Apple's Speech framework.
- **Notifications** — deliver local reminders and briefings.
- **Focus / Shortcuts** — toggle Do Not Disturb during Pomodoro sessions.

Permissions can be revoked at any time in System Settings → Privacy &
Security.

## 5. Data sent to Anthropic

When you send a message to Miss M, the message and a short system prompt
are sent to Anthropic's Claude API to generate a response. This is required
for the assistant to function.

- On the **Free (BYOK)** tier, requests go directly from your Mac to
  Anthropic using your own API key. Elevarel does not see, log, or proxy
  these requests.
- On **Miss M Plus**, requests are proxied through our infrastructure to
  apply your subscription entitlement, then forwarded to Anthropic. We
  retain only minimal operational metadata (request timestamps, token
  counts, error codes) for 30 days. We do not store prompt content or
  responses.

Anthropic's handling of API data is governed by
[Anthropic's Commercial Terms](https://www.anthropic.com/legal/commercial-terms)
and
[Anthropic's Privacy Policy](https://www.anthropic.com/legal/privacy).
At the time of writing, Anthropic does not train its models on API traffic.

## 6. Account data (Miss M Plus only)

If you subscribe to Miss M Plus, we collect the minimum data required to
administer your subscription:

- Email address.
- A hashed licence key bound to your device.
- Payment metadata handled by our payment processor (Stripe or Paddle).
  We never see your full card number.

## 7. Cookies and tracking on this website

The marketing site (`elevarel.github.io/miss-m`) is hosted as a static site
on GitHub Pages. We do not set tracking cookies. Google Fonts is loaded
from Google's CDN to render the site typefaces; Google receives standard
HTTP request metadata (IP, user agent) for that purpose.

## 8. Children

Miss M is not directed at children under 13 and we do not knowingly
collect data from them.

## 9. Your rights (GDPR / UK GDPR / CCPA)

You can request access to, correction of, or deletion of any personal data
we hold about you by emailing <privacy@elevarel.io>. On the Free tier we
typically hold no data about you at all.

## 10. Changes

If we change this policy materially, we will note the change in the app
and on this page, with a new "Last updated" date.
