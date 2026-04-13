# Miss M — Remaining Work

## Status: Phases 1-4 Complete, Phases 5-7 Files Created (Need Integration + Testing)

---

## What's Done (Built & Compiling)

### Phase 1 — Foundation
- [x] Xcode project (macOS App, SwiftUI, com.missm.assistant, macOS 14.0)
- [x] Menu bar icon ♛ + Popover 420x620pt
- [x] OnboardingView with API key -> Keychain
- [x] MainAppView + 6-tab bar (Chat/Today/School/Home/Wellness/Settings)
- [x] Claude API streaming chat with all 7 states
- [x] CalendarService.swift (EventKit read/write)
- [x] RemindersService.swift (EventKit read/write)
- [x] KeychainManager (API key, phone number, husband name)
- [x] Pink design system (Theme.swift) with glass cards
- [x] Settings view (API key, Calendar/Reminders toggles)
- [x] Info.plist + entitlements

### Phase 2 — School
- [x] Assignment Kanban (3-col board, AI priority banner, add/move/delete)
- [x] Essay Writer (outline steps, AI generation per section, editor, stats, tone)
- [x] Study Planner + Pomodoro timer (ring animation, sessions, breaks)
- [x] Flashcards (3D flip with swipe, progress dots, AI generate from notes)
- [x] Marketing Tools (SWOT/STP/Persona/Campaign/PESTLE tabs)
- [x] Research + Citations (AI search, APA/Harvard toggle, citation manager)
- [x] Calendar full view (month grid, day events, upcoming week)
- [x] DataStore (actor-based JSON persistence)

### Phase 3 — iMessage AI
- [x] BriefingScheduler with real Calendar + Reminders data
- [x] Morning briefing (weekdays 7:30am), Evening wind-down (daily 9pm)
- [x] Sunday weekly plan (Sundays 7pm)
- [x] Deadline warnings (3d / 1d / morning of)
- [x] Two-way iMessage monitor (10s poll, auto-reply via Claude)
- [x] iMessage UI (phone setup, toggles, quick send, quick chips)
- [x] Today overview (greeting card, schedule, tasks)

### Phase 4 — Home & Life
- [x] Meal Planner (7-day grid, AI generation, dietary filters)
- [x] Grocery List (5 sections, checkable items, quantities)
- [x] Budget Tracker (donut chart, categories, savings goal, expenses)
- [x] Email Drafter (4 templates, tone selector, AI draft, open in Mail)
- [x] Home Hub overview (card grid, chores, budget summary)

---

## What's Left To Do

### Phase 5 — Mac Power Tools (files exist, need testing + polish)
Files already created:
- MacTools/PDFDropzoneView.swift
- MacTools/ScreenshotOCRView.swift
- MacTools/MenuBarMiniView.swift
- MacTools/SafariCompanionView.swift
- MacTools/FileCommandCentreView.swift
- MacTools/PomodoroMenuBarView.swift
- MacTools/QuickLauncherView.swift

Still needed:
- [ ] Test PDFKit + Vision OCR integration end-to-end
- [ ] Wire QuickLauncher global shortcut (Cmd+Shift+M via NSEvent.addGlobalMonitorForEvents)
- [ ] Test menu bar mini view popover
- [ ] Safari companion — verify page reading works
- [ ] Pomodoro menu bar — connect DND + Apple Music AppleScript
- [ ] Add MacTools tab to app navigation (if not already wired)

### Phase 6 — Health & Wellness (files exist, need HealthKit testing)
Files already created:
- Wellness/WellnessDashboardView.swift
- Wellness/CycleTrackerView.swift
- Core/Apple/HealthService.swift

Still needed:
- [ ] Test HealthKit data reading (steps, sleep, heart rate, HRV)
- [ ] Test cycle tracking (HealthKit CycleTracking API)
- [ ] Wire WellnessView to use WellnessDashboardView (replace placeholder)
- [ ] Verify mood logging and phase correlation
- [ ] Test on a Mac with HealthKit data available

### Phase 7 — Polish & Power (files partially exist)
Files already created:
- Polish/TouchIDLockView.swift
- Polish/VoiceInputView.swift
- Polish/SmartWritingView.swift
- Polish/AppleNotesSyncView.swift
- Polish/SystemDashboardView.swift

Still needed:
- [ ] Siri Shortcuts (App Intents) — 8 voice commands
- [ ] Wire Touch ID lock flow (LAContext)
- [ ] Wire text-to-speech (AVSpeechSynthesizer) into chat
- [ ] Wire voice input (SFSpeechRecognizer) to chat mic button
- [ ] Test Apple Notes sync via AppleScript
- [ ] System dashboard — verify IOKit battery, WiFi reachability
- [ ] Global keyboard shortcut (Cmd+Shift+M)
- [ ] App icon design and integration
- [ ] Lock screen widget (if supported on macOS)

### General
- [ ] Test full end-to-end flow with real API key
- [ ] Verify all Apple permissions are requested properly
- [ ] Test iMessage send/receive on a Mac with Messages signed in
- [ ] Font installation check (Playfair Display, Cormorant Garamond, DM Sans)
- [ ] Final UI polish pass across all screens
