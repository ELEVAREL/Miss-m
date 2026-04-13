import Foundation

// MARK: - Focus Service
// Toggles macOS Focus/DND mode via Shortcuts CLI
// If "Share across devices" is enabled in System Settings > Focus,
// this also activates Focus on iPhone, iPad, and Apple Watch.

@Observable
class FocusService {
    static let shared = FocusService()

    var isStudyModeActive = false
    var focusShortcutName = "Study"
    var isSetupComplete = false

    private init() {
        checkSetup()
    }

    // MARK: - Enable Study Focus

    func enableStudyMode() {
        guard isSetupComplete else { return }
        Task.detached { [focusShortcutName] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", focusShortcutName]
            try? process.run()
            process.waitUntilExit()
        }
        isStudyModeActive = true
    }

    // MARK: - Disable Study Focus

    func disableStudyMode() {
        // Toggle DND off by running a "DND Off" shortcut, or use defaults
        Task.detached {
            // Method 1: Try Shortcuts-based disable
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", "Study Off"]
            try? process.run()
            process.waitUntilExit()

            // Method 2: Fallback — reset DND assertion
            if process.terminationStatus != 0 {
                let fallback = Process()
                fallback.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
                fallback.arguments = ["-currentHost", "write", "com.apple.notificationcenterui", "doNotDisturb", "-boolean", "false"]
                try? fallback.run()
                fallback.waitUntilExit()
            }
        }
        isStudyModeActive = false
    }

    // MARK: - Check if Shortcuts are set up

    func checkSetup() {
        Task.detached { [weak self] in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["list"]
            process.standardOutput = pipe
            try? process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let hasStudy = output.localizedCaseInsensitiveContains("Study")

            await MainActor.run {
                self?.isSetupComplete = hasStudy
            }
        }
    }

    // MARK: - Setup Instructions

    static let setupSteps: [(step: String, detail: String)] = [
        ("Open System Settings", "Go to Focus on your Mac"),
        ("Create a Focus", "Tap the + button and select \"Custom\""),
        ("Name it \"Study\"", "Choose a book or brain icon"),
        ("Enable \"Share Across Devices\"", "This syncs Focus to your iPhone, iPad & Watch"),
        ("Create two Shortcuts", "Open the Shortcuts app and create:\n1. \"Study\" — Turn On Study Focus\n2. \"Study Off\" — Turn Off Study Focus"),
        ("Come back here", "Miss M will auto-detect the shortcuts")
    ]
}
