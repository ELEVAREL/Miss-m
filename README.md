# 👑 Miss M — Personal AI Assistant

A native macOS AI assistant built for a Marketing university student. Lives in the menu bar, knows her schedule, helps with essays, sends her morning briefings via iMessage, and responds when she texts her Mac from her iPhone.

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🤖 AI Chat | Full Claude Sonnet 4.6 chat with streaming, tool use, voice |
| 🌅 Morning Briefing | Auto iMessage at 7:30am with schedule + weather + tasks |
| 📚 Assignment Tracker | Kanban board with AI prioritisation |
| ✍️ Essay Writer | AI drafting, citations, tone adjustment |
| 🎓 Study Planner | Pomodoro timer + AI-generated study schedules |
| 💬 Two-Way iMessage AI | Text her Mac from iPhone — AI reads and replies |
| 🍽️ Meal Planner | 7-day AI meal plan + shopping list |
| 💰 Budget Tracker | Income, expenses, savings goals |
| 🌙 Wellness | Hydration, mood, study breaks, sleep reminders |
| ⚙️ Settings | API key, Apple integrations, all toggles |

## 🎨 Design

- **Theme:** Pink/rose luxury · Apple Liquid Glass
- **Fonts:** Playfair Display · Cormorant Garamond · DM Sans
- **Design files:** See `/docs/design/` — open any HTML file in browser

## 🛠️ Requirements

- macOS 14.0+
- Xcode 15+
- Anthropic API key (get at platform.anthropic.com)
- Messages app signed in on Mac

## 🚀 Getting Started

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/MissM.git
cd MissM

# 2. Open in Xcode
open MissM.xcodeproj

# 3. Build with Claude Code
claude  # then say: "Start building Phase 1 — read CLAUDE.md first"
```

## 📁 Project Structure

```
MissM/
├── CLAUDE.md          ← Master prompt for Claude Code (read this first)
├── README.md
├── MissM/             ← Swift source code
│   ├── App/
│   ├── Core/
│   ├── Features/
│   └── Shared/
└── docs/
    └── design/        ← 6 HTML design reference screens
        ├── 01-chat-advanced.html
        ├── 02-morning-briefing.html
        ├── 03-assignments-kanban.html
        ├── 04-essay-writer.html
        ├── 05-study-meals-budget.html
        └── 06-imessage-wellness-settings.html
```

## 💰 API Cost

Estimated **$3–6/month** at typical daily use with ~$24 in account = 4–8 months of everything.

## 🔒 Privacy

- All data stays on the Mac locally
- API key stored in macOS Keychain
- No cloud sync — fully private

---

*Built with ❤️ for Miss M*
