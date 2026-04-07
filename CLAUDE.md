# Miss M — Personal AI Assistant
## Claude Code Master Prompt

You are building **Miss M**, a native macOS personal assistant app for a Marketing university student. This is a SwiftUI menu bar application that uses the Claude API (Sonnet 4.6) as its AI brain.

---

## 🎯 Project Identity

- **App name:** Miss M
- **User:** A female Marketing university student who also manages home/family tasks
- **Platform:** macOS (menu bar app, no App Store release needed)
- **AI model:** Claude Sonnet 4.6 via Anthropic API
- **API key storage:** macOS Keychain (never hardcode keys)
- **Design language:** Pink/rose luxury · Liquid Glass · Playfair Display + DM Sans

---

## 🏗️ Tech Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (macOS 14+)
- **AI:** Anthropic Claude API (claude-sonnet-4-20250514)
- **Apple integrations:** EventKit (Calendar), EventKit (Reminders), UserNotifications, Speech, AVFoundation
- **iMessage automation:** AppleScript via NSAppleScript
- **Data persistence:** Swift actors + JSON file storage in Application Support
- **Networking:** URLSession with async/await
- **No third-party dependencies** (keep it pure Swift)

---

## 📁 Project Structure

```
MissM/
├── MissM/
│   ├── App/
│   │   ├── MissMApp.swift           # App entry point + menu bar setup
│   │   └── AppDelegate.swift        # NSApplicationDelegate
│   ├── Core/
│   │   ├── Claude/
│   │   │   ├── ClaudeService.swift  # API calls, streaming, tool use
│   │   │   └── ClaudeModels.swift   # Request/response models
│   │   ├── Apple/
│   │   │   ├── CalendarService.swift
│   │   │   ├── RemindersService.swift
│   │   │   └── MessagesService.swift # AppleScript iMessage
│   │   └── Storage/
│   │       └── DataStore.swift      # Actor-based persistence
│   ├── Features/
│   │   ├── Chat/
│   │   │   ├── ChatView.swift
│   │   │   └── ChatViewModel.swift
│   │   ├── Briefing/
│   │   │   ├── BriefingView.swift
│   │   │   └── BriefingScheduler.swift
│   │   ├── Assignments/
│   │   │   ├── AssignmentsView.swift
│   │   │   └── AssignmentsViewModel.swift
│   │   ├── Essay/
│   │   │   └── EssayView.swift
│   │   ├── Study/
│   │   │   ├── StudyView.swift
│   │   │   └── PomodoroTimer.swift
│   │   ├── Home/
│   │   │   ├── MealsView.swift
│   │   │   ├── GroceryView.swift
│   │   │   └── BudgetView.swift
│   │   ├── Wellness/
│   │   │   └── WellnessView.swift
│   │   └── Settings/
│   │       └── SettingsView.swift
│   ├── Shared/
│   │   ├── Theme.swift              # Colors, fonts, design tokens
│   │   └── Components/             # Reusable UI components
│   └── Resources/
│       └── Assets.xcassets
├── CLAUDE.md                        # This file
├── README.md
└── docs/
    └── design/                      # HTML design files for reference
```

---

## 🎨 Design System (ALWAYS follow this)

```swift
// Colors
let rosePrimary = Color(hex: "#E91E8C")
let roseDeep = Color(hex: "#C2185B")
let roseDark = Color(hex: "#880E4F")
let roseLight = Color(hex: "#F8BBD9")
let rosePale = Color(hex: "#FFF0F8")
let gold = Color(hex: "#D4AF7A")

// Typography
// Display: Playfair Display (italic, large headings)
// Heading: Cormorant Garamond (uppercase labels, section titles)
// Body: DM Sans (all UI text, buttons, inputs)

// Glass Effect (Liquid Glass style)
// .background(.ultraThinMaterial) with pink tint overlay
// .cornerRadius(20) on cards
// shadow: Color(rosePrimary).opacity(0.12), radius: 16
```

---

## 🤖 Claude API Integration

### Base Setup
```swift
struct ClaudeRequest: Codable {
    let model = "claude-sonnet-4-20250514"
    let maxTokens = 1024
    let system: String
    let messages: [Message]
}
```

### System Prompt for Miss M
```
You are Miss M's personal AI assistant — warm, smart, and always on her side. 
She is a Marketing university student who also manages her home.
Always address her as "Miss M". Be encouraging, concise and helpful.
You have access to her Apple Calendar, Reminders, and can send iMessages.
When you use a tool, show what you're doing clearly.
Respond warmly but efficiently — she's busy.
```

### Streaming
- Always use streaming for chat responses
- Show thinking indicator before first token arrives
- Show tool use pills with spinners when calling Apple APIs
- Mark tool pills green with ✓ when complete

### Tool Use
Claude can call these tools:
1. `read_calendar` — Read EventKit calendar events
2. `add_reminder` — Add to Apple Reminders
3. `send_imessage` — Send via AppleScript
4. `read_reminders` — Read existing reminders
5. `get_weather` — WeatherKit (or simple URL fetch)
6. `web_search` — URLSession fetch for research

---

## 📱 iMessage Two-Way AI (KEY FEATURE)

This is how Miss M texts her Mac and gets AI replies:

```swift
// AppleScript to SEND a message
let script = """
tell application "Messages"
    send "\(message)" to buddy "\(phoneNumber)"
end tell
"""

// Monitor INCOMING messages via AppleScript polling
// Poll every 10 seconds for new messages from her number
// When detected → send to Claude → send reply back
```

**Important:** The Mac must be signed into Messages app. This feature runs as a background timer.

---

## 🌅 Morning Briefing (Automated)

Runs daily at 7:30am via a scheduled timer:
1. Read today's calendar events (EventKit)
2. Read due reminders (EventKit)  
3. Fetch weather (WeatherKit or API)
4. Send Claude-generated summary via iMessage to her iPhone
5. Evening wind-down at 9pm with recap

---

## 🏗️ Build Order (Follow Phases)

### Phase 1 — CURRENT: Foundation (Build this first)
- [ ] Menu bar app shell with popover window
- [ ] Claude API chat working with streaming
- [ ] Basic chat UI with all 7 states (thinking/tools/streaming/voice/rich-cards/write-back)
- [ ] Apple Calendar read access
- [ ] Apple Reminders read/write
- [ ] Settings panel with API key input (stored in Keychain)
- [ ] Pink/rose design system applied throughout

### Phase 2 — School
- [ ] Assignment tracker (kanban board)
- [ ] Essay writer with AI drafting
- [ ] Study planner + Pomodoro timer
- [ ] Flashcard generator

### Phase 3 — iMessage AI
- [ ] Incoming message monitor (AppleScript polling)
- [ ] Auto-reply with Claude
- [ ] Morning briefing scheduler (7:30am daily)
- [ ] Evening wind-down (9pm)

### Phase 4 — Home & Life
- [ ] Meal planner (7-day grid)
- [ ] Grocery list with sections
- [ ] Budget tracker with donut chart
- [ ] Email drafter

### Phase 5 — Marketing Tools
- [ ] SWOT/PESTLE template generator
- [ ] Consumer persona builder
- [ ] Campaign idea generator
- [ ] Citation manager (APA/Harvard)

### Phase 6 — Wellness
- [ ] Hydration reminders
- [ ] Mood tracker
- [ ] Study break alerts
- [ ] Sleep wind-down

### Phase 7 — Polish
- [ ] Touch ID lock
- [ ] Onboarding flow
- [ ] Keyboard shortcuts
- [ ] Spotlight integration

---

## ⚙️ Key Rules for Claude Code

1. **Always use async/await** — no completion handlers
2. **Always store API key in Keychain** — never in UserDefaults or plist
3. **Use @Observable** — not ObservableObject (modern SwiftUI)
4. **Use Swift actors** for any shared mutable state
5. **Always handle errors gracefully** — show friendly messages to Miss M
6. **Keep Claude API costs low** — use Haiku for simple tasks, Sonnet for complex
7. **Request Apple permissions gracefully** — explain WHY before asking
8. **Always test on macOS 14+** — use #available checks where needed
9. **Follow the pink design system** — every screen should feel cohesive
10. **iMessage feature requires Full Disk Access** — add a clear setup prompt

---

## 🔐 Permissions Required

Add to Info.plist:
```xml
<key>NSCalendarsUsageDescription</key>
<string>Miss M reads your calendar to give you daily briefings and smart scheduling.</string>
<key>NSRemindersUsageDescription</key>
<string>Miss M manages your reminders so you never miss a deadline.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Miss M listens when you want to speak instead of type.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Miss M uses your microphone for voice input.</string>
```

---

## 💰 API Cost Management

- Default model: `claude-sonnet-4-20250514` (~$3/$15 per MTok)
- Simple queries (reminders, quick answers): consider `claude-haiku-4-5` (~$1/$5)
- Current API balance: ~$24 — estimated 4-8 months of daily use
- Always show token usage in Settings debug panel

---

## 📐 Design Files Reference

All 6 HTML design screens are in `/docs/design/`:
- `01-chat-advanced.html` — Chat with all 7 live states
- `02-morning-briefing.html` — Morning briefing card + iMessage
- `03-assignments-kanban.html` — Kanban board
- `04-essay-writer.html` — 3-panel essay writer
- `05-study-meals-budget.html` — Study/meals/budget/grocery
- `06-imessage-wellness-settings.html` — iMessage AI + wellness + settings

Open these in a browser to see the exact UI to replicate in SwiftUI.

---

## 🚀 Getting Started (First Session)

When you open this project with Claude Code, say:

> "Start building Phase 1. Create the menu bar app shell with the pink design system, Claude API streaming chat, and Calendar/Reminders integration. Follow CLAUDE.md exactly."

Claude Code will read this file and know exactly what to build.
