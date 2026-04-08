import AppKit

// MARK: - Apple Notes Service (Phase 7)
// AppleScript — read/write Apple Notes: save summaries + study notes

@Observable
class NotesService {
    static let shared = NotesService()

    var recentNotes: [AppleNote] = []
    var errorMessage: String?

    struct AppleNote: Identifiable {
        let id = UUID()
        let name: String
        let body: String
        let folder: String
    }

    // MARK: - Create Note

    func createNote(title: String, body: String, folder: String = "Miss M") async -> Bool {
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        let escapedFolder = folder.replacingOccurrences(of: "\"", with: "\\\"")

        let script = NSAppleScript(source: """
            tell application "Notes"
                tell account "iCloud"
                    if not (exists folder "\(escapedFolder)") then
                        make new folder with properties {name:"\(escapedFolder)"}
                    end if
                    tell folder "\(escapedFolder)"
                        make new note with properties {name:"\(escapedTitle)", body:"\(escapedBody)"}
                    end tell
                end tell
            end tell
        """)

        var error: NSDictionary?
        script?.executeAndReturnError(&error)

        if error != nil {
            errorMessage = "Could not create note — check Notes app access."
            return false
        }

        return true
    }

    // MARK: - Read Notes from Folder

    func readNotes(from folder: String = "Miss M", limit: Int = 10) async -> [AppleNote] {
        let escapedFolder = folder.replacingOccurrences(of: "\"", with: "\\\"")

        let script = NSAppleScript(source: """
            tell application "Notes"
                tell account "iCloud"
                    if exists folder "\(escapedFolder)" then
                        set noteList to ""
                        set noteCount to count of notes of folder "\(escapedFolder)"
                        if noteCount > \(limit) then set noteCount to \(limit)
                        repeat with i from 1 to noteCount
                            set thisNote to note i of folder "\(escapedFolder)"
                            set noteName to name of thisNote
                            set noteBody to plaintext of thisNote
                            set noteList to noteList & noteName & "|||" & noteBody & "|||" & "\(escapedFolder)" & "###"
                        end repeat
                        return noteList
                    else
                        return ""
                    end if
                end tell
            end tell
        """)

        var error: NSDictionary?
        guard let result = script?.executeAndReturnError(&error),
              let text = result.stringValue, !text.isEmpty else {
            return []
        }

        let noteStrings = text.components(separatedBy: "###").filter { !$0.isEmpty }
        var notes: [AppleNote] = []

        for noteString in noteStrings {
            let parts = noteString.components(separatedBy: "|||")
            if parts.count >= 3 {
                notes.append(AppleNote(name: parts[0], body: parts[1], folder: parts[2]))
            }
        }

        recentNotes = notes
        return notes
    }

    // MARK: - Save Summary to Notes

    func saveSummary(title: String, summary: String, source: String? = nil) async -> Bool {
        var body = summary
        if let source = source {
            body += "\n\n---\nSource: \(source)"
        }
        body += "\n\nSaved by Miss M AI — \(Date().formatted(date: .abbreviated, time: .shortened))"

        return await createNote(title: "📝 \(title)", body: body)
    }
}
