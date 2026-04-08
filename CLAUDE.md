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

---

## 🖥️ EXPANDED MAC TOOLS — FULL CAPABILITY LIST

Being native macOS gives Miss M access to the entire Apple ecosystem.
All of these are available via AppleScript, macOS frameworks, or system APIs.
Add these to phases as appropriate.

---

### 📧 MAIL APP (AppleScript)
Send real emails — not just drafts. AI composes, user confirms, Mail sends.
```applescript
tell application "Mail"
    set newMsg to make new outgoing message with properties
        {subject:"[subject]", content:"[body]", visible:true}
    tell newMsg
        make new to recipient with properties {address:"[email]"}
    end tell
    send newMsg
end tell
```
Use cases: Email professor, send assignment submissions, respond to group project

---

### 📝 APPLE NOTES (AppleScript)
Read and create notes. Sync study notes, save AI outputs, essay drafts.
```applescript
-- Create note
tell application "Notes"
    tell account "iCloud"
        make new note at folder "Notes" with properties
            {name:"[title]", body:"[content]"}
    end tell
end tell

-- Read notes (search)
tell application "Notes"
    set matchingNotes to notes whose name contains "[search]"
end tell
```
Use cases: Save essay drafts to Notes, read lecture notes for summarising, create study summaries

---

### 👥 CONTACTS (AddressBook/CNContactStore)
Look up contacts by name for iMessage sending.
```swift
import Contacts
let store = CNContactStore()
let request = CNContactFetchRequest(keysToFetch: [CNContactPhoneNumbersKey, CNContactGivenNameKey] as [CNKeyDescriptor])
try store.enumerateContacts(with: request) { contact, _ in ... }
```
Use cases: "Text my husband" → looks up number → sends via MessagesService

---

### 📄 PDF READING (PDFKit + Vision OCR)
Read lecture slides, textbooks, assignment briefs uploaded as PDFs.
```swift
import PDFKit
import Vision

// Extract text from PDF
let pdf = PDFDocument(url: fileURL)
let text = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")

// OCR scanned PDFs (Vision)
let request = VNRecognizeTextRequest()
VNImageRequestHandler(cgImage: pageImage).perform([request])
let text = request.results?.compactMap { $0.topCandidates(1).first?.string }.joined()
```
Use cases: "Summarise this lecture PDF", "Generate flashcards from this reading", "Find the deadline in this brief"

---

### 📋 CLIPBOARD MANAGER (NSPasteboard)
Read and write the clipboard. Copy AI outputs directly, paste research.
```swift
// Read clipboard
let clipboard = NSPasteboard.general.string(forType: .string) ?? ""

// Write to clipboard
NSPasteboard.general.clearContents()
NSPasteboard.general.setString(text, forType: .string)
```
Use cases: "Copy my essay to clipboard", "Summarise what I just copied", "Format this text I copied"

---

### 🎵 APPLE MUSIC (AppleScript)
Play focus playlists, control music during study sessions.
```applescript
tell application "Music"
    play playlist "Study Focus"
    -- or: set volume to 30
    -- or: pause / play / next track
end tell
```
Use cases: "Play my focus playlist", "Turn music down while I study", auto-pause music during Pomodoro break

---

### 🔕 FOCUS MODE / DO NOT DISTURB (System Events)
Enable Focus/DND during study sessions automatically.
```swift
// Via shortcuts URL scheme
NSWorkspace.shared.open(URL(string: "shortcuts://run-shortcut?name=StudyFocus")!)
```
Use cases: Auto-enable Focus mode when Pomodoro starts, disable when break

---

### 📁 FINDER / FILES (NSOpenPanel + FileManager)
Let Miss M open PDFs, documents, images directly in the app.
```swift
let panel = NSOpenPanel()
panel.allowedContentTypes = [.pdf, .plainText, .image]
panel.begin { response in
    if response == .OK, let url = panel.url { ... }
}
```
Use cases: "Summarise this PDF", "Read my essay draft", "Generate flashcards from this file"

---

### 🖼️ SCREENSHOT + VISION OCR
Capture screen or a selected area, extract text with Vision framework.
```swift
// Capture screen
let image = CGDisplayCreateImage(CGMainDisplayID())

// Extract text
let handler = VNImageRequestHandler(cgImage: image!)
let request = VNRecognizeTextRequest()
try handler.perform([request])
let text = request.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
```
Use cases: "What does this say?" (points at screen), capture assignment from browser, read text from any app

---

### 🌐 SAFARI (AppleScript + WKWebView)
Get current browser URL, page title, selected text.
```applescript
tell application "Safari"
    set currentURL to URL of current tab of window 1
    set pageTitle to name of current tab of window 1
end tell
```
Use cases: "Summarise the page I'm reading", "Save this article to my research", "What is the deadline on this page"

---

### 📊 MICROSOFT WORD / GOOGLE DOCS (AppleScript + API)
Open, read, and write Word documents directly.
```applescript
tell application "Microsoft Word"
    open POSIX file "/path/to/essay.docx"
    set docText to content of text object of active document
end tell
```
Google Docs via REST API with OAuth.
Use cases: Open essay in Word, export AI draft to .docx, read existing assignment

---

### 📅 ZOOM / TEAMS (URL Schemes)
Join meetings automatically based on calendar events.
```swift
// Zoom join
NSWorkspace.shared.open(URL(string: "zoommtg://zoom.us/join?confno=[ID]")!)
// Teams
NSWorkspace.shared.open(URL(string: "msteams://teams.microsoft.com/l/meetup-join/[ID]")!)
```
Use cases: Auto-detect Zoom links in calendar events, "Join my 3pm lecture"

---

### 🔋 SYSTEM STATUS (IOKit + SystemConfiguration)
Battery level, WiFi status, storage space — for smart notifications.
```swift
// Battery
import IOKit.ps
let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
let list = IOPSCopyList(info).takeRetainedValue() as! [[String: Any]]
let battery = list.first?[kIOPSCurrentCapacityKey] as? Int ?? 0

// WiFi
import SystemConfiguration
let reachability = SCNetworkReachabilityCreateWithName(nil, "api.anthropic.com")
```
Use cases: "Charge your Mac — 15% battery", warn if offline before study session, smart notifications

---

### 🗣️ TEXT TO SPEECH (AVSpeechSynthesizer)
Read AI responses aloud — hands-free when cooking or commuting.
```swift
let synth = AVSpeechSynthesizer()
let utterance = AVSpeechUtterance(string: text)
utterance.rate = 0.5
utterance.voice = AVSpeechSynthesisVoice(language: "en-AU")
synth.speak(utterance)
```
Use cases: Read morning briefing aloud, narrate flashcard answers, read essay back to her

---

### 🎙️ VOICE INPUT (Speech Framework)
Already planned in Phase 7 but can add sooner. Transcribes speech to text.
```swift
import Speech
let recogniser = SFSpeechRecognizer(locale: Locale(identifier: "en-AU"))
let request = SFSpeechAudioBufferRecognitionRequest()
// Feed AVAudioEngine buffer → get live transcription
```
Use cases: Voice chat, dictate reminders, speak commands, hands-free operation

---

### 📍 LOCATION (CoreLocation)
Location-aware suggestions — nearest library, coffee shop, campus.
```swift
import CoreLocation
let manager = CLLocationManager()
manager.requestWhenInUseAuthorization()
// CLGeocoder for reverse geocoding
```
Use cases: "Find a quiet cafe near me to study", weather uses location, campus navigation

---

### 🔔 RICH NOTIFICATIONS (UserNotifications)
Already using basic notifications — enhance with actions and images.
```swift
let content = UNMutableNotificationContent()
content.title = "Miss M ♛"
content.body = "Essay due in 2 hours!"
content.categoryIdentifier = "DEADLINE"  // custom action buttons

// Action buttons on notification
let snooze = UNNotificationAction(identifier: "SNOOZE", title: "Snooze 30min")
let start = UNNotificationAction(identifier: "START", title: "Start Writing")
let category = UNNotificationCategory(identifier: "DEADLINE", actions: [snooze, start], ...)
```
Use cases: Tap "Start Writing" on notification → opens essay, "Snooze" delays reminder

---

### ☁️ GOOGLE DRIVE (REST API)
Access her university documents, lecture slides, shared files.
```swift
// OAuth2 + Drive REST API
// GET https://www.googleapis.com/drive/v3/files
// Needs OAuth setup — add in Phase 2 or later
```
Use cases: "Find my marketing lecture slides", "Save essay to Drive", access shared group project files

---

### 📲 PHONE CALL via FaceTime (URL Scheme)
Initiate FaceTime audio calls to contacts.
```swift
NSWorkspace.shared.open(URL(string: "facetime-audio://+[number]")!)
```
Use cases: "Call mum", quick family contact from the assistant

---

### ⌨️ GLOBAL KEYBOARD SHORTCUT
Trigger Miss M from anywhere on the Mac — not just clicking menu bar.
```swift
// Via CGEventTap or NSEvent global monitor
// Example: Cmd+Shift+M opens Miss M from any app
NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
    if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 46 {
        appDelegate.togglePopover()
    }
}
```

---

### 📸 CAMERA (AVCaptureSession)
Mood detection from facial expression — optional, privacy-first.
```swift
// AVCaptureSession + Vision VNDetectFaceLandmarksRequest
// Can detect smile/neutral/frown for mood logging
// Only with explicit user permission — OFF by default
```
Use cases: Auto mood check-in, detect stress during study

---

### 🖥️ MULTI-DISPLAY AWARENESS (NSScreen)
Show popover on correct screen if she uses multiple displays.
```swift
let screens = NSScreen.screens
let mainScreen = NSScreen.main
// Position popover relative to menu bar on active screen
```

---

### SUMMARY — TOOLS TO ADD BY PHASE

Phase 1 (NOW): Calendar, Reminders, Keychain, Menu bar ← already planned
Phase 2: PDF reading (PDFKit+Vision), Clipboard, Files/NSOpenPanel, Safari reading
Phase 3: iMessage monitor ← already planned, Mail send, Contacts lookup
Phase 4: Notes app, Google Drive API, Zoom/Teams join
Phase 5: Apple Music, Focus Mode, Text-to-speech
Phase 6: Battery/WiFi status, Rich notifications with actions, Voice input
Phase 7: Screenshot OCR, Camera mood detection, Global keyboard shortcut, FaceTime, Location

---

---

## 👤 CONTACTS & PEOPLE REFERENCE

Miss M's husband contact name in her phone: "Husband"
When she says "text my husband", "message my husband", "call my husband" etc:
  → Look up contact named "Husband" via CNContactStore
  → Use that number for MessagesService.send() or FaceTime URL scheme
  → Never ask her for his number — always look it up from Contacts

The AI should feel like it knows her life. Examples:
  "Text my husband I'll be home by 7" → finds "Husband" in Contacts → sends iMessage
  "Call my husband" → finds number → opens facetime-audio:// URL
  "What's my husband's number?" → looks up and reads it back to her

Add more named contacts as user provides them.
Future: Mum, Dad, friends etc can be added to this section.

---

## 👤 HUSBAND — CONTACT ASSOCIATION

Miss M's husband's name is: NyRiian
He is saved in her Contacts as: "NyRiian"

When Miss M says ANY of these:
  "my husband", "text my husband", "call my husband",
  "tell my husband", "message my husband", "where is my husband",
  "let my husband know", "NyRiian" directly

→ The AI MUST look up "NyRiian" in CNContactStore
→ Use that number for MessagesService.send() or FaceTime
→ Never ask Miss M for his number — always resolve it from Contacts
→ The AI should feel like it naturally knows who her husband is

Examples:
  "Text my husband I'm on my way home"
  → Finds NyRiian in Contacts → sends iMessage: "I'm on my way home 🩷"

  "Tell my husband dinner is at 7"
  → Finds NyRiian → sends: "Dinner is at 7! 🍽️"

  "Call my husband"
  → Finds NyRiian's number → opens facetime-audio://[number]

  "What is my husband doing tonight?"
  → Checks if NyRiian has shared calendar events (if available)
  → Or just suggests she ask him directly via message

Smart association examples (AI should handle naturally):
  "Can you check if my husband is free Saturday?" → check shared calendar or message him
  "Remind my husband to pick up milk" → sends him an iMessage reminder
  "Draft a message to my husband saying I'll be late" → drafts then sends to NyRiian
