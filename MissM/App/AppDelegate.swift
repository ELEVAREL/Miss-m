import AppKit
import SwiftUI
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var pomodoroStatusItem: NSStatusItem?
    var globalHotkeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupPopover()
        setupGlobalHotkey()
        // Hide dock icon — menu bar only
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "♛"
            button.font = NSFont.systemFont(ofSize: 16)
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 420, height: 620)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(
            rootView: ContentView()
        )
    }

    // MARK: - Global Keyboard Shortcut (Cmd+Shift+M) — Phase 7

    private func setupGlobalHotkey() {
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Cmd+Shift+M
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 46 { // 46 = M
                DispatchQueue.main.async {
                    self?.togglePopover()
                }
            }
        }

        // Also monitor local events (when app is active)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 46 {
                DispatchQueue.main.async {
                    self?.togglePopover()
                }
                return nil
            }
            return event
        }
    }

    // MARK: - Pomodoro Menu Bar (Phase 5)

    func showPomodoroInMenuBar(timeRemaining: String) {
        if pomodoroStatusItem == nil {
            pomodoroStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
        pomodoroStatusItem?.button?.title = "⏱ \(timeRemaining)"
        pomodoroStatusItem?.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    }

    func hidePomodoroFromMenuBar() {
        if let item = pomodoroStatusItem {
            NSStatusBar.system.removeStatusItem(item)
            pomodoroStatusItem = nil
        }
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
