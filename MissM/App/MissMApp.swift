import SwiftUI

@main
struct MissMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Miss M") {
            ContentView()
        }
    }
}
