# ♛ Miss M — Personal AI Assistant

A native macOS AI assistant that lives in the menu bar, knows your schedule,
writes your essays, and keeps your life in rhythm — powered by Claude
Sonnet 4 and a pile of native Apple frameworks. All data stays on your
Mac.

> Marketing site: <https://elevarel.github.io/miss-m>
> Licence: see [`TERMS.md`](./TERMS.md) · Privacy: see [`PRIVACY.md`](./PRIVACY.md)
> Commercial strategy: [`COMMERCIAL.md`](./COMMERCIAL.md)

## 🚀 Install — one line

```bash
curl -fsSL https://elevarel.github.io/miss-m/install.sh | bash
```

That script:

1. Checks you're on macOS 14.0+ with the Xcode Command Line Tools.
2. Clones the repo into `~/.missm/src`.
3. Builds Miss M with `xcodebuild`.
4. Installs `Miss M.app` into `/Applications` (or `~/Applications`).
5. Launches her.

On first launch she'll ask for your Anthropic API key — get one free at
<https://console.anthropic.com>.

Prefer to read the script before piping it to your shell? [Here it is.](./install.sh)

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🤖 AI Chat | Full Claude Sonnet chat with streaming, tool use, voice |
| 🌅 Morning Briefing | Local notification at 7:30am with schedule + weather + tasks |
| 📚 Assignment Tracker | Kanban board with AI prioritisation |
| ✍️ Essay Writer | AI drafting, citations, tone adjustment |
| 🎓 Study Planner | Pomodoro timer + AI-generated study schedules |
| 🧠 Smart Life Planner | 7-day plan that threads Calendar, cycle, sleep, meals, budget |
| 💪 Smart Fitness | Workout suggestions aware of energy and cycle phase |
| 🍽️ Meal Planner | 7-day AI meal plan + shopping list |
| 💰 Budget Tracker | Income, expenses, savings goals |
| 🩺 Wellness & Cycle | HealthKit + Flo-synced cycle data, mood correlation |
| 📄 PDF & OCR | PDFKit + Vision: drop a PDF or screenshot, get a summary |
| ⚙️ Settings | API key, Apple integrations, all toggles |

## 🎨 Design

- **Theme:** Pink / rose · Apple Liquid Glass
- **Fonts:** Playfair Display · Cormorant Garamond · DM Sans
- **Design files:** `/docs/design/` — open any HTML file in a browser

## 🛠️ Requirements

- macOS 14.0+
- Xcode 15+ (or the Command Line Tools if you don't need the IDE)
- **Anthropic API key** — BYOK on the Free tier, managed on Miss M Plus

## 💰 Pricing

| | Free (BYOK) | Miss M Plus |
|---|---|---|
| Price | $0 | $12/month |
| API key | You supply yours | Managed by us |
| Features | Full app | Full app |
| Data | 100% local | 100% local, requests proxied |

Details: [`COMMERCIAL.md`](./COMMERCIAL.md).

## 📁 Project Structure

```
Miss-m/
├── CLAUDE.md          ← Master prompt for Claude Code
├── README.md
├── PRIVACY.md · TERMS.md · COMMERCIAL.md
├── install.sh         ← one-line installer
├── MissM/             ← Swift source
│   ├── App/ · Core/ · Features/ · Shared/
├── docs/design/       ← 29 HTML design reference screens
└── site/              ← GitHub Pages marketing site
    ├── index.html · privacy.html · terms.html
    └── install.sh · styles.css · favicon.svg
```

## 🔒 Privacy

- All user data stays on the Mac locally.
- API key stored in the macOS Keychain.
- No analytics, no telemetry, no cloud sync.
- Full policy: [`PRIVACY.md`](./PRIVACY.md).

## 🏗️ Development

```bash
git clone https://github.com/elevarel/miss-m.git
cd miss-m
./run-miss-m.sh          # build & launch locally
```

Or open `MissM.xcodeproj` in Xcode and ⌘R.

## 🗒️ Note on iMessage

Earlier Miss M builds included an iMessage auto-reply loop via AppleScript.
That integration was **removed in v2.1** — Apple has progressively
restricted AppleScript access to Messages and it is incompatible with paid
distribution. Briefings are now local notifications, and sending messages
opens the native Messages compose sheet for you to review and send.

---

*♛ Built with care by Elevarel.*
