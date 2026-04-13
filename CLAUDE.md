# CLAUDE.md — Miss M Personal AI Assistant
# READ THIS ENTIRE FILE BEFORE WRITING A SINGLE LINE OF CODE

---

## ⚠️ ABSOLUTE RULES — NEVER BREAK

1. Read this ENTIRE file before starting any task
2. Only build what is in this file — never invent features
3. NEVER hardcode API keys — always KeychainManager.swift
4. NEVER use ObservableObject — always @Observable (Swift 5.9+)
5. NEVER use completion handlers — always async/await
6. ALWAYS follow Theme.swift for ALL colors, fonts, spacing
7. ALWAYS open the matching design file in docs/design/ before building any UI screen
8. Ask user before starting a new Phase — confirm previous Phase works first
9. NEVER delete existing files — only add or modify
10. NEVER store sensitive data anywhere except Keychain

---

## 🎯 PROJECT IDENTITY

App name:         Miss M
Type:             Native macOS menu bar app (NOT iOS, NOT web)
User:             Miss M — female Marketing university student + home manager
Platform:         macOS 14.0+ only
Distribution:     Direct download via one-line installer — github.com/elevarel/miss-m (NOT Mac App Store)
AI model:         Claude Sonnet 4.6 — claude-sonnet-4-20250514
Bundle ID:        com.missm.assistant
Popover size:     420 × 620pt — NEVER change this

---

## 👤 KEY PEOPLE (v2.1 — no longer hardcoded)

Onboarding captures:
  - User's preferred name (default "Miss M" for the original deployment, user-editable)
  - Optional partner / husband / wife name and relationship label
  - Partner is pinned #1 in People Hub. If no partner is configured, position 1 is left empty.

When the user says "my husband" / "my partner" / "my wife" → resolve via CNContactStore using the name stored in onboarding. If nothing is configured, ask once and save the answer.

Maintainer (private deployment): NyRiian runs Claude Code on this repo. When building the single-user fork, treat "Miss M" as the user and NyRiian as her partner. When building the commercial distribution, do NOT hardcode either name.

---

## 📱 CURRENT PHASE: PHASE 1 — BUILD THIS FIRST

Complete in this exact order:
[ ] 1. Create Xcode project: macOS App · SwiftUI · Bundle ID com.missm.assistant · macOS 14.0
[ ] 2. Copy all existing Swift files into correct Xcode groups (match folder structure exactly)
[ ] 3. Add all Info.plist permissions (see PERMISSIONS section below)
[ ] 4. Menu bar icon ♛ showing — use AppDelegate.swift
[ ] 5. Popover 420×620pt opens when icon clicked
[ ] 6. OnboardingView shows if no API key in Keychain
[ ] 7. API key saved to Keychain — never anywhere else
[ ] 8. MainAppView + tab bar shows after setup complete
[ ] 9. Claude API chat working with streaming responses
[ ] 10. Thinking state shows before first token arrives
[ ] 11. Tool-use pills show when Claude calls Apple APIs
[ ] 12. CalendarService.swift — EventKit read access
[ ] 13. RemindersService.swift — EventKit read + write
[ ] 14. Pink design system from Theme.swift applied everywhere
[ ] 15. Test full flow end-to-end — confirm working before Phase 2

---

## 🗂️ ALL PHASES

### Phase 1 — Foundation ← BUILD NOW
Menu bar app · Onboarding · Claude streaming chat (all 7 states) · Calendar · Reminders · Settings · Pink design

### Phase 2 — School
Assignment Kanban · Essay Writer (3-panel) · Study Planner + Pomodoro · Flashcards · Marketing Tools (SWOT/STP/Persona/Campaign/PESTLE) · Research + Citations · Calendar full view · Smart Writing (NSSpellChecker + NaturalLanguage + Claude)

### Phase 3 — Local Briefings & Notifications
⚠️ iMessage integration has been REMOVED from Miss M as of v2.1 (commercial build). Apple has progressively restricted AppleScript access to Messages and it is incompatible with paid distribution. All iMessage features are replaced with native macOS features:

- Morning briefing 7:30am → UNUserNotificationCenter rich local notification + in-app briefing card
- Evening wind-down 9pm → local notification
- Sunday weekly plan 7pm → local notification
- Deadline warnings 3d / 1d / morning → local notifications
- "Text my husband" / auto-reply / People Hub dynamic Messages history → REMOVED

MessagesService.swift remains in the repo (rule #9: never delete files) but is marked @deprecated and must not be wired into any new feature. Do not add new call sites for it.

### Phase 4 — Home & Life
Meal planner (7-day grid) · Grocery list (sections, tap to check) · Budget tracker (donut chart, savings goals) · Email drafter (tone selector, professor templates) · Home hub overview

### Phase 5 — Mac Power Tools
PDF reader (PDFKit + Vision OCR) · Screenshot OCR · Menu bar mini view · Safari companion · File command centre · Pomodoro in menu bar · Quick launcher (Cmd+Shift+M)

### Phase 6 — Health & Wellness
HealthKit: sleep · steps · heart rate · HRV · calories · mindful sessions · Cycle tracking (HealthKit CycleTracking) · Mood × phase correlation · Full wellness dashboard

### Phase 7 — Polish & Power
Siri Shortcuts (App Intents) · Touch ID lock · Text-to-speech (AVFoundation) · Voice input (Speech framework) · Apple Notes sync · System dashboard · Global keyboard shortcut · App icon

---

## 📁 FILE STRUCTURE

MissM/App/
  MissMApp.swift        @main entry — no main window, Settings scene only, NSApp.setActivationPolicy(.accessory)
  AppDelegate.swift     NSStatusItem + NSPopover setup, togglePopover()
  ContentView.swift     Root: OnboardingView if no API key, else MainAppView with tab bar

MissM/Core/Claude/
  ClaudeService.swift   Streaming API, system prompt, tool event handling — already written

MissM/Core/Apple/
  CalendarService.swift   CREATE Phase 1: EKEventStore, requestFullAccessToEvents, get/add events
  RemindersService.swift  CREATE Phase 1: EKEventStore, requestFullAccessToReminders, get/add reminders
  MessagesService.swift   @deprecated in v2.1 — DO NOT wire into new features. File stays per rule #9.
  HealthService.swift     CREATE Phase 6: HKHealthStore, read steps/sleep/heart rate/cycle

MissM/Core/Storage/
  KeychainManager.swift   API key + phone number + husband name — already written
  DataStore.swift         CREATE when needed: actor-based JSON persistence for assignments/meals/budget/grocery

MissM/Features/
  Chat/ChatView.swift              All 7 chat states — already written
  Briefing/BriefingScheduler.swift Morning/evening/weekly briefings via UNUserNotificationCenter + in-app card (Phase 3)
  Assignments/                     CREATE Phase 2
  Essay/                           CREATE Phase 2
  Study/                           CREATE Phase 2
  Marketing/                       CREATE Phase 2
  Home/                            CREATE Phase 4
  Wellness/                        CREATE Phase 6
  Settings/SettingsView.swift      EXPAND Phase 1

MissM/Shared/
  Theme.swift   ALL design tokens, GlassCard modifier, RoseButtonStyle, Color(hex:) — already written

docs/design/    29 HTML reference files — open before building any screen

---

## 🎨 DESIGN SYSTEM — ALWAYS USE THEME.SWIFT

Never use raw hex values. Never use system colors. Always Theme.*

Colors:
  rosePrimary   #E91E8C   Primary actions, active states, pills
  roseDeep      #C2185B   Button gradients, hover states
  roseDark      #880E4F   Hero card gradients
  roseMid       #F06292   Thinking dots, secondary accents
  roseLight     #F8BBD9   Borders, chip outlines
  rosePale      #FCE4EC   Section backgrounds
  roseUltra     #FFF0F8   App background
  gold          #D4AF7A   Premium accent
  textPrimary   #1A0A10   Main body text
  textMedium    #5C3049   Secondary text
  textSoft      #9A6B80   Hints, placeholders, descriptions
  textXSoft     #C4A0B2   Disabled, very soft text
  glassWhite    white 62%  Card backgrounds
  glassBorder   white 82%  Card borders
  shadow        rose 13%   Card shadows

Typography:
  Display:  Playfair Display Italic — large headings, hero titles, greeting cards
  Heading:  Cormorant Garamond SemiBold + 2.5pt tracking + uppercase — section labels
  Body:     DM Sans — all UI text, buttons, inputs, messages

Glass card pattern — use .glassCard() modifier from Theme.swift:
  .background(Theme.Colors.glassWhite)
  .background(.ultraThinMaterial)
  .cornerRadius(Theme.Radius.md)
  .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder, lineWidth: 1))
  .shadow(color: Theme.Colors.shadow, radius: 10, x: 0, y: 4)

Gradient hero cards: Theme.Gradients.heroCard (rose → deep → dark)
Primary buttons: .buttonStyle(RoseButtonStyle()) — defined in Theme.swift

---

## 📐 DESIGN FILES — OPEN BEFORE BUILDING ANY SCREEN

docs/design/00-feature-gallery.html   MASTER INDEX — click any card to preview all screens
docs/design/01-chat-advanced.html     All 7 chat states (click state cards on right panel)
docs/design/02-morning-briefing.html  Morning card + iMessage preview + schedule settings
docs/design/03-assignments-kanban.html  3-col kanban + AI priority banner + progress bars
docs/design/04-essay-writer.html      Outline sidebar + editor + citations (3 panels)
docs/design/05-study-meals-budget.html Pomodoro timer + week calendar + meal grid + budget donut + grocery
docs/design/06-imessage-wellness-settings.html  iPhone mockup + wellness cards + mood + settings toggles
docs/design/07-marketing-tools.html   SWOT/STP/Persona/Campaign/PESTLE (tabbed)
docs/design/08-calendar-view.html     Month grid + day time blocks + AI scheduling
docs/design/09-research-citations.html  Web search + AI summary + source cards + citation manager
docs/design/10-home-hub-email.html    Home hub grid + chores + bills + email drafter with tone
docs/design/11-flashcards-quiz.html   3D flip card + progress dots + decks + generate from notes
docs/design/12-nyriian-message.html   NyRiian profile hero + quick chips + chat history + compose
docs/design/13-reminders.html         Smart list sidebar + all reminders + priority add panel
docs/design/14-onboarding.html        5-step first-launch: welcome → API key → permissions → phone → done
docs/design/15-people-hub.html        Dynamic contacts from real Messages history — no fake people
docs/design/16-pdf-dropzone.html      Drag PDF → AI reads via PDFKit + Vision OCR → summary + flashcards
docs/design/17-screenshot-ocr.html    Capture screen region → Vision OCR → AI explains any text
docs/design/18-menubar-mini.html      Compact ♛ popover: stats + next event + quick chat
docs/design/19-safari-companion.html  Reads current browser page → summarise + cite + save to essay
docs/design/20-file-command-centre.html  Drag any file → AI reads/summarises/generates study content
docs/design/21-pomodoro-menubar.html  Timer in menu bar → DND + Apple Music auto-control
docs/design/22-apple-health.html      HealthKit: steps + heart rate + HRV + sleep + activity rings
docs/design/23-cycle-tracker.html     HealthKit CycleTracking: phase ring + mood correlation + calendar
docs/design/24-siri-shortcuts.html    App Intents: 8 voice commands + lock screen widget
docs/design/25-smart-writing.html     NSSpellChecker + NaturalLanguage + Claude: real-time essay check
docs/design/26-system-dashboard.html  Battery + WiFi + storage + system controls + automations
docs/design/27-quick-launcher.html    Cmd+Shift+M spotlight: natural language → any feature instantly
docs/design/28-apple-notes-sync.html  Read/write Apple Notes: save summaries + study notes

---

## 🤖 CLAUDE API

Model:      claude-sonnet-4-20250514  ← EXACT string, never change
MaxTokens:  1024 (chat) · 512 (briefing) · 2048 (essay generation)
Streaming:  Always use for chat
API key:    Always load from KeychainManager.loadAPIKey()

System prompt (use EXACTLY):
"""
You are Miss M's personal AI assistant — warm, smart, and always on her side.
She is a Marketing university student who also manages her home and family tasks.
Always address her as "Miss M". Never use her real name.
Be warm and encouraging — she is often stressed and busy.
Be concise — she does not have time for long responses.
Use emojis naturally but not excessively (1-2 per message max).
When you use a tool, briefly mention what you are doing.
Always end with a helpful follow-up offer when appropriate.
You have access to her Apple Calendar and Reminders.
If the user has configured a partner's name in Settings, resolve "my husband" / "my partner" to that contact via CNContactStore. If no partner is configured, ask.
"""

---

## 💬 THE 7 CHAT STATES — ALL MUST BE IMPLEMENTED

1. Normal reply         White bubble, rose border, complete text
2. Thinking             ThinkingBubble: spinning 🧠 + bouncing 3 dots + italic "thinking…"
3. Tool Use — Running   Blue ToolPill + ProgressView spinner, shows which Apple system
4. Tool Use — Done      Green ToolPill ✓, RichCard below showing real data
5. Streaming            Text builds char by char (26ms) with blinking rose cursor at end
6. Write-Back Action    Action pill (adding reminder/sending message), turns green when done
7. Voice Input          7-bar animated waveform + pulsing voice button + seconds timer

All components already written in MissM/Features/Chat/ChatView.swift

Tool names Claude uses → Swift handler:
  read_calendar    → CalendarService.getEventsToday()
  add_reminder     → RemindersService.addReminder(title:due:)
  read_reminders   → RemindersService.getIncompleteReminders()
  (send_imessage removed in v2.1 — DO NOT re-register this tool with Claude)
  get_weather      → WeatherKit or URLSession
  web_search       → URLSession research queries

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
NSHealthShareUsageDescription:
  "Miss M reads your health data to give personalised wellness and energy insights."
NSHealthUpdateUsageDescription:
  "Miss M logs your mood and wellness data to HealthKit."

---

## 🍎 APPLE INTEGRATIONS — ALL NATIVE, NO THIRD-PARTY

EventKit (Calendar):    EKEventStore — read + write events and reminders
Contacts:               CNContactStore — look up partner and other contacts by name
(Messages AppleScript integration REMOVED in v2.1)
HealthKit:              HKHealthStore — steps, sleep, heart rate, HRV, cycle tracking
Vision:                 VNRecognizeTextRequest — OCR from screenshots + scanned PDFs
PDFKit:                 PDFDocument — extract text from lecture PDFs
NaturalLanguage:        NLTagger, NLTokenizer — sentiment, grammar, readability
NSSpellChecker:         Grammar + spelling in essay writer
Speech:                 SFSpeechRecognizer — voice input transcription
AVFoundation:           AVSpeechSynthesizer — text-to-speech for responses
WeatherKit:             WKWeatherService — weather for morning briefing
CoreLocation:           CLLocationManager — location for weather + nearby study spots
UserNotifications:      UNUserNotificationCenter — local push notifications
LocalAuthentication:    LAContext — Touch ID lock (Phase 7)
NSPasteboard:           Read + write clipboard
NSWorkspace:            Open apps, files, URLs
AppIntents:             Siri Shortcuts — voice commands (Phase 7)
IOKit:                  Battery level + charging status
SystemConfiguration:    WiFi reachability check
NSScreen:               Multi-display awareness for popover placement
Notes (AppleScript):    Read + write Apple Notes
Mail (AppleScript):     Send emails via Mail app
Apple Music (AppleScript): Play focus playlists during Pomodoro

---

## 💬 PEOPLE HUB — CONTACT-BASED (v2.1)

AppleScript Messages-history ingestion has been removed. People Hub now sources contacts from CNContactStore only.

Flow:
1. User taps "Add favourite" and picks from CNContactStore, OR pins a contact from a quick-compose action
2. Partner configured in Settings is auto-pinned at position 1 (no hardcoded name)
3. Relationship label ("Partner", "Family", "Friend", "Classmate", "Lecturer", "Group chat") is user-selected per contact
4. Claude generates 4 smart reply chips per relationship type
5. Tapping a chip drafts an iMessage in the system Messages app via `NSWorkspace.open(url:)` with `sms:` / `imessage:` URL scheme — Miss M does NOT send it herself, the user reviews and hits send

Gradient colours by relationship:
  Partner:     rose (#E91E8C → #C2185B → #880E4F)
  Family:      warm pink (#FF6B9D → #E91E8C)
  Friend:      orange (#FF9800 → #F57C00)
  Classmate:   teal (#26A69A → #00796B)
  Lecturer:    deep blue (#1976D2 → #1565C0)
  Group chat:  dark teal (#00838F → #006064)

---

## 🌅 MORNING BRIEFING — EXACT FORMAT (Phase 3)

Delivered weekdays 7:30am as a UNUserNotificationCenter rich notification AND rendered in the in-app Briefing card (open the popover to see the full card). No iMessage is sent.

Notification title: "Good morning Miss M ☀️"
Notification body:

[Day], [Date]

📚 [Most urgent deadline] — [X] days left
📅 [Event 1 time] · [Event 2 time]
🌤 [Temperature]°C · [brief weather note]
✅ [X] tasks today

[1 line encouragement]
Tap to open Miss M 💬

Data sources: CalendarService.getEventsToday() + RemindersService.getIncompleteReminders() + WeatherKit

---

## 🔐 SECURITY — NON-NEGOTIABLE

Store API key:     KeychainManager.saveAPIKey(_:)    — service: "com.missm.assistant", account: "anthropic-api-key"
Store partner:     KeychainManager — save user-entered partner name (captured in onboarding)
Store licence key: KeychainManager — Miss M Plus subscribers only, account: "missm-licence"
NEVER store in:    UserDefaults, hardcoded strings, .plist, print/log statements
NEVER print:       API key in any log, debug or error output

---

## 💰 API COST — $24 ANTHROPIC ACCOUNT

Model pricing: Sonnet 4.6 = $3 input / $15 output per million tokens
Estimated daily use: ~500-1500 tokens per interaction
Estimated monthly cost: $3-8/month
Estimated runway: 3-8 months on $24

Optimization:
  Simple tasks (quick answers, weather, reminders) → consider claude-haiku-4-5 ($1/$5)
  Complex tasks (essay drafting, research, planning) → claude-sonnet-4-20250514
  Max tokens for chat: 1024 — never exceed unless essay generation

---

## 🚫 NEVER BUILD THESE

No iOS version · No iCloud sync (local only) · No App Store submission
No third-party packages (pure Swift + Apple frameworks only)
No analytics · No ads · No cloud storage · No APNs push (local UserNotifications only)
No Grammarly SDK · No Spotify SDK · No Google SDK · No third-party auth

Everything must use Apple-native frameworks ONLY.

---

## 🐛 ERROR HANDLING

API errors:          Show friendly message in chat — never raw error strings
Permission denied:   Show permission request view with clear reason WHY before asking
Notification fails:  "Couldn't schedule briefing — grant notifications in System Settings → Notifications"
Calendar fails:      "Couldn't read calendar — permission may have been revoked in System Settings"
Keychain errors:     Show "API key error — please re-enter in Settings"
HealthKit errors:    "Health data unavailable — grant access in System Settings → Privacy → Health"

---

## 🏁 FIRST SESSION — DO THIS EXACTLY

1. Say: "I have read CLAUDE.md in full. Starting Phase 1. Opening docs/design/01-chat-advanced.html and docs/design/14-onboarding.html as reference."
2. Create new macOS Xcode project: MissM · com.missm.assistant · SwiftUI · macOS 14.0
3. Add all existing Swift files to correct Xcode groups
4. Add Info.plist permissions listed above
5. Run ⌘B — fix every compile error before proceeding
6. Run ⌘R — confirm ♛ appears in menu bar
7. Click ♛ — confirm onboarding appears
8. Enter API key — confirm chat tab opens
9. Send test message — confirm streaming works
10. Tell user: "Phase 1 working — menu bar live, chat streaming, design is pink. Ready for Calendar + Reminders integration or shall I continue Phase 1 checklist?"

---

## 📊 BUILD TIMELINE ESTIMATE (Claude Code · $100 Max Plan)

Phase 1 — Foundation:     1 evening (2-3 hrs) — working app same night
Phase 2 — School:         3-4 evenings across 1-2 weeks
Phase 3 — Local briefings & notifications: 1 evening
Phase 4 — Home & Life:    2-3 evenings
Phase 5 — Mac Tools:      2-3 evenings
Phase 6 — Health:         1-2 evenings
Phase 7 — Polish:         2-3 evenings

Total: ~4-6 weeks of light evening sessions
Full app usable by Miss M: after Phase 1-3 (within first week)

Max Plan capacity: More than enough — $100/month Max plan handles heavy daily Claude Code use.
This project fits comfortably within 2-3 months even with daily building sessions.

---

---

## v2 FEATURES (April 2026)

### Smart Life Planner (New Sidebar Tab — 🧠)
- 8th tab in sidebar, between Home and Tools
- Cross-references ALL data: Calendar, Reminders, Cycle, Meals, Fitness, Budget, Assignments, HealthKit
- Generates comprehensive 7-day smart plan via Claude
- Each day: schedule blocks + meals + workout + wellness tip
- Cycle-aware: lighter tasks and comfort meals during menstrual phase
- Energy-aware: adjusts if sleep was poor
- "Adjust" feature: tell Claude to tweak the plan naturally
- Persists via DataStore (smart-plan.json)
- File: MissM/Features/Planner/SmartPlannerView.swift

### Smart Fitness (New Wellness Sub-Tab — 💪)
- Under Health tab, alongside Dashboard and Cycle
- Workout suggestion engine powered by Claude
- Cycle-aware: yoga/walking during menstrual, HIIT during ovulation
- Energy level selector (1-5 scale)
- 7-day workout plan with exercise details per day
- Types: Strength, Cardio, Yoga, HIIT, Walking, Rest Day
- Persists via DataStore (fitness-plan.json)
- File: MissM/Features/Wellness/FitnessView.swift

### Flo App Integration (via HealthKit Bridge)
- Flo syncs period data to Apple HealthKit
- Miss M reads menstrual flow, ovulation, cervical mucus from HealthKit
- "Import from Health" button on Cycle Tracker
- Auto-calculates cycle day and cycle length from HealthKit history
- No direct Flo API needed — HealthKit is the bridge
- Enhanced: MissM/Core/Apple/HealthService.swift + CycleTrackerView.swift

### Auto-DND / Focus Mode
- FocusService.swift uses macOS Shortcuts CLI to toggle Focus mode
- Auto-activates when Pomodoro starts or Study session begins
- Auto-deactivates when session ends/pauses
- Cross-device sync: if "Share across devices" is on, DND activates on iPhone/iPad/Watch
- Setup guide built into Pomodoro settings view
- File: MissM/Core/Apple/FocusService.swift

### New File Structure Additions
MissM/Core/Apple/FocusService.swift         — Focus/DND toggle via Shortcuts CLI
MissM/Features/Wellness/FitnessView.swift    — Smart Fitness tab
MissM/Features/Planner/SmartPlannerView.swift — Smart Life Planner tab

---

## v2.1 — COMMERCIAL BUILD (April 2026)

Miss M is now distributed publicly. See `COMMERCIAL.md` for the business
plan, `PRIVACY.md` / `TERMS.md` for legal, and `site/` for the
GitHub Pages marketing site.

Key changes from v2.0:

1. **iMessage features REMOVED.** MessagesService.swift stays on disk
   (rule #9) but is @deprecated — do not wire new features into it.
   Briefings are now local notifications. "Send a message" uses the
   system Messages compose sheet via URL scheme; Miss M never sends.
2. **No more hardcoded "Miss M" / "NyRiian".** Onboarding captures user
   name and optional partner name. Everything that used to reference
   NyRiian by name now reads from config.
3. **Two pricing tiers:** Free BYOK (current flow) and Miss M Plus
   (managed proxy — not yet built; see COMMERCIAL.md §proxy).
4. **Distribution:** one-line `install.sh` installer served from GitHub
   Pages. NOT Mac App Store. Site deploys automatically via
   `.github/workflows/pages.yml`.
5. **Privacy & Terms** live at `PRIVACY.md` + `TERMS.md` and their
   HTML twins at `site/privacy.html` + `site/terms.html`.

Last updated: April 2026 — Miss M v2.1 (commercial)
If anything in this file is unclear, ASK before building.
