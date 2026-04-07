import SwiftUI

@main
struct MissMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — this is a menu bar app
        Settings {
            SettingsPlaceholderView()
        }
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        Text("Miss M Settings")
            .frame(width: 400, height: 300)
    }
}
