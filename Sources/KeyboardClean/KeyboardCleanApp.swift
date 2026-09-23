import SwiftUI

@main
struct KeyboardCleanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var cleaner = KeyboardCleaner.shared

    var body: some Scene {
        WindowGroup("键盘清理") {
            ContentView(cleaner: cleaner)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Closing the window quits the app (and therefore restores the keyboard).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Always restore the keyboard on quit, no matter how the app exits
    /// (Dock → Quit, app menu → Quit, window close, etc.).
    func applicationWillTerminate(_ notification: Notification) {
        KeyboardCleaner.shared.disable()
    }
}
