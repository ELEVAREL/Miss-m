# CLAUDE.md — Miss M Personal AI Assistant
# READ THIS ENTIRE FILE BEFORE WRITING A SINGLE LINE OF CODE

---

## ⚠️ CRITICAL RULES — NEVER BREAK THESE

1. ALWAYS read this entire file first before starting any task
2. ALWAYS check which Phase we are in (see CURRENT PHASE below)
3. NEVER hardcode API keys — always use KeychainManager.swift
4. NEVER use ObservableObject — always use @Observable (Swift 5.9+)
5. NEVER use completion handlers — always use async/await
6. ALWAYS follow the pink design system in Theme.swift exactly
7. ALWAYS reference the HTML design files in docs/design/ before building any UI
8. NEVER invent features not in this file
9. ALWAYS ask the user before starting a new Phase
10. NEVER delete existing files — only add or modify

---

## 🎯 WHAT THIS APP IS

Name: Miss M
Type: Native macOS menu bar app (NOT iOS, NOT web)
Purpose: Personal AI assistant for a Marketing university student
User: Miss M — female Marketing student who also manages home and family
Platform: macOS 14.0+ only
Distribution: NOT on App Store — runs locally on her Mac
AI Brain: Claude Sonnet 4.6 via Anthropic API
Bundle ID: com.missm.assistant

What makes it special:
- Lives in the menu bar (♛ icon) — one click away always
- Two-way iMessage AI — she texts her Mac from iPhone, AI replies
- Morning briefing — auto iMessage at 7:30am with schedule + weather + tasks
- Knows her whole life — school, home, meals, budget, wellness
- Feels like a luxury product — pink, glass, elegant

---

## 📱 CURRENT PHASE: PHASE 1 — NOT STARTED

Build in this exact order:
[ ] 1. Create Xcode project: macOS App, SwiftUI, Bundle ID com.missm.assistant, deployment macOS 14.0
[ ] 2. Copy all existing Swift files into correct Xcode groups (match folder structure)
[ ] 3. Add Info.plist permissions (see PERMISSIONS section)
[ ] 4. Menu bar icon ♛ showing via AppDelegate.swift
[ ] 5. Popover 420x620pt opens on click
[ ] 6. Onboarding screen if no API key in Keychain
[ ] 7. API key saved to Keychain when entered
[ ] 8. Main app + tab bar shows after setup
[ ] 9. Claude chat working with streaming
[ ] 10. Thinking indicator before response arrives
[ ] 11. Tool-use pills when Claude uses Apple APIs
[ ] 12. Apple Calendar read access (CalendarService.swift)
[ ] 13. Apple Reminders read + write (RemindersService.swift)
[ ] 14. Pink design system applied to all views
[ ] 15. Test end-to-end — tell user Phase 1 complete

---

## 🏗️ ALL PHASES OVERVIEW

PHASE 1 — Foundation (CURRENT)
  Menu bar app, onboarding, Claude chat (all 7 states), Calendar, Reminders, Settings, pink design

PHASE 2 — School
  Assignment kanban (3 cols), Essay writer (3 panels), Study planner + Pomodoro,
  Flashcards, Marketing tools (SWOT/STP/Persona/Campaign), Research + citations, Calendar view

PHASE 3 — iMessage AI
  Incoming message monitor (AppleScript poll 10s), Auto-reply via Claude,
  Morning briefing 7:30am weekdays, Evening wind-down 9pm, Sunday weekly plan 7pm, Deadline warnings

PHASE 4 — Home and Life
  Meal planner (7-day grid), Grocery list (sections, tap to check),
  Budget tracker (donut chart, categories, savings goals), Email drafter (tone selector + templates)

PHASE 5 — Marketing Tools
  SWOT/PESTLE builders, STP walkthrough, Persona builder, Campaign generator,
  Social media planner, LinkedIn drafter, Marketing news briefing

PHASE 6 — Wellness
  Hydration tracker (reminders every 2hrs), Mood check-in (5 options),
  Study break alerts (after 90min), Sleep reminder 10:30pm, Wellness dashboard

PHASE 7 — Polish
  Touch ID lock, Voice input (Speech), Text-to-speech (AVFoundation),
  Keyboard shortcuts, Spotlight, Onboarding flows, App icon

---

## 🎨 DESIGN SYSTEM — USE THEME.SWIFT ALWAYS

Never use raw hex values. Always use Theme.* constants.

COLORS (all in Theme.Colors.*):
  rosePrimary   #E91E8C   — buttons, active states, highlights
  roseDeep      #C2185B   — button gradients, icon backgrounds
  roseDark      #880E4F   — hero card gradients
  roseMid       #F06292   — thinking dots, secondary accents
  roseLight     #F8BBD9   — borders, chip outlines
  rosePale      #FCE4EC   — pale backgrounds
  roseUltra     #FFF0F8   — body background
  gold          #D4AF7A   — premium accent
  textPrimary   #1A0A10   — main text
  textMedium    #5C3049   — secondary text
  textSoft      #9A6B80   — hints, descriptions
  textXSoft     #C4A0B2   — placeholder text, disabled
  glassWhite    white 62% — card backgrounds
  glassBorder   white 82% — card borders
  shadow        rose 13%  — card shadows

TYPOGRAPHY:
  Display/headers:  Playfair Display Italic (large headings, hero titles)
  Section labels:   Cormorant Garamond SemiBold + 2.5pt tracking + uppercase
  All body text:    DM Sans (system font is acceptable fallback)

GLASS CARD PATTERN:
  .glassCard() modifier — defined in Theme.swift
  white 62% background + ultraThinMaterial + white 82% border + rose shadow

GRADIENT HERO CARDS:
  Theme.Gradients.heroCard — rose to deep to dark
  Always overflow:hidden with two decorative white circles

BUTTONS:
  Primary: .buttonStyle(RoseButtonStyle()) — gradient, white text, rose shadow
  Ghost: white 75% bg + rose border + medium text + hover darkens

POPOVER SIZE: 420 x 620pt — NEVER change this

---

## 📐 DESIGN FILES — OPEN THESE BEFORE BUILDING ANY UI

docs/design/01-chat-advanced.html      — All 7 chat states (click right panel cards)
docs/design/02-morning-briefing.html   — Hero card, stats, schedule, iMessage preview
docs/design/03-assignments-kanban.html — 3-col kanban, progress bars, AI banner
docs/design/04-essay-writer.html       — Outline + editor + citations (3 panels)
docs/design/05-study-meals-budget.html — Pomodoro, week view, meal grid, budget donut, grocery
docs/design/06-imessage-wellness-settings.html — iPhone mockup, wellness cards, mood, settings

---

## 📁 FILE STRUCTURE

MissM/App/
  MissMApp.swift        — @main entry, no main window, Settings scene only
  AppDelegate.swift     — NSStatusItem setup, popover toggle, NSApp.setActivationPolicy(.accessory)
  ContentView.swift     — Root: shows OnboardingView or MainAppView based on Keychain

MissM/Core/Claude/
  ClaudeService.swift   — Streaming API, system prompt, tool event handling

MissM/Core/Apple/
  CalendarService.swift   — CREATE IN PHASE 1: EKEventStore, request access, get/add events
  RemindersService.swift  — CREATE IN PHASE 1: EKEventStore, request access, get/add reminders
  MessagesService.swift   — NSAppleScript send + receive, MessageMonitor polling class

MissM/Core/Storage/
  KeychainManager.swift   — save/load API key and phone number, kSecClassGenericPassword
  DataStore.swift         — CREATE WHEN NEEDED: actor-based JSON persistence

MissM/Features/Chat/
  ChatView.swift        — Full chat UI: all 7 states, ThinkingBubble, ToolPill, streaming cursor

MissM/Features/Briefing/
  BriefingScheduler.swift — Timer, morning/evening send, buildContext() uses CalendarService

MissM/Shared/
  Theme.swift           — ALL design tokens, GlassCard modifier, RoseButtonStyle, Color(hex:)

docs/design/            — 6 HTML design reference files

---

## 🤖 CLAUDE API — EXACT DETAILS

Model string: "claude-sonnet-4-20250514"
Default maxTokens: 1024
Streaming: always use for chat
Non-streaming: use for briefings, background tasks

System prompt (use EXACTLY this):
"""
You are Miss M's personal AI assistant — warm, smart, and always on her side.
She is a Marketing university student who also manages her home and family tasks.
Always address her as "Miss M". Never use her real name.
Be warm and encouraging — she is often stressed and busy.
Be concise — she does not have time for long responses.
Use emojis naturally but not excessively (1-2 per message max).
When you use a tool, briefly mention what you are doing.
Always end with a helpful follow-up offer when appropriate.
You have access to her Apple Calendar, Reminders, and can send iMessages.
"""

Tool names Claude uses:
  read_calendar    → CalendarService.getEventsToday()
  add_reminder     → RemindersService.addReminder(title:due:)
  read_reminders   → RemindersService.getIncompleteReminders()
  send_imessage    → MessagesService.send(_:to:)
  get_weather      → WeatherKit or URLSession weather API
  web_search       → URLSession for research

---

## 💬 THE 7 CHAT STATES — IMPLEMENT ALL

STATE 1 — Normal reply: white bubble, rose border, assistant role
STATE 2 — Thinking: ThinkingBubble (spinning 🧠 + bouncing dots + italic text)
STATE 3 — Tool running: blue ToolPill + ProgressView spinner
STATE 4 — Tool done + rich card: green ToolPill with ✓, data shown as RichCard below
STATE 5 — Streaming: text builds char by char (26ms interval), blinking rose cursor
STATE 6 — Write-back: shows action pill (adding reminder etc), turns green when done
STATE 7 — Voice: animated 7-bar waveform, pulsing voice button, seconds timer

All component implementations are in MissM/Features/Chat/ChatView.swift already.

---

## 📱 INFO.PLIST PERMISSIONS — ADD ALL

NSCalendarsUsageDescription:
  "Miss M reads your calendar to give you daily briefings and smart scheduling suggestions."

NSRemindersUsageDescription:
  "Miss M manages your reminders so you never miss a deadline or important task."

NSSpeechRecognitionUsageDescription:
  "Miss M listens when you want to speak your request instead of typing."

NSMicrophoneUsageDescription:
  "Miss M uses your microphone to hear your voice commands."

---

## 💬 TWO-WAY iMESSAGE — PHASE 3

Flow:
1. Miss M texts Mac from iPhone
2. MessageMonitor (10s timer) detects via AppleScript
3. Message sent to Claude with full context
4. Claude responds (may call calendar/reminders tools)
5. Reply sent back to her phone number via AppleScript
6. She receives it as normal iMessage

Phone number saved in Keychain via KeychainManager.savePhoneNumber()
MessagesService.swift already has send() and MessageMonitor class

---

## 🌅 MORNING BRIEFING FORMAT

Sent weekdays at 7:30am. Claude generates from real CalendarService + RemindersService data.

Template:
Good morning Miss M! ☀️

[Day], [Date]

📚 [Urgent deadline] — [X] days left
📅 [First event] [time] · [Second event] [time]
🌤 [Temperature]°C · [brief weather note]
✅ [X] tasks today

[1 line encouragement]
Reply to ask me anything 💬

---

## 🔐 SECURITY RULES

Store API key:      KeychainManager.saveAPIKey(_:)
Load API key:       KeychainManager.loadAPIKey()
Store phone:        KeychainManager.savePhoneNumber(_:)
NEVER store in:     UserDefaults, hardcoded strings, plist, console logs
NEVER print:        API key anywhere in logs

---

## 💰 COST MANAGEMENT

Balance: $24.00 USD (estimated 4-8 months daily use)
Chat: claude-sonnet-4-20250514, maxTokens 1024
Simple queries: consider claude-haiku-4-5 (cheaper)
Briefings: maxTokens 512
Essay generation: maxTokens 2048

---

## 🚫 NEVER BUILD THESE

No iOS version, no iCloud sync, no App Store submission,
no third-party packages (pure Swift only), no analytics,
no ads, no cloud storage of any kind, no APNs push notifications

---

## 🏁 FIRST SESSION INSTRUCTIONS

1. Say: "I have read CLAUDE.md. Building Phase 1. Starting with Xcode project setup."
2. Create new macOS Xcode project with settings above
3. Copy all Swift files into correct Xcode groups
4. Add Info.plist permissions
5. Run cmd+B, fix errors
6. Run cmd+R, confirm ♛ in menu bar
7. Enter API key in onboarding, confirm chat streams
8. Tell user: "Phase 1 foundation working. Chat is live, design is pink, menu bar active. What next?"

---

## 📋 KEY DATA MODELS

Assignment: id, title, subject, description, dueDate, status (.todo/.inProgress/.done), progressPercent, wordCount, wordTarget

GroceryItem: id, name, quantity, section (.produce/.protein/.dairy/.pantry/.other), isChecked

MoodEntry: id, date, mood (.great=5/.good=4/.okay=3/.low=2/.stressed=1), note

BudgetEntry: id, date, amount, category (.food/.school/.transport/.subscriptions/.health/.home/.other), note

---

## 📞 PROJECT CONTEXT

This app is a gift from husband to wife.
Wife is the user — always "Miss M" in UI.
Husband manages the repo and runs Claude Code.
Goal: Working app tonight, full app over coming weeks.
Keep all instructions simple — owner is not a developer.

---

Last updated: April 2026 — Miss M v1.0
If anything is unclear in this file, ask before building.
