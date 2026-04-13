import SwiftUI

// MARK: - Apple Notes Models

struct AppleNote: Identifiable {
    let id = UUID()
    var title: String
    var body: String
    var folder: String
}

// MARK: - Apple Notes ViewModel

@Observable
class AppleNotesViewModel {
    var notes: [AppleNote] = []
    var isLoading = false
    var newNoteTitle = ""
    var newNoteBody = ""
    var showNewNote = false
    var aiSummary = ""
    var isSummarising = false
    private let claudeService: ClaudeService

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
    }

    func fetchNotes() {
        isLoading = true
        let script = """
        tell application "Notes"
            set noteList to ""
            set allNotes to notes of default account
            set noteCount to count of allNotes
            if noteCount > 20 then set noteCount to 20
            repeat with i from 1 to noteCount
                set n to item i of allNotes
                set noteTitle to name of n
                set noteBody to plaintext of n
                if (count of noteBody) > 200 then
                    set noteBody to text 1 thru 200 of noteBody
                end if
                set noteList to noteList & noteTitle & "|||" & noteBody & ":::"
            end repeat
            return noteList
        end tell
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if let text = result.stringValue {
                notes = text.components(separatedBy: ":::").compactMap { entry in
                    let parts = entry.components(separatedBy: "|||")
                    guard parts.count >= 2, !parts[0].isEmpty else { return nil }
                    return AppleNote(title: parts[0], body: parts[1], folder: "Notes")
                }
            }
        }
        isLoading = false
    }

    func createNote() {
        guard !newNoteTitle.isEmpty else { return }
        let escapedTitle = newNoteTitle.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = newNoteBody.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Notes"
            make new note at default account with properties {name:"\(escapedTitle)", body:"\(escapedBody)"}
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        newNoteTitle = ""
        newNoteBody = ""
        showNewNote = false
        fetchNotes()
    }

    func summariseNote(_ note: AppleNote) async {
        isSummarising = true
        do {
            aiSummary = try await claudeService.ask("Summarise this note in 3 bullet points:\n\nTitle: \(note.title)\n\(note.body)")
        } catch {
            aiSummary = "Could not summarise."
        }
        isSummarising = false
    }
}

// MARK: - Apple Notes Sync View

struct AppleNotesSyncView: View {
    let claudeService: ClaudeService
    @State private var vm: AppleNotesViewModel
    @State private var selectedNote: AppleNote?

    init(claudeService: ClaudeService) {
        self.claudeService = claudeService
        self._vm = State(initialValue: AppleNotesViewModel(claudeService: claudeService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("Apple Notes")
                        .font(Theme.Fonts.display(18))
                        .foregroundColor(Theme.Colors.rosePrimary)
                    Spacer()
                    Button(action: { vm.showNewNote.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("New")
                        }
                        .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(RoseButtonStyle())

                    Button(action: vm.fetchNotes) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.rosePrimary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)

                // New Note Form
                if vm.showNewNote {
                    VStack(spacing: 8) {
                        TextField("Note title...", text: $vm.newNoteTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(8)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(8)
                        TextEditor(text: $vm.newNoteBody)
                            .font(.system(size: 11))
                            .frame(height: 80)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(8)
                        HStack {
                            Button("Cancel") { vm.showNewNote = false }
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textSoft)
                                .buttonStyle(.plain)
                            Spacer()
                            Button("Save to Notes") { vm.createNote() }
                                .buttonStyle(RoseButtonStyle())
                                .disabled(vm.newNoteTitle.isEmpty)
                        }
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                // Notes List
                if vm.isLoading {
                    HStack { ProgressView().scaleEffect(0.6); Text("Loading notes...").font(.system(size: 11)).foregroundColor(Theme.Colors.textSoft) }
                        .glassCard(padding: 10)
                        .padding(.horizontal, 14)
                } else if vm.notes.isEmpty {
                    VStack(spacing: 8) {
                        Text("\u{1F4DD}").font(.system(size: 28))
                        Text("No notes yet")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textSoft)
                        Button("Load Notes") { vm.fetchNotes() }
                            .buttonStyle(RoseButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .glassCard(padding: 20)
                    .padding(.horizontal, 14)
                } else {
                    ForEach(vm.notes.prefix(10)) { note in
                        Button(action: { selectedNote = note }) {
                            HStack(spacing: 8) {
                                Text("\u{1F4DD}").font(.system(size: 14))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                        .lineLimit(1)
                                    Text(note.body)
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.Colors.textSoft)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9))
                                    .foregroundColor(Theme.Colors.textXSoft)
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.5))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 14)
                    }
                }

                // Selected Note Detail + AI
                if let note = selectedNote {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(note.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.Colors.textPrimary)
                            Spacer()
                            Button(action: {
                                NSWorkspace.shared.open(URL(string: "notes://")!)
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.up.forward.app")
                                        .font(.system(size: 9))
                                    Text("Open in Notes")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(Theme.Colors.rosePrimary)
                            }
                            .buttonStyle(.plain)
                            Button(action: { selectedNote = nil }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.Colors.textXSoft)
                            }
                            .buttonStyle(.plain)
                        }
                        Text(note.body)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.textMedium)
                            .lineSpacing(2)
                        Button(action: { Task { await vm.summariseNote(note) } }) {
                            HStack(spacing: 4) {
                                if vm.isSummarising { ProgressView().scaleEffect(0.4) }
                                Text(vm.isSummarising ? "..." : "\u{2728} Summarise")
                                    .font(.system(size: 10, weight: .medium))
                            }
                        }
                        .buttonStyle(RoseButtonStyle())

                        if !vm.aiSummary.isEmpty {
                            Text(vm.aiSummary)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineSpacing(3)
                        }
                    }
                    .glassCard(padding: 10)
                    .padding(.horizontal, 14)
                }

                Spacer().frame(height: 14)
            }
            .padding(.top, 10)
        }
    }
}
