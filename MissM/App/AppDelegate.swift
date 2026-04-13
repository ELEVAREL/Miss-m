import AppKit
import SwiftUI
import Carbon.HIToolbox
import CoreLocation
import Photos
import Speech
import Contacts

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupGlobalHotkey()
        requestAllPermissions()
    }

    /// Request all permissions upfront on first launch so Miss M only asks once
    private func requestAllPermissions() {
        Task {
            // Calendar
            _ = await CalendarService.shared.requestAccess()
            // Reminders
            _ = await RemindersService.shared.requestAccess()
            // HealthKit
            if HealthService.shared.isAvailable {
                _ = await HealthService.shared.requestAccess()
            }
            // Speech Recognition (for voice mode + trigger word)
            _ = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
                SFSpeechRecognizer.requestAuthorization { status in
                    cont.resume(returning: status)
                }
            }
            // Contacts
            let contactStore = CNContactStore()
            _ = try? await contactStore.requestAccess(for: .contacts)
            // Photos
            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            // Location
            let locationManager = CLLocationManager()
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "♛"
            button.font = NSFont.systemFont(ofSize: 16)
            button.action = #selector(showWindow)
            button.target = self
        }
    }

    private func setupGlobalHotkey() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4D534D41)
        hotKeyID.id = 1
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        RegisterEventHotKey(UInt32(kVK_ANSI_M), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let delegate = NSApp.delegate as? AppDelegate else { return noErr }
            DispatchQueue.main.async { delegate.showWindow() }
            return noErr
        }, 1, &eventType, nil, nil)
    }

    @objc func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWindow() }
        return true
    }
}
